#!/bin/bash -e

count=1
pids=()

echo "Downloading ISOs"
echo "----------------"
printf "\n"

for i in $(oc get installenv -A -o custom-columns=ISO:status.isoDownloadURL --no-headers); do
  D=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  echo "$D Begining $count download..."
  curl $i -# -o /dev/null &>/dev/null &
  pids+=($!)
  count=$((count+1))
done

for pid in ${pids[@]}; do
  wait $pid
done

D=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "$D ...All downloads complete!"

printf "\n"
echo "----------------"
echo "Downloads complete."
echo 'Have a nice day :)'
