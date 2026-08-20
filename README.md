<p align="center">
  <img
    width="320"
    src="docs/img/nix-bitcoin-logo.png"
    alt="nix-bitcoin logo">
</p>
<br/>
<p align="center">
    <a href="https://github.com/ostermayer/nix-bitcoin/actions/workflows/test.yml" target="_blank">
        <img src="https://github.com/ostermayer/nix-bitcoin/actions/workflows/test.yml/badge.svg?branch=release"
             alt="CI status (release)">
    </a>
    <a href="https://github.com/ostermayer/nix-bitcoin/releases/latest" target="_blank">
        <img src="https://img.shields.io/github/v/tag/ostermayer/nix-bitcoin?label=release" alt="Latest release tag">
    </a>
</p>
<br/>

> ### Maintained fork
>
> This is an **independently maintained fork** of
> [fort-nix/nix-bitcoin](https://github.com/fort-nix/nix-bitcoin), which reached
> **end of life** at `v0.0.139` (2026-08): the upstream repo is archived and
> receives no further updates or security fixes. Because nix-bitcoin pins its
> **entire nixpkgs** (kernel, sshd, tor, openssl, …), that freeze would strand
> security updates for anyone still on it — so this fork continues maintenance.
>
> It is **trimmed to a subset of upstream's services** (see below) and is driven
> by the maintainer's own production fleet. It is offered in good faith and
> **without warranty**; review it yourself before trusting funds to it. Not
> affiliated with or endorsed by the original nix-bitcoin developers — do not
> send them reports or donations on this fork's behalf (see
> [SECURITY.md](SECURITY.md)).

nix-bitcoin is a collection of Nix packages and NixOS modules for easily installing **full-featured Bitcoin nodes** with an emphasis on **security**.

Overview
---
nix-bitcoin can be used for personal or merchant wallets, public infrastructure or
for Bitcoin application backends. In all cases, the aim is to provide security and
privacy by default. However, while nix-bitcoin is used in production today, it is
still considered experimental.

What this fork changes
---
- **Trimmed to the services we run and test:** `bitcoind`, `lnd`
  (+ `lndinit`, `lndconnect`), `electrs`, `btcpayserver` + `nbxplorer`, plus the
  infrastructure modules (operator, secrets, onion services, netns-isolation,
  nodeinfo, backups, presets). Removed: clightning (+ plugins), joinmarket, RTL,
  mempool, fulcrum, liquid, lightning-loop/pool, charge-lnd, hardware-wallets.
  Enabling a removed service gives a clear eval error. Tag `v0.0.139` is the last
  revision with the full upstream service set.
- **We own the nixpkgs pin now.** Security bumps for kept packages land as
  version-guarded overrides in `pkgs/overrides.nix` (inert once the pin catches
  up). The pin is moved deliberately and tested (below).
- **Every change is tested before `release` moves:** the full NixOS VM assertion
  suite (`default`/`regtest`/`netns`) runs in CI on KVM, plus a weekly
  [CVE scan](.github/workflows/cve-scan.yml) of the shipped closure. All commits
  are signed; the `release` branch only advances on green CI.

Using this fork
---
Pin the **`release`** branch — it only ever points at a CI-validated, tagged
snapshot. Flake input:

```nix
inputs.nix-bitcoin.url = "github:ostermayer/nix-bitcoin/release";
```

Optional: our binary cache serves the CI-built closures, so you skip local
recompiles.

```nix
nix.settings = {
  extra-substituters = [ "https://ostermayer.cachix.org" ];
  extra-trusted-public-keys =
    [ "ostermayer.cachix.org-1:Pllh4qnP/CkBt+XhIPyT3mMZ/3tnEdcAiSgV/KSqvUk=" ];
};
```

nix-bitcoin nodes can be deployed on dedicated hardware, virtual machines or containers.
The Nix packages and NixOS modules can be used independently and combined freely.

