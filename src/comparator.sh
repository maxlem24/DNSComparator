#!/bin/bash

dnsList=''
blockpagesList=''
domains='valid.txt'
timecheck=true
accept_mail=false

VALID_LENGTH=0
FINISHED_SCAN=0

mkdir lists 2>>/dev/null

# Check Valid Domains
check_valid() {
	local id=$1
	while read host; do
		local data=$(dig @8.8.8.8 $host +short +time=3)
                local ip_address=$(echo "${data}" \
			| grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}" \
			| tail -n1)

		if [ -n "$ip_address" ] \
		&& [ "$ip_address" != "0.0.0.0" ] \
		&& [ "$ip_address" != "127.0.0.1" ] \
		&& [ "$ip_address" != "8.8.8.8" ] ; then
			echo $host >> "lists/sublist_valid${id}"
		fi

	done < "lists/sublist_test${id}"
}

# Init lists

init_list() {
	local INIT_START=$(date +%s)
	rm -f lists/*

	curl -s "https://zonefiles.io/f/compromised/domains/live/compromised_domains_live.txt" \
	| grep -i -v -e '^#' \
	> lists/zonefiles_compromised.txt

	curl -s "https://hole.cert.pl/domains/v2/domains.txt" \
	-o lists/certpl_compromised.txt

	curl -s "https://v.firebog.net/hosts/Prigent-Malware.txt" \
	| grep -i -v -e '^#|^$' \
	> lists/firebog_compromised.txt

	curl -s "https://urlhaus.abuse.ch/downloads/hostfile/" \
	| grep -i -v -e '^#' \
	| sed "s/127.0.0.1\t//" \
	> lists/abusesh_compromised.txt

	cat lists/*.txt | sort | uniq > lists/compromised.txt

	local length=$(wc -l lists/compromised.txt | sed 's/ .*//')
	local INIT_THREADS=50

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

	local INIT_END=$(date +%s)

	echo "Completed in $(($INIT_END-INIT_START))s"
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

# Check sublist

thread_check_blocked() {
	local dnsServer=$1
	local dnsName=$2
	local dnsOptions=$3
	local id=$4

	if [ ! -f "lists/sub_valid${id}" ]; then
		exit 0
	fi

	local thread_blocked=0

	touch "lists/${dnsName}/timed_out_${id}.txt"
        touch "lists/${dnsName}/not_blocked_${id}.txt"
	touch "lists/${dnsName}/time_${id}.txt"
	while read host; do
		local begin=$(date +%s%3N)
		local data=$(dig @$dnsServer $host $dnsOptions +short)
		local end=$(date +%s%3N)
		local ip_address=$(echo "${data}" \
			| grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}" \
			| tail -n1)
		if [[ -z "$ip_address" ]] || is_a_blockpage "$ip_address" ;then
			let thread_blocked++
		elif [ "$ip_address" == "$dnsServer" ]; then
			echo "${host}" >> "lists/${dnsName}/timed_out_${id}.txt"
		else
			echo "${ip_address} ${host}" >> "lists/${dnsName}/not_blocked_${id}.txt"
		fi
		local timequery=$(($end-$begin))
		echo "${timequery}" >> "lists/${dnsName}/time_${id}.txt"
	done < "lists/sub_valid${id}"

	echo $thread_blocked >> "lists/${dnsName}/sub_valid_total"
}

# Check list with 1 DNS server

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
			thread_check_blocked "$dnsServer" "$dnsName" "$dnsOptions" "0${i}" &
			CHECK_PIDS+=($!)

		else
			thread_check_blocked "$dnsServer" "$dnsName" "$dnsOptions" "${i}" &
                	CHECK_PIDS+=($!)

		fi
	done

	for pid in "${CHECK_PIDS[@]}"; do
		wait $pid
	done

	cat "lists/${dnsName}"/timed_out_*.txt | sort > "verbose/${dnsName}_timed_out.txt"
	cat "lists/${dnsName}"/not_blocked_*.txt | sort > "verbose/${dnsName}_not_blocked.txt"
	cat "lists/${dnsName}"/time_*.txt > "verbose/${dnsName}_time.txt"

	local ENDTIME=$(date +%s)
	local sum_blocked=0

	local total_time=0
	local max_time=0
	local min_time=3600000

	while read value; do
                total_time=$(($total_time+$value))
		if [ "$value" -gt "$max_time" ]; then
			max_time=$value
		fi
		if [ "$value" -lt "$min_time" ]; then
			min_time=$value
		fi
        done < "verbose/${dnsName}_time.txt"

	while read value; do
		sum_blocked=$(($sum_blocked+$value))
	done < "lists/${dnsName}/sub_valid_total"

	average_time=$(($total_time/$VALID_LENGTH))

	rm -r "lists/${dnsName}"

	percentage=$(echo "scale=2;100*${sum_blocked}/${VALID_LENGTH}" | bc -l)

	echo "${dnsName};${sum_blocked};${VALID_LENGTH};${percentage}%;$(($ENDTIME - $STARTTIME));${average_time};${min_time};${max_time}" >> results.csv
}

