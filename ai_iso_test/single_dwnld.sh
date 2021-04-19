#!/bin/bash -e

ISO=$1

START=`date -u +"%Y-%m-%dT%H:%M:%SZ`

curl $i -o /dev/null &>> $1.log

RETURN=$?

STOP=`date -u +"%Y-%m-%dT%H:%M:%SZ`
