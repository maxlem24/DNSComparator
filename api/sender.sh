jsonfile="{"

jsonfile+="\"length\" : $(wc -l data.txt | grep -Eo '^[0-9]*'),\"results\" :[ "

results=""
while read line; do
	results+="\"$line\","
done < data.txt
jsonfile+="${results%?}"

jsonfile+="]}"

curl -X POST -H 'Content-Type: application/json' -d "$jsonfile" http://localhost:3000/result --silent