# Send email

send_email(){
	set -a
	source .env
	set +a

	zip results -r -q results.csv verbose
	subject="Test results"
	file="results.zip"

	curl -s --url 'smtps://smtp.gmail.com:465' --ssl-reqd \
    	--mail-from "$SENDER_MAIL" \
    	--mail-rcpt "$RECEIVER_MAIL" \
    	--user "$SENDER_MAIL:$SENDER_PASSWD" \
    	-H "From: ${SENDER_MAIL}" \
   	-H "To: ${RECEIVER_MAIL}" \
    	-H "Subject : ${subject}" \
    	-F '=(;type=multipart/mixed' \
    	-F '="Here are the results";type=text/plain' \
    	-F "file=@$file;type=application/zip;encoder=base64" \
    	-F "=)"

	rm $file
}

# Manual

print_usage() {
	printf "Usage: \n"
	printf "\t-l filename : Set the list of DNS provider to test (required) \n"
	printf "\t-b filename : Set the list of the blockpages IP adresses (required) \n"
	printf "\t-d filename : Set the list of domains to test. Default: valid.txt \n"
	printf "\t-f : Force the use of the list of domains if it is been updated since more than 24 hours \n"
	printf "\t-h : Display the use of the command\n"
	printf "\t-y : Accept that the data collected will be sent to Kappa Data\n"
}

print_agreement() {
	printf "This tool is provided by Kappa Data BV\n"
	printf "By using it, you consent that the results of this scan are used to statistics\n"
}

# Handle Args

while getopts 'l:b:d:fhy' flag; do
	case "${flag}" in
		l) 	dnsList="${OPTARG}";;
		b) 	blockpagesList="${OPTARG}";;
		d)	domains="${OPTARG}";;
		f)	timecheck=false ;;
		h)	print_usage
			exit 0 ;;
		y)	accept_mail=true ;;
		*) 	print_usage
	   		exit 1 ;;
	esac
done

if [ -z "$dnsList" ] || [ ! -f "$dnsList" ] \
|| [ -z "$blockpagesList" ] || [ ! -f "$blockpagesList" ];then
	print_usage
	exit 1
fi

# Accept email condition
if ! $accept_mail; then
	print_agreement
fi
while ! $accept_mail; do
	printf "Do you agree the condition above ? Y/N "
	read response
	case "$response" in
		"y" | "Y") accept_mail=true;;
		"n" | "N") exit 0;;
		*);;
	esac
done

# Init the blockpage list

while read blockpage; do
        blockpages+=($blockpage)
done <"$blockpagesList"

# Verify the list of domains to check

if [ -f $domains ];then

	currentDate=$(date +%s)
	lastModif=$(date -r $domains +%s)
	day=86400

	if $timecheck \
	&& [ "$(($currentDate-$lastModif))" -gt "${day}" ];then

		printf "Update of the domains list\r"
		init_list

	fi
else
	printf "The list of domains is empty, generation of a new list\r"
	init_list
fi

# Init result.csv file

echo "Name of the provider;Number of blocked domains;Number of tested domains;Ratio of blocked domains;Total Time (s);Average answer time (ms);Minimal answer time (ms);Maximal answer time (ms)" > results.csv

VALID_LENGTH=$(wc -l "$domains" | sed 's/ .*//')
DNS_THREADS=30

split -l $(($VALID_LENGTH/$DNS_THREADS+1)) -d -a 2 "$domains" "lists/sub_valid"

# Clean verbose folder

mkdir verbose 2>>/dev/null
rm -f verbose/*

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

NB_DNS=${#PIDS[@]}

printf "Scan running... ${FINISHED_SCAN}/${NB_DNS} finished\r"

for pid in "${PIDS[@]}"; do
	wait $pid
	FINISHED_SCAN=$(($FINISHED_SCAN+1))
	printf "Scan running... ${FINISHED_SCAN}/${NB_DNS} finished\r"
done

send_email

rm  -f lists/sub*

echo "Comparison finished, check the result in the 'results.csv' file"
echo "The detailled results are in the 'verbose' folder"
