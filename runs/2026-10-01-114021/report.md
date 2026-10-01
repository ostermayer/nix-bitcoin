# Adversarial LLM audit — 2026-10-01-114021

- Commit audited: `b314aa94eb69da924c09ed5893676540f5cada20` (ref `rc-2026-10-01`)
- Models: kimi-k3 (fireworks, thinking=max), glm-5p3 (fireworks, thinking=max)
- Prompt: the exact brief used is saved next to this report as `prompt.used.md`
- Findings: **13** total · 0 critical · 0 high · 0 flagged by >1 model

> LLM findings gate the release: the audit must complete and be reviewed before shipping.

## [medium] lnd admin REST API bound to 0.0.0.0 by the wireguard preset, protected by the firewall alone
- model: glm-5p3 · confidence: null · null
- ?:0
- attack: null
- fix: Implement the second-restlisten variant from docs/wireguard-rest-bind.md, including its pre-flight checklist (ordering, TLS SANs are not needed for the nocert path, cold-boot test asserting REST is not reachable on the external interface).

## [low] Demo QEMU VM forwards SSH on all host interfaces with a committed private key
- model: kimi-k3 · confidence: null · null
- examples/qemu-vm/run-vm.sh:29 (hostfwd=tcp::${sshPort}-:22), examples/qemu-vm/id-vm, examples/qemu-vm/vm-config.nix:12, examples/deploy-krops.sh:0
- attack: null
- fix: Bind the forward to loopback: hostfwd=tcp:127.0.0.1:${sshPort}-:22. Keep the existing key-replacement warning.

## [low] lnd one point release behind upstream (0.21.3-beta vs 0.21.4-beta)
- model: kimi-k3 · confidence: null · null
- flake.lock (nixpkgs-unstable @ b6c8664d), pkgs/pinned.nix:0
- attack: null
- fix: No action beyond the normal weekly pin update. Same for electrs 0.11.0 -> 0.12.0 (rewrite, no security content, but watch whether 0.11.x keeps receiving fixes).

## [low] wireguard preset: lnd admin REST API bound to 0.0.0.0, guarded only by iptables
- model: kimi-k3 · confidence: null · null
- modules/presets/wireguard.nix:207, docs/wireguard-rest-bind.md:0
- attack: null
- fix: Work through docs/wireguard-rest-bind.md when bandwidth allows; until then the current assertions are the right guardrail.

## [low] bitcoind RPC cookie group-readable: group 'bitcoin' equals full privileged RPC
- model: kimi-k3 · confidence: null · null
- modules/bitcoind.nix postStart (chmod 0640 .cookie):0
- attack: null
- fix: None required. Keep new consumers on rpc.users + HMAC.

## [low] bitcoind RPC cookie is group-readable: every member of group bitcoin gets full privileged RPC
- model: glm-5p3 · confidence: null · null
- ?:0
- attack: null
- fix: None required now. Keep group membership minimal and prefer the existing rpc-user pattern for any new consumer.

## [low] btcpayserver fetches price rates over clearnet, correlating invoice activity with the node IP
- model: glm-5p3 · confidence: null · null
- ?:0
- attack: null
- fix: Track upstream btcpayserver rate-fetch proxy support and re-enable enforcement when it lands.

## [low] netns-isolation service ids are not asserted unique
- model: glm-5p3 · confidence: null · null
- ?:0
- attack: null
- fix: Add an assertion comparing the id list for duplicates.

## [info] nix-bitcoin-wg-connect without an explicit host queries external-IP providers in clearnet
- model: glm-5p3 · confidence: null · null
- ?:0
- attack: null
- fix: None required. Operators who care can pass the host explicitly, as docs/services.md already shows.

## [info] The shared 'public' RPC user whitelist includes getpeerinfo and getnodeaddresses
- model: glm-5p3 · confidence: null · null
- ?:0
- attack: null
- fix: None now. If the fork ever ships a public RPC proxy scenario, split the local and public users.

## [info] Flake example ships a plaintext demo login password
- model: glm-5p3 · confidence: null · null
- ?:0
- attack: null
- fix: None required. Could switch the template to initialPassword with a forced change, but the FIXME suffices.

## [informational] test/lib/copy-src.sh reuses a fixed /tmp source-cache path and executes from it
- model: kimi-k3 · confidence: null · null
- test/lib/copy-src.sh:0
- attack: null
- fix: Skip the cache when /tmp/nix-bitcoin-src is not owned by euid, or key the cache dir by user.

## [informational] CI evals repo-controlled Nix output in a shell eval; workflow-level CACHIX secrets
- model: kimi-k3 · confidence: null · null
- test/ci/build_test_drivers.sh:21-23, .github/workflows/test.yml:0
- attack: null
- fix: Optional: move secrets from workflow-level env to the single job/step that pushes, and gate the push step on github.event_name != 'pull_request'.


> Second opinion by gpt-6-astra (codex, thinking=xhigh): **ok** — see `second-opinion.gpt-6-astra.md`.
