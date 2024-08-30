#!/bin/bash

print_usage() {
        printf "Usage: \n"
        printf "\t-s server_address : Set the address of the DNS server (required) \n"
        printf "\t-n name : Set the name of the DNS Provider (required) \n"
        printf "\t-b filename : Set the list of the blockpages IP adresses (required) \n"
	printf "\t-v : Set verbose on \n"
        printf "\t-H endpoint : To use DNS-over-HTTPS, with the HTTP endpoint of the query beginning by '/' \n"
	printf "\t-h : Display the use of the command\n"
}

dnsServer=''
dnsName=''
blockpagesList=''
httpsEndpoint=''
verbose=false

while getopts 's:n:b:vH:h' flag; do
        case "${flag}" in
                s)      dnsServer="${OPTARG}";;
                n)      dnsName="${OPTARG}";;
		b)	blockpagesList="${OPTARG}";;
                v)      verbose=true;;
                H)      httpsEndpoint="${OPTARG}";;
		h)	print_usage
			exit 0;;
                *)      print_usage
                        exit 1 ;;
        esac
done

if [ -z "$dnsServer" ] || [ -z "$dnsName" ] || [ -z "$blockpagesList" ] || [ ! -f "$blockpagesList" ];then
        print_usage
        exit 1
fi

if $verbose ;then
        mkdir verbose 2>>/dev/null
        rm -f verbose/*
fi

mkdir -p "lists/${dnsName}"

blockpages=()

while read blockpage; do
	blockpages+=($blockpage)
done <"$blockpagesList"

function is_a_blockpage {
	local ip=$1
	for exception in "${blockpages[@]}"; do
		if [ "$ip" == "$exception" ]; then
			return 0
		fi
	done
	return 1
}


function check_blocked {
	local id=$1
	if [ ! -f "lists/${dnsName}/sub_valid${id}" ]; then
		exit 0
	fi
	local thread_blocked=0
	dnsOptions=''
	if [ -n "$httpsEndpoint" ]; then
		dnsOptions="+https=${httpsEndpoint}"
	fi
	if $verbose ; then
        	touch "lists/${dnsName}/timed_out_${id}.txt"
        	touch "lists/${dnsName}/not_blocked_${id}.txt"
	fi
	while read host; do
		data=$(dig @$dnsServer $host $dnsOptions +short)
		ip_address=$(echo "${data}" | grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}" | tail -n1)
		if [[ -z "$ip_address" ]] || is_a_blockpage "$ip_address" ;then
			let thread_blocked++
		elif $verbose ;then
			if [ "$ip_address" == "$dnsServer" ]; then
				echo "${host}" >> "lists/${dnsName}/timed_out_${id}.txt"
			else
				echo "${host}" >> "lists/${dnsName}/not_blocked_${id}.txt"
			fi
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

if $verbose ; then
	cat "lists/${dnsName}/timed_out_"* > "verbose/${dnsName}_timed_out.txt"
	cat "lists/${dnsName}/not_blocked_"* > "verbose/${dnsName}_not_blocked.txt"
fi

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
