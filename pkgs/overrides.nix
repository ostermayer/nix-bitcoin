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
  # 2.4.3 (2026-08-24) is a security release ("updating is recommended for
  # servers shared with many users"); nixpkgs 26.05 carries 2.4.2. The nuget
  # deps changed (HtmlSanitizer 9.1.982 -> 9.2.995 among others), so this is a
  # full package copy with a regenerated lockfile (see ./btcpayserver/) —
  # buildDotnetModule can't take nugetDeps via overrideAttrs. Drop the copy
  # together with this override once the pin catches up.
  btcpayserver = if lagging pkgs.btcpayserver "2.4.4"
                 then pkgs.callPackage ./btcpayserver { }
                 else pkgs.btcpayserver;
}
