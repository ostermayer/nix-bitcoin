# Adversarial LLM audit — 2026-09-09-025815

- Commit audited: `d22c5daca12431b8fd697b5b61d818938f000e90` (ref `origin/audit-fixes-2026-09`)
- Models: kimi-k3 (fireworks, thinking=max), glm-5p3 (fireworks, thinking=max)
- Prompt: the exact brief used is saved next to this report as `prompt.used.md`
- Findings: **14** total · 0 critical · 0 high · 0 flagged by >1 model

> LLM findings gate the release: the audit must complete and be reviewed before shipping.

## [medium] Weekly CVE scan does not scan the recommended deployment: tor, duplicity and the secure-node preset are absent from the scan target
- model: glm-5p3 · confidence: null · monitoring/detection gap
- test/ci/scan-node.nix; test/ci/cve-scan.sh; README.md (CVE scan claim):0
- attack: null
- fix: Import modules/presets/secure-node.nix (or at minimum enable services.tor + services.backups) in scan-node.nix, then re-baseline .github/cve-whitelist.toml. Secondary note: the whitelist's blanket build-tool pname entries (gcc, go, cargo, ...) should carry the nixpkgs rev they were triaged against, since blanket pnames stay silent across pin moves.

## [low] WireGuard preset binds lnd admin REST API to 0.0.0.0, protected by firewall only
- model: kimi-k3 · confidence: null · null
- modules/presets/wireguard.nix:186:0
- attack: null
- fix: null

## [low] `+`-prefixed rootScript runs fully unsandboxed (bypasses ProtectSystem=strict), not just User=
- model: kimi-k3 · confidence: null · null
- pkgs/lib.nix (rootScript), modules/lnd.nix:257-310:0
- attack: null
- fix: null

## [low] lnd REST (admin-macaroon API) bound to 0.0.0.0 in the wireguard preset, protected by the host firewall alone
- model: glm-5p3 · confidence: null · defense-in-depth / network exposure
- modules/presets/wireguard.nix:186 (restAddress = "0.0.0.0"):0
- attack: null
- fix: Ship the deferral doc's own recommended design: keep restAddress at 127.0.0.1 and add a second listener via services.lnd.extraConfig 'restlisten=<serverAddress>:<port>' plus the lnd-wants-wireguard ordering and the doc's pre-flight checklist. That variant avoids all six documented breakages.

## [low] Documented krops install/update flow is dead post-guard, and its only signposted exit deploys unpatched archived upstream
- model: glm-5p3 · confidence: null · documentation / supply chain
- docs/install.md:226 (§3.3 'Obtain the hash of the latest nix-bitcoin release'); docs/configuration.md:14-18 ('Updating nix-bitcoin' / update-nix-bitcoin); examples/importable-configuration.nix:8-12; helper/makeShell.nix:65-77 (update-nix-bitcoin -> fetch-release):0
- attack: null
- fix: Rewrite install.md §3.3, configuration.md's update section, and importable-configuration.nix around a fork-native pin (e.g. builtins.fetchTarball of a pinned commit of ostermayer/nix-bitcoin, or a flake-ref krops source). If the upstream escape hatch stays, have it emit a loud 'UNPATCHED UPSTREAM, NOT THIS FORK' marker into the generated nix-bitcoin-release.nix.

## [low] Release tags are unsigned, contradicting SECURITY.md's signing claim
- model: glm-5p3 · confidence: null · release integrity / docs accuracy
- .github/workflows/release-tag.yml (git tag -a, bot identity, no signing key); SECURITY.md ('Commits and tags on this fork are signed with the maintainer's SSH key'):0
- attack: null
- fix: Either sign tags in the release job (tag -s with a protected key, or move tagging to a maintainer-side signed step), or narrow the SECURITY.md claim to commits and manually created tags.

## [low] setup-secrets: root service handling the entire secrets dir with zero systemd sandboxing
- model: glm-5p3 · confidence: null · hardening / defense-in-depth
- modules/secrets/secrets.nix:200-246 (systemd.services.setup-secrets):0
- attack: null
- fix: Apply a scoped sandbox: ProtectSystem=strict, ReadWritePaths=<secretsDir>, PrivateTmp, NoNewPrivileges, RestrictAddressFamilies=AF_UNIX, CapabilityBoundingSet=CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE (CAP_DAC_READ_SEARCH only if the manual-setup path requires reading foreign files).

## [low] btcpayserver/nbxplorer rely on the NixOS default postgres HBA; the shared unix socket is the real (and netns-invisible) cross-service boundary
- model: glm-5p3 · confidence: null · isolation boundary / verify
- modules/btcpayserver.nix:126-145 (services.postgresql: ensureDatabases/ensureUsers + ALTER DATABASE OWNER; no explicit services.postgresql.authentication):0
- attack: null
- fix: Set services.postgresql.authentication explicitly in the module (peer for local unix-socket connections, or scram for anything else) so the boundary does not track nixpkgs defaults across weekly pin moves; verify the generated pg_hba.conf in the VM test.

## [info] bitcoind .cookie is group-readable, granting full privileged RPC to group bitcoin (operator)
- model: kimi-k3 · confidence: null · null
- modules/bitcoind.nix postStart:0
- attack: null
- fix: null

## [info] Operator is funds-equivalent by design (nopass doas to lnd, netns-exec cap_sys_admin)
- model: kimi-k3 · confidence: null · null
- modules/operator.nix:50-56, modules/netns-isolation.nix:84-90:0
- attack: null
- fix: null

## [info] nix-bitcoin-wg-connect host autodetection queries third-party IP-echo services
- model: kimi-k3 · confidence: null · null
- modules/presets/wireguard.nix (wgConnect script):0
- attack: null
- fix: null

## [info] Committed SSH private key in examples/qemu-vm
- model: kimi-k3 · confidence: null · null
- examples/qemu-vm/id-vm:0
- attack: null
- fix: null

## [info] cve-scan.sh summary text contradicts scan target
- model: kimi-k3 · confidence: null · null
- test/ci/cve-scan.sh (triage hint line):0
- attack: null
- fix: null

## [info] tests.py retains dead branches for services removed by the trim
- model: glm-5p3 · confidence: null · test hygiene
- test/tests.py (netns-isolation: clightning/liquidd/rtl/lightning-loop reachability lists; backups: clightning/joinmarket file list; regtest: fulcrum/clightning/lightning-loop/lightning-pool/mempool blocks; joinmarket capsh check):0
- attack: null
- fix: Delete the dead branches; keep one explicit assertion that trimmed-service netns names are rejected by netns-exec (which is the actual invariant).


> Second opinion by gpt-6-astra (codex, thinking=xhigh): **ok** — see `second-opinion.gpt-6-astra.md`.
