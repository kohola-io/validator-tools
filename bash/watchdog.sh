#!/bin/bash
# Author: Kohola.io
# Date: 12/20/2022
# License: MIT License
# Description:  This script assumes you have a pricefeeder.service - it queries the LCD 
# to determine if miss count is increasing over a 5 minute period.  If miss count has 
# increased 3 out of 5 times, this script will trigger a restart of the pricefeeder service.
# 
# Suggest adding the following to crontab - the RANDOM sleep is important to prevent 
# restarts from occurring across all validators simultaneously:
#
# */10 * * * *    sleep $((RANDOM \%300)) && /path/to/watchdog.sh >> /tmp/watchdog.log 2>&1

############## change to suit your config ###################

valoper=kujiravaloper...
lcd_url=https://lcd.kaiyo.kujira.setten.io

# for notify_*, set to 1 to enable notifications, 0 to disable notifications
discord_url=https://discord.com/api/webhooks/...
notify_if_LCD_down=1
notify_if_missed_votes_increases=1
notify_if_oracle_is_working_fine=0
notify_on_restart=1

################### end of config ###########################

delta=0
counter=$(curl -s "${lcd_url}/oracle/validators/${valoper}/miss" |\
    jq .miss_counter |\
    sed 's/"//g')
strikes=0

for i in 1 2 3 4 5
do
    sleep 60
    old_counter=$(($counter))
    counter=$(curl -s "${lcd_url}/oracle/validators/${valoper}/miss" |\
        jq .miss_counter |\
        sed 's/"//g')
    if [ -z "$counter" ]; then
        mesg="***Call to LCD failed, using old value."
        echo $mesg
        if [ $notify_if_LCD_down -gt 0 ]; then
            curl -sH "Content-Type: application/json" -X POST \
            $discord_url \
            -d "{\"content\": \"$mesg\"}"
        fi
        counter=$(($old_counter))
    fi
    delta=$(($counter-$old_counter))
    if [ $delta -lt 0 ]; then
        mesg="Missed oracle votes since last checked: $delta"
        echo $mesg
        if [ $notify_if_missed_votes_increases -gt 0 ]; then
            curl -sH "Content-Type: application/json" -X POST \
            $discord_url \
            -d "{\"content\": \"$mesg\"}"
        fi
        ((strikes++))
    else
        mesg="Missed oracle votes hasn't incremented since last checked: $counter"
        echo $mesg
        if [ $notify_if_oracle_is_working_fine -gt 0 ]; then
            curl -sH "Content-Type: application/json" -X POST \
            $discord_url \
            -d "{\"content\": \"$mesg\"}"
        fi
    fi
done

if [ $strikes -gt 3 ]; then
    # ESCALATION!
    mesg="Price feeder is down! Restarting..."
    echo $mesg
    if [ $notify_on_restart -gt 0 ]; then
        curl -sH "Content-Type: application/json" -X POST \
        $discord_url \
        -d "{\"content\": \"$mesg\"}"
    fi
    # Command to run to restart the pricefeeder
    systemctl restart pricefeeder
fi
