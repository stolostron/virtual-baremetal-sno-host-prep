#!/bin/bash -e


ISO=isogen$2
START=`date -u +"%Y-%m-%dT%H:%M:%SZ`

curl $1 -o /dev/null &> log/$ISO.log

RETURN=$?
STOP=`date -u +"%Y-%m-%dT%H:%M:%SZ`

echo "\
$ISO,\
$START,\
$RETURN,\
$STOP" >> managedISO.csv
