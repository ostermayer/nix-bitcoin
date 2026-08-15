# Integration tests, can be run without internet access.

lib: nixBitcoinModule:
let
  # Included in all scenarios
  baseConfig = { config, pkgs, ... }: with lib; let
    cfg = config.services;
    inherit (config.nix-bitcoin.lib.test) mkIfTest;
  in {
    imports = [
      ./lib/test-lib.nix
      nixBitcoinModule
      {
        # Features required by the Python test suite
        nix-bitcoin.secretsDir = "/secrets";
        nix-bitcoin.generateSecrets = true;
        nix-bitcoin.operator.enable = true;
        environment.systemPackages = with pkgs; [ jq ];
      }
    ];

    config = mkMerge [{
      environment.systemPackages = mkMerge (with pkgs; [
        # Needed to test macaroon creation
        (mkIfTest "btcpayserver" [ openssl xxd ])
        # Needed to test certificate creation
        (mkIfTest "lnd" [ openssl ])
      ]);

      tests.bitcoind = cfg.bitcoind.enable;
      services.bitcoind = {
        enable = true;
        extraConfig = mkIf config.test.noConnections "connect=0";
      };

      tests.lnd = cfg.lnd.enable;
      services.lnd = {
        port = 9736;
        certificate = {
          extraIPs = [ "10.0.0.1" "20.0.0.1" ];
          extraDomains = [ "example.com" ];
        };
      };

      nix-bitcoin.onionServices.lnd.public = true;

      tests.lndconnect-onion-lnd = with cfg.lnd.lndconnect; enable && onion;

      tests.electrs = cfg.electrs.enable;

      tests.btcpayserver = cfg.btcpayserver.enable;
      services.btcpayserver = {
        lightningBackend = mkDefault "lnd";
      };

      tests.nodeinfo = config.nix-bitcoin.nodeinfo.enable;

      tests.backups = cfg.backups.enable;

      # To test that unused secrets are made inaccessible by 'setup-secrets'
      systemd.services.setup-secrets.preStart = mkIfTest "security" ''
        install -D -o nobody -g nogroup -m777 <(:) /secrets/dummy
      '';

      # Avoid timeout failures on slow CI nodes
      systemd.services.postgresql.serviceConfig.TimeoutStartSec = "5min";
    }
    ];
  };

  scenarios = with lib; {
    # Included in all scenarios by ./lib/make-test.nix
    base = baseConfig;

    default = scenarios.secureNode;

    # All available basic services and tests
    full = {
      tests.security = true;

      services.lnd.enable = true;
      services.lnd.lndconnect = { enable = true; onion = true; };
      services.electrs.enable = true;
      services.btcpayserver.enable = true;
      services.backups.enable = true;

      nix-bitcoin.nodeinfo.enable = true;
    };

    secureNode = {
      imports = [
        scenarios.full
        ../modules/presets/secure-node.nix
      ];
      tests.secure-node = true;
      tests.restart-bitcoind = true;

      # Stop electrs from spamming the test log with 'WARN - wait until IBD is over' messages
      tests.stop-electrs = true;
    };

    netns = {
      imports = with scenarios; [ netnsBase secureNode ];
      # This test is rather slow and unaffected by netns settings
      tests.backups = mkForce false;
    };

    # All regtest-enabled services
    regtest = {
      imports = [ scenarios.regtestBase ];
      services.lnd.enable = true;
      services.electrs.enable = true;
      services.btcpayserver.enable = true;

      # Regression guard for two production failures: lnd must survive a
      # bitcoind restart (it `wants`, not `requires`, bitcoind), and its
      # chain-backend health check must keep passing across the restart — which
      # requires the public RPC whitelist to include getpeerinfo/getnodeaddresses
      # (lnd uses that RPC user). Removing either would flap lnd here.
      tests.lndSurvivesBitcoindRestart = true;
      test.extraTestScript = ''
        @test("lndSurvivesBitcoindRestart")
        def _():
            assert_running("lnd")
            machine.succeed("systemctl restart bitcoind.service")
            machine.wait_for_unit("bitcoind.service")
            machine.wait_until_succeeds("runuser -u operator -- bitcoin-cli getnetworkinfo")
            # Give lnd's chain-backend health check time to run a few cycles; it
            # self-shuts-down after 3 failures, so a missing whitelist entry
            # would take lnd down in this window.
            machine.sleep(45)
            assert_running("lnd")
            machine.fail("journalctl -u lnd | grep -q 'chain backend failed'")
      '';
    };

    # netns and regtest, without secure-node.nix
    netnsRegtest = {
      imports = with scenarios; [ netnsBase regtest ];
    };

    hardened = {
      imports = [
        scenarios.secureNode
        ../modules/presets/hardened-extended.nix
      ];
    };

    netnsBase = { config, pkgs, ... }: {
      nix-bitcoin.netns-isolation.enable = true;
      test.data.netns = config.nix-bitcoin.netns-isolation.netns;
      tests.netns-isolation = true;
      environment.systemPackages = [ pkgs.fping ];

      # Used for testing that `netns-exec` is not executable by users other than
      # the operator. Like all normal users, this user is a member of group `users`.
      users.users.unauthorized.isNormalUser = true;
    };

    regtestBase = { config, pkgs, ... }: {
      tests.regtest = true;
      test.data.num_blocks = 100;

      services.bitcoind.regtest = true;
      systemd.services.bitcoind.postStart = mkAfter ''
        cli=${config.services.bitcoind.cli}/bin/bitcoin-cli
        if ! $cli listwallets | ${pkgs.jq}/bin/jq -e 'index("test")'; then
          "$cli" -named createwallet  wallet_name=test load_on_startup=true
          address=$($cli -rpcwallet=test getnewaddress)
          "$cli" generatetoaddress ${toString config.test.data.num_blocks} "$address"
        fi
      '';

    };

    # Test the special bitcoin RPC setup that lnd uses when bitcoin is pruned
    lndPruned = {
      services.lnd.enable = true;
      services.bitcoind.prune = 1000;
    };

  } // (import ../dev/dev-scenarios.nix {
    inherit lib scenarios;
  });

  ## Example scenarios that showcase extra features
  exampleScenarios = with lib; {
    # Run a selection of tests in scenario 'netns'
    selectedTests = {
      imports = [ scenarios.netns ];
      tests = mkForce {
        btcpayserver = true;
        netns-isolation = true;
      };
    };

    # Container-specific features
    containerFeatures = {
      # Container has WAN access and bitcoind connects to external nodes
      test.container.enableWAN = true;
      # See ./lib/test-lib.nix for a description
      test.container.exposeLocalhost = true;
    };

    ## Scenarios with a custom Python test

    # Variant 1: Define testing code that always runs
    customTestSimple = {
      networking.hostName = "myhost";

      # Variant 1: Define testing code that always runs
      test.extraTestScript = ''
        succeed("[[ $(hostname) == myhost ]]")
      '';
    };

    # Variant 2: Define a test that can be enabled/disabled
    # via the Nix module system.
    customTestExtended = {
      networking.hostName = "myhost";

      tests.hostName = true;
      test.extraTestScript = ''
        @test("hostName")
        def _():
            succeed("[[ $(hostname) == myhost ]]")
      '';
    };
  };
