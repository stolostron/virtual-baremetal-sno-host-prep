#!/usr/bin/env bash

# Gets all provisioned cluster kubeconfigs
# Usage:
#   ./getkubeconfigs.sh cluster-name dircluster-directory
# cluster-name: the cluster of the kubeconfig you wish to download.
# cluster-directory: the location of the downloaded kubeconfig will be
#   put here with `/kubeconfig` appended to the path.

cluster_name=$1
base_file_dir=$2
echo "$(date -u +%Y%m%d-%H%M%S) - Getting kubeconfigs"
echo "$(date -u +%Y%m%d-%H%M%S) - Clusters name: ${cluster_name}"
oc get secret -n $cluster_name | grep kubeconfig | awk '{print $1}' | xargs -I % oc get secret -n $cluster_name % -o json | jq -r '.data.kubeconfig' | base64 -d > $base_file_dir/$cluster_name/kubeconfig

echo "$(date -u +%Y%m%d-%H%M%S) - Finished getting kubeconfig"
