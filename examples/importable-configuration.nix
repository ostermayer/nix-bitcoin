# You can directly copy and import this file to use nix-bitcoin
# in an existing NixOS configuration.
# Make sure to check and edit all lines marked by 'FIXME:'

# See ./flakes/flake.nix on how to include nix-bitcoin in a flake-based
# system configuration.

let
  # FIXME:
  # Pin a commit of this fork (NOT an upstream fort-nix release — those lack
  # the fork's fixes). Get the hash with
  #   nix-prefetch-url --unpack https://github.com/ostermayer/nix-bitcoin/archive/<commit>.tar.gz
  # or let `update-nix-bitcoin` in the deployment shell write it for you.
  nix-bitcoin = builtins.fetchTarball {
    url = "https://github.com/ostermayer/nix-bitcoin/archive/<commit>.tar.gz";
    sha256 = "<hash>";
  };
in
{ config, pkgs, lib, ... }: {
  imports = [
    "${nix-bitcoin}/modules/modules.nix"
  ];

  # Automatically generate all secrets required by services.
  # The secrets are stored in /etc/nix-bitcoin-secrets
  nix-bitcoin.generateSecrets = true;

  # Enable some services.
  # See ./configuration.nix for all available features.
  services.bitcoind.enable = true;
  services.lnd.enable = true;

  # Enable interactive access to nix-bitcoin features (like bitcoin-cli) for
  # your system's main user
  nix-bitcoin.operator = {
    enable = true;
    # FIXME: Set this to your system's main user
    name = "main";
  };

  # Prevent garbage collection of the nix-bitcoin source
  system.extraDependencies = [ nix-bitcoin ];
}
