{ pkgs ? import <nixpkgs> {} }:

let
  src = pkgs.fetchgit {
    url = "https://cgit.krebsco.de/krops";
    # Commit of tag 1.26.2 (pin the commit, tags can be re-targeted)
    rev = "13ae434b140035e7e2664bd5a8ef4c475413b2e0";
    sha256 = "0mzn213dh3pklvdzfpwi4nin4lncdap447zvl11j81r809jll76j";
  };
in {
  lib = import "${src}/lib";
  pkgs = rec {
    krops = pkgs.callPackage "${src}/pkgs/krops" { inherit populate; };
    populate = pkgs.callPackage "${src}/pkgs/populate" {};
  };
}
