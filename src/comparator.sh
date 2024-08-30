#!/bin/bash

dnsList=''
blockpagesList=''
verbose=false
domains='valid.txt'
timecheck=true

VALID_LENGTH=0

mkdir lists 2>>/dev/null

# Check Valid Domains
check_valid() {
	local id=$1
	while read host; do
		local data=$(dig @8.8.8.8 $host +short +time=3)
                local ip_address=$(echo "${data}" | grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}" | tail -n1)
		if [ -n "$ip_address" ] && [ "$ip_address" != "0.0.0.0" ] && [ "$ip_address" != "127.0.0.1" ] && [ "$ip_address" != "8.8.8.8" ] ; then
			echo $host >> "lists/sublist_valid${id}"
		fi
	done < "lists/sublist_test${id}"
}

# Init lists
init_list() {

	rm -f lists/*

	wget --quiet "https://zonefiles.io/f/compromised/domains/live/compromised_domains_live.txt" -O - | grep -i -v -e '^#' > lists/zonefiles_compromised.txt
	wget --quiet "https://hole.cert.pl/domains/v2/domains.txt" -O lists/certpl_compromised.txt
	wget --quiet "https://v.firebog.net/hosts/Prigent-Malware.txt" -O - | grep -i -v -e '^#|^$' > lists/firebog_compromised.txt
	wget --quiet "https://urlhaus.abuse.ch/downloads/hostfile/" -O - | grep -i -v -e '^#' | sed "s/127.0.0.1\t//"> lists/abusesh_compromised.txt

	cat lists/*.txt | sort | uniq > lists/compromised.txt

	local length=$(wc -l lists/compromised.txt | sed 's/ .*//')
	local INIT_THREADS=30

	split -l $(($length/$INIT_THREADS+1)) -d -a 2 lists/compromised.txt lists/sublist_test
	local INIT_PIDS=()

	for ((i=0;i<INIT_THREADS;i++)); do
		if [ "$i" -lt "10" ];then
			check_valid "0${i}" &
			INIT_PIDS+=($!)
		else
			check_valid $i &
                	INIT_PIDS+=($!)
		fi
	done

	for pid in "${INIT_PIDS[@]}"; do
		wait $pid
	done

	cat lists/sublist_valid* | sort > "$domains"

	echo "Completed"
	echo "Length of the final list: $(wc -l ${domains} | sed 's/ .*//')"
}

# Ignore blockpages
blockpages=()

is_a_blockpage() {
	local ip=$1
	for exception in "${blockpages[@]}"; do
		if [ "$ip" == "$exception" ]; then
			return 0
		fi
	done
	return 1
}

# Check domains with 1 DNS
check_blocked() {
	local dnsServer=$1
	local dnsName=$2
	local dnsOptions=$3
	local id=$4

	if [ ! -f "lists/sub_valid${id}" ]; then
		exit 0
	fi

	local thread_blocked=0

	if $verbose ; then
        	touch "lists/${dnsName}/timed_out_${id}.txt"
        	touch "lists/${dnsName}/not_blocked_${id}.txt"
	fi

	while read host; do
		local data=$(dig @$dnsServer $host $dnsOptions +short)
		local ip_address=$(echo "${data}" | grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}" | tail -n1)
		if [[ -z "$ip_address" ]] || is_a_blockpage "$ip_address" ;then
			let thread_blocked++
		elif $verbose ;then
			if [ "$ip_address" == "$dnsServer" ]; then
				echo "${host}" >> "lists/${dnsName}/timed_out_${id}.txt"
			else
				echo "${host}" >> "lists/${dnsName}/not_blocked_${id}.txt"
			fi
		fi
	done < "lists/sub_valid${id}"

	echo $thread_blocked >> "lists/${dnsName}/sub_valid_total"
}

