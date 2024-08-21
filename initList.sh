#!/bin/bash

# CLean Previous lists
rm lists/*

# Get lists
wget --quiet "https://zonefiles.io/f/compromised/domains/live/compromised_domains_live.txt" -O - | grep -i -v -e '^#' > lists/zonefiles_compromised.txt
wget --quiet "https://hole.cert.pl/domains/v2/domains.txt" -O lists/certpl_compromised.txt
wget --quiet "https://raw.githubusercontent.com/deathbybandaid/piholeparser/master/Subscribable-Lists/ParsedBlacklists/DNS-BH-Malware-Domains.txt" -O lists/pihole_compromised.txt
wget --quiet "https://urlhaus.abuse.ch/downloads/hostfile/" -O - | grep -i -v -e '^#' | sed "s/127.0.0.1\t//"> lists/abusesh_compromised.txt

# Merge and unification
cat lists/*.txt | sort | uniq > lists/compromised.txt
split -l 2500 -d -a 2 lists/compromised.txt lists/sublist_test
echo "list merged and sorted"

# Create Thread to check if domains still valid
NUM_THREADS=$(($(wc -l lists/compromised.txt | sed 's/ .*//')/2500))

PIDS=()

function check_valid {
	local id=$1
	while read host; do
		ip_address=$(dig @8.8.8.8 +short $host | head -n1)
		if [[ -n $ip_address ]]; then
			echo $host >> "lists/sublist_valid${id}"
		fi
	done < "lists/sublist_test${id}"
}
ten=10
for ((i=0;i<NUM_THREADS;i++)); do
	if [ "$i" -lt "$ten" ];then
		check_valid "0${i}" &
		PIDS+=($!)
	else
		check_valid $i &
                PIDS+=($!)
	fi
done

for pid in "${PIDS[@]}"; do
	wait $pid
done

cat lists/sublist_valid* | sort > lists/valid.txt
sleep 1
rm lists/sublist_*

echo "Completed"
echo "Length of the final list: $(wc -l lists/valid.txt | sed 's/ .*//')"
