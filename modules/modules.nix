{
  # The modules are topologically sorted by their dependencies.
  # This means that modules only depend on modules higher in the list
  # (unless otherwise noted).
  imports = [
    # Core modules
    ./nix-bitcoin.nix
    ./secrets/secrets.nix
    ./operator.nix

    # Main features
    # This fork maintains only the services its maintainers deploy (see
    # SECURITY.md). Everything else was removed 2026-08-14; the last revision
    # carrying the full upstream set is tag v0.0.139.
    ./bitcoind.nix
    ./lnd.nix
    ./lndconnect.nix # Requires onion-addresses.nix
    ./electrs.nix
    ./btcpayserver.nix

    # Support features
    ./versioning.nix
    ./security.nix
    ./onion-addresses.nix
    ./onion-services.nix
    ./netns-isolation.nix
    ./nodeinfo.nix
    ./backups.nix
  ];

  disabledModules = [ "services/networking/bitcoind.nix" ];
}
