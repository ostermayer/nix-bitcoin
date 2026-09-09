# Adversarial LLM audit — 2026-09-09-034148

- Commit audited: `c021a3e441a3b7c21c2a75fe28d3f17f01fcdebd` (ref `origin/audit-fixes-2026-09`)
- Models: kimi-k3 (fireworks, thinking=max), glm-5p3 (fireworks, thinking=max)
- Prompt: the exact brief used is saved next to this report as `prompt.used.md`
- Findings: **13** total · 0 critical · 0 high · 0 flagged by >1 model

> LLM findings gate the release: the audit must complete and be reviewed before shipping.

## [medium] Shipped tor 0.4.9.11 misses security release 0.4.9.12
- model: glm-5p3 · confidence: null · supply-chain / stale pin
- flake.lock (nixpkgs pin); fix belongs in pkgs/overrides.nix:0
- attack: null
- fix: Add a version-guarded override pinning tor 0.4.9.12 in pkgs/overrides.nix (the fork's stated policy for exactly this case). Add tor-announce to the subscription list in docs/security-audit-2026-08-14.md section 5, which currently lists no tor feed.

## [medium] btcpayserver 2.4.3 lags security release 2.4.4
- model: glm-5p3 · confidence: null · supply-chain / stale override
- pkgs/overrides.nix; pkgs/btcpayserver/default.nix (version = "2.4.3", deps-2.4.3.json):0
- attack: null
- fix: Bump the override to 2.4.4 with a regenerated nuget lockfile (procedure documented in pkgs/btcpayserver/default.nix). Fold 'check upstream release feed on every pin update' into the weekly routine for btcpayserver and nbxplorer.

## [low] wireguard preset binds lnd admin REST to 0.0.0.0 with the firewall as the only guard, and nothing asserts the firewall is enabled
- model: kimi-k3 · confidence: null · null
- modules/presets/wireguard.nix:186-207 (restAddress = "0.0.0.0"), rules at lines 153-175:0
- attack: null
- fix: Add an assertion `config.networking.firewall.enable` to the wireguard preset (and netns-isolation), or have the preset set it via mkDefault. Long-term, work through docs/wireguard-rest-bind.md and bind to serverAddress.

## [low] public RPC whitelist retains stateless signing and PSBT calls with no in-tree consumer
- model: kimi-k3 · confidence: null · null
- modules/bitcoind-rpc-public-whitelist.nix:58-82:0
- attack: null
- fix: Drop the orphaned PSBT/signing entries from the default whitelist; users who need them can extend services.bitcoind.rpc.users.public.rpcwhitelist (it is already mkDefault).

## [low] bitcoind RPC cookie is group-readable (0640), granting full privileged RPC to group bitcoin
- model: kimi-k3 · confidence: null · null
- modules/bitcoind.nix postStart (chmod 0640 .cookie):0
- attack: null
- fix: Move consumers to dedicated rpc users + HMAC (the pattern already used for public/btcpayserver) and stop group-sharing the cookie.

## [low] cve-whitelist.toml keeps ~13 blanket whole-pname entries that contradict the scan's runtime-closure premise
- model: kimi-k3 · confidence: null · null
- .github/cve-whitelist.toml (gcc, go, cargo, binutils, ninja, patch, ada, lapack, fontforge, mercurial, ShellCheck, async, Diff, stringbuilder):0
- attack: null
- fix: Scope each build-tool entry with an explicit cve list (like the pname-collision section does), or delete the blanket entries and re-add scoped ones only if the runtime scan actually flags them.

## [low] wireguard preset has no release-gating CI coverage
- model: glm-5p3 · confidence: null · test coverage gap
- .github/workflows/test.yml (matrix: default, regtest, netns); test/ci/test-info.nix (derives scenario list from that matrix); test/run-tests.sh:302 (wireguard-lndconnect only in local buildable list):0
- attack: null
- fix: Add wireguard-lndconnect to the test.yml scenario matrix (it is a two-node VM test, modest cost), or fold a wg assertion into the default scenario.

## [info] update-nix-bitcoin pins whatever commit the newest unsigned git tag points at
- model: kimi-k3 · confidence: null · null
- helper/makeShell.nix update-nix-bitcoin():0
- attack: null
- fix: Acceptable given the disclosure; consider signing release tags (CI OIDC/sigstore or a maintainer key) so the updater can verify rather than trust.

## [info] Committed demo SSH private key for the QEMU example VM
- model: kimi-k3 · confidence: null · null
- examples/qemu-vm/id-vm:0
- attack: null
- fix: Optional: generate the keypair at first use instead of committing it.

## [info] nixops deployment makes the secrets directory world-traversable (o+x)
- model: kimi-k3 · confidence: null · null
- modules/deployment/nixops.nix (allowSecretsDirAccess):0
- attack: null
- fix: None required; note for anyone adding new secret types under the nixops method.

## [info] Dev firejail profile enables allow-debuggers
- model: kimi-k3 · confidence: null · null
- dev/dev-env/nix-bitcoin-firejail.conf:0
- attack: null
- fix: Drop allow-debuggers unless a dev workflow needs it.

## [info] Dead code: fetchNodeModules build support kept after RTL removal
- model: glm-5p3 · confidence: null · hygiene / unused attack surface
- pkgs/build-support/fetch-node-modules.nix; referenced only by its own wiring at pkgs/default.nix:16:0
- attack: null
- fix: Delete the file and its callPackage entry, per the fork's own delete-over-add policy.

## [medium-low] wireguard preset exposes lnd admin REST on 0.0.0.0 but never asserts the firewall is enabled
- model: glm-5p3 · confidence: null · missing guard on a load-bearing assumption
- modules/presets/wireguard.nix:97-101 (only assertion is netns incompatibility), :148-180 (firewall extraCommands), :192 (restAddress = "0.0.0.0"):0
- attack: null
- fix: Add an assertion that networking.firewall.enable is true whenever the wg lndconnect mode is active (or whenever restAddress would be 0.0.0.0). This is independent of, and much cheaper than, the deferred rebind work in docs/wireguard-rest-bind.md.

