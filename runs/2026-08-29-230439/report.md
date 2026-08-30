# Adversarial LLM audit — 2026-08-29-230439

- Commit audited: `6181cd196a37d95e028859f46cd1589ad9ad0cd1` (ref `origin/master`)
- Models: kimi-k3 glm-5p3 (Fireworks, thinking=max)
- Prompt: the exact brief used is saved next to this report as `prompt.used.md`
- Findings: **8** total · 0 critical · 0 high · 0 flagged by >1 model

> LLM findings gate the release: the audit must complete and be reviewed before shipping.

## [low] Macaroon delivery directory /run/lnd is owned by the lnd user
- model: kimi-k3 · confidence: high · null
- modules/lnd.nix:249-250:0
- attack: null
- fix: Deliver macaroons from a root-owned directory instead: e.g. RuntimeDirectory=lnd-macaroons with RuntimeDirectoryMode=0755 on a tiny root oneshot (or keep staging dir /run/lnd-macaroons.XXXXXX pattern but rename into a root-owned final dir), and point consumers' macaroonfilepath there. Mirrors the onion-addresses root:root-then-chown pattern already in tree.

## [low] Wireguard preset: lnd REST accept rule is neither interface- nor peer-scoped while REST binds 0.0.0.0
- model: glm-5p3 · confidence: null · null
- modules/presets/wireguard.nix:163-170 (rule), :181 (restAddress = "0.0.0.0"):0
- attack: null
- fix: Ship the interim hardening now, independent of the deferred rebind: add '-i wg-nb' and narrow the source to the single peer address ('-s ${peerAddress}/32') in the accept rule, and optionally set strict rp_filter in the preset. Then proceed with the recommended second-listener design in docs/wireguard-rest-bind.md when the checklist can be worked.

## [low] Deploy example scripts execute the removed 'lightning-cli' and fail after a successful deploy
- model: glm-5p3 · confidence: null · null
- examples/deploy-krops.sh:118-119, examples/deploy-qemu-vm.sh:57-58, examples/deploy-container.sh:50-51 (also examples/qemu-vm/minimal-vm.nix:46 help text):0
- attack: null
- fix: Replace with 'c lncli getinfo' in the three scripts and the minimal-vm help line. One-line fix per file.

## [info] Dead code: mkCliExec left behind by the trim cleanup
- model: glm-5p3 · confidence: null · null
- modules/netns-isolation.nix:98:0
- attack: null
- fix: Delete the line.

## [info] SECURITY.md references the deleted helper/push-release.sh
- model: glm-5p3 · confidence: null · null
- SECURITY.md, 'Release Integrity' note:0
- attack: null
- fix: Update the note to name only helper/fetch-release and mention its refusal guard.

## [informational] cve-whitelist: blanket [stringbuilder] pname entry contradicts stated scoping policy
- model: kimi-k3 · confidence: medium · null
- .github/cve-whitelist.toml:0
- attack: null
- fix: Either scope it with cve = [...] like the collision entries at the bottom of the file, or document which store path vulnix is matching so the 'not runtime surface' claim is checkable.

## [informational] netns-isolation declares an nginx netns although the fork ships no nginx module
- model: kimi-k3 · confidence: high · null
- modules/netns-isolation.nix:243-245:0
- attack: null
- fix: Remove the nginx entry (and nb-nginx from netns-exec's whitelist) or gate it behind an assertion with a clear error message.

## [informational] Dead code: mkCliExec defined but never used
- model: kimi-k3 · confidence: high · null
- modules/netns-isolation.nix:98:0
- attack: null
- fix: Delete it.

