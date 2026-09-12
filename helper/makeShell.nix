{ configDir, shellVersion ? null, extraShellInitCmds ? (pkgs: "") }:
let
  pinned = import ../pkgs/nixpkgs-pinned.nix;
  pkgs = import nixpkgs { config = {}; overlays = []; };
  inherit (pkgs) lib;
  inherit (pinned) nixpkgs;
  nbPkgs = import ../pkgs { inherit pkgs; };
  cfgDir = toString configDir;
  setPath = lib.optionalString pkgs.stdenv.isLinux ''
    export PATH="${lib.makeBinPath [ nbPkgs.pinned.extra-container ]}''${PATH:+:}$PATH"
  '';
in
pkgs.stdenv.mkDerivation {
  name = "nix-bitcoin-environment";

  helpMessage = ''
    nix-bitcoin path: ${toString ../.}

    Available commands
    ==================
    deploy
      Run krops-deploy and eval-config in parallel.
      This ensures that eval failures appear quickly when deploying.
      In this case, deployment is stopped.

    krops-deploy
      Deploy your node via krops

    eval-config
      Evaluate your node system configuration

    build-config
       Build your node system on your local machine

    generate-secrets
      Create secrets required by your node configuration.
      Secrets are written to ./secrets/
      This function is automatically called by krops-deploy.

    update-nix-bitcoin
      Fetch and use the latest version of nix-bitcoin
  '';

  shellHook = ''
    export NIX_PATH="nixpkgs=${nixpkgs}:nix-bitcoin=${toString ../.}:."
    ${setPath}
    export NIX_BITCOIN_EXAMPLES_DIR="${cfgDir}"
    export nixpkgsUnstable="${pinned.nixpkgs-unstable}"

    # Set isInteractive=1 if
    # 1. stdout is a TTY, i.e. we're not piping the output
    # 2. the shell is interactive
    if [[ -t 1 && $- == *i* ]]; then isInteractive=1; else isInteractive=; fi

    # Make this a non-environment var
    export -n helpMessage

    help() { echo "$helpMessage"; }
    h() { help; }

    fetch-release() {
      ${toString ./fetch-release}
    }

    update-nix-bitcoin() {(
      # Fork-native pin: resolve the fork's latest CalVer release tag to the
      # commit it points at, prefetch that commit's tarball and rewrite
      # nix-bitcoin-release.nix. Never fetches upstream fort-nix releases
      # (they lack this fork's fixes). Tags are unsigned CI pointers — the
      # commit is what you review; see SECURITY.md.
      set -euo pipefail
      releaseFile="${cfgDir}/nix-bitcoin-release.nix"
      repo=https://github.com/ostermayer/nix-bitcoin
      tag=$(git ls-remote --tags --refs "$repo" 'refs/tags/20*' | sed 's|.*refs/tags/||' | sort -V | tail -n1)
      [[ $tag ]] || { echo "No release tag found on $repo" >&2; exit 1; }
      commit=$(git ls-remote "$repo" "refs/tags/$tag^{}" | cut -f1)
      [[ $commit ]] || commit=$(git ls-remote "$repo" "refs/tags/$tag" | cut -f1)
      url="$repo/archive/$commit.tar.gz"
      hash=$(nix-prefetch-url --unpack "$url" 2>/dev/null)
      new=$(printf 'builtins.fetchTarball {\n  # fork release %s\n  url = "%s";\n  sha256 = "%s";\n}\n' "$tag" "$url" "$hash")
      current=$(cat "$releaseFile" 2>/dev/null || true)
      if [[ $new == "$current" ]]; then
        echo "nix-bitcoin-release.nix already pins $tag ($commit)"
      else
        printf '%s' "$new" > "$releaseFile"
        echo "Pinned $tag ($commit) in nix-bitcoin-release.nix."
        echo "Review that commit first — the next nix-shell evaluates the new tree's shellHook:"
        echo "  https://github.com/ostermayer/nix-bitcoin/compare/$(echo "$current" | sed -n 's|.*/archive/\([0-9a-f]*\)\.tar\.gz.*|\1|p')...$commit"
        echo "then re-enter the deployment shell with: exit; nix-shell"
        # Deliberately no automatic `exec nix-shell`: that would run the newly
        # pinned revision's shell code on this machine before the review the
        # line above asks for (second opinion 2026-09-09).
      fi
    )}

    generate-secrets() {(
      set -euo pipefail
      config="${cfgDir}/krops/krops-configuration.nix"
      if [[ ! -e $config ]]; then
        config="${cfgDir}/configuration.nix"
      fi
      genSecrets=$(nix-build --no-out-link -I nixos-config="$config" \
                   '<nixpkgs/nixos>' -A config.nix-bitcoin.generateSecretsScript)
      mkdir -p "${cfgDir}/secrets"
      (cd "${cfgDir}/secrets"; $genSecrets)
    )}

    deploy() {(
      set -euo pipefail
      krops-deploy &
      kropsPid=$!
      if eval-config; then
        wait $kropsPid
      else
        # Kill all subprocesses
        kill $(pidClosure $kropsPid)
        return 1
      fi
    )}

    krops-deploy() {(
      set -euo pipefail
      generate-secrets
      # Ensure strict permissions on secrets/ directory before rsyncing it to
      # the target machine
      chmod 700 "${cfgDir}/secrets"
      $(nix-build --no-out-link "${cfgDir}/krops/deploy.nix")
    )}

    eval-config() {(
      set -euo pipefail
      system=$(getNodeSystem)
      NIXOS_CONFIG="${cfgDir}/krops/krops-configuration.nix" \
        nix-instantiate --eval ${nixpkgs}/nixos $system -A system.outPath | tr -d '"'
      echo
    )}

    build-config() {(
      set -euo pipefail
      system=$(getNodeSystem)
      NIXOS_CONFIG="${cfgDir}/krops/krops-configuration.nix" \
        nix-build --no-out-link ${nixpkgs}/nixos $system -A system
    )}

    getNodeSystem() {
      if [[ -e '${cfgDir}/krops/system' ]]; then
        echo -n "--argstr system "; cat '${cfgDir}/krops/system'
      elif [[ $OSTYPE == darwin* ]]; then
        # On macOS, `builtins.currentSystem` (`*-darwin`) can never equal
        # the node system (`*-linux`), so we can always provide a helpful error message:
        >&2 echo "Error, node system not set. See here how to fix this:"
        >&2 echo "https://github.com/fort-nix/nix-bitcoin/blob/master/docs/install.md#optional-specify-the-system-of-your-node"
        return 1
      fi
    };

    pidClosure() {
      echo "$1"
      for pid in $(ps -o pid= --ppid "$1"); do
        pidClosure "$pid"
      done
    }

    if [[ $isInteractive ]]; then
      ${pkgs.figlet}/bin/figlet "nix-bitcoin"
      echo 'Enter "h" or "help" for documentation.'
    fi

    # Don't run this hook when another nix-shell is run inside this shell
    unset shellHook

    ${extraShellInitCmds pkgs}
  '';
}
