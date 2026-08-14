{ config, lib, pkgs, ... }:

with lib;
let
  options = {
    services.lnd.lndconnect = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Add a `lndconnect` binary to the system environment which prints
          connection info for lnd clients.
          See: https://github.com/LN-Zap/lndconnect

          Usage:
          ```bash
            # Print QR code
            lndconnect

            # Print URL
            lndconnect --url
          ```
        '';
      };
      onion = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Create an onion service for the lnd REST server,
          which is used by lndconnect.
        '';
      };
    };

    nix-bitcoin.mkLndconnect = mkOption {
      readOnly = true;
      default = mkLndconnect;
      description = ''
        A function to create a lndconnect binary.
        See the source for further details.
      '';
    };
  };

  nbLib = config.nix-bitcoin.lib;
  runAsUser = config.nix-bitcoin.runAsUserCmd;

  inherit (config.services) lnd;

  mkLndconnect = {
    name,
    shebang ? "#!${pkgs.stdenv.shell} -e",
    port,
    authSecretPath,
    enableOnion,
    onionService ? null,
    certPath ? null
  }:
  # TODO-EXTERNAL:
  # lndconnect requires a --configfile argument, although it's unused
  # https://github.com/LN-Zap/lndconnect/issues/25
  lib.hiPrio (pkgs.writeScriptBin name ''
    ${shebang}
    url=$(
      ${getExe config.nix-bitcoin.pkgs.lndconnect} --url \
        ${optionalString enableOnion "--host=$(cat ${config.nix-bitcoin.onionAddresses.dataDir}/${onionService})"} \
        --port=${toString port} \
        ${if enableOnion || certPath == null then "--nocert" else "--tlscertpath='${certPath}'"} \
        --adminmacaroonpath='${authSecretPath}' \
        --configfile=/dev/null "$@"
    )

    # If --url is in args
    if [[ " $* " =~ " --url " ]]; then
      echo "$url"
    else
      # This UTF-8 encoding yields a smaller, more convenient output format
      # compared to the native lndconnect output
      echo -n "$url" | ${getExe pkgs.qrencode} -t UTF8 -o -
    fi
  '');

  operatorName = config.nix-bitcoin.operator.name;
in {
  inherit options;

  config = mkMerge [
    (mkIf (lnd.enable && lnd.lndconnect.enable)
      (mkMerge [
        {
          environment.systemPackages = [(
            mkLndconnect {
              name = "lndconnect";
              # Run as lnd user because the macaroon and cert are not group-readable
              shebang = "#!/usr/bin/env -S ${runAsUser} ${lnd.user} ${pkgs.bash}/bin/bash";
              enableOnion = lnd.lndconnect.onion;
              onionService = "${lnd.user}/lnd-rest";
              port = lnd.restPort;
              certPath = lnd.certPath;
              authSecretPath = "${lnd.networkDir}/admin.macaroon";
            }
          )];

          services.lnd.restAddress = mkIf (!lnd.lndconnect.onion) "0.0.0.0";
        }

        (mkIf lnd.lndconnect.onion {
          services.tor = {
            enable = true;
            relay.onionServices.lnd-rest = nbLib.mkOnionService {
              target.addr = nbLib.address lnd.restAddress;
              target.port = lnd.restPort;
              port = lnd.restPort;
            };
          };
          nix-bitcoin.onionAddresses.access = {
            ${lnd.user} = [ "lnd-rest" ];
            ${operatorName} = [ "lnd-rest" ];
          };
        })
      ]))
  ];
}
