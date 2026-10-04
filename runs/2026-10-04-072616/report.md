# Adversarial LLM audit — 2026-10-04-072616

- Commit audited: `d5ac2b83e21b6ab637c62833acf339ca5932f891` (ref `d5ac2b83e21b6ab637c62833acf339ca5932f891`)
- Models: kimi-k3 (fireworks, thinking=max), glm-5p3 (fireworks, thinking=max), gpt-6-astra (codex, thinking=xhigh)
- Prompt: the exact brief used is saved next to this report as `prompt.used.md`
- Findings: **9** total · 0 critical · 0 high · 0 flagged by >1 model

> ⚠ INCOMPLETE — at least one model failed or its findings could not be parsed (no verdict from: gpt-6-astra). The counts above are NOT a clean result. Read the per-model transcripts before trusting this report.

> LLM findings gate the release: the audit must complete and be reviewed before shipping.

## [medium] Wireguard preset firewall-backend assertions miss networking.firewall.backend = "firewalld": all preset rules silently vanish and no firewall runs at all
- model: glm-5p3 · confidence: verified · null
- assertions block, lines ~88-107; interacts with networking.firewall.extraCommands rules (lines ~178-205):0
- attack: null
- fix: Extend the backend assertion to require the iptables backend itself, with a fallback for nixpkgs versions lacking the option: assertion = ((config.networking.firewall.backend or "iptables") == "iptables") && !(config.networking.nftables.enable || (config.services.firewalld.enable or false));. This makes the nftables and firewalld backend paths fail loudly by design instead of relying on nixpkgs' incidental extraCommands assertion. Add a VM/eval test that the backend="firewalld" configuration fails to evaluate.

## [low] SECURITY.md claims fork commits are SSH-signed; all 72 fork commits are unsigned
- model: kimi-k3 · confidence: null · null
- SECURITY.md (Release Integrity):0
- attack: null
- fix: null

## [low] wireguard-lndconnect VM test asserts only positive reachability; no negative test that the firewall rules actually restrict
- model: glm-5p3 · confidence: verified · null
- testScript, both subtests:0
- attack: null
- fix: In the existing two-node test, add two negative assertions: (1) before wg-quick up, client.fail('curl ... https://<server-external-ip>:8080/...') or an equivalent reachability probe; (2) after wg-quick up, client.fail to reach a second, deliberately-open-but-non-REST port on a non-wg server address (exercising the REJECT), e.g. allow a TCP port via allowedTCPPorts and assert the peer still cannot hit it through the tunnel.

## [low] Known and deliberately deferred: lnd admin REST binds 0.0.0.0 under the wireguard preset, guarded by the firewall alone
- model: glm-5p3 · confidence: verified · null
- services.lnd.restAddress = "0.0.0.0" (mkIf lndconnect); docs/wireguard-rest-bind.md:0
- attack: null
- fix: Keep the deferral, but land FW-1 and FW-2 first; the pre-flight checklist in docs/wireguard-rest-bind.md remains the right gate for the rebind itself.

## [low] Known and documented: getpeerinfo/getnodeaddresses retained in the public bitcoind RPC whitelist
- model: glm-5p3 · confidence: verified · null
- Network section:0
- attack: null
- fix: None beyond the documented guidance: narrow rpcwhitelist in your own config when exposing the public user over a proxy. Optionally add an assertion in a future release that fails evaluation when rpc.address is non-local and the whitelist still contains these calls.

## [medium-low] helper/fetch-release: GPG verification decoupled from the consumed artifact
- model: kimi-k3 · confidence: null · null
- helper/fetch-release:50:0
- attack: null
- fix: null

## [informational] WireGuard preset binds lnd admin REST API to 0.0.0.0; protection is iptables-only
- model: kimi-k3 · confidence: null · null
- modules/presets/wireguard.nix:211:0
- attack: null
- fix: null

## [informational] Stale FORWARD REJECT rule persists after the wireguard preset is removed from the configuration
- model: glm-5p3 · confidence: medium · null
- networking.firewall.extraStopCommands (restrictPeer block):0
- attack: null
- fix: Make the stop command self-contained: change the start side to also record/cleanup on stop is already attempted; simplest robust fix is to have extraStopCommands delete the rule by position-independent spec guarded with '|| :' (already done) AND accept the reboot caveat in the module comment, or move the FORWARD insert into a dedicated chain with a flush on both start and stop. Low priority; document if not fixed.

## [informational] netns-exec capability-drop behavior is untested for the fork's service set
- model: glm-5p3 · confidence: verified · null
- netns-isolation test block (joinmarket-guarded assertion):0
- attack: null
- fix: Repoint the existing assertion at a live allowlisted namespace, e.g. runuser -u operator -- netns-exec nb-lnd capsh --print | grep -E '^Current: =$', and un-gate it from joinmarket. One-line change in the netns scenario.

