# Security Audit — 2026-08-14

Scope: full snapshot audit of ostermayer/nix-bitcoin @ 37931e5 (== fort-nix/nix-bitcoin master HEAD).
Two angles: (1) known CVEs/vulns in every pinned component version, (2) vulnerabilities in
nix-bitcoin's own module/packaging code.

Method: version inventory resolved from flake.lock pins (nixpkgs 26.05 @ fcb8fcd6, 2026-08-09;
nixpkgs-unstable @ d482ef84, 2026-08-10; nixpkgs 25.05 @ ac62194c). CVE data from bitcoincore.org
security advisories, GitHub Security Advisories, NVD, and upstream changelogs. Code audit of
modules/, pkgs/, helper/, secrets/, presets/ by manual review.

---

## 1. Actionable: known vulnerabilities in pinned versions

| # | Component | Pinned | Fixed in | Severity | Issue | Source |
|---|-----------|--------|----------|----------|-------|--------|
| 1 | **clboss** | 0.16.1 | **0.16.2** | HIGH | Fund theft: `FundsMover` self-payment claim did not verify HTLC amount; last-hop peer settles reduced amount, learns preimage, claims full amount upstream ("Leak of Faith", PR #322, 2026-08-11). 0.16.3 additionally fixes Boltz swap DB corruption and JitRebalancer fee-burn race. | github.com/ZmnSCPxj/clboss CHANGELOG |
| 2 | **clightning (CLN)** | 26.04.1 | **26.06.x** (latest 26.06.6) | MED-HIGH | Unrecoverable funds: `fundchannel_complete` accepts PSBTs with unsigned non-segwit inputs (PR #8922). Also two crash DoS fixed in 26.06: `setconfig` (PR #8751), xpay circular routehints (PR #9174). | github.com/ElementsProject/lightning |
| 3 | **joinmarket** | 0.9.11 | **0.9.12** | MEDIUM | Commitments not format-checked before comparison: malicious taker bypasses anti-snooping, harvests maker UTXO info over time. Upstream calls the fix "very important". Project is now ARCHIVED — no future security updates. Plan migration. | joinmarket-clientserver release-notes-0.9.12 |
| 4 | **RTL** | 0.15.8 | **0.15.10** | MEDIUM | Auth request validation hardening (PR #1654, 2FA setups most affected); auth secrets leaked into node logs and config API responses (PR #1659/#1664). 0.15.9 separately cleared 13 npm audit findings (2 critical) via request→axios, csurf→csrf-csrf. | github.com/Ride-The-Lightning/RTL |
| 5 | **bitcoind_29** (fallback pkg) | 29.2 | 29.4 | LOW-MED | Two point releases behind. Core's low-severity disclosure policy means low-sev fixes ship silently in point releases. Default `bitcoind` (31.1 from nixpkgs) is unaffected. Bump to 29.4 or drop the fallback. | bitcoincore.org |
| 6 | **bitcoin-knots** | 29.3.knots20260508 | 29.4.knots20260508 (2026-08-07) | LOW-MED | One point release behind; 29.4.knots carries the Core 29.4 fixes. | github.com/bitcoinknots/bitcoin |
| 7 | **lightning-loop** | 0.33.2-beta | 0.34.0-beta | LOW | 0.34.0 bumps transitive Go deps "to address security alerts". | lightninglabs/loop |
| 8 | **nbxplorer** | 2.6.7 | 2.6.10 | LOW (precautionary) | BTCPay 2.4.2 advisory recommends integrators run ≥2.6.10. No confirmed vuln in 2.6.7. | blog.btcpayserver.org/security-advisory-btcpay-server-2-4-2 |

### Priority order
1. **clboss → 0.16.2 immediately.** Actively-exploitable fund theft in the pinned version.
2. **CLN → 26.06.x** and **RTL → 0.15.10**.
3. **joinmarket → 0.9.12**, plus a roadmap decision on the archived upstream.
4. Routine bumps: bitcoind_29 → 29.4, knots → 29.4, loop → 0.34.0, nbxplorer → 2.6.10.

## 2. Verified clean at pinned versions

| Component | Pinned | Note |
|-----------|--------|------|
| bitcoind (default) | 31.1 | Latest release. CVE-2024-52911 (script interpreter UAF) affects only < 29.0. 31.0's `-privatebroadcast` IP leak is fixed in 31.1. CVE-2025-54604/54605/46598 backported to 29.1+, included in 31.x. |
| lnd | 0.21.1-beta | All published advisories (CVE-2024-38359, CVE-2022-39389, CVE-2021-41593) affect < 0.17. 0.21.2 is migration fixes only. |
| btcpayserver | 2.4.2 | 2.4.2 IS the security release fixing the critical unauthenticated LND macaroon-theft vuln (exploited in the wild). Pin resolves to the final release, not an RC. Verify again on every bump — an RC of 2.4.2 would be vulnerable. |
| electrs | 0.11.0 | No advisories; 0.11.1 has no security content. |
| fulcrum | 2.1.1 | Latest upstream, no advisories. |
| elements (liquidd) | 23.3.3 | Latest upstream, no post-release fixes. |
| lightning-pool | 0.6.4-beta | Clean; 0.7.0 is reliability only. |
| mempool | 3.2.1 | No advisories; 3.3.x has no security fixes. |
| charge-lnd | 0.3.1 | No advisories. |
| clightning-rest (pkg) | 0.10.7 | No CVEs (but see module finding M-1 — the package is fine, the module default is not). |
| clnrest 0.2.0, trustedcoin 0.8.6, lndconnect 0.2.1, lndinit 0.1.3-beta | — | No advisories. trustedcoin is unmaintained upstream: trust-model risk, not a CVE. |
| autobahn (joinmarket dep) | 20.12.3 | Only known CVE (CVE-2020-35678, redirect header injection) affects **before** 20.12.3. The pin IS the fix. Not a finding. |

## 3. nix-bitcoin's own code — module findings

### High

**M-1. clightning-rest: full-admin REST API bound to 0.0.0.0 by default** — `modules/clightning-rest.nix:45,60`
`RPCCOMMANDS=["*"]` (includes `withdraw`) and listens on all interfaces. Enabling the module exposes
complete wallet control to any network the node sits on. Fix: default `rpcCommands` to a read-only
set and bind localhost unless an explicit option opts into exposure.

**M-2. lndconnect without onion rebinds admin APIs to 0.0.0.0** — `modules/lndconnect.nix:177,213`
Enabling lndconnect (for wallet QR pairing) silently moves the lnd REST API (and clnrest, where
applicable) from localhost/Tor to all interfaces. These are macaroon/rune-authenticated admin
endpoints; exposure should never be a side effect of a QR-code helper. Fix: keep services on
localhost and have lndconnect print the onion path, or require an explicit `openFirewall`-style flag.

### Medium

**M-3. bitcoind-rpc-public-whitelist is not DoS-safe** — `modules/bitcoind-rpc-public-whitelist.nix`
The "public" set includes `getblocktemplate` and `scantxoutset` (expensive, unauthenticated DoS via
the public RPC proxy), plus peer-info and wallet-UTXO leaks (`listunspent`-class). Fix: split into
`safe` (getblockchaininfo, estimatesmartfee, ...) vs `expensive`, expose only `safe` by default.

**M-4. onion-addresses follows symlinks in user-owned dirs as root** — `modules/onion-addresses.nix:86-105`
Root service with CAP_DAC_OVERRIDE reads hostname files from service-owned data dirs without
symlink/hardlink checks; also unquoted shell expansions. A compromised service user could redirect
reads (e.g. wire a macaroon path into a world-readable onion-address output). Fix: `test ! -L` guards,
quote everything, consider `ProtectSystem=strict` + per-service read-only bind instead.

**M-5. clightning-replication mounts service lacks all systemd hardening** — `modules/clightning-replication.nix:159-200`
Every other daemon gets `defaultHardening` (ProtectSystem=strict, NoNewPrivileges, PrivateTmp, ...);
the replication mount helper does not. Also a doc/code mismatch on the SSH key filename. Fix: apply
`defaultHardening` with the minimal mount exceptions.

**M-6. netns-exec execvp with inherited PATH/env** — `pkgs/netns-exec/`
The capability wrapper (post-#846: owner-only 0500 + cap_sys_admin, setns into joinmarket netns) calls
`execvp` with the caller's environment and does not require an absolute path. PATH manipulation by the
operator could run an unexpected binary inside the netns; unchecked `cap_*` returns and a missing
exit-status on exec failure are secondary. Operator is already privileged, so practical impact is
contained. Fix: require `argv[0]` absolute, scrub env, check returns.

**M-7. ecdsa CVE-2024-23342 (Minerva timing attack) meta stripped repo-wide** — `overlay.nix` / `pkgs/`
The CVE flag on the python `ecdsa` package is removed globally to re-enable `hwi`/`trezor` (hardware
wallet support). Plausible for Miniscript-only paths, but the unlock is blanket: any consumer doing
ecdsa signing is silently re-exposed. Fix: scope the meta rewrite to the two packages that need it,
with a re-check date.

**M-8. txzmq 0.8.2 (2019-era, unmaintained)** — `pkgs/python-packages/txzmq/`
Custom-packaged for the clightning zmq plugin. No known CVE, but dead upstream on an old Twisted.
Fix: consider dropping the zmq plugin, or budget maintenance for the fork.

### Low (fix opportunistically)

- `modules/secrets/secrets.nix:80` — RPC password passed in process argv during secret generation (visible in `/proc` briefly). Pass via stdin/env.
- `modules/secrets/secrets.nix:166-183` — unquoted config values/filenames in a root shell script; `printf '%q'` or env passing.
- `modules/presets/wireguard.nix:101-109` — root service re-executes its own script with a pubkey spliced in by `sed`. Converts secrets-store write into root RCE; fragile. Use `wg set` directly.
- `modules/clightning.nix:172` + `modules/clnrest.nix:57` — group `clightning` (operator, btcpayserver) can read the **admin** rune: convenience access and "withdraw all funds" share one boundary. Issue a read-only restricted rune for operator/RTL/nodeinfo; keep admin 0600.
- `modules/bitcoind.nix:302` — `.cookie` chmod g=r: group `bitcoin` == full privileged RPC. Prefer the dedicated `bitcoinrpc-public`-style group.
- `modules/presets/bitcoind-remote.nix:13-15` — privileged `rpcpassword` appended to bitcoin.conf on every restart (file grows), in a 0640 group-readable file. Rewrite instead of append; 0600.
- `pkgs/krops` — fetchgit pins a **tag** (re-targetable), hash still protects integrity. Pin the commit.
- `doCheck = false` on liquid-swap, sha256, chromalog, autobahn — re-enable where feasible (liquid-swap moves funds).
- `pkgs/rtl` — `--legacy-peer-deps` (tracked TODO-EXTERNAL, RTL#1182).
- `pkgs/nixops` — NixOps 1.x is EOL; dev-only tooling, prefer krops/morph.

### Verified good (no action)

- PR #846 netns-exec permission fix is present and complete: owner-only `0500`, file-cap `cap_sys_admin=ep`, no setuid, exact-string whitelist of `nb-joinmarket`, caps dropped before exec.
- No secrets in `/nix/store`. Secret files are assembled in preStart with `install -m 600/640`, `umask u=rw,go=`, and setup-secrets locks unlisted files to `root:root 0440`.
- All source fetches in pkgs/ are hash-pinned, HTTPS-only, no curl|bash, no remote patches, no prebuilt binaries. `bitcoind_29` additionally does full GPG multi-key verification of SHA256SUMS against a hash-pinned guix.sigs keyring — exemplary.
- All onion services are v3 with correct port mapping.
- `defaultHardening` (pkgs/lib.nix) is applied to every daemon service; clightning-replication (M-5) is the only exception found.
- helper/push-release.sh: token from `pass`, GPG-signed artifacts, signature verified against pinned fingerprint on fetch.

## 4. Resolution log (2026-08-14, same day)

This fork was trimmed on the same day to only the services its maintainers
deploy (commit ea0b625): bitcoind, lnd (+lndinit, lndconnect), electrs,
btcpayserver/nbxplorer, and supporting infrastructure. That closed most of
this audit by deletion. Status of every finding:

| Finding | Status | Fix |
|---------|--------|-----|
| clboss 0.16.1 fund theft | CLOSED (deleted) | Fork no longer ships clightning/clboss |
| CLN 26.04.1 funds loss | CLOSED (deleted) | Same |
| joinmarket 0.9.11 snooping | CLOSED (deleted) | joinmarket removed; upstream archived |
| RTL 0.15.8 | CLOSED (deleted) | RTL removed in the trim |
| bitcoind_29 29.2, knots, loop | CLOSED (deleted) | Removed from fork |
| nbxplorer 2.6.7 | FIXED | Bumped to 2.6.10 (f9135cd) |
| M-1 clightning-rest 0.0.0.0 | CLOSED (deleted) | Module removed |
| M-2 lndconnect 0.0.0.0 rebind | FIXED | lndconnect no longer touches restAddress; exposure is explicit (modules/lndconnect.nix) |
| M-3 public RPC whitelist | FIXED | Dropped the DoS/side-effect methods (scantxoutset, gettxoutsetinfo, getblocktemplate, getblockfrompeer); whitelist now mkDefault-overridable. getpeerinfo/getnodeaddresses are KEPT — the "public" user is also lnd/nbxplorer's local RPC user and they require them (removing them fails lnd's chain-backend health check). Only trim those two if you actually expose this user over a public proxy. |
| M-4 onion-addresses symlinks | FIXED | Root builds dirs root:root then chowns; symlink reads refused (2aa9475) |
| M-5 clightning-replication hardening | CLOSED (deleted) | Module removed |
| M-6 netns-exec PATH/env | FIXED | Absolute path required (execv), cap returns checked, exec failure nonzero; whitelist updated to live services |
| M-7 ecdsa CVE-meta unlock | CLOSED (deleted) | Left with hardware-wallets |
| M-8 txzmq | CLOSED (deleted) | Removed with clightning plugins |
| L secrets argv | FIXED | rpcauth.py gets the password via file, not argv |
| L unquoted expansions in setup-secrets | FIXED | escapeShellArg on all interpolations |
| L wireguard self-re-exec | FIXED | Explicit `wg set` call, no sed-patched re-execution |
| L clightning group == admin | CLOSED (deleted) | clightning removed |
| L bitcoind cookie group-readable | DOCUMENTED | By design for local operator convenience; warning comment added at modules/bitcoind.nix |
| L bitcoind-remote password append | FIXED | Line rewritten, not appended; 0640 enforced |
| L krops tag pin | FIXED | Pinned commit hash of tag 1.26.2 |
| L doCheck=false / RTL npm flags / nixops | CLOSED (mostly deleted) | nixops remains dev-only tooling |

Verified on the build host: all kept packages build (nbxplorer 2.6.10,
lndinit, netns-exec), all 12 real test scenarios evaluate, netns-exec
functional tests pass, rpcauth wrapper produces valid HMAC without argv
exposure. `tests.base`/`tests.regtestBase` fail to evaluate both before
and after the trim — pre-existing upstream scaffolding quirk, not a
regression.

## 5. Maintenance posture (the real long-term risk)

The snapshot is fresh (nixpkgs pins are ~5 days old), but the security model of this repo is
**rolling nixpkgs pins**. Once maintenance stalls, every component above decays at the pace of
upstream disclosures (Bitcoin Core discloses low-sev fixes 2 weeks after each major release;
CLN/LND fix silently in point releases).

Recommendations for the new maintainers:
1. Automate `helper/update-flake.nix` on a schedule (weekly), with the test suite as the gate.
2. Subscribe to: bitcoincore.org security RSS, lightningnetwork/lnd + ElementsProject/lightning
   releases, ZmnSCPxj/clboss, btcpayserver security advisories, Ride-The-Lightning/RTL releases.
3. Decide joinmarket's future now: upstream is archived. 0.9.12 is the final release ever.
4. Add a `docs/security.md` tracker: this file as the first entry, re-run the version/CVE matrix
   on every flake bump.
