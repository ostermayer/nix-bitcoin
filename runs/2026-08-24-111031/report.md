# Adversarial LLM audit — 2026-08-24-111031

- Commit audited: `121406c4eb63781a01b101e2c07909313305fecd` (ref `origin/master`)
- Models: kimi-k3 glm-5p2 (Fireworks, thinking=medium)
- Prompt: the exact brief used is saved next to this report as `prompt.used.md`
- Findings: **12** total · 0 critical · 0 high · 0 flagged by >1 model

> LLM findings are ADVISORY input to human review — not a release gate.

- [medium] WireGuard preset rebinds lnd admin REST API to 0.0.0.0 as a side effect of enabling lndconnect (kimi-k3) — null:null
- [low] Inverted dirty-tree guard: check fires when -f is given, not when it is absent (kimi-k3) — null:null
- [info] netns-exec execs target with caller's full environment (kimi-k3) — null:null
- [info] Dead code: mkCliExec / cliExec wiring unused (kimi-k3) — null:null
- [info] Stale nixpkgs-25_05 input is threaded through pinned.nix but unused (kimi-k3) — null:null
- [info] Committed demo SSH private key (kimi-k3) — null:null
- [none] All shipped components at versions with no known applicable advisories (kimi-k3) — null:null
- [none] HEAD's four onion-hostname/secret-file fixes are correctly implemented (kimi-k3) — null:null
- [low] wireguard preset binds lnd admin REST API to 0.0.0.0, protected only by the firewall (glm-5p2) — modules/presets/wireguard.nix:null
- [low] btcpayserver and nbxplorer silently disable MemoryDenyWriteExecute (W^X) (glm-5p2) — modules/btcpayserver.nix:null
- [info] onion-addresses content-validation fix (121406c) verified sound (glm-5p2) — modules/onion-addresses.nix:null
- [info] Committed SSH private key in examples/qemu-vm is a disposable test fixture (glm-5p2) — examples/qemu-vm/id-vm:null
