# Extra scenarios for developing and debugging

{ lib, scenarios }:

with lib;
{
  btcpayserver-regtest = {
    imports = [ scenarios.regtestBase ];
    services.btcpayserver.enable = true;
    test.container.exposeLocalhost = true;

    # Required for testing interactive plugin installation
    test.container.enableWAN = true;
  };

  wireguard-lndconnect-online = { config, pkgs, lib, ... }: {
    imports = [
      ../modules/presets/wireguard.nix
      scenarios.regtestBase
    ];

    # 51820 (default wg port) + 1
    networking.wireguard.interfaces.wg-nb.listenPort = 51821;
    test.container.enableWAN = true;
    # test.container.exposeLocalhost = true;

    services.lnd = {
      enable = true;
      lndconnect = {
        enable = true;
        onion = true;
      };
    };
    nix-bitcoin.nodeinfo.enable = true;
  };
}
