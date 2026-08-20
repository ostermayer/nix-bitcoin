# Security Policy

This repository is an independently maintained fork of
[fort-nix/nix-bitcoin](https://github.com/fort-nix/nix-bitcoin), which is no
longer actively maintained. The contacts, GPG keys, signing key, and security
fund listed in upstream's SECURITY.md belong to the original developers and do
not reach or represent this fork. Do not send reports or donations to them on
our behalf.

## Reporting a Vulnerability

Report vulnerabilities through [GitHub private vulnerability
reporting](../../security/advisories/new). This opens a private security
advisory that only the maintainers can see.

If private reporting is unavailable, open a regular issue that says you have a
security concern, without any details, and we will arrange a private channel.

Please include:

- The component and version or commit you tested
- Steps to reproduce or a proof of concept
- The impact you see (fund theft, privacy loss, denial of service, ...)

We aim to acknowledge reports within 7 days. We follow coordinated disclosure:
we agree on a public disclosure date with you, credit you in the fix and
release notes unless you prefer anonymity.

## Scope

In scope:

- nix-bitcoin's own code: NixOS modules, `netns-exec`, secrets handling,
  helper scripts, packaging in `pkgs/`
- Privilege boundaries we claim to provide: service isolation, RPC
  whitelisting, `netns-isolation`, systemd sandboxing
- Documentation that instructs users to do something blatantly insecure

Out of scope:

- Vulnerabilities in the daemons we package (bitcoind, lnd,
  electrs, btcpayserver, nbxplorer, ...). Report those to the upstream
  project first. If upstream has shipped a fix that we have not yet pulled in,
  tell us and we will treat it as urgent.
- Attacks requiring physical access or an already-compromised deployment
  machine.

## Supported Versions

Only the latest commit on the default branch and the latest release are
supported. Security fixes are delivered by updating your flake input; we do
not maintain stable branches.

## Security Tracker

Known findings and their status are tracked in
[docs/security-audit-2026-08-14.md](docs/security-audit-2026-08-14.md). The
audit is re-run on every nixpkgs pin update.

## Release Integrity

Merge and release commits are signed by the maintainers. `bitcoind` source
tarballs are verified against the Bitcoin Core `guix.sigs` keyring at build
time. Verify releases with `helper/fetch-release` before deploying.
