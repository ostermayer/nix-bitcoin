# Adversarial LLM audit — 2026-08-29-215807

- Commit audited: `8c86b9162db823c15b26d53dc53a5d68b330761f` (ref `origin/release`)
- Models: kimi-k3 glm-5p3 (Fireworks, thinking=max)
- Prompt: the exact brief used is saved next to this report as `prompt.used.md`
- Findings: **6** total · 0 critical · 1 high · 0 flagged by >1 model

> LLM findings gate the release: the audit must complete and be reviewed before shipping.

## [high] Root ExecStartPost reads admin.macaroon through a symlink-followable path in the lnd-owned datadir and exfiltrates the bytes to lnd's own REST endpoint
- model: glm-5p3 · confidence: 0.75 · activation-script
- modules/lnd.nix:280
- attack: Attacker: the lnd service user, compromised via an lnd exploit (the exact adversary the script's own comment names at lines 265-274). Steps: (1) replace /var/lib/lnd/chain/bitcoin/<net>/admin.macaroon — inside the 0770 lnd:lnd datadir lnd fully controls — with a symlink to a root-only file, e.g. /etc/nix-bitcoin-secrets/backup-encryption-env, wg-server-private-key, /etc/ssh/ssh_host_ed25519_key, or /etc/shadow; (2) trigger a service start (Restart=on-failure spaced over time, any deploy, any reboot — ExecStartPost re-runs on every start); (3) the '+'-prefixed script runs as unsandboxed root, xxd reads the target THROUGH the symlink, and the hex-encoded content is transmitted as the Grpc-Metadata-macaroon header of the POST to https://<restAddress>:<restPort>/v1/macaroon — the listener the compromised lnd itself owns and reads. One root-only file per start; iterate per restart. Payoff: root-only secret exfiltration the lnd user could never read directly — the backup passphrase decrypts backups that contain the whole secretsDir and /var/lib/tor (backups.nix filelist), the wg server key fronts the admin REST API, SSH host keys enable MITM of operator access.
- fix: De-privilege the read so root never dereferences an lnd-controlled path: read the macaroon as the service user (e.g. adminMacaroonHex=$(${runAsUser} lnd cat '${networkDir}/admin.macaroon' | ${pkgs.xxd}/bin/xxd -ps -u -c 99999)) — a symlink to a root-only file then fails closed because the lnd user cannot read it — or open with O_NOFOLLOW and fstat-verify a regular file before reading. The existing root-only staging + rename(2) write path is correct and needs no change.

## [low] setup-secrets lockdown glob misses dotfiles (fail-open)
- model: kimi-k3 · confidence: null · null
- modules/secrets/secrets.nix:229:0
- attack: null
- fix: null

## [low] WireGuard preset binds lnd admin REST to 0.0.0.0, guarded only by a source-subnet firewall rule that is not interface-scoped
- model: kimi-k3 · confidence: null · null
- modules/presets/wireguard.nix:156-160,181:0
- attack: null
- fix: null

## [low] docs/install.md instructs installing Nix 2.3.10 (2021, EOL) on the deploy machine
- model: kimi-k3 · confidence: null · null
- docs/install.md:184-188:0
- attack: null
- fix: null

## [informational] bitcoind preStart compares config with an unquoted RHS glob pattern
- model: kimi-k3 · confidence: null · null
- modules/bitcoind.nix:437:0
- attack: null
- fix: null

## [informational] Public RPC whitelist retains getblockstats; docs demonstrate rpc.allowip 0.0.0.0/0
- model: kimi-k3 · confidence: null · null
- modules/bitcoind-rpc-public-whitelist.nix, docs/configuration.md:99-110:0
- attack: null
- fix: null

