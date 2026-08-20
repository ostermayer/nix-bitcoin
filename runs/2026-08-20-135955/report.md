# Adversarial LLM audit — 2026-08-20-135955

- Commit audited: `c365f9d6e26102bbcc2d61b3804c9f496563fa5e` (ref `origin/master`)
- Models: kimi-k3 glm-5p2 (Fireworks, thinking=max)
- Prompt: [`audits/prompt.md`](../../blob/c365f9d6e26102bbcc2d61b3804c9f496563fa5e/audits/prompt.md) at the audited commit
- Findings: **5** total · 0 critical · 0 high · 0 flagged by >1 model

> LLM findings are ADVISORY input to human review — not a release gate.

- [medium] Fork's own flake templates and install docs pin the archived, unpatched upstream (fort-nix) instead of this fork (kimi-k3) — examples/flakes/flake.nix:11
- [low] btcpayserver joins nbxplorer's group, granting write access to nbxplorer's whole data dir (only needs to read one cookie file) (kimi-k3) — modules/btcpayserver.nix:250
- [info] nodeinfo checks a misspelled unit name 'onion-adresses', making its failure guard dead code (kimi-k3) — modules/nodeinfo.nix:68
- [low] WireGuard preset binds lnd admin REST to 0.0.0.0 without asserting the firewall that gates it (glm-5p2) — modules/presets/wireguard.nix:172
- [info] Public bitcoind RPC whitelist grants signmessagewithprivkey/signrawtransactionwithkey (caller-key signing oracles, no local consumer) (glm-5p2) — modules/bitcoind-rpc-public-whitelist.nix:81
