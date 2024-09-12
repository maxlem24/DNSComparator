#!/bin/bash

check(){
	local domain=$1
	result=$(dig @$dns $domain +short +time=10 +retry=5)
	echo "${result} ${domain}" >> dns_timed_out.txt
}

file=$1
dns=$2
PIDS=()
while read line; do
	check $line &
	PIDS+=($!)
done < "${file}"

for pid in "${PIDS[@]}"; do
	wait $pid
done
