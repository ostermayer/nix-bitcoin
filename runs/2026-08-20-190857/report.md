# Adversarial LLM audit — 2026-08-20-190857

- Commit audited: `638d92cf4cb14afc91ea2104539295718796bc3a` (ref `origin/master`)
- Models: kimi-k3 glm-5p2 (Fireworks, thinking=max)
- Prompt: [`audits/prompt.md`](../../blob/638d92cf4cb14afc91ea2104539295718796bc3a/audits/prompt.md) at the audited commit
- Findings: **5** total · 0 critical · 2 high · 0 flagged by >1 model

> LLM findings are ADVISORY input to human review — not a release gate.

- [high] Root ExecStartPost reads lnd's admin.macaroon through an lnd-controlled path, giving the lnd user an arbitrary root file read (kimi-k3) — modules/lnd.nix:280
- [medium] audits/run.sh bwrap masks only ~/.ssh and the secrets file; rest of home dir and host /proc stay readable with unrestricted network egress (kimi-k3) — audits/run.sh:82
- [info] hardened preset re-enables unprivileged user namespaces, undoing a NixOS hardened-profile protection (kimi-k3) — modules/presets/hardened.nix:11
- [high] Custom lnd macaroons live in lnd-owned /run/lnd, so a compromised lnd can symlink-swap them after creation and exfiltrate btcpayserver-readable secrets (glm-5p2) — modules/lnd.nix:288
- [low] copyOnionFile's symlink refusal is a non-atomic check-then-read (TOCTOU) in a root service with DAC_OVERRIDE (glm-5p2) — modules/onion-addresses.nix:96