nix-bitcoin is built on top of Nix and [NixOS](https://nixos.org/) which provide powerful abstractions to keep it highly customizable and
maintainable. Testament to this are nix-bitcoin's robust security features and its potent test framework.  However,
running nix-bitcoin does not require any previous experience with the Nix ecosystem.

Get started
---
- See the [examples](examples/README.md) for an overview of all features.
- To setup a new node from scratch, see the [installation instructions](docs/install.md).
- To add nix-bitcoin to an existing NixOS configuration, see [importable-configuration.nix](examples/importable-configuration.nix)
  and the [Flake example](examples/flakes/flake.nix).

Docs
---
Hint: To show a table of contents, click the button (![Github TOC button](docs/img/github-table-of-contents.svg)) in the
top left corner of the documents.

<!-- TODO-EXTERNAL: -->
<!-- Change query to `nix-bitcoin` when upstream search has been fixed -->
* [NixOS options search](https://search.nixos.org/flakes?channel=unstable&sort=relevance&type=options&query=bitcoin)
* [Hardware requirements](docs/hardware.md)
* [Installation](docs/install.md)
* [Configuration and maintenance](docs/configuration.md)
* [Using services](docs/services.md)
* [FAQ](docs/faq.md)

Features
---
A [configuration preset](modules/presets/secure-node.nix) for setting up a secure node
* All applications use Tor for outbound connections and support accepting inbound connections via onion services.

NixOS modules ([src](modules/modules.nix))
* Application services
  * [bitcoind](https://github.com/bitcoin/bitcoin)
  * [lnd](https://github.com/lightningnetwork/lnd) with support for announcing an onion service and [static channel backups](https://github.com/lightningnetwork/lnd/blob/master/docs/recovery.md)
  * [lndconnect](https://github.com/LN-Zap/lndconnect): connect your wallet to lnd
    [via WireGuard](./docs/services.md#use-zeus-mobile-lightning-wallet-via-wireguard) or
    [Tor](./docs/services.md#use-zeus-mobile-lightning-wallet-via-tor)
  * [electrs](https://github.com/romanz/electrs): Electrum server
  * [btcpayserver](https://github.com/btcpayserver/btcpayserver)
* Helper
  * [netns-isolation](modules/netns-isolation.nix): isolates applications on the network-level via network namespaces
  * [nodeinfo](modules/nodeinfo.nix): script which prints info about the node's services
  * [backups](modules/backups.nix): duplicity backups of all your node's important files
  * [operator](modules/operator.nix): configures a non-root user who has access to client tools (e.g. `bitcoin-cli`, `lncli`)

Security
---
See [SECURITY.md](SECURITY.md) for the security policy and how to report a vulnerability.

nix-bitcoin aims to achieve a high degree of security by building on the following principles:

* **Simplicity:** Only services enabled in `configuration.nix` and their dependencies are installed, support for [doas](https://github.com/Duncaen/OpenDoas) ([sudo alternative](https://lobste.rs/s/efsvqu/heap_based_buffer_overflow_sudo_cve_2021#c_c6fcfa)), code is continuously reviewed and refined.
* **Integrity:** The Nix package manager guarantees that all dependencies are exactly specified, packages can be built from source to reduce reliance on binary caches, nix-bitcoin merge commits are signed, all commits are approved by multiple nix-bitcoin developers, upstream packages are cryptographically verified where possible, we use this software ourselves.
* **Principle of Least Privilege:** Services operate with least privileges; they each have their own user and are restricted further with [systemd features](pkgs/lib.nix), [RPC whitelisting](modules/bitcoind-rpc-public-whitelist.nix) and [netns-isolation](modules/netns-isolation.nix). There's a non-root user *operator* to interact with the various services.
* **Defense-in-depth:** nix-bitcoin supports a [hardened kernel](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/hardened.nix), services are confined through discretionary access control, Linux namespaces, [dbus firewall](modules/security.nix) and seccomp-bpf with continuous improvements.

Note that if the machine you're deploying *from* is insecure, there is nothing nix-bitcoin can do to protect itself.


Developing
---
See [dev/README](./dev/README.md).

Troubleshooting
---
If you are having problems with this fork, check the [FAQ](docs/faq.md) or open an
issue on **this** repository. The upstream Matrix room and nixbitcoin.org
channels belong to the original project and do not cover this fork.
