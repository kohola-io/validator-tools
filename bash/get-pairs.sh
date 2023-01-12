#!/bin/bash
# Author: Kohola.io
# Date: 11/25/2022
# Revision: 2.0
# License: MIT License
# Description: Helper script to find providers that support a specific denom. Requires jq to be installed and accessible in PATH
# Example command: ./get-pairs.sh BTC USD

lcdURL="https://lcd-kujira.mintthemoon.xyz"

binanceURL="https://api1.binance.com/api/v3/ticker/price"
binanceusURL="https://api.binance.us/api/v3/ticker/price"
bitgetURL="https://api.bitget.com/api/spot/v1/public/products"
coinbaseURL="https://api.exchange.coinbase.com/products"
cryptoURL="https://api.crypto.com/v2/public/get-ticker"
finURL="https://api.kujira.app/api/coingecko/pairs"
gateURL="https://api.gateio.ws/api/v4/spot/currency_pairs"
huobiURL="https://api.huobi.pro/market/tickers"
krakenURL="https://api.kraken.com/0/public/AssetPairs"
mexcURL="https://www.mexc.com/open/api/v2/market/ticker"
okxURL="https://www.okx.com/api/v5/market/tickers?instType=SPOT"
osmosisURL="https://api-osmosis.imperator.co/pairs/v1/summary"

OKQuotes="USD AXLUSDC USDC USDT DAI BTC ETH ATOM"

get_whitelisted_denoms () {
    lcdURL="$lcdURL/oracle/params"
    denoms_to_query=()

    echo "Whitelisted denoms:"
    denoms=$(curl -s $lcdURL | jq -r '.params.whitelist[].name | @sh' | tr -d \')
    # declare -a den="($denoms)"
    # echo $denoms
    for i in $denoms;
    do
      for j in $OKQuotes;
      do
        if [ $i != $j ];
        then
          val="$i,$j"
          denoms_to_query+=("$val")
        fi
      done
    done
    # echo ${denoms_to_query[@]}
    query_denom ${denoms_to_query[@]}
}

query_denom () {
    arg=$@
    # for d in $arg;
    # do
    #   echo $d
    # done
    echo "Binance.com:"
    res=$(curl -s $binanceURL)
    for d in $arg;
    do
      IFS=','
      set -- $d
    #   echo $1 and $2
      echo "$res" | jq .'[] | "  " + try .symbol' | tr -d \" | grep "  "$1$2$
      unset IFS
    done
    echo ""
    echo "Binance.us:"
    res=$(curl -s $binanceusURL)
    for d in $arg;
    do
      IFS=','
      set -- $d
      echo "$res" | jq .'[] | "  " + try .symbol' | tr -d \" | grep "  "$1$2$
      unset IFS
    done
    echo ""
    echo "Bitget:"
    res=$(curl -s $bitgetURL)
    for d in $arg;
    do
      IFS=','
      set -- $d
      echo "$res" | jq .'data[] | "  " + try .symbol' | tr -d \" | grep "  "$1_$2$
      unset IFS
    done
    echo ""
    echo "Coinbase:"
    res=$(curl -s $coinbaseURL)
    for d in $arg;
    do
      IFS=','
      set -- $d
      echo "$res" | jq .'[] | "  " + try .id' | tr -d \" | grep "  "$1-$2$
      unset IFS
    done
    echo ""
    echo "Crypto:"
    res=$(curl -s $cryptoURL)
    for d in $arg;
    do
      IFS=','
      set -- $d
      echo "$res" | jq .'result.data[] | "  " + try .i' | sed -e 's|LUNA2|LUNA|' | tr -d \" | grep "  "$1_$2$
      unset IFS
    done
    echo ""
    echo "Fin:"
    res=$(curl -s $finURL)
    for d in $arg;
    do
      IFS=','
      set -- $d
      echo "$res" | jq .'pairs[] | "  " + try .base + "-" + try .target' | tr -d \" | grep "  "$1_$2$
      unset IFS
    done
    echo ""
    echo "Gate:"
    res=$(curl -s $gateURL)
    for d in $arg;
    do
      IFS=','
      set -- $d
      echo "$res" | jq .'[] | "  " + try .base + "-" + try .quote' | tr -d \" | grep "  "$1_$2$
      unset IFS
    done
    echo ""
    echo "Huobi:"
    res=$(curl -s $huobiURL)
    for d in $arg;
    do
      IFS=','
      set -- $d
      echo "$res" | jq .'data[] | "  " + try .symbol' | tr [:lower:] [:upper:] | tr -d \" | grep "  "$1$2$
      unset IFS
    done
    echo ""
    echo "Kraken:"
    res=$(curl -s $krakenURL)
    for d in $arg;
    do
      IFS=','
      set -- $d
      echo "$res" | jq .'result[] | "  " + try .wsname' | tr -d \" | sed -e 's|LUNA/|LUNC/|' | sed -e 's|LUNA2/|LUNA/|' | tr / - | grep "  "$1-$2$
      unset IFS
    done
    echo ""
    echo "MEXC:"
    res=$(curl -s $mexcURL)
    for d in $arg;
    do
      IFS=','
      set -- $d
      echo "$res" | jq .'data[] | "  " + try .symbol' | tr -d \" | grep "  "$1_$2$
      unset IFS
    done
    echo ""
    echo "OKX:"
    res=$(curl -s $okxURL)
    for d in $arg;
    do
      IFS=','
      set -- $d
      echo "$res" | jq .'data[] | "  " + try .instId' | tr -d \" | grep "  "$1-$2$
      unset IFS
    done
    echo ""
    echo "Osmosis:"
    res=$(curl -s $osmosisURL)
    for d in $arg;
    do
      IFS=','
      set -- $d
      echo "$res" | jq .'data[] | "  " + try .base_symbol + "-" + try .quote_symbol' | tr [:lower:] [:upper:] | tr -d \" | grep "  "$1-$2$
      unset IFS
    done
    echo ""
}

if [ $# -lt 2 ]
then
    if [ $# -eq 1 ]
    then
        echo "No quote denom provided - assuming any accepted quote denom"
        echo "Next time try something like: ./get-pairs.sh BTC USD"
        denoms_to_query=()
        for j in $OKQuotes;
        do
            if [ $1 != $j ];
            then
            val="$1,$j"
            denoms_to_query+=("$val")
            fi
        done
        query_denom ${denoms_to_query[@]}
    else
        echo "No input arguments provided - getting all whitelisted denoms"
        get_whitelisted_denoms
    fi
else
    query_denom $1 $2
fi
