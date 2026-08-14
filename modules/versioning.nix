{ config, pkgs, lib, ... }:

# Workflow for releasing a new nix-bitcoin version with incompatible changes:
# Let V be the version of the upcoming, incompatible release.
# 1. Add change descriptions with `version = V` at the end of the `changes` list below.
# 2. Set `nix-bitcoin.configVersion = V` in ../examples/configuration.nix.

with lib;
let
  options = {
    nix-bitcoin.configVersion = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "0.0.92";
      description = ''
        The nix-bitcoin release version that your config is compatible with.

        When upgrading to a backwards-incompatible release, nix-bitcoin will throw an
        error during evaluation and provide instructions for migrating your config to
        the new release.

        Once set, you only need to update this option when explicitly told to in an
        error message during evaluation.
      '';
    };
  };

  # Sorted by increasing version numbers.
  # Historical upstream migration notices (0.0.26 - 0.0.139) were dropped in
  # the fork trim: they all concerned services this fork no longer ships, and
  # several referenced their (now removed) config options.
  changes = [
    {
      version = "0.0.140";
      condition = false; # informational marker only, never fires
      message = ''
        This fork was trimmed to the services its maintainers deploy:
        bitcoind, lnd, electrs, btcpayserver/nbxplorer, lndconnect and the
        supporting infrastructure. clightning (and its plugins/REST servers),
        joinmarket, rtl, mempool, fulcrum, liquid, lightning-loop,
        lightning-pool, charge-lnd and hardware-wallets were removed.
        The last revision with the full upstream set is tag v0.0.139.
      '';
    }
  ];

  version = config.nix-bitcoin.configVersion;

  incompatibleChanges = optionals
    (version != null && versionOlder lastChange)
    (builtins.filter (change: versionOlder change && (change.condition or true)) changes);

  errorMsg = ''

    This version of nix-bitcoin contains the following changes
    that are incompatible with your config (version ${version}):

    ${concatMapStringsSep "\n" (change: ''
      - ${change.message}(This change was introduced in version ${change.version})
    '') incompatibleChanges}
    After addressing the above changes, set nix-bitcoin.configVersion = "${lastChange.version}";
    in your nix-bitcoin configuration.
  '';

  versionOlder = change: (builtins.compareVersions change.version version) > 0;
  lastChange = builtins.elemAt changes (builtins.length changes - 1);
in
{
  imports = [
    ./obsolete-options.nix
  ];

  inherit options;

  config = {
    # Force evaluation. An actual option value is never assigned
    system = optionalAttrs (builtins.length incompatibleChanges > 0) (builtins.throw errorMsg);
  };
}
