# Adversarial LLM audit — 2026-08-20-111919

- Commit audited: `b74265add786a6d823d7f1eb9a7dea6bd01d355e` (ref `origin/master`)
- Models: kimi-k3 (Fireworks, thinking=low)
- Prompt: [`audits/prompt.md`](../../blob/b74265add786a6d823d7f1eb9a7dea6bd01d355e/audits/prompt.md) at the audited commit
- Findings: **3** total · 0 critical · 0 high · 0 flagged by >1 model

> LLM findings are ADVISORY input to human review — not a release gate.

- [medium] btcpayserver RPC user is granted setban, enabling peer-eclipse DoS from a compromised nbxplorer (kimi-k3) — modules/btcpayserver.nix:105
- [low] fundrawtransaction in the public RPC whitelist leaks loaded-wallet UTXOs and change addresses (kimi-k3) — modules/bitcoind-rpc-public-whitelist.nix:50
- [info] In netns-isolation mode, unauthenticated bitcoind ZMQ and the Tor SOCKS port are reachable by any local user via the bridge IP (kimi-k3) — modules/netns-isolation.nix:238
