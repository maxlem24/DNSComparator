#!/bin/bash

dnsServer=$1
dnsName=$2
dnsOptions=$3

echo "Starting analyse ${dnsName} on ${dnsServer}"

mkdir "lists/${dnsName}"

function check_blocked {
	local id=$1
	local thread_blocked=0
	while read host; do
		ip_address=$(dig @$dnsServer $host $dnsOptions +short | grep -E "([0-9]{1,3}.){3}[0-9]{1,3}" | tail -n1)
		if [[ -z "$ip_address" ]] || [ "$ip_address" == "0.0.0.0" ] || [ "$ip_address" == "127.0.0.1" ] || [ "$ip_address" == "52.6.32.13" ] || [ "$ip_address" == "34.236.196.185" ] || [ "$ip_address" == "199.247.2.157" ] || [ "$ip_address" == "95.179.166.46" ] || [ "$ip_address" == "156.154.113.16" ]; then
			let thread_blocked++
		fi
	done < "lists/${dnsName}/sub_valid${id}"
	echo $thread_blocked >> "lists/${dnsName}/sub_valid_total"
}

length=$(wc -l valid.txt | sed 's/ .*//')

NUM_THREADS=20

split -l $(($length/$NUM_THREADS+1)) -d -a 2 valid.txt "lists/${dnsName}/sub_valid"

PIDS=()
STARTTIME=$(date +%s)
for ((i=0;i<NUM_THREADS;i++)); do
	if [ "$i" -lt "10" ];then
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

ENDTIME=$(date +%s)
sum_blocked=0
while read value; do
	sum_blocked=$(($sum_blocked+$value))
done < "lists/${dnsName}/sub_valid_total"

sleep 1

rm -r "lists/${dnsName}"

percentage=$(echo "scale=2;100*${sum_blocked}/${length}" | bc -l)

echo "${sum_blocked}/${length} blocked by ${dnsName} (${percentage}%) $(($ENDTIME - $STARTTIME)) secs" >> results.txt
echo "${dnsName} finished in $(($ENDTIME - $STARTTIME)) secs"
