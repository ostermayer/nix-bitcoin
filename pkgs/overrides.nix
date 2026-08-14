# Security-driven version overrides for packages whose pinned nixpkgs
# version ships known vulnerabilities.
#
# Each override is version-guarded: once the pinned nixpkgs reaches the
# fixed version, the override turns inert and the nixpkgs package is used
# unchanged. Flake updates are therefore always safe to take; overrides
# simply stop applying. Keep the `lagging` version exactly equal to the
# first fixed release.
#
# Hashes for fetchurl entries were taken from the upstream signed
# SHA256SUMS files (GPG verification also runs at build time).
{ pkgs, pkgsUnstable }:
let
  inherit (pkgs) lib;
  lagging = pkg: version: lib.versionOlder pkg.version version;
  fakeHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
in
{
  # clboss 0.16.2 ("Leak of Faith") fixes a fund-theft vector: FundsMover
  # self-payments settled the returning HTLC without checking the amount,
  # letting the last-hop peer steal the difference. nixpkgs ships 0.16.1.
  clboss = if lagging pkgsUnstable.clboss "0.16.2" then pkgsUnstable.clboss.overrideAttrs (old: rec {
    version = "0.16.2";
    src = pkgs.fetchzip {
      url = "https://github.com/ZmnSCPxj/clboss/releases/download/v${version}/clboss-v${version}.tar.gz";
      hash = fakeHash;
    };
  }) else pkgsUnstable.clboss;

  # clightning 26.06 fixes unrecoverable funds loss via fundchannel_complete
  # accepting PSBTs with unsigned non-segwit inputs (PR #8922), plus two
  # crash DoS (PR #8751, #9174). nixos-26.05 ships 26.04.1.
  clightning = if lagging pkgs.clightning "26.06.6" then pkgs.clightning.overrideAttrs (old: rec {
    version = "26.06.6";
    src = pkgs.fetchurl {
      url = "https://github.com/ElementsProject/lightning/releases/download/v${version}/clightning-v${version}.zip";
      hash = fakeHash;
    };
  }) else pkgs.clightning;

  # lightning-loop 0.34.0 bumps vulnerable transitive Go dependencies.
  lightning-loop = if lagging pkgsUnstable.lightning-loop "0.34.0-beta" then pkgsUnstable.lightning-loop.overrideAttrs (old: rec {
    version = "0.34.0-beta";
    src = pkgs.fetchFromGitHub {
      owner = "lightninglabs";
      repo = "loop";
      rev = "v${version}";
      hash = fakeHash;
    };
    vendorHash = fakeHash;
  }) else pkgsUnstable.lightning-loop;

  # bitcoind-knots 29.4.knots20260508 carries the Bitcoin Core 29.4 fixes.
  # nixpkgs-unstable ships 29.3.knots20260508.
  bitcoind-knots = if lagging pkgsUnstable.bitcoind-knots "29.4.knots20260508" then pkgsUnstable.bitcoind-knots.overrideAttrs (old: rec {
    version = "29.4.knots20260508";
    src = pkgs.fetchurl {
      url = "https://bitcoinknots.org/files/29.x/${version}/bitcoin-${version}.tar.gz";
      # From the signed SHA256SUMS at the same URL
      hash = "sha256-36032ab380ac1337fb73dcbbd32a7bae8669cd2c82c440929083e7ae67fee1ab";
    };
  }) else pkgsUnstable.bitcoind-knots;
}
