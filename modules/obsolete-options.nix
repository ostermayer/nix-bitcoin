{ lib, config, ... }:

with lib;
let
  mkRenamedAnnounceTorOption = service:
    # use mkRemovedOptionModule because mkRenamedOptionModule fails with an infinite recursion error
    mkRemovedOptionModule [ "services" service "announce-tor" ] ''
      Use option `nix-bitcoin.onionServices.${service}.public` instead.
    '';

  mkSplitEnforceTorOption = service:
    (mkRemovedOptionModule [ "services" service "enforceTor" ] ''
      The option has been split into options `tor.proxy` and `tor.enforce`.
      Set `tor.proxy = true` to proxy outgoing connections with Tor.
      Set `tor.enforce = true` to only allow connections (incoming and outgoing) through Tor.
    '');
  mkRenamedEnforceTorOption = service:
    (mkRenamedOptionModule [ "services" service "enforceTor" ] [ "services" service "tor" "enforce" ]);

  # Services removed in the fork trim. Give users a clear eval
  # error instead of a bare "option does not exist".
  mkTrimmedServiceModule = service:
    mkRemovedOptionModule [ "services" service ] ''
      The `${service}` service was removed from this fork, which maintains
      only the services its maintainers deploy (see SECURITY.md). The last
      revision with the full upstream service set is tag v0.0.139 (identical
      to the final fort-nix/nix-bitcoin release).
    '';
in {
  imports = [
    (mkRenamedOptionModule [ "services" "bitcoind" "bind" ] [ "services" "bitcoind" "address" ])
    (mkRenamedOptionModule [ "services" "bitcoind" "rpcallowip" ] [ "services" "bitcoind" "rpc" "allowip" ])
    (mkRenamedOptionModule [ "services" "bitcoind" "rpcthreads" ] [ "services" "bitcoind" "rpc" "threads" ])
    (mkRenamedOptionModule [ "services" "lnd" "rpclisten" ] [ "services" "lnd" "rpcAddress" ])
    (mkRenamedOptionModule [ "services" "lnd" "listen" ] [ "services" "lnd" "address" ])
    (mkRenamedOptionModule [ "services" "lnd" "listenPort" ] [ "services" "lnd" "port" ])
    (mkRenamedOptionModule [ "services" "btcpayserver" "bind" ] [ "services" "btcpayserver" "address" ])

    (mkRenamedOptionModule [ "nix-bitcoin" "setup-secrets" ] [ "nix-bitcoin" "setupSecrets" ])

    (mkRenamedAnnounceTorOption "lnd")

    # 0.0.53
    (mkRemovedOptionModule [ "services" "electrs" "high-memory" ] ''
      This option is no longer supported by electrs 0.9.0. Electrs now always uses
      bitcoin peer connections for syncing blocks. This performs well on low and high
      memory systems.
    '')
    # 0.0.86
    (mkRemovedOptionModule [ "services" "lnd" "restOnionService" "enable" ] ''
      Set the following options instead:
      services.lnd.lndconnect = {
        enable = true;
        onion = true;
      }
    '')
    (mkRemovedOptionModule [ "services" "lnd" "lndconnectOnion" ] ''
      Set the following options instead:
      services.lnd.lndconnect = {
        enable = true;
        onion = true;
      }
    '')
  ] ++
  # 0.0.59
  (map mkSplitEnforceTorOption [
    "lnd"
    "bitcoind"
  ]) ++
  (map mkRenamedEnforceTorOption [
    "btcpayserver"
    "electrs"
  ]) ++
  # Fork trim
  (map mkTrimmedServiceModule [
    "clightning"
    "clightning-rest"
    "charge-lnd"
    "fulcrum"
    "joinmarket"
    "joinmarket-ob-watcher"
    "lightning-loop"
    "lightning-pool"
    "liquidd"
    "mempool"
    "rtl"
    "spark-wallet"
  ]);
}
