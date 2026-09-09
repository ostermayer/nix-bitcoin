# Representative nix-bitcoin node: the secure-node preset plus every shipped
# service and backups — i.e. the recommended deployment.
#
# CVE-scan target (test/ci/cve-scan.sh): vulnix scans this system's RUNTIME
# closure — the software a user actually runs (bitcoind, lnd, electrs,
# btcpayserver, nbxplorer, kernel, systemd, openssl, …) — NOT build-time
# dependencies like compilers, which are what a test-derivation closure drags
# in and are irrelevant to a deployed node.
#
# Built with:  nix build --impure -f test/ci/scan-node.nix
let
  f = builtins.getFlake (builtins.toString ./../..);
  lib = f.inputs.nixpkgs.lib;
in
(lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    f.nixosModules.default
    # The recommended deployment, not the bare service set: secure-node pulls
    # in tor (client + onion services — the largest continuously exposed
    # parsing surface on a real node), the operator/doas setup and the preset
    # infrastructure; backups adds duplicity. Without these the scan silently
    # skipped exactly the components a deployed node exposes (audit
    # 2026-09-09, medium).
    "${f.outPath}/modules/presets/secure-node.nix"
    {
      nix-bitcoin.generateSecrets = true;
      services.backups.enable = true;
      services.bitcoind.enable = true;
      services.lnd.enable = true;
      services.electrs.enable = true;
      services.btcpayserver.enable = true;
      services.btcpayserver.lightningBackend = "lnd";
      # Minimal boot/fs so the system evaluates and builds a toplevel.
      boot.loader.grub.enable = false;
      fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
      system.stateVersion = "26.05";
    }
  ];
}).config.system.build.toplevel
