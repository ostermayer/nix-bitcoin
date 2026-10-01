# Adversarial LLM audit — 2026-10-01-103328

- Commit audited: `0b35be2cd0e139a237274fa972f91f5e42aa4bf7` (ref `rc-2026-10-01`)
- Models: kimi-k3 (fireworks, thinking=max), glm-5p3 (fireworks, thinking=max)
- Prompt: the exact brief used is saved next to this report as `prompt.used.md`
- Findings: **13** total · 0 critical · 0 high · 0 flagged by >1 model

> LLM findings gate the release: the audit must complete and be reviewed before shipping.

## [medium] lnd admin REST API bound to 0.0.0.0 in the wireguard preset; host firewall is the only protection layer
- model: glm-5p3 · confidence: high · null
- ?:0
- attack: null
- fix: Work through docs/wireguard-rest-bind.md (systemd ordering, TLS SAN, ExecStartPost/btcpayserver/lndconnect-onion consumers) and bind to the wg address; until then keep the documented advisory.

## [low] wireguard preset binds lnd admin REST API to 0.0.0.0, guarded only by iptables
- model: kimi-k3 · confidence: null · null
- modules/presets/wireguard.nix:185-200 (services.lnd.restAddress = "0.0.0.0" when lndconnect enabled):0
- attack: null
- fix: Work through docs/wireguard-rest-bind.md and bind to serverAddress (needs systemd ordering on wireguard-wg-nb, TLS SAN via services.lnd.certificate.extraIPs, and macaroon/btcpayserver/lndconnect-onion consumer migration). Until then, keep the eval assertions as-is.

## [low] Operator user is root-equivalent by design (full bitcoind RPC, lnd admin macaroon, NOPASSWD run-as)
- model: glm-5p3 · confidence: high · null
- ?:0
- attack: null
- fix: Keep documenting; optionally split operator into a read-only role and a funds-admin role if the fleet ever needs it.

## [low] CVE whitelist blanket-pname entries silence all future CVEs for build-toolchain packages if they ever enter the runtime closure
- model: glm-5p3 · confidence: high · null
- ?:0
- attack: null
- fix: Have cve-scan.sh fail or warn when a blanket-whitelisted pname actually appears in the scanned closure.

## [low] CalVer release tags are created unsigned by CI
- model: glm-5p3 · confidence: high · null
- ?:0
- attack: null
- fix: Sign tags with the maintainer SSH key, or have the workflow verify the pushed commit's SSH signature before tagging.

## [info] restrictPeer FORWARD REJECT rule has an asymmetric add/remove lifecycle
- model: kimi-k3 · confidence: null · null
- modules/presets/wireguard.nix:166-192 (networking.firewall extraCommands/extraStopCommands):0
- attack: null
- fix: Make the removal unconditional (move the `-D FORWARD ... || :` out of the mkIf), or accept and document that restrictPeer changes need a reboot/firewall restart with manual `iptables -D FORWARD` cleanup.

## [info] Release distribution relies on unsigned CI-created tags plus manual commit review
- model: kimi-k3 · confidence: null · null
- .github/workflows/release-tag.yml, helper/makeShell.nix (update-nix-bitcoin):0
- attack: null
- fix: If the maintainer's threat model allows, sign release tags (or commits on `release`) with the maintainer key and have update-nix-bitcoin verify the signature before writing the pin; the infrastructure (SSH/GPG signing) is already described in SECURITY.md.

## [info] Fork-carried btcpayserver 2.4.4 package and nuget lockfile sit outside nixpkgs review
- model: kimi-k3 · confidence: null · null
- pkgs/btcpayserver/default.nix, pkgs/btcpayserver/deps-2.4.4.json, pkgs/overrides.nix:0
- attack: null
- fix: Drop pkgs/btcpayserver + the overrides.nix entry as soon as the pinned nixpkgs carries btcpayserver >= 2.4.4, as the header comment already instructs; consider regenerating the lockfile from the upstream release tarball on each future override.

## [info] MemoryDenyWriteExecute disabled for nbxplorer and btcpayserver (.NET JIT)
- model: kimi-k3 · confidence: null · null
- modules/btcpayserver.nix:190-201 and :246-247:0
- attack: null
- fix: None actionable; keep the remaining defaultHardening intact and revisit if .NET on Linux ever supports a hardened JIT mode.

## [info] bitcoind RPC cookie is group-readable (group bitcoin = full privileged RPC)
- model: kimi-k3 · confidence: null · null
- modules/bitcoind.nix:435-443 (postStart chmod 0640 .cookie):0
- attack: null
- fix: Keep the cookie consumer set fixed; new local consumers should get a dedicated rpc user + HMAC instead of group membership, as the in-tree comment already states.

## [informational] Branch-protection ruleset and GitHub-side signature verification are asserted in comments but unverifiable from the checkout
- model: glm-5p3 · confidence: high · null
- ?:0
- attack: null
- fix: Consumers should verify branch protection and commit signatures on GitHub before trusting the release branch.

## [informational] MemoryDenyWriteExecute disabled for btcpayserver and nbxplorer (.NET JIT)
- model: glm-5p3 · confidence: high · null
- ?:0
- attack: null
- fix: Re-check whether .NET supports W^X-compatible JIT modes on current runtimes.

## [none] No backdoor, exfiltration, or supply-chain compromise indicators found in the fork-specific changes
- model: glm-5p3 · confidence: high · null
- ?:0
- attack: null
- fix: None. Re-audit on every nixpkgs pin bump as the project itself prescribes.


> Second opinion by gpt-6-astra (codex, thinking=xhigh): **ok** — see `second-opinion.gpt-6-astra.md`.
