# vulnix for the CVE scan (test/ci/cve-scan.sh).
#
# NVD's .json.gz feed intermittently returns 404 (the 2026-09-21 CI scan and
# four node scans in the week of 2026-09-29 failed on it). vulnix upstream falls
# back to the .json.zip copy of the same feed since 4b14b4b (2026-09-30), which
# is newer than any release nixpkgs carries. Build that commit on top of the
# pinned package; the override turns itself off once nixpkgs is past 1.12.5.
{ pkgs }:
if pkgs.lib.versionAtLeast pkgs.vulnix.version "1.12.6" then pkgs.vulnix
else pkgs.vulnix.overrideAttrs (_: {
  version = "1.12.5-unstable-2026-09-30";
  src = pkgs.fetchFromGitHub {
    owner = "nix-community";
    repo = "vulnix";
    rev = "4b14b4bf3e627946a162ca8ae4a6b406c77a7aa2";
    hash = "sha256-KLEd3hchTqLBA6KTupfuOXsx2IuqyvWCPxj5WiU88/c=";
  };
})
