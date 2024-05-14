#!/bin/bash
# Author: Kohola.io
# Date: 5/14/2024
# License: MIT License
# Description:  Calling './vote.sh' will query the configured RPC server for open votes and interactively walk you through the voting process.

set -e
cosmos_exec=${CHAIN_DAEMON:-kujirad}
rpc_node=${RPC:-'https://rpc-kujira.mintthemoon.xyz:443'}
wallet=${VOTE_WALLET}
if [[ -z "${wallet}" ]]
then
  read -p "Enter wallet name: " wallet
fi
chain=${CHAIN_ID:-kaiyo-1}
fees=${VOTE_FEES:-340ukuji}
voter=${VOTE_ADDR:-$(${cosmos_exec} keys show -a ${wallet})}
status_filter=${PROPOSAL_STATUS:-voting_period}

crad="${cosmos_exec} --node ${rpc_node}"

props_to_vote_on=()

props=$($crad query gov proposals --status "$status_filter" -o json | jq -r '.proposals[].id')
[ $? -ne 0 ] && echo "No props need to be voted on!"
echo "Finding active proposals..."
echo "*____________________________*"
echo " "
for X in $props;
do
  prop_info=$($crad query gov proposal $X -o json)

  prop_num=$X
  echo "Proposal ID: ${prop_num}"

  prop_end=$(echo $prop_info | jq -r '.voting_end_time')
  time_now=$(date +%s)
  prop_end=$(date --date $prop_end +%s)
  (( prop_end=prop_end-time_now ))
  [ $prop_end -lt 61 ] && prop_time_f="${prop_end} seconds" || \
  [ $prop_end -lt 3601 ] && { (( res=(prop_end+60)/60 )); prop_time_f="${res} minutes"; } || \
  [ $prop_end -lt 86401 ] && { (( res=(prop_end+(60*60))/(60*60) )); prop_time_f="${res} hours"; } || \
  { (( res=(prop_end+(60*60*24))/(60*60*24) )); prop_time_f="${res} days"; }
  echo "Time Left: ${prop_time_f}"

  prop_title=$(echo $prop_info | jq -r '.title')
  echo "Title: ${prop_title}"

  prop_desc=$(echo $prop_info | jq -r '.summary')
  echo "Summary: ${prop_desc}"

  prop_msgs=$(echo $prop_info | jq '.messages[] | del(.wasm_byte_code)')
  echo "Messages:"
  echo $prop_msgs | jq

  prop_myvote=$($crad query gov vote $prop_num $voter -o json 2>/dev/null) || true
  [ -z "$prop_myvote" ] && { prop_myvote="Not available!"; props_to_vote_on+=($prop_num); } || \
  prop_myvote=$(echo $prop_myvote | jq -r '.options[0].option')
  echo "My Vote: ${prop_myvote}"
  echo "*____________________________*"
  echo " "
done

if [[ -z "$props_to_vote_on" ]]
then
  echo "$wallet has voted on all active proposals! 🎉"
  exit 0
fi
echo "You need to vote on: ${props_to_vote_on[@]}"
echo " "
read -p "Begin voting? [Y/n]" -n 1 -r
REPLY=${REPLY:-Y}
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 0
fi
echo " "
echo " *** "
echo " "
for X in ${props_to_vote_on[@]};
do
  prop_info=$($crad query gov proposal $X -o json)

  prop_num=$X
  echo "Voting on Proposal ID: ${prop_num}"

  prop_title=$(echo $prop_info | jq -r '.title')
  echo "Title: ${prop_title}"

  prop_desc=$(echo $prop_info | jq -r '.summary')
  echo "Summary: ${prop_desc}"

  prop_msgs=$(echo $prop_info | jq '.messages[] | del(.wasm_byte_code)')
  echo "Messages:"
  echo $prop_msgs | jq

  stuck=1
  valid_words="yes no nowithveto abstain"
  while [ $stuck -eq 1 ]
  do
    echo -n "My Vote [Yes/No/NoWithVeto/Abstain]: "
    read -r vote
    vote=$(echo $vote | tr '[:upper:]' '[:lower:]')
    for val in $valid_words;
    do
      [ $val = $vote ] && ((stuck--))
    done
    [ $stuck -eq 1 ] && { echo " "; echo "That's not a valid answer... please retry"; echo " "; }
  done

  stuck=1
  num_chars=255
  while [ $stuck -eq 1 ]
  do
    echo -n "Note: "
    read -r note
    note_len=$(echo $note | wc -c)
    [ $note_len -gt $num_chars ] && { echo " "; echo "Warning: Note is going to be truncated"; echo " "; } || ((stuck--))
    if [ $stuck -eq 1 ]
    then
      read -p "Do you want to enter the note again? [Y/n]" -n 1 -r
      REPLY=${REPLY:-Y}
      if [[ $REPLY =~ ^[Nn]$ ]]
      then
        ((stuck--))
      fi
    fi
  done

  stuck=1
  while [ $stuck -eq 1 ]
  do
    $crad tx gov vote $prop_num $vote --note "$note" --from $wallet --fees $fees --chain-id $chain -y
    read -p "Was the transaction successful? [y/N]" -n 1 -r
    REPLY=${REPLY:-N}
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
      ((stuck--))
    else
      echo "Broadcasting again..."
      echo " "
    fi
  done
  echo " "
  echo "*____________________________*"
  echo " "

done
echo "Thanks for voting! 🗳️"
