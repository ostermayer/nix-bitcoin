# RPC calls that are safe for public use.
#
# Safety bar: bounded CPU cost per call, no P2P side effects beyond
# transaction relay, no leaks of peer topology or wallet contents.
#
# Deliberately excluded (audit M-3):
# - scantxoutset, gettxoutsetinfo, getblocktemplate: minutes-scale CPU,
#   trivially abused for DoS by any holder of the public credentials.
# - getpeerinfo, getnodeaddresses: leak the node's peer topology.
# - getblockfrompeer: lets the caller drive the node's P2P block fetching.
# If you need any of these, grant them via
# `services.bitcoind.rpc.users.public.rpcwhitelist` in your own config.
[
  "echo"
  "getinfo"
  "getindexinfo"
  "help"
  "ping"
  "uptime"
  # Blockchain
  "getbestblockhash"
  "getblock"
  "getblockchaininfo"
  "getblockcount"
  "getblockfilter"
  "getblockhash"
  "getblockheader"
  "getblockstats"
  "getchaintips"
  "getchaintxstats"
  "getdeploymentinfo"
  "getdifficulty"
  "getmempoolancestors"
  "getmempooldescendants"
  "getmempoolentry"
  "getmempoolinfo"
  "getrawmempool"
  "gettxout"
  "gettxoutproof"
  "verifytxoutproof"
  # Mining
  "getmininginfo"
  "getnetworkhashps"
  # Network
  "getnetworkinfo"
  # Rawtransactions
  "analyzepsbt"
  "combinepsbt"
  "combinerawtransaction"
  "converttopsbt"
  "createpsbt"
  "createrawtransaction"
  "decodepsbt"
  "decoderawtransaction"
  "decodescript"
  "finalizepsbt"
  "fundrawtransaction"
  "getrawtransaction"
  "joinpsbts"
  "sendrawtransaction"
  "signrawtransactionwithkey"
  "testmempoolaccept"
  "utxoupdatepsbt"
  # Util
  "createmultisig"
  "deriveaddresses"
  "estimatesmartfee"
  "getdescriptorinfo"
  "signmessagewithprivkey"
  "validateaddress"
  "verifymessage"
  # Zmq
  "getzmqnotifications"
]
