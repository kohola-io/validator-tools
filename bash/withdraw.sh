#!/bin/bash
# Author: Kohola.io
# Date: 6/15/2023
# License: MIT License
# Description:  Calling './withdraw.sh' will withdraw validator commission and staking rewards against the configured RPC server

set -e
cosmos_exec=${CHAIN_DAEMON:-kujirad}
rpc_node=${RPC:-'https://rpc-kujira.mintthemoon.xyz:443'}
wallet=${VOTE_WALLET}
if [[ -z "${wallet}" ]]
then
  read -p "Enter wallet name: " wallet
fi
chain=${CHAIN_ID:-kaiyo-1}
fees=${VOTE_FEES:-250ukuji}
val=${VOTE_ADDR:-$(${cosmos_exec} keys show ${wallet} --bech val -a)}

crad="${cosmos_exec} --node ${rpc_node}"

$crad tx distribution withdraw-rewards $val --commission --from $wallet --chain-id $chain --gas-prices 0.2ukuji --gas-adjustment 1.5 --gas auto
