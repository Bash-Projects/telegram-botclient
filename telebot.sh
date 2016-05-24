#!/usr/bin/env bash
# Copyright 2016 prussian <generalunrest@airmail.cc>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Telegram bot client for sh
# depends on:
#  curl
#  jq

if [ -f ./config.sh ]; then
	. ./config.sh
else
	echo "cannot read config"
	exit 1
fi
if [ -z $bot_token ]; then
	echo "please set your bot api token"
	exit 1
fi
BOT_URI="https://api.telegram.org/bot${bot_token}"
# clears messages from the update queue
# set to last message id + 1
OFFSET=0

# send message to chat id
# $1 is chat id
# $2 is message
function sendMessage {
	curl "${BOT_URI}/sendMessage?chat_id=${1}&text=${2}" 2> /dev/null
}

# no inputs, returns array of updates
# array only contains one object
function getMessage {
	curl "${BOT_URI}/getUpdates?offset=${OFFSET}" 2> /dev/null
}

# takes input from pipe
# returns newline separated json results
function get_results {
	jq -r '.result | map(tostring+"\n") | add' |\
		sed '/^\s*$/d'
}

# offset is what consumes messages
# $1 - the result object
function get_new_offset {
	echo $((`jq -M '.update_id' <<< "$1"`+1))
}

# get message object in result
# $1 - the result object
function get_message {
	jq -M '.message' <<< "$1"
}

# get the chat the message was from
# $1 - the message object
function get_chat_id {
	jq -M '.chat.id' <<< "$1"
}

# get username or user's first name
# $1 - the message object
function get_username {
	user=`jq -M -r '.from.username' <<< "$1"`
	if [ -z "$user" ]; then
		user=`jq -M -r '.from.first_name' <<< "$1"`
	fi
	echo $user
}

# get the message
# $1 - the message object
function get_text {
	jq -M -r '.text' <<< "$1" |\
		tr '\n' ' '
}

# gets date of message
# $1 - the message object
function get_date {
	jq -M '.date' <<< "$1" |\
		date +%Y-%m-%d
}

# gets time of message
# $1 - the message object
function get_time {
	jq -M '.date' <<< "$1" |\
		date +%H:%M:%S
}

# process results
# outputs a line like:
# chat_id date time <user> message
# $1 - result object
function process_input {
	if [ "$1" = "null" ]; then
		return
	fi
	OFFSET=`get_new_offset "$1"`
	msg=`get_message "$1"`
	echo "`get_chat_id "$msg"` `get_date "$msg"` `get_time "$msg"` <`get_username "$msg"`> `get_text "$msg"`"
}

# Input loop
# reads in data
# arg format
# chat_id your message with spaces or what have you
while read chat_id message; do
	sendMessage "$chat_id" "$message" >& /dev/null
done < /dev/stdin &

# output loop
while true; do
	IFS=$'\n'
	for result in `getMessage | get_results`; do
		process_input "$result"
	done
	sleep ${polling_delay}
done
