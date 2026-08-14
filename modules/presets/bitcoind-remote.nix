{ config, lib, pkgs, ... }:

let
  cfg = config.services.bitcoind;
  secretsDir = config.nix-bitcoin.secretsDir;
in {
  services.bitcoind = {
    # Make the local bitcoin-cli work with the remote node.
    # Without this, bitcoin-cli would try to use the .cookie file in the local
    # bitcoind data dir for authorization, which doesn't exist.
    extraConfig = ''
      rpcuser=${cfg.rpc.users.privileged.name}
    '';
  };

  systemd.services.bitcoind = {
    preStart = lib.mkAfter ''
      # Rewrite, don't append: the old version added a duplicate line on every
      # restart (audit L-11). The privileged RPC password must stay 0640
      # (owner bitcoin, group bitcoin) so the operator can read it for
      # bitcoin-cli, but not world-readable.
      conf='${cfg.dataDir}/bitcoin.conf'
      ${pkgs.gnused}/bin/sed -i '/^rpcpassword=/d' "$conf"
      echo "rpcpassword=$(cat ${secretsDir}/bitcoin-rpcpassword-privileged)" >> "$conf"
      chmod 0640 "$conf"
    '';
    postStart = lib.mkForce "";
    serviceConfig = {
      Type = lib.mkForce "oneshot";
      ExecStart = lib.mkForce "${pkgs.coreutils}/bin/true";
      RemainAfterExit = true;
    };
  };
}