in {
  inherit scenarios;

  pkgs = flake: pkgs: rec {
    # A basic test using the nix-bitcoin test framework
    makeTestBasic = import ./lib/make-test.nix flake pkgs makeTestVM;

    # Wraps `makeTest` in NixOS' testing-python.nix so that the drv includes the
    # log output and the test driver
    makeTestVM = import ./lib/make-test-vm.nix pkgs;

    # A test using the nix-bitcoin test framework, with some helpful defaults
    makeTest = { name ? "nix-bitcoin-test", config }:
      makeTestBasic {
        inherit name;
        config = {
          imports = [
            scenarios.base
            config
          ];
          # Share the same pkgs instance among tests
          # Set priority slightly higher (i.e. to a slightly lower number) than `mkDefault`,
          # so that this module can be used with function `pkgs.nixos`, which already
          # sets `nixpkgs.pkgs` with prio `mkDefault`.
          nixpkgs.pkgs = lib.mkOverride 900 pkgs;
        };
      };

    # A test using the nix-bitcoin test framework, with defaults specific to nix-bitcoin
    makeTestNixBitcoin = { name, config }:
      makeTest {
        name = "nix-bitcoin-${name}";
        config = {
          imports = [ config ];
          test.shellcheckServices.sourcePrefix = toString ./..;
        };
      };

    makeTests = scenarios: let
      mainTests = builtins.mapAttrs (name: config:
        makeTestNixBitcoin { inherit name config; }
      ) scenarios;
    in
      {
        wireguard-lndconnect = import ./wireguard-lndconnect.nix makeTestVM pkgs;
      } // mainTests;

    tests = makeTests scenarios;

    ## Helper for ./run-tests.sh

    getTest = { name, extraScenariosFile ? null }:
      let
        tests = makeTests (scenarios // (
          lib.optionalAttrs (extraScenariosFile != null)
            (import extraScenariosFile {
              inherit scenarios lib pkgs;
              nix-bitcoin = flake;
            })
        ));
      in
        tests.${name} or (makeTestNixBitcoin {
          inherit name;
          config = {
            services.${name}.enable = true;
          };
        });

    instantiateTestsFromStr = testNamesStr: instantiateTests (lib.splitString " " testNamesStr);

    instantiateTests = testNames:
      map (name:
        let
          test = tests.${name};
        in
          builtins.seq (builtins.trace "Evaluating test '${name}'" test.outPath)
            test
      ) testNames;
  };
}