checker() {
	local dnsServer=$1
	local dnsName=$2
	local endpoint=$3

	mkdir -p "lists/${dnsName}"
	touch "lists/${dnsName}/sub_valid_total"

	local dnsOptions=''
	if [ -n "$endpoint" ]; then
                dnsOptions="+https=${endpoint}"
        fi

	local CHECK_PIDS=()
	local STARTTIME=$(date +%s)

	for ((i=0;i<DNS_THREADS;i++)); do
		if [ "$i" -lt "10" ];then
			check_blocked "$dnsServer" "$dnsName" "$dnsOptions" "0${i}" &
			CHECK_PIDS+=($!)
		else
			check_blocked "$dnsServer" "$dnsName" "$dnsOptions" "${i}" &
                	CHECK_PIDS+=($!)
		fi
	done

	for pid in "${CHECK_PIDS[@]}"; do
		wait $pid
	done

	if $verbose ; then
		cat "lists/${dnsName}"/timed_out_*.txt > "verbose/${dnsName}_timed_out.txt"
		cat "lists/${dnsName}"/not_blocked_*.txt > "verbose/${dnsName}_not_blocked.txt"
	fi

	local ENDTIME=$(date +%s)
	local sum_blocked=0
	while read value; do
		sum_blocked=$(($sum_blocked+$value))
	done < "lists/${dnsName}/sub_valid_total"

	rm -r "lists/${dnsName}"

	percentage=$(echo "scale=2;100*${sum_blocked}/${VALID_LENGTH}" | bc -l)

	echo "${sum_blocked}/${VALID_LENGTH} blocked by ${dnsName} (${percentage}%) $(($ENDTIME - $STARTTIME)) secs" >> results.txt
	echo "${dnsName} finished in $(($ENDTIME - $STARTTIME)) secs"
}


# Manual
print_usage() {
	printf "Usage: \n"
	printf "\t-l filename : Set the list of DNS to test (required) \n"
	printf "\t-b filename : Set the list of the blockpages IP adresses (required) \n"
	printf "\t-d filename : Set the list of domains to test. Default: valid.txt \n"
	printf "\t-v : Set verbose on \n"
	printf "\t-f : Force the use of the list of domains if it is been updated since more than 24 hours \n"
	printf "\t-h : Display the use of the command\n"
}

while getopts 'l:b:vd:fh' flag; do
	case "${flag}" in
		l) 	dnsList="${OPTARG}";;
		b) 	blockpagesList="${OPTARG}";;
		v) 	verbose=true ;;
		d)	domains="${OPTARG}";;
		f)	timecheck=false ;;
		h)	print_usage
			exit 0 ;;
		*) 	print_usage
	   		exit 1 ;;
	esac
done

if [ -z "$dnsList" ] || [ ! -f "$dnsList" ] || [ -z "$blockpagesList" ] || [ ! -f "$blockpagesList" ];then
	print_usage
	exit 1
fi

# Init the blockpage list
while read blockpage; do
        blockpages+=($blockpage)
done <"$blockpagesList"

# Verify the list of domains to check
if [ -f $domains ];then
	currentDate=$(date +%s)
	lastModif=$(date -r $domains +%s)
	day=86400
	if $timecheck && [ "$(($currentDate-$lastModif))" -gt "${day}" ];then
		printf "Update of the domains list\n"
		init_list
	fi
else
	printf "The list of domains is empty, generation of a new list"
	init_list
fi

# Init result.txt file
result="results.txt"
if [ -f $result ];then
	rm $result
fi

VALID_LENGTH=$(wc -l "$domains" | sed 's/ .*//')
DNS_THREADS=20

split -l $(($VALID_LENGTH/$DNS_THREADS+1)) -d -a 2 "$domains" "lists/sub_valid"

# Clean verbose folder
if $verbose ;then
        mkdir verbose 2>>/dev/null
        rm -f verbose/*
fi

while read dns; do
	if [ -z "$dns" ]; then
		continue
	fi
	address=$(echo $dns | grep -Eo "^[^ ]*" )
	name=$(echo $dns | grep -Eo "[A-Z][0-9A-Za-Z ]+[0-9A-Za-Z]" )
	options=$(echo $dns | grep -Eo "\/.*$")

	if [ -z "$address" ] || [ -z "$name" ]; then
		continue
	fi

       	checker  "$address"  "$name" "$options" &
	PIDS+=($!)
done < "${dnsList}"

for pid in "${PIDS[@]}"; do
	wait $pid
done

rm  -f lists/sub*

if $verbose ; then
        echo "Verbose results in 'verbose' directory"
fi

echo "Comparison finished, check the result in the 'results.txt' file"
