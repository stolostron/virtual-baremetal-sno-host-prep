#!/bin/bash
set -o nounset

# Starts monitoring the progress of the creation and provisioning of SNO clusters
# installed with Assisted Installer.
# Usage:
#   ./monitor-deployment.sh [INTERVAL_SECONDS]
# The output of the stats will both be displayed in terminal output and saved to
# csv file managedsnocluster.csv.
# You can optionally supply the number of seconds between each intervals of collecting
# stats. The default value is 10 seconds.

# The following stats are reported:
#   - initialized: the number of clusterdeployment that have been created.
#   - booted: baremetal hosts that are provisioned; currently running discovery iso and downloading rootfs.
#   - discovered: rootfs has been downloaded and discovery results sent back to the hub; agent created.
#   - provisioning: clusterdeployment in provisioning state
#   - completed: clusterdeployment in completed state
#   - managed: managedcluster avaialble
#   - agent_installed: managedclusteraddon avaialble

file=managedsnocluster.csv

if [ ! -f ${file} ]; then
  echo "\
date,\
initialized,\
booted,\
discovered,\
provisioning,\
completed,\
managed,\
agent_installed\
" > ${file}
fi

export KUBECONFIG=/root/bm/kubeconfig
sleep_seconds=10
while true; do
  D=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  initialized=$(oc get clusterdeployment --all-namespaces | grep -c sno | tr -d " ")
  booted=$(oc get bmh --all-namespaces | grep -c provisioned | tr -d " ")
  discovered=$(oc get agent --all-namespaces | wc -l | tr -d " ")
  provisioning=$(oc get clusterdeployment --all-namespaces | grep sno | grep provisioning | wc -l | tr -d " ")
  completed=$(oc get clusterdeployment --all-namespaces | grep sno | grep completed | wc -l | tr -d " ")
  managed=$(oc get managedcluster --no-headers -o custom-columns=JOINED:'.status.conditions[?(@.type=="ManagedClusterJoined")].status',AVAILABLE:'.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status' | grep -v none | grep True | grep -v Unknown | wc -l | tr -d " ")
  agent_installed=$(oc get managedclusteraddon -A --no-headers -o custom-columns=AVAILABLE:'.status.conditions[?(@.type=="Available")].status' | grep -c True)

  echo "$D"
  echo "$D initialized: $initialized"
  echo "$D booted: $booted"
  echo "$D discovered: $discovered"
  echo "$D provisioning: $provisioning"
  echo "$D completed: $completed"
  echo "$D managed: $managed"
  echo "$D agent_installed: $agent_installed"

  echo "\
$D,\
$initialized,\
$booted,\
$discovered,\
$provisioning,\
$completed,\
$managed,\
$agent_installed\
" >> ${file}

  sleep "$sleep_seconds"
done
