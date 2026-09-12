# Adversarial LLM audit — 2026-09-12-174146

- Commit audited: `ebf269ebfeae3293f1180566e59c1eb68779c448` (ref `origin/audit-fixes-2026-09`)
- Models: kimi-k3 (fireworks, thinking=max), glm-5p3 (fireworks, thinking=max)
- Prompt: the exact brief used is saved next to this report as `prompt.used.md`
- Findings: **9** total · 0 critical · 0 high · 0 flagged by >1 model

> LLM findings gate the release: the audit must complete and be reviewed before shipping.

## [low] lnd custom macaroons inherit the target user's login group, leaking to shared 'users' group
- model: kimi-k3 · confidence: null · null
- modules/lnd.nix:300
- attack: null
- fix: Resolve the group explicitly instead of relying on login-group semantics: e.g. a dedicated per-macaroon group, or `chown <user>:nogroup` plus an ACL, or document that macaroon `user` must be a system user with a same-named group.

## [low] update-nix-bitcoin auto-selects the newest unsigned release tag; integrity rests on advisory operator review
- model: kimi-k3 · confidence: null · null
- helper/makeShell.nix:74
- attack: null
- fix: Verify the resolved commit's SSH signature against the maintainer's allowed-signers entry before writing the pin (the infrastructure exists: commits are signed), or at minimum fail unless the tag is an annotated tag object created by the CI workflow identity.

## [low] wireguard preset: restrictPeer silently inert when firewall is disabled and lndconnect is off
- model: glm-5p3 · confidence: null · null
- assertions block (lines ~104-118) vs networking.firewall.extraCommands:0
- attack: null
- fix: Add assertion: !cfg.restrictPeer || config.networking.firewall.enable (or set restrictPeer default to false when the firewall is off), keeping it symmetric with the existing nftables assertion.

## [low] lnd admin REST API bound to 0.0.0.0 by the wireguard preset (known, deferred)
- model: glm-5p3 · confidence: null · null
- services.lnd.restAddress = "0.0.0.0" (mkIf lndconnect):0
- attack: null
- fix: Implement the documented second-listener design from docs/wireguard-rest-bind.md (extraConfig restlisten=${serverAddress}:${restPort} plus lnd-after-wireguard-wg-nb ordering), then re-run the adversarial audit per the fork's policy.

## [info] update-nix-bitcoin prints a malformed compare URL on first run
- model: glm-5p3 · confidence: null · null
- update-nix-bitcoin(): compare-URL echo:0
- attack: null
- fix: Print the commit URL (github.com/ostermayer/nix-bitcoin/commit/$commit) when no previous pin exists.

## [info] deriveaddresses in the public RPC whitelist is the largest remaining per-call CPU cost
- model: glm-5p3 · confidence: null · null
- "deriveaddresses" entry:0
- attack: null
- fix: Optionally drop deriveaddresses (no local consumer in the fork's service set: lnd, electrs, nbxplorer, btcpayserver do not call it), or document it alongside the getpeerinfo/getnodeaddresses caveat.

## [informational] netns-exec leaks the netns fd into the executed program (missing O_CLOEXEC)
- model: kimi-k3 · confidence: null · null
- pkgs/netns-exec/src/main.c:73
- attack: null
- fix: open(netns_path, O_RDONLY | O_CLOEXEC).

## [informational] wireguard preset binds lnd admin REST to 0.0.0.0; protection is firewall-only
- model: kimi-k3 · confidence: null · null
- modules/presets/wireguard.nix:207
- attack: null
- fix: Work through docs/wireguard-rest-bind.md and bind to the WG server address; until then, consider also asserting services.lnd.restAddress == 0.0.0.0 only when the accept rule is in place.

## [informational] bitcoind RPC cookie is group-readable (0640, group bitcoin) = full privileged RPC for group members
- model: kimi-k3 · confidence: null · null
- modules/bitcoind.nix:442
- attack: null
- fix: Long-term, move local consumers to dedicated rpc users with HMAC and make the cookie root-only; at minimum keep group-bitcoin membership under review.


> Second opinion by gpt-6-astra (codex, thinking=xhigh): **ok** — see `second-opinion.gpt-6-astra.md`.
