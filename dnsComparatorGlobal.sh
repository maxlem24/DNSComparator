#!/bin/bash

dnsList=$1
if [ -z "$dnsList" ] || [ ! -f "$dnsList" ];then
	echo "use : dnsComparator <list of DNS to test>"
	exit
fi
list="valid.txt"
if [ -f $list ];then
	currentDate=$(date +%s)
	lastModif=$(date -r $list +%s)
	day=86400
	if [ "$(($currentDate-$lastModif))" -gt "${day}" ];then
		/bin/bash initList.sh
	fi
else
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
		options=$(echo $dns | grep -Eo "\+.*$")
		/bin/bash dnsChecker.sh "$address" "$name" "$options" &
		PIDS+=($!)
	fi
done < "${dnsList}"

for pid in "${PIDS[@]}"; do
	wait $pid
done

echo "Comparaison finished, check the result in the 'results.txt' file"
