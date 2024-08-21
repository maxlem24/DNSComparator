#!/bin/bash

dnsList=$1
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
	if [ -n dns ]; then
		address=$(echo $dns | grep -Eo "^[^ ]*" )
		name=$(echo $dns | grep -Eo "[A-Z][0-9A-Za-Z ]+[0-9A-Za-Z]" )
		/bin/bash dnsChecker.sh "$address" "$name"
	fi
done < "${dnsList}"

echo "Comparaison finished, check the result in the 'results.txt' file"
