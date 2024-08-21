#!/bin/bash
dnsServer=$1
dnsName=$2
echo "Starting analyse ${dnsName} on ${dnsServer}"

function check_blocked {
	local id=$1
	local thread_blocked=0
	while read host; do
		ip_address=$(dig @$dnsServer +short $host | head -n1)
		if [[ -z $ip_address ]]; then
			let thread_blocked++
		fi
	done < "lists/sub_valid${id}"
	echo $thread_blocked >> lists/sub_valid_total
}

length=$(wc -l lists/valid.txt | sed 's/ .*//')

split -l 1000 -d -a 2 lists/valid.txt lists/sub_valid

NUM_THREADS=$(($length/1000))

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
	sum_blocked=$(($sum_blocked+$value))
done < lists/sub_valid_total

rm lists/sub_valid*

percentage=$(($sum_blocked/$length*100))

echo "${sum_blocked}/${length} blocked by ${dnsName} (${percentage}%)" >> results.txt
echo "${dnsName} finished"
