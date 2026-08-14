# This module enables unprivileged users to read onion addresses.
# By default, onion addresses in /var/lib/tor/onion are only readable by the
# tor user.
# The included service copies onion addresses to /var/lib/onion-addresses/<user>/
# and sets permissions according to option 'access'.

{ config, lib, ... }:

with lib;
let
  options.nix-bitcoin.onionAddresses = {
    access = mkOption {
      type = with types; attrsOf (listOf str);
      default = {};
      description = ''
        This option controls who is allowed to access onion addresses.
        For example, the following allows user 'myuser' to access bitcoind
        and lnd onion addresses:
        ```nix
        {
          "myuser" = [ "bitcoind" "lnd" ];
        };
        ```
        The onion hostnames can then be read from
        {file}`/var/lib/onion-addresses/myuser`.
      '';
    };
    services = mkOption {
      type = with types; listOf str;
      default = [];
      description = ''
        Services that can access their onion address via file
        {file}`/var/lib/onion-addresses/<service>`
        The file is readable only by the service user.
      '';
    };
    dataDir = mkOption {
      readOnly = true;
      default = "/var/lib/onion-addresses";
    };
  };

  cfg = config.nix-bitcoin.onionAddresses;
  nbLib = config.nix-bitcoin.lib;
in {
  inherit options;

  config = mkIf (cfg.access != {} || cfg.services != []) {
    systemd.services.onion-addresses = {
      wantedBy = [ "tor.service" ];
      bindsTo = [ "tor.service" ];
      after = [ "tor.service" ];
      serviceConfig = nbLib.defaultHardening // {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "onion-addresses";
        StateDirectoryMode = "771";
        PrivateNetwork = true; # This service needs no network access
        PrivateUsers = false;
        CapabilityBoundingSet = "CAP_CHOWN CAP_FSETID CAP_SETFCAP CAP_DAC_OVERRIDE CAP_DAC_READ_SEARCH CAP_FOWNER CAP_IPC_OWNER";
      };
      # This service runs as root with CAP_DAC_OVERRIDE/CAP_DAC_READ_SEARCH/
      # CAP_CHOWN, so it must never follow an attacker-planted symlink: doing so
      # would let a compromised service user redirect a read or a chown to an
      # arbitrary path (e.g. copy a macaroon out, or take ownership of /etc/shadow).
      # Two rules enforce this:
      #   1. Refuse to read a Tor hostname file that is a symlink.
      #   2. Build each output directory as root:root, fully populate it, and
      #      only THEN hand ownership to the target user — so the user never has
      #      write access to the directory while root is still writing into it,
      #      and there is no window to race a symlink in. All chowns use `-h` so
      #      a symlink is never dereferenced even if one somehow appears.
      script = ''
        set -euo pipefail

        waitForFile() {
          local file=$1
          for ((i=0; i<300; i++)); do
            if [[ -e $file ]]; then
              return
            fi
            sleep 0.1
          done
          echo "Error: File $file did not appear after 30 sec." >&2
          exit 1
        }

        # Copy a Tor hostname file, refusing to read it through a symlink.
        copyOnionFile() {
          local src=$1 dst=$2
          waitForFile "$src"
          if [[ -L $src ]]; then
            echo "Error: refusing to read onion hostname via symlink: $src" >&2
            exit 1
          fi
          install -T -m 400 "$src" "$dst"
        }

        # Wait until tor is up
        waitForFile /var/lib/tor/state

        if [[ -L ${cfg.dataDir} ]]; then
          echo "Error: ${cfg.dataDir} is a symlink" >&2
          exit 1
        fi
        cd ${cfg.dataDir}
        rm -rf -- ./*

        ${concatMapStrings
          (user: ''
            # Create the dir as root:root 0700 and keep it that way while writing:
            # the target user cannot enter it, so cannot plant a symlink to race.
            mkdir -p -m 0700 -- '${user}'
            ${concatMapStrings
              (service: ''
                copyOnionFile '/var/lib/tor/onion/${service}/hostname' '${user}/${service}'
                chown -h '${user}' '${user}/${service}'
              '')
              cfg.access.${user}
             }
            # Hand the fully-populated directory to the user last.
            chown -h '${user}' '${user}'
          '')
          (builtins.attrNames cfg.access)
        }

        ${optionalString (cfg.services != []) ''
          # Root-owned, world-traversable (not writable): each service reads only
          # its own 0400 file by exact path; no user can plant symlinks here.
          mkdir -p -m 0755 -- services
          ${concatMapStrings (service: ''
            copyOnionFile '/var/lib/tor/onion/${service}/hostname' 'services/${service}'
            chown -h '${config.systemd.services.${service}.serviceConfig.User}' 'services/${service}'
          '') cfg.services}
        ''}
      '';
    };
  };
}
