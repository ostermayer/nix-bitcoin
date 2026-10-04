# Tutorial: Install and configure NixOS for nix-bitcoin on a dedicated machine

This tutorial installs NixOS on a dedicated machine and manages the resulting
Bitcoin node from another computer with the deployment tool
[krops](https://github.com/krebs/krops). nix-bitcoin is deployment-tool
agnostic; see the [examples](../examples/README.md) for flake, VM, and container
alternatives.

## 0. Preparation

1. Find a machine to deploy nix-bitcoin on (see [hardware.md](hardware.md)).

2. Optional: Make sure your system firmware (BIOS/UEFI and device firmware) is
   current. NixOS can install CPU microcode updates after deployment.

3. Optional: Disable simultaneous multithreading (SMT) in the firmware.

   SMT, marketed by Intel as Hyper-Threading, can increase exposure to some
   cross-thread microarchitectural attacks. Disabling it trades performance for
   a smaller attack surface; decide according to the node's threat model.

## 1. NixOS installation

This is a focused version of the official [NixOS installation
manual](https://nixos.org/manual/nixos/stable/#sec-installation). Follow the
manual when your storage, boot, or networking setup differs from the simple
examples below.

1. Download the current stable minimal ISO from the official [NixOS download
   page](https://nixos.org/download/). Use the architecture of the target node
   (`x86_64-linux` or `aarch64-linux`) and verify the SHA-256 checksum published
   beside the image:

    ```bash
    sha256sum nixos-minimal-<version>-<architecture>.iso
    ```

    Do not copy a checksum from this guide: installer revisions change as
    security and bug fixes are released.

2. Write the NixOS ISO to installation media. On Linux, for example:

    ```bash
    lsblk
    sudo cp nixos-minimal-<version>-<architecture>.iso /dev/sdX
    sync
    ```

    **Warning:** replace `/dev/sdX` with the whole USB device, not a partition.
    This overwrites the selected device. Confirm it with `lsblk` immediately
    before running the copy command.

3. Boot the system and become root:

    ```
    sudo -i
    ```

    Check whether the installer booted with UEFI:

    ```
    ls /sys/firmware/efi
    ```

    If the directory exists, use the UEFI instructions; otherwise use the
    legacy BIOS instructions. Prefer UEFI when the machine supports it.

4. Partition and format the installation disk. The commands below destroy all
   data on `/dev/sda`; confirm the device name with `lsblk` first.

   **Option 1: UEFI**

    ```
    parted /dev/sda -- mklabel gpt
    parted /dev/sda -- mkpart primary 512MiB -8GiB
    parted /dev/sda -- mkpart primary linux-swap -8GiB 100%
    parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
    parted /dev/sda -- set 3 boot on
    mkfs.ext4 -L nixos /dev/sda1
    mkswap -L swap /dev/sda2
    mkfs.fat -F 32 -n boot /dev/sda3
    mount /dev/disk/by-label/nixos /mnt
    mkdir -p /mnt/boot
    mount -o umask=077 /dev/disk/by-label/boot /mnt/boot
    swapon /dev/sda2
    ```

   **Option 2: Legacy BIOS (MBR)**

    ```
    parted /dev/sda -- mklabel msdos
    parted /dev/sda -- mkpart primary 1MiB -8GiB
    parted /dev/sda -- mkpart primary linux-swap -8GiB 100%
    mkfs.ext4 -L nixos /dev/sda1
    mkswap -L swap /dev/sda2
    mount /dev/disk/by-label/nixos /mnt
    swapon /dev/sda2
    ```

   **Option 3: Encrypted storage**

   Follow the current NixOS manual's instructions for LUKS, LVM, or your chosen
   storage layout. Do not rely on an unmaintained copy-and-paste partitioning
   recipe for a machine that will hold keys.

5. Generate the NixOS configuration:

    ```
    nixos-generate-config --root /mnt
    nano /mnt/etc/nixos/configuration.nix
    ```

    Add SSH key authentication before installation. Replace the example key
    with the public key from your deployment computer:

    ```
    { config, pkgs, ... }:

    {
      imports = [
        ...
      ];

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "prohibit-password";
        };
      };

      users.users.root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAA... deployment-key"
      ];

      # The rest of the file are default options and hints.
    }
    ```

    `nixos-generate-config` normally detects the filesystems and UEFI boot mode.
    Review both generated files. For legacy BIOS, set
    `boot.loader.grub.device = "/dev/sda";` in `configuration.nix`. Do not edit
    generated hardware settings unless you have verified that detection was
    wrong.

6. Do the installation

    ```
    nixos-install
    ```

    You may set a strong local root password when prompted. Remote password
    login remains disabled by the SSH configuration above.

    ```
    setting root password...
    Enter new UNIX password:
    Retype new UNIX password:
    ```

7. If everything went well

    ```
    reboot
    ```

## 2. Nix installation
The following steps are meant to be run on the machine you deploy from, not the machine you deploy to.
You can also build Nix from source by following the instructions at https://nixos.org/nix/manual/#ch-installing-source.

1. Install dependencies. On Debian or Ubuntu:

    ```
    sudo apt-get install curl git gnupg2 dirmngr
    ```

2. Install a current multi-user Nix. Follow the official installer and its
   verification steps at https://nixos.org/download.

    ```
    curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon
    ```

    This fork is a flake. Enable the flake features. Add the line
    `experimental-features = nix-command flakes` to `/etc/nix/nix.conf`, then
    restart the `nix-daemon`. Open a new terminal window when you are done.

    If you get an error similar to

    ```
    error: cloning builder process: Operation not permitted
    error: unable to start build process
    /tmp/nix-binary-tarball-unpack.hqawN4uSPr/unpack/nix-2.2.1-x86_64-linux/install: unable to install Nix into your default profile
    ```

    you're likely not installing as multi-user because you forgot to pass the `--daemon` flag to the install script.

3. Optional: Disallow substitutes

    You can put `substitute = false` to your `nix.conf` usually found in `/etc/nix/` to build the packages from source.
    This eliminates an attack vector where nix's build server or binary cache is compromised.

## 3. Setup deployment directory

1. Clone this project

    ```
    git clone https://github.com/ostermayer/nix-bitcoin.git
    ```

2. Create a new directory for your nix-bitcoin node config and copy initial files from nix-bitcoin

    ```
    mkdir nix-bitcoin-node
    cd nix-bitcoin-node
    cp -r ../nix-bitcoin/examples/{configuration.nix,shell.nix,krops,.gitignore} .
    ```

3. Pin the fork release to deploy

    This is a maintained fork: do **not** use upstream fort-nix release
    tarballs (they lack the fork's fixes; `helper/fetch-release` refuses to
    run for that reason). Pin a commit of this fork instead — the deployment
    shell's `update-nix-bitcoin` command writes `nix-bitcoin-release.nix` for
    you from the latest `release` tag, or do it by hand:

    ```
    git -C ../nix-bitcoin fetch origin release
    commit=$(git -C ../nix-bitcoin rev-parse origin/release) # or any reviewed commit
    hash=$(nix-prefetch-url --unpack "https://github.com/ostermayer/nix-bitcoin/archive/$commit.tar.gz")
    cat > nix-bitcoin-release.nix <<EOF
    builtins.fetchTarball {
      url = "https://github.com/ostermayer/nix-bitcoin/archive/$commit.tar.gz";
      sha256 = "$hash";
    }
    EOF
    ```

    Release tags are unsigned CI pointers; the commit is what you review and
    pin (see `SECURITY.md`).

### Optional: Specify the system of your node
This enables evaluating your node config on a machine that has a different system platform
than your node.\
Examples: Deploying from macOS or deploying from a x86 desktop PC to a Raspberry Pi.

```bash
# Run this when your node has a 64-Bit x86 CPU (e.g., an Intel or AMD CPU)
echo "x86_64-linux" > krops/system

# Run this when your node has a 64-Bit ARM CPU (e.g., Raspberry Pi 4 B, Pine64)
echo "aarch64-linux" > krops/system
```
This fork supports `x86_64-linux` and `aarch64-linux`. Other architectures are
not release-tested.

## 4. Deploy with krops

1. Edit your ssh config

    ```
    nano ~/.ssh/config
    ```

    and add the node with an entry similar to the following (make sure to fix `Hostname` and `IdentityFile`):

    ```
    Host bitcoin-node
        # FIXME
        HostName NODE_IP_ADDRESS_OR_HOST_NAME_HERE
        User root
        PubkeyAuthentication yes
        # FIXME
        IdentityFile ~/.ssh/id_...
        AddKeysToAgent yes
    ```

2. Make sure you are in the deployment directory and edit `krops/deploy.nix`

    ```
    nano krops/deploy.nix
    ```

    Locate the `FIXME` and set the target to the name of the ssh config entry created earlier, i.e. `bitcoin-node`.

    Note that any file imported by your `configuration.nix` must be copied to the target machine by krops.
    For example, if there is an import of `networking.nix` you must add it to `extraSources` in `krops/deploy.nix` like this:
    ```
    extraSources = {
        "hardware-configuration.nix".file = toString ../hardware-configuration.nix;
        "networking.nix".file = toString ../networking.nix;
    };
    ```

3. Optional: Disallow substitutes

    If you prefer to build the system from source instead of copying binaries from the Nix cache, add the following line to `configuration.nix`:
    ```
      nix.settings.substitute = false;
    ```

    If the build process fails for some reason when deploying with `krops-deploy` (see later step), it may be difficult to find the cause due to the missing output.
    To see the build output, SSH into the target machine and run
    ```
    nixos-rebuild -I /var/src switch
    ```

4. Copy `hardware-configuration.nix` from your node to the deployment directory.

    ```
    scp root@bitcoin-node:/etc/nixos/hardware-configuration.nix .
    ```

5. Adjust configuration by opening the `configuration.nix` file and enable/disable the modules you want by editing this file.

    ```
    nano configuration.nix
    ```

    Pay attention to lines preceded by `FIXME` comments. In particular:

    1. Set your SSH public key. Otherwise, you lose remote access because
       password authentication is disabled.
    2. Uncomment `./hardware-configuration.nix` by removing `#`.

6. Enter the deployment environment

    ```
    nix-shell
    ```

7. Deploy with krops in nix-shell

    ```
    deploy
    ```

    This will now create a nix-bitcoin node on the target machine.

8. You can now access `bitcoin-node` via ssh

    ```
    ssh operator@bitcoin-node
    ```

    Note that you're able to log in as the unprivileged `operator` user because nix-bitcoin automatically authorizes the ssh key added to `root`.

For security reasons, all normal system management tasks can and should be performed with the `operator` user. Logging in as `root` should be done as rarely as possible.

See also:
- [Migrating existing services to nix-bitcoin](configuration.md#migrate-existing-services-to-nix-bitcoin)
- [Managing your deployment](configuration.md#managing-your-deployment)
- [Using services](services.md)
