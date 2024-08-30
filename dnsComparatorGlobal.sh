#!/bin/bash

print_usage() {
	printf "Usage: \n"
	printf "\t-l filename : Set the list of DNS to test (required) \n"
	printf "\t-b filename : Set the list of the blockpages IP adresses (required) \n"
	printf "\t-d filename : Set the list of domains to test. Default: valid.txt \n"
	printf "\t-v : Set verbose on \n"
	printf "\t-f : Force the use of the list of domains if it is been updated since more than 24 hours \n"
	printf "\t-h : Display the use of the command\n"
}



dnsList=''
blockpages=''
verbose=false
domains='valid.txt'
timecheck=true

while getopts 'l:b:vd:fh' flag; do
	case "${flag}" in
		l) 	dnsList="${OPTARG}";;
		b) 	blockpages="${OPTARG}";;
		v) 	verbose=true ;;
		d)	domains="${OPTARG}";;
		f)	timecheck=false ;;
		h)	print_usage
			exit 0 ;;
		*) 	print_usage
	   		exit 1 ;;
	esac
done

if [ -z "$dnsList" ] || [ ! -f "$dnsList" ] || [ -z "$blockpages" ] || [ ! -f "$blockpages" ];then
	print_usage
	exit 1
fi

if [ -f $domains ];then
	currentDate=$(date +%s)
	lastModif=$(date -r $domains +%s)
	day=86400
	if $timecheck && [ "$(($currentDate-$lastModif))" -gt "${day}" ];then
		printf "Update of the domains list\n"
		/bin/bash initList.sh
	elif [ "$domains" != "valid.txt" ]; then
		cp "$domains" "valid.txt"
	fi
else
	printf "The list of domains is empty, generation of a new list"
	/bin/bash initList.sh
fi

result="results.txt"
if [ -f $result ];then
	rm $result
fi

while read dns; do
	if [ -n "$dns" ]; then
		address=$(echo $dns | grep -Eo "^[^ ]*" )
		name=$(echo $dns | grep -Eo "[A-Z][0-9A-Za-Z ]+[0-9A-Za-Z]" )
		options=$(echo $dns | grep -Eo "\/.*$")

		if [ -z "$options" ]; then
			if $verbose ; then
				/bin/bash dnsChecker.sh -s "$address" -n "$name" -b "$blockpages" -v &
				PIDS+=($!)
			else
				/bin/bash dnsChecker.sh -s "$address" -n "$name" -b "$blockpages" &
				PIDS+=($!)
			fi
		else
			if $verbose ; then
                                /bin/bash dnsChecker.sh -s "$address" -n "$name" -b "$blockpages" -v -H "$options" &
                        	PIDS+=($!)
			else
                                /bin/bash dnsChecker.sh -s "$address" -n "$name" -b "$blockpages" -H "$options" &
                        	PIDS+=($!)
			fi
		fi
	fi
done < "${dnsList}"

for pid in "${PIDS[@]}"; do
	wait $pid
done

if $verbose ; then
        echo "Verbose results in 'verbose' directory"
fi

echo "Comparison finished, check the result in the 'results.txt' file"
