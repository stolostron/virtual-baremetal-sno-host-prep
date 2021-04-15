#!/bin/bash

file=managedcluster.csv

if [ ! -f ${file} ]; then
  echo "\
date,\
clusterdeployment_count,\
installenv_count,\
iso_generated\
" > ${file}
fi

export HISTO_DELAY=${HISTO_DELAY:-20}
echo "DELAY: ${HISTO_DELAY}"
COUNTER=0

while [ true ]; do
  D=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  clusterdeployment_status=$(oc get clusterdeployment -A -o custom-columns=NAME:metadata.name --no-headers | base64 -w 0)
  clusterdeployment_count=$(echo $clusterdeployment_status | base64 --decode | wc -l | tr -d " ")
  
  installenv_status=$(oc get installenv -A -o custom-columns=NAME:metadata.name,ISO:status.isoDownloadURL --no-headers | base64 -w 0)
#  intsallenv_count=$(echo $installenv_status | base64 --decode | wc -l | tr -d " ")
  iso_generated=$(echo $installenv_status    | base64 --decode | grep -v none | wc -l | tr -d " ")

  echo $D
  echo "$D   clusterdeployment_count      : $clusterdeployment_count"
#  echo "$D   installenv_count             : $installenv_count"
  echo "$D   installenv_count             : $(echo $installenv_status | base64 --decode | wc -l | tr -d " ")"
  echo "$D   iso_generated                : $iso_generated"

  echo "\
$D,\
$clusterdeployment_count,\
$(echo $installenv_status | base64 --decode | wc -l | tr -d " "),\
$iso_generated\
" >> managedcluster.csv

  sleep $HISTO_DELAY
  let COUNTER=COUNTER+1
done
