# Adversarial LLM audit — 2026-08-29-191448

- Commit audited: `19517ec427f173f3984957d86dd3612d41d09321` (ref `origin/master`)
- Models: kimi-k3 glm-5p3 (Fireworks, thinking=max)
- Prompt: the exact brief used is saved next to this report as `prompt.used.md`
- Findings: **8** total · 0 critical · 1 high · 0 flagged by >1 model

> LLM findings are ADVISORY input to human review — not a release gate.

- [high] Root ExecStartPost of lnd reads admin.macaroon through a fully lnd-owned path, giving a compromised lnd arbitrary root file disclosure (kimi-k3) — modules/lnd.nix:280
- [low] setup-secrets runs without `set -e` and word-splits unprocessed filenames, so permission hardening failures are silent and the secrets target still activates (kimi-k3) — modules/secrets/secrets.nix:234
- [low] Inline rpc.users.<name>.passwordHMAC values are baked into the world-readable Nix store bitcoin.conf (kimi-k3) — modules/bitcoind.nix:334
- [info] wireguard preset binds lnd's macaroon-admin REST API to 0.0.0.0, protected by the firewall alone (already tracked, deferred) (kimi-k3) — modules/presets/wireguard.nix:181
- [medium] CVE-scan summary silently drops derivations that carry both whitelisted collision CVEs and active CVEs, defeating the per-CVE scoping policy (glm-5p3) — test/ci/cve-scan.sh:52
- [low] A failed vulnix run (NVD fetch error, whitelist parse error, invalid JSON) reports 'clean' and closes the CVE tracking issue (glm-5p3) — test/ci/cve-scan.sh:44
- [low] electrs/btcpayserver still enable a whitelisted (NoBan) bitcoind P2P socket on localhost usable by any local user — open finding from the 2026-08-20 run, unfixed and undocumented at 19517ec (glm-5p3) — modules/bitcoind.nix:319
- [info] wireguard preset binds lnd's macaroon-admin REST API to 0.0.0.0, relying on the firewall alone — consciously deferred with a documented checklist in 19517ec (glm-5p3) — modules/presets/wireguard.nix:181
