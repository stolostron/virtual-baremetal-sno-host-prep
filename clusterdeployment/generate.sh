#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

cluster_array=`yq e '.snoInventory' inventory-manifest.yaml`
for i in ${cluster_array[@]}; do
    cluster_name=`yq e '.snoInventory[i].clusterName' inventory-manifest.yaml`
    base_domain=`yq e '.snoInventory[i].baseDomainName' inventory-manifest.yaml`
    mac_addr=`yq e '.snoInventory[i].networkInformation.macAddr' inventory-manifest.yaml`
    ip_addr=`yq e '.snoInventory[i].networkInformation.ip' inventory-manifest.yaml`
    gateway=`yq e '.snoInventory[i].networkInformation.gateway' inventory-manifest.yaml`
    bmc_addr=`yq e '.snoInventory[i].bmcAddr' inventory-manifest.yaml`
    bmc_username=`yq e '.snoInventory[i].bmcUsername' inventory-manifest.yaml`
    bmc_password=`yq e '.snoInventory[i].bmcPassword' inventory-manifest.yaml`

    mkdir -p $cluster_name
    cat clusterdeployment.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
            -e s/base_domain/$base_domain/g > $cluster_name/clusterdeployment-$i.yaml

    # TODOTARA next:  baremetalhost.yaml.template
done

