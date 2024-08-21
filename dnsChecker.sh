#!/bin/bash

# 2 arguments : ip and name of the DNS Server
dnsServer=$1
dnsName=$2
echo "Starting analyse ${dnsName} on ${dnsServer}"

function check_blocked {
	local id=$1
	local thread_blocked=0
	while read host; do
		ip_address=$(dig @$dnsServer $host +short | head -n1 )
		if [ -z "$ip_address" ] || [ "$ip_address" == "0.0.0.0" ] || [ "$ip_address" == "127.0.0.1" ]; then
			let thread_blocked++
		fi
	done < "lists/sub_valid${id}"
	echo $thread_blocked >> lists/sub_valid_total
}

length=$(wc -l valid.txt | sed 's/ .*//')

NUM_THREADS=30

split -n l/$NUM_THREADS -d -a 2 valid.txt lists/sub_valid

PIDS=()
ten=10
for ((i=0;i<NUM_THREADS;i++)); do
	if [ "$i" -lt "$ten" ];then
		check_blocked "0${i}" &
		PIDS+=($!)
	else
		check_blocked $i &
                PIDS+=($!)
	fi
done

for pid in "${PIDS[@]}"; do
	wait $pid
done

sum_blocked=0
while read value; do
	sum_blocked=$((sum_blocked+value))
done < lists/sub_valid_total

sleep 0.1

rm lists/sub_valid*

percentage=$(echo "scale=2; 100*${sum_blocked}/${length}" | bc -l)

echo "${sum_blocked}/${length} blocked by ${dnsName} (${percentage}%)" >> results.txt
echo "${dnsName} finished"
