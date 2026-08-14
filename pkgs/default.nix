let
  nixpkgsPinned = import ./nixpkgs-pinned.nix;
in
# Set default values for use without flakes
{ pkgs ? import <nixpkgs> { config = {}; overlays = []; }
, pkgsUnstable ? import nixpkgsPinned.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = {};
    overlays = [];
  }
, pkgs-25_05 ? import nixpkgsPinned.nixpkgs-25_05 {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = {};
    overlays = [];
  }
}:
let self = {
  lndinit = pkgs.callPackage ./lndinit { };
  nbxplorer = pkgs.callPackage ./nbxplorer { };

  fetchNodeModules = pkgs.callPackage ./build-support/fetch-node-modules.nix { };

  # Internal pkgs
  netns-exec = pkgs.callPackage ./netns-exec { };
  krops = import ./krops { inherit pkgs; };

  # Deprecated pkgs
  generate-secrets = import ./generate-secrets-deprecated.nix;
  nixops19_09 = pkgs.callPackage ./nixops { };

  pinned = import ./pinned.nix pkgs pkgsUnstable pkgs-25_05;

  modulesPkgs = self // self.pinned;
}; in self
