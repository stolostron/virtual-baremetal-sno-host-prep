#!/bin/bash -e

echo 'delete assisted installer bundle'
oc delete subscriptions.operators.coreos.com -n assisted-installer --all
oc delete csv -n assisted-installer --all 

echo 'delete pvc'
oc delete pvc -n assisted-installer bucket-pv-claim --wait=false
oc delete pvc -n assisted-installer postgres-pv-claim --wait=false

echo 'delete pv if is using local pv'
oc delete pv assisted-installer-local-pv-postgres --wait=false
oc delete pv assisted-installer-local-pv-bucket --wait=false


#echo delete namespace
#oc delete ns assisted-installer