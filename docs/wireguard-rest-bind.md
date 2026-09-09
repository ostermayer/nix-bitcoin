# Deferred: bind lnd's REST API to the WireGuard address

Status: **DEFERRED — do not implement without working through every item below.**

The 2026-08-24 adversarial audit (run `2026-08-24-111031`, both models) flagged
that the wireguard preset sets `services.lnd.restAddress = "0.0.0.0"`
(modules/presets/wireguard.nix), exposing the macaroon-admin REST API on all
interfaces and relying solely on the nixos-fw firewall (default-drop plus an
accept rule for the wg subnet) for protection. Severity medium/low, advisory.
The suggested fix — bind to the wg server address (`${subnet}.1`, default
10.10.0.1) instead — is correct as defense-in-depth but **breaks several
things that are non-obvious**, because of one load-bearing detail:

> `nbLib.address` (pkgs/lib.nix) maps the bind address `0.0.0.0` to the
> *connect* address `127.0.0.1`. Every internal consumer of `restAddress`
> goes through it. Today they all silently talk to localhost, which the
> default TLS cert covers. Bind to `10.10.0.1` and they **all** follow.

## What a naive `restAddress = serverAddress` breaks

1. **lnd startup becomes hard-coupled to WireGuard.** lnd fails fatally if it
   cannot bind `restlisten`; the `10.10.0.1` address only exists once
   `wireguard-wg-nb.service` has configured the interface. Without systemd
   ordering, boot is a crash-loop race (`Restart=on-failure`/10s masks it
   until it doesn't). *With* ordering, a broken wg setup (e.g. missing
   `wg-server-private-key` secret) takes the whole lightning node down —
   today lnd runs fine with wg broken. This coupling is inherent to the fix;
   it must be a conscious acceptance, or defused with
   `net.ipv4.ip_nonlocal_bind = 1` (system-wide sysctl loosening — an
   auditor trade-off of its own).

2. **TLS cert SANs.** The generated lnd cert only has
   `DNS:localhost,IP:127.0.0.1` plus `rpcAddress` when non-local
   (modules/secrets/secrets.nix `doMakeCert`; modules/lnd.nix
   `certificate.extraIPs`). Nothing adds the REST address. Any validating
   client connecting to `https://10.10.0.1:8080` fails TLS. The preset must
   set `services.lnd.certificate.extraIPs = [ serverAddress ]`. Note
   `makeCert` *does* regenerate the cert when alt-names change
   (secrets.nix, `$name-cert-alt-names` comparison), so deployed nodes pick
   the new SAN up on the next deploy — but anything that pinned the old cert
   must tolerate rotation.

3. **Macaroon creation runs in lnd's `ExecStartPost`** (modules/lnd.nix): a
   root script curls `https://<nbLib.address restAddress>:<restPort>/v1` with
   `--cacert`. It would move from 127.0.0.1 to 10.10.0.1 → fails without
   item 2 and item 1 → **lnd.service itself fails post-start**, even though
   the daemon is healthy.

4. **btcpayserver's lnd-rest backend** (modules/btcpayserver.nix,
   `btclightning=...server=https://<address restAddress>...`) moves to
   10.10.0.1 too: needs the SAN fix and makes btcpayserver transitively
   wg-dependent.

5. **lndconnect onion mode** (modules/lndconnect.nix): the Tor hidden
   service forwards to `nbLib.address lnd.restAddress`. Tor-based mobile
   access would then depend on the wg interface being up.

6. **nodeinfo** (modules/nodeinfo.nix) reports `rest_address` — cosmetic,
   but scripts parsing it see a new value.

## Recommended design (avoids 2–6 entirely)

Do **not** touch `restAddress`. Leave it at its default `127.0.0.1` and have
the preset add a *second* listener — lnd accepts repeated `restlisten`
entries:

```nix
services.lnd.extraConfig = ''
  restlisten=${serverAddress}:${toString lnd.restPort}
'';
```

All internal consumers keep localhost (valid cert SAN, no wg coupling); the
wg peer reaches `10.10.0.1:8080` exactly as before (`lndconnect-wg` already
targets `serverAddress` with `--nocert`). Only item 1 — the bind-time
dependency on the interface — remains, and still needs:

- `systemd.services.lnd = { wants = [ "wireguard-wg-nb.service" ]; after = [ "wireguard-wg-nb.service" ]; }`
  in the preset (runtime wg restarts are fine: a bound socket survives
  interface teardown and resumes when the address returns);
- the firewall accept rule stays (nixos-fw default-drops; the rule is what
  admits the peer). Since 2026-09-09 it is already scoped to the interface
  and the single peer (`-i wg-nb -s <peerAddress>/32`), closing the
  2026-08-29 low: a spoofed-source packet on the external interface no
  longer matches the rule at all, independent of rp_filter/routing.

## Pre-flight checklist before shipping any variant

- [ ] Decide on the lnd↔wg startup coupling (accept, or `ip_nonlocal_bind`).
- [ ] `test/wireguard-lndconnect.nix`: assert lnd comes up cleanly from a
      cold boot (ordering race), REST reachable over wg at
      `serverAddress:restPort`, REST **not** bound on the external
      interface (the actual point of the fix), macaroon `ExecStartPost`
      succeeded, and — if btcpayserver is in the scenario — its lnd backend
      connects.
- [ ] Full local VM suite green (`./test/run-tests.sh`).
- [ ] Verify on a staging deploy that cert regeneration (if `restAddress`
      was changed rather than the extraConfig variant) does not strand
      existing clients.
- [ ] Re-run the adversarial LLM audit (audits branch) — per policy every
      fix re-runs the whole review; the review should specifically re-check
      items 1–6.
