#!/bin/bash

dnsList=$1
FILE="/lists/valid.txt"
if [ -f $FILE ];then
	currentDate=$(date +%s)
	lastModif=$(date -r $FILE +%s)
	if [ "$(($currentDate-$lastModif))" -gt "${86400}"];then
		/bin/bash initFile.sh
	fi
else
	/bin/bash initFile.sh
fi

while read dns; do
	address=$(sed 's/ .*//' dns)
	name=$(sed 's/^.* //' dns)
	/bin/bash dnsChecker $address $name
done < dnsList

echo "Comparaison finished, check the result in the 'results.txt' file"
