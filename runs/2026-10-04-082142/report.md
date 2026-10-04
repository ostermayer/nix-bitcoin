# Adversarial LLM audit — 2026-10-04-082142

- Commit audited: `8dd96504668cb2f887b27cf2469ea10ea9c7029c` (ref `8dd96504668cb2f887b27cf2469ea10ea9c7029c`)
- Models: kimi-k3 (fireworks, thinking=max), glm-5p3 (fireworks, thinking=max), gpt-6-astra (codex, thinking=xhigh)
- Prompt: the exact brief used is saved next to this report as `prompt.used.md`
- Findings: **10** total · 0 critical · 0 high · 0 flagged by >1 model

> LLM findings gate the release: the audit must complete and be reviewed before shipping.

## [low] Inline bitcoind RPC passwordHMAC values are written to the world-readable Nix store
- model: kimi-k3 · confidence: null · null
- modules/bitcoind.nix (configFile = builtins.toFile ...):0
- attack: null
- fix: Add a warning to the passwordHMAC option description, or route all HMACs through nix-bitcoin.secrets like the FromFile path.

## [low] lnd macaroon ExecStartPost runs as fully unsandboxed root (systemd '+' prefix) against daemon-controlled output
- model: kimi-k3 · confidence: null · null
- pkgs/lib.nix (rootScript), modules/lnd.nix ExecStartPost:0
- attack: null
- fix: Replace '+' with a dedicated helper unit running with only the caps it needs (CAP_DAC_READ_SEARCH for the macaroon read can be avoided entirely by reading as the lnd user, which the script already does), keeping defaultHardening applied.

## [low] nodeinfo exec()s Python built by unescaped Nix string interpolation
- model: kimi-k3 · confidence: null · null
- modules/nodeinfo.nix (mkInfoLong / add_service exec):0
- attack: null
- fix: Interpolate via json.dumps-equivalent escaping (builtins.toJSON) instead of raw string splicing.

## [low] Demo QEMU SSH forward binds 0.0.0.0 with a repo-published private key
- model: kimi-k3 · confidence: null · null
- examples/qemu-vm/run-vm.sh (QEMU_NET_OPTS hostfwd=tcp::PORT-:22), examples/qemu-vm/id-vm:0
- attack: null
- fix: Use hostfwd=tcp:127.0.0.1:${sshPort}-:22.

## [low] Predictable /tmp paths trusted by dev/test scripts on multi-user machines
- model: kimi-k3 · confidence: null · null
- examples/qemu-vm/run-vm.sh (tmpDir=/tmp/nix-bitcoin-qemu-vm, mkdir -p), test/lib/copy-src.sh (/tmp/nix-bitcoin-src cache):0
- attack: null
- fix: Always mktemp -d (no fixed name, no cache reuse), or verify ownership/mode of the cache dir before trusting it.

## [low] wg-connect host autodetection trusts plaintext external-IP echo providers
- model: glm-5p3 · confidence: null · null
- modules/presets/wireguard.nix:0
- attack: null
- fix: Validate the extracted host against an IP/hostname regex and fail otherwise, or drop the autodetection and require an explicit host argument in the docs.

## [informational] Committed demo SSH identity authorizes root on example VM configs
- model: glm-5p3 · confidence: null · null
- examples/qemu-vm/id-vm, examples/qemu-vm/vm-config.nix:0
- attack: null
- fix: Acceptable as-is; optionally generate the identity per-clone at first run instead of committing it.

## [informational (advisory, medium if the firewall is bypassed by user config)] lnd admin REST API remains bound to 0.0.0.0 under the wireguard preset, guarded only by iptables
- model: glm-5p3 · confidence: null · null
- modules/presets/wireguard.nix:0
- attack: null
- fix: No action this audit; implement the recommended extraConfig second-listener variant from the deferral doc.

## [informational (accepted)] bitcoind RPC cookie is group-readable by bitcoin (operator gets full privileged RPC)
- model: glm-5p3 · confidence: null · null
- modules/bitcoind.nix:0
- attack: null
- fix: Keep group membership minimal; consider a dedicated macaroon-style credential for operator bitcoin-cli if the operator account should be deprivileged.

## [critical|high|medium|low|info] one line
- model: gpt-6-astra · confidence: 0.0 · secrets-in-store|file-perms|rpc-whitelist|sandboxing|privesc|ordering|activation-script|network-exposure|netns|secrets-lifecycle|availability|privacy|default-creds|config-injection|supply-chain|other
- modules/foo.nix:123
- attack: attacker, starting tier, steps, payoff
- fix: the fix

