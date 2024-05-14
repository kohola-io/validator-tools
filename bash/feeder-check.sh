#!/bin/bash
# Author: Kohola.io
# Date: 4/21/2024
# License: MIT License
# Description:  Calling './feeder-check.sh' will query the configured RPC server for the last voting round and output a CSV-like output with headers

set -e
rpc=${RPC:-'https://kujira-api.polkachu.com'}
voter=${VOTER}
if [[ -z "${voter}" ]]
then
  read -p "Enter validator address (kujiravaloper...): " voter
fi

oracleParams=$(curl -s "$rpc/oracle/params")
validatorData=$(curl -s "$rpc/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED")
voteRoundData=$(curl -s "$rpc/oracle/validators/aggregate_votes")

rewardBand=$(echo $oracleParams | jq -r '.params.reward_band')
activeDenoms=$(echo $oracleParams | jq -r '.params.whitelist[].name')

weightedMedians=()
standardDeviations=()
rewardSpreads=()

# Output Header
echo "Denom, Weighted Median, Standard Deviation, Minimum Accepted Price, Max Accepted Price, Validator Vote Price, Warning"

for ad in $activeDenoms;
do
  #echo $ad
  powers=()
  totalpower=0
  vers=$(echo $voteRoundData | jq -r --arg denom $ad '[.aggregate_votes[] | {val: (.voter), rate: ((.exchange_rate_tuples[]|select(.denom == $denom)|.exchange_rate))}] | sort_by(.rate) | .[] | .val')
  for av in $vers;
  do
    #echo $av
    p=$(echo $validatorData | jq -r --arg val $av '.validators[] | select(.operator_address == $val) | .tokens')
    let totalpower=totalpower+p
    powers+=($p)
  done

  rates=()
  rateArr=$(echo $voteRoundData | jq -r --arg denom $ad '[.aggregate_votes[] | {val: (.voter), rate: ((.exchange_rate_tuples[]|select(.denom == $denom)|.exchange_rate))}] | sort_by(.rate) | .[] | .rate')
  while IFS= read -r line; do
    rates+=("$line")
  done <<< "$rateArr"

  # find weightedmedian for denom
  pivot=0
  weightedmedian=0
  let compare=totalpower/2
  #echo $compare
  for i in "${!rates[@]}";
  do
    let pivot=pivot+${powers[$i]}
    #echo $pivot
    if [ $pivot -ge $compare ]; then
        weightedmedian=${rates[$i]}
        weightedMedians+=($weightedmedian)
        #echo "$ad Median: $weightedmedian"
        break
    fi
  done

  # find standard deviation
  running_sum=0
  variance=0
  stddev=0
  for i in "${!rates[@]}";
  do
    dev=$(echo "${rates[$i]}-$weightedmedian" | bc -l)
    running_sum=running_sum+$(echo "$dev * $dev" | bc -l)
  done
  variance=$(echo "$running_sum / ${#rates[@]}" | bc -l)
  stddev=$(echo "sqrt($variance)" | bc -l)
  standardDeviations+=($stddev)
  #echo "$ad Standard Deviation: $stddev"

  # find reward spread
  spread=$(echo "$weightedmedian * ($rewardBand/2)" | bc -l)
  if [[ $(echo "if ($spread < $stddev) 1 else 0" | bc) -eq 1 ]]; then
    spread=$(echo "$stddev" | bc -l)
    #echo "One STDDEV is larger than rewardspread, using STDDEV"
  fi
  rewardSpreads+=($spread)

  # find min/max accepted value
  min=$(echo "$weightedmedian - $spread" | bc -l)
  max=$(echo "$weightedmedian + $spread" | bc -l)

  # find val submission
  submission=$(echo $voteRoundData | jq -r --arg denom $ad --arg voter $voter '[.aggregate_votes[]|select(.voter == $voter) | {rate: ((.exchange_rate_tuples[]|select(.denom == $denom)|.exchange_rate))}] | .[] | .rate')

  # display !!! if submission doesn't match
  if [[ $(echo "if (($submission <= $max) && ($submission >= $min)) 1 else 0" | bc) -eq 1 ]]; then
    echo "$ad, $weightedmedian, $stddev, $min, $max, $submission,"
  else
    echo "$ad, $weightedmedian, $stddev, $min, $max, $submission, !!!"
  fi

done
