# Adversarial LLM audit — 2026-08-20-122905

- Commit audited: `8611a39424fef211be191a0409ea5dc0d1701e80` (ref `origin/master`)
- Models: kimi-k3 glm-5p2 (Fireworks, thinking=medium)
- Prompt: [`audits/prompt.md`](../../blob/8611a39424fef211be191a0409ea5dc0d1701e80/audits/prompt.md) at the audited commit
- Findings: **6** total · 0 critical · 0 high · 0 flagged by >1 model

> LLM findings are ADVISORY input to human review — not a release gate.

- [medium] Root lnd ExecStartPost writes/chowns through attacker-controlled symlinks in lnd-owned /run/lnd (kimi-k3) — modules/lnd.nix:274
- [medium] btcpayserver-reachable bitcoind RPC user retains setban, enabling peer-eclipse from a web-app compromise (kimi-k3) — modules/btcpayserver.nix:110
- [low] onion-addresses: check-then-install TOCTOU on tor-controlled hostname files still allows a root symlink read (kimi-k3) — modules/onion-addresses.nix:93
- [low] fork's release tooling and docs still fetch/clone upstream fort-nix/nix-bitcoin, silently discarding fork security fixes (kimi-k3) — helper/fetch-release:9
- [low] The 'public' bitcoind RPC user is shared by lnd locally and intended for public exposure, so its getpeerinfo/getnodeaddresses leak peer topology and the documented mitigation breaks lnd (glm-5p2) — modules/bitcoind-rpc-public-whitelist.nix:53
- [low] btcpayserver RPC user (used by nbxplorer) is granted setban and generatetoaddress, neither needed, enabling eclipse-DoS of bitcoind if nbxplorer is compromised (glm-5p2) — modules/btcpayserver.nix:110
