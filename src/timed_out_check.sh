#!/bin/bash

rm -f dns_timed_out.txt

sudo tcpdump port 53 -w dump.pcap &

sleep 5

check(){
	local domain=$1
	result=$(dig @$dns $domain +short +time=60 +retry=4)
	echo "${result} ${domain}" >> dns_timed_out.txt
	sleep 1
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



