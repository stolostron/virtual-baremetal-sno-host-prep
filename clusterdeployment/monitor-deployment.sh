#!/bin/bash
set -o nounset

# Starts monitoring the progress of the creation and provisioning of SNO clusters
# installed with Assisted Installer.
# Usage:
#   ./monitor-deployment.sh
# The output of the stats will both be displayed in terminal output and saved to
# csv file managedsnocluster.csv.

# The following stats are reported:
#   - manifests_applied: the number of baremetal host manifests that have been applied.
#   - bmh_provisioned: running discovery iso and download rootfs.
#   - agent_count: rootfs has been downloaded and discovery results sent back to the hub.

file=managedsnocluster.csv

if [ ! -f ${file} ]; then
  echo "\
date,\
manifests_applied,\
agent_count,\
bmh_provisioned\
" > ${file}
fi

export KUBECONFIG=/root/bm/kubeconfig
sleep_seconds=5
while true; do
  D=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  manfest_applied=$(oc get clusterdeployment --all-namespaces | grep sno | wc -l | tr -d " ")
  agent_count=$(oc get agent --all-namespaces | wc -l | tr -d " ")
  bmh_provisioned_count=$(oc get bmh --all-namespaces | grep -c provisioned | tr -d " ")

  echo "$D"
  echo "$D manfest_applied     : $manfest_applied"
  echo "$D agent_count     : $agent_count"
  echo "$D bmh_provisioned_count      : $bmh_provisioned_count"

  echo "\
$D,\
$manfest_applied,\
$agent_count,\
$bmh_provisioned_count\
" >> ${file}

  sleep "$sleep_seconds"
done
