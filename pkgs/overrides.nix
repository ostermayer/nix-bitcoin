# Security-driven version overrides for packages whose pinned nixpkgs
# version ships known vulnerabilities.
#
# Each override is version-guarded: once the pinned nixpkgs reaches the
# fixed version, the override turns inert and the nixpkgs package is used
# unchanged. Flake updates are therefore always safe to take; overrides
# simply stop applying. Keep the `lagging` version exactly equal to the
# first fixed release.
#
# Entry pattern (hash from the upstream signed SHA256SUMS, SRI format):
#
#   lnd = if lagging pkgsUnstable.lnd "0.21.2-beta" then
#     pkgsUnstable.lnd.overrideAttrs (old: rec {
#       version = "0.21.2-beta";
#       src = pkgs.fetchFromGitHub {
#         owner = "lightningnetwork";
#         repo = "lnd";
#         rev = "v${version}";
#         hash = "sha256-...";
#       };
#     }) else pkgsUnstable.lnd;
#
# The 2026-08-14 entries (clboss, clightning, lightning-loop,
# bitcoind-knots) were dropped with the fork trim: those packages are no
# longer shipped. See tag v0.0.139 for the full upstream set.
{ pkgs, pkgsUnstable }:
let
  inherit (pkgs) lib;
  lagging = pkg: version: lib.versionOlder pkg.version version;
in
{
}
