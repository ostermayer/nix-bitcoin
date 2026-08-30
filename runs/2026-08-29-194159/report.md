# Adversarial LLM audit — 2026-08-29-194159

- Commit audited: `1caa0af55020600de6fab30fe89e50444b45645a` (ref `origin/master`)
- Models: kimi-k3 glm-5p3 (Fireworks, thinking=max)
- Prompt: the exact brief used is saved next to this report as `prompt.used.md`
- Findings: **13** total · 0 critical · 0 high · 0 flagged by >1 model

> LLM findings are ADVISORY input to human review — not a release gate.

- [medium] btcpayserver 2.4.2 pinned; upstream 2.4.3 is a security release and nixpkgs will not deliver it (kimi-k3) — null:null
- [low] wireguard preset: lnd REST firewall accept rule is not interface-scoped (kimi-k3) — null:null
- [low] lndinit pinned at 0.1.3-beta (2022), 33 releases behind upstream (kimi-k3) — null:null
- [low] CVE-scan loop is blind to non-CVE security releases, the exact class of F-1 (kimi-k3) — null:null
- [low] User-supplied bitcoind rpcauth HMACs land in the world-readable nix store (kimi-k3) — null:null
- [info] No-action verification results for this snapshot (kimi-k3) — null:null
- [medium] wireguard preset binds lnd admin REST API on 0.0.0.0, firewall is the only defense layer (glm-5p3) — null:null
- [low] direnv dev-env bootstraps the archived upstream repo instead of this fork (glm-5p3) — null:null
- [low] push-release.sh still publishes to fort-nix/nix-bitcoin and versions from upstream's release line (glm-5p3) — null:null
- [info] Demo VM help text references removed clightning binary (glm-5p3) — null:null
- [info] CVE-scan whitelist blanket-suppresses whole build-toolchain pnames present in the scan target (glm-5p3) — null:null
- [info] Residual fail-open path in CVE count computation (glm-5p3) — null:null
- [info] Public RPC user doubles as the shared local-services credential (glm-5p3) — null:null
