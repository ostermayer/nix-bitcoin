# Adversarial LLM audit — 2026-08-20-195545

- Commit audited: `76f3b120f8aa6fb1af125b41845b3b9f9c638515` (ref `origin/master`)
- Models: kimi-k3 glm-5p2 (Fireworks, thinking=max)
- Prompt: [`audits/prompt.md`](../../blob/76f3b120f8aa6fb1af125b41845b3b9f9c638515/audits/prompt.md) at the audited commit
- Findings: **4** total · 0 critical · 1 high · 0 flagged by >1 model

> LLM findings are ADVISORY input to human review — not a release gate.

- [high] Unvalidated tor-writable onion hostname content flows into bitcoin.conf/lnd.conf and the lndconnect admin-macaroon URL (kimi-k3) — modules/onion-addresses.nix:96
- [medium] check-then-read TOCTOU in onion-addresses copyOnionFile lets a tor-user swap in a symlink after the -L check, copying arbitrary root-readable files into service-owned outputs (kimi-k3) — modules/onion-addresses.nix:92
- [info] electrs.toml holding the bitcoind public RPC password is created with the service default umask (0644), relying solely on the 0770 parent dir (kimi-k3) — modules/electrs.nix:78
- [low] postStart `chmod g=r` on .cookie does not clear other-readable bit; world-readability depends entirely on bitcoind (UMask unset by default) (glm-5p2) — modules/bitcoind.nix:439
