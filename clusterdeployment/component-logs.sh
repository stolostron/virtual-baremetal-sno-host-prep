#!/bin/bash

epoch_time=$(date +%s)
as_log_file=assisted-service-$epoch_time.log
bmo_log_file=baremetal-operator-$epoch_time.log
touch $as_log_file
touch $bmo_log_file

export KUBECONFIG=/root/bm/kubeconfig
assisted_service_pod_name=$(oc get pod -n assisted-installer-2 | grep assisted-service | awk '{print $2}'| head -n 1)
oc logs $assisted_service_pod_name -n assisted-installer >> $as_log_file
baremetal_operator_pod_name=$(oc get pod -n openshift-machine-api | grep metal3 | awk '{print $2}'| head -n 1)
oc logs $baremetal_operator_pod_name -c baremetal-operator -n openshift-machine-api >> $bmo_log_file
