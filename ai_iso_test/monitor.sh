#!/bin/bash

file=managedcluster.csv

if [ ! -f ${file} ]; then
  echo "\
date,\
clusterdeployment_ct,\
installenv_ct,\
iso_generated,\
" > ${file}
fi

export HISTO_DELAY=${HISTO_DELAY:-60}
echo "DELAY: ${HISTO_DELAY}"
COUNTER=0

while [ true ]; do
  D=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  clusterdeployment_status=$(oc get clusterdeployment -A -o custom-columns=NAME:metadata.name --no-headers)
  clusterdeployment_ct=$(echo $clusterdeployment_status | wc -l)
  
  installenv_status=$(oc get installenv -A -o custom-columns=NAME:metadata.name,ISO:status.isoDownloadURL --no-headers)
  intsallenv_ct=$(echo $installenv_status | wc -l)
  iso_generated=$(echo $installenv_status | grep -v none | wc -l)

  echo $D
  echo "$D clusterdeployment_ct      : $clusterdeployment_ct"

  echo "$D installenv_ct      : $installenv_ct"
  echo "$D iso_generated      : $iso_generated"

  echo "\
$D,\
$clusterdeployment_ct,\
$installenv_ct,\
$iso_generated,\
" >> managedcluster.csv

  sleep $HISTO_DELAY
  let COUNTER=COUNTER+1
done
