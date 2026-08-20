# Adversarial LLM audit — 2026-08-20-131746

- Commit audited: `c3253f3bdb7b15816b74e09134429c2ab3e6d315` (ref `origin/master`)
- Models: kimi-k3 glm-5p2 (Fireworks, thinking=max)
- Prompt: [`audits/prompt.md`](../../blob/c3253f3bdb7b15816b74e09134429c2ab3e6d315/audits/prompt.md) at the audited commit
- Findings: **4** total · 0 critical · 2 high · 0 flagged by >1 model

> LLM findings are ADVISORY input to human review — not a release gate.

- [high] Root ExecStartPost chmod/chown/write through swappable mktemp file in lnd-writable /run/lnd (kimi-k3) — modules/lnd.nix:276
- [low] Typo 'syskernel.core_pattern' silently disables the stated core-dump kill switch (kimi-k3) — modules/presets/hardened-extended.nix:56
- [info] Residual TOCTOU between symlink check and install in onion-addresses copyOnionFile (kimi-k3) — modules/onion-addresses.nix:82
- [high] lnd macaroon root ExecStartPost still symlink-raceable: mktemp is in the lnd-owned $RUNTIME_DIRECTORY (no sticky bit) (glm-5p2) — modules/lnd.nix:276
