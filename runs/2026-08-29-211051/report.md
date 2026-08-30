# Adversarial LLM audit — 2026-08-29-211051 (report regenerated 2026-08-30 after harness fix)

- Commit audited: `8c86b9162db823c15b26d53dc53a5d68b330761f` (ref `origin/master`, == release tag 2026.08.30.2)
- Models: kimi-k3 glm-5p3 (Fireworks, thinking=max); first run with the sharpened prompt
- Findings: **12** total · 0 critical · 1 high

> NOTE: the original report for this run showed 0 findings due to a harness parse fail-open (models emitted {findings:[...]} not a bare array). Fixed in run.sh; findings below recovered from the per-model JSON.

## [high] lnd ExecStartPost root script follows lnd-planted symlinks when reading admin.macaroon, exfiltrating arbitrary root-readable files to lnd
- model: glm-5p3 · modules/lnd.nix:280 (ExecStartPost 'lnd-create-macaroons', '+'-prefixed root script):0
- fix: Apply the same discipline the file already demands for writes to reads. Either (a) read the macaroon with O_NOFOLLOW semantics (copy it into the root-only staging dir with a no-follow guard, mirroring onion-addresses.nix), or (b) run the xxd read as the lnd user (runuser) so a symlink only exposes lnd-readable files, and/or (c) fail closed unless the bytes look like a v2 macaroon (hex prefix '0201' plus length bounds), which blocks exfiltration of any non-macaroon file.

## [low] lnd REST bound to 0.0.0.0 under wireguard preset; accept rule not interface-scoped
- model: kimi-k3 · modules/presets/wireguard.nix (services.lnd.restAddress, networking.firewall.extraCommands):0
- fix: Work the docs/wireguard-rest-bind.md checklist; scope the accept rule with -i wg-nb when touching it.

## [low] Same root script writes lnd-controlled REST response to /run tmpfs without a size bound
- model: glm-5p3 · modules/lnd.nix:286:0
- fix: Bound the write (e.g. head -c 1M) or validate the response is a plausible macaroon before writing.

## [low] SECURITY.md overstates tag signing: CalVer release tags are unsigned bot tags
- model: glm-5p3 · SECURITY.md:72-75; release-tag.yml 'Tag and release' step; tag 2026.08.30 (58ccea1) has no signature:0
- fix: Scope the SECURITY.md sentence to maintainer commits, or sign release tags with a documented bot key.

## [low] Legacy fetch-release update path is a dead end and, when forced, silently pins archived upstream code without the fork's fixes
- model: glm-5p3 · helper/makeShell.nix:61-69 (update-nix-bitcoin), pkgs/generate-secrets-deprecated.nix:10, examples/importable-configuration.nix:11, docs/install.md:227, docs/nixops-krops-migration.md:29:0
- fix: Delete the update-nix-bitcoin()/fetch-release shell functions and rewrite the remaining doc references to point at the flake pin (github:ostermayer/nix-bitcoin/release).

## [low] lnd admin REST API bound to 0.0.0.0 by the wireguard preset, firewall-only protection with a subnet-scoped (not interface-scoped) accept rule
- model: glm-5p3 · modules/presets/wireguard.nix:126-131 (restAddress = "0.0.0.0"), firewall extraCommands accept rule:0
- fix: No new action; ship the documented second-listener design with the checklist when taken up.

## [low] makePasswordSecret guards on file existence only; an interrupted write can strand an empty secret forever
- model: glm-5p3 · modules/secrets/secrets.nix:99-101 ([[ -e $1 ]] || pwgen -s 20 1 > "$1"):0
- fix: Guard with [[ -s $1 ]] (non-empty) and write via temp file + mv, matching the atomic-rename pattern already used elsewhere in this repo.

## [info] test.yml lacks a top-level permissions block
- model: kimi-k3 · .github/workflows/test.yml:0
- fix: Add 'permissions: { contents: read }' for consistency with the repo's own CI posture.

## [info] Trim residue: dead code and stale references
- model: kimi-k3 · modules/netns-isolation.nix:98 (dead mkCliExec); examples/deploy-krops.sh, examples/deploy-container.sh (invoke removed lightning-cli); SECURITY.md (references deleted helper/push-release.sh):0
- fix: Delete mkCliExec, drop the lightning-cli demo lines, update SECURITY.md.

## [info] Docs show rpc.address=0.0.0.0 / allowip 0.0.0.0/0 without scoping caveat
- model: kimi-k3 · docs/configuration.md (~L95-113):0
- fix: Add one sentence noting the public whitelist's exposure scope follows the firewall rule.

## [info] btcpayserver holds group write on nbxplorer's data directory (broader than its read need)
- model: glm-5p3 · modules/btcpayserver.nix:236 (extraGroups = [ cfg.nbxplorer.group ]), tmpfiles 0770 rule:0
- fix: Consider a read-only bind of just the cookie path for btcpayserver, or 0750 on the datadir plus a group-readable cookie, if the pair is ever decoupled.

## [none] HEAD-adjacent security commits re-verified
- model: kimi-k3 · test/ci/cve-scan.sh, pkgs/btcpayserver/, pkgs/overrides.nix, pkgs/lndinit/, modules/onion-addresses.nix, modules/lnd.nix, pkgs/netns-exec/, modules/secrets/secrets.nix:0
- fix: ?

