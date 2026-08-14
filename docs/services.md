# Nodeinfo
Run `nodeinfo` to see onion addresses and local addresses for enabled services.

# Managing services

NixOS uses the [systemd](https://wiki.archlinux.org/title/systemd) service manager.

Usage:
```shell
# Show service status
systemctl status bitcoind

# Show the last 100 log messages
journalctl -u bitcoind -n 100
# Show all log messages since the last system boot
journalctl -b -u bitcoind

# These commands require root permissions
systemctl stop bitcoind
systemctl start bitcoind
systemctl restart bitcoind

# Show the service definition
systemctl cat bitcoind
# Show all service parameters
systemctl show bitcoind
```

# Use Zeus (mobile lightning wallet) via Tor
1. Install [Zeus](https://zeusln.app) (version ≥ 0.9.0)

2. Edit your `configuration.nix`

   Add the following config:
   ```nix
   services.lnd.lndconnect = {
     enable = true;
     onion = true;
   };
   ```

3. Deploy your configuration

4. Run the following command on your node (as user `operator`) to create a QR code
   with address and authentication information:

   ```
   lndconnect
   ```

5. Configure Zeus
   - Add a new node and scan the QR code
   - Click `Save node config`
   - Start sending and stacking sats privately

### Additional lndconnect features
- Create a plain text URL:
  ```bash
  lndconnect --url
  ```
- Set a custom host. By default, `lndconnect` detects the system's external IP and uses it as the host.
  ```bash
  lndconnect --host myhost
  ```

# Use Zeus (mobile lightning wallet) via WireGuard

Connecting Zeus directly to your node is much faster than using Tor, but a bit more complex to setup.

There are two ways to establish a secure, direct connection:

- Connecting via TLS. This requires installing your lightning app's
  TLS Certificate on your mobile device.

- Connecting via WireGuard. This approach is simpler and more versatile, and is
  described in this guide.

1. Install [Zeus](https://zeusln.app) (version ≥ 0.9.0) and
   [WireGuard](https://www.wireguard.com/install/) on your mobile device.

2. Add the following to your `configuration.nix`:
   ```nix
   imports = [
     # Use this line when using the default deployment method
     <nix-bitcoin/modules/presets/wireguard.nix>

     # Use this line when using Flakes
     (nix-bitcoin + /modules/presets/wireguard.nix)
   ]

   services.lnd.lndconnect.enable = true;
   ```
3. Deploy your configuration.

4. If your node is behind an external firewall or NAT (e.g. a router), add the following port forwarding
   rule to the external device:
   - Port: 51820 (the default value of option `networking.wireguard.interfaces.wg-nb.listenPort`)
   - Protocol: UDP
   - Destination: IP of your node

5. Setup WireGuard on your mobile device.

   Run the following command on your node (as user `operator`) to create a QR code
   for WireGuard:
   ```bash
   nix-bitcoin-wg-connect

   # For debugging: Show the WireGuard config as text
   nix-bitcoin-wg-connect --text
   ```
   The above commands automatically detect your node's external IP.\
   To set a custom IP or hostname, run the following:
   ```
   nix-bitcoin-wg-connect 93.184.216.34
   nix-bitcoin-wg-connect mynode.org
   ```

   Configure WireGuard:
   - Press the `+` button in the bottom right corner
   - Scan the QR code
   - Add the tunnel

6. Setup Zeus

   Run the following command on your node (as user `operator`) to create a QR code for Zeus:

   ```
   lndconnect-wg
   ```

   Configure Zeus:
   - Add a new node and scan the QR code
   - Click `Save node config`
   - On the certificate warning screen, click `I understand, save node config`.\
     Certificates are not needed when connecting via WireGuard.
   - Start sending and stacking sats privately

### Additional lndconnect features
Create a plain text URL:
```bash
lndconnect-wg --url
``````

# Connect to electrs
### Requirements Android
* Android phone
* [Orbot](https://guardianproject.info/apps/orbot/) installed from [F-Droid](https://guardianproject.info/fdroid) (recommended) or [Google Play](https://play.google.com/store/apps/details?id=org.torproject.android&hl=en)
* [Electrum mobile app](https://electrum.org/#home) 4.0.1 and newer installed from [direct download](https://electrum.org/#download) or [Google Play](https://play.google.com/store/apps/details?id=org.electrum.electrum)

### Requirements Desktop
* [Tor](https://www.torproject.org/) installed from [source](https://www.torproject.org/docs/tor-doc-unix.html.en) or [repository](https://www.torproject.org/docs/debian.html.en)
* [Electrum](https://electrum.org/#download) installed

1. Enable electrs in `configuration.nix`

    Change
    ```
    # services.electrs.enable = true;
    ```
    to
    ```
    services.electrs.enable = true;
    ```

2. Deploy new `configuration.nix`

3. Get electrs onion address with format `<onion-address>:<port>`

    ```
    nodeinfo | jq -r .electrs.onion_address
    ```

4. Connect to electrs

    Make sure Tor is running on Desktop or as Orbot on Android.

    On Desktop
    ```
    electrum --oneserver -1 -s "<electrs onion address>:t" -p socks5:127.0.0.1:9050
    ```

    On Android
    ```
    Three dots in the upper-right-hand corner
    Network > Proxy mode: socks5, Host: 127.0.0.1, Port: 9050
    Network > Auto-connect: OFF
    Network > One-server mode: ON
    Network > Server: <electrs onion address>:t
    ```

# Connect to nix-bitcoin node through the SSH onion service
1. Get the SSH onion address (excluding the port suffix)

    ```
    ssh operator@bitcoin-node
    nodeinfo | jq -r .sshd.onion_address | sed 's/:.*//'
    ```

2. Create a SSH key

    ```
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
    ```

3. Place the ed25519 key's fingerprint in the `configuration.nix` `openssh.authorizedKeys.keys` field like so

    ```
    # FIXME: Add your SSH pubkey
    services.openssh.enable = true;
    users.users.root = {
      openssh.authorizedKeys.keys = [ "<contents of ~/.ssh/id_ed25519.pub>" ];
    };
    ```

4. Connect to your nix-bitcoin node's SSH onion service, forwarding a local port to the nix-bitcoin node's SSH server

    ```
    ssh -i ~/.ssh/id_ed25519 -L <random port of your choosing>:127.0.0.1:22 root@<SSH onion address>
    ```

5. Edit your deployment tool's configuration and change the node's address to `127.0.0.1` and the ssh port to `<random port of your choosing>`.
   If you use krops as described in the [installation tutorial](./install.md), set `target = "127.0.0.1:<random port of your choosing>";` in `krops/deploy.nix`.

6. After deploying the new configuration, it will connect through the SSH tunnel you established in step iv. This also allows you to do more complex SSH setups that some deployment tools don't support. An example would be authenticating with [Trezor's SSH agent](https://github.com/romanz/trezor-agent), which provides extra security.
