# Representative nix-bitcoin node with all shipped services enabled.
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
    {
      nix-bitcoin.generateSecrets = true;
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
