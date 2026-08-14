# Security-driven version overrides for packages whose pinned nixpkgs
# version ships known vulnerabilities.
#
# Each override must be version-guarded so it turns inert once the pinned
# nixpkgs catches up. Flake updates are then always safe to take.
#
# Example (from the clboss fund-theft fix, since resolved by
# trimming clightning support from this fork):
#
#   clboss = if lagging pkgsUnstable.clboss "0.16.2" then pkgsUnstable.clboss.overrideAttrs (old: rec {
#     version = "0.16.2";
#     src = pkgs.fetchzip {
#       url = "https://github.com/ZmnSCPxj/clboss/releases/download/v${version}/clboss-v${version}.tar.gz";
#       hash = "...";
#     };
#   }) else pkgsUnstable.clboss;
{ pkgs, pkgsUnstable }:
let
  inherit (pkgs) lib;
  lagging = pkg: version: lib.versionOlder pkg.version version;
in
{
}
