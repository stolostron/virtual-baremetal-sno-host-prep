#!/bin/bash
set -o errexit
set -o pipefail

if [ -z "$2" ]; then
    echo 'usage: ./create-resources.sh PULL_SECRET_PATH SSH_KEY_PATH [DNS_RESOLVER]'
    exit 1
fi
pull_secret_path=$1
ssh_key_path=$2
if [ -z "$3" ]; then
    dns_resolver=${3}
fi

pull_secret_base64=`cat $pull_secret_path | base64 -w 0`
public_key_base64=`cat "${ssh_key_path}.pub" | base64 -w 0`
private_key_base64=`cat "${ssh_key_path}" | base64 -w 0`

cluster_array=`awk -F"," '{print $1}' inventory-manifest.csv`

addon_array=`jq '.acmAddonConfig[].addonName' addon.json`

input=inventory-manifest.csv
while  IFS="," read cluster_name base_domain mac_addr ip_addr gateway public_ip_network_prefix bmc_addr bmc_username_base64 bmc_password_base64 ; do
    # TODOTARA 1) apply at a rate and 2) refactor single cluster creation

    echo "=============== creating resources for cluster $cluster_name ==============="

    yaml_dir=`echo $cluster_name/manifest`
    mkdir -p $yaml_dir

    cat clusterdeployment.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
            -e s/base_domain/$base_domain/g > $yaml_dir/500-clusterdeployment-$i.yaml
    cat bmh-secret.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
	    -e s/bmc_username_base64/$bmc_username_base64/g \
            -e s/bmc_password_base64/$bmc_password_base64/g > $yaml_dir/200-bmh-secret-$i.yaml
    cat infraenv.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
            -e s/public_key_base64/$public_key_base64/g > $yaml_dir/800-infraenv-$i.yaml
    cat managedcluster.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g > $yaml_dir/700-managedcluster-$i.yaml
    cat namespace.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g > $yaml_dir/100-namespace-$i.yaml
    cat nmstate.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
	    -e s/dns_resolver/$dns_resolver/g \
	    -e s/cluster_name/$cluster_name/g > $yaml_dir/300-nmstate-$i.yaml
    # TODOTARA possibly delete entry of dns-resolver
    cat pull-secret.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
	    -e s/pull_secret_base64/$pull_secret_base64/g > $yaml_dir/400-pull-secret-$i.yaml
    cat private-key.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
	    -e s/private_key_base64/$private_key_base64/g > $yaml_dir/400-private-key-$i.yaml

    # Write klusterletaddonconfig
    cat klusterletaddonconfig.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g > $yaml_dir/600-klusterletaddonconfig-$i.yaml
    # Append addon enable info
    for j in ${addon_array[@]}; do
	enabled=`yq e '.acmAddonConfig.addon_array[j]' inventory-manifest.yaml`
	yq w $yaml_dir/klusterletaddonconfig-$i.yaml '.spec.addon_array[j]' $enabled
    done
    # TODOTARA debug, to be removed
    echo "!!!!!!!!!!!!! klusterletaddonconfig file:"
    cat $yaml_dir/600-klusterletaddonconfig-$i.yaml
    
    # Apply resources (except baremetal host) for each cluster:
    oc apply -f $yaml_dir

    # Get image url for baremetal host
    image_url=`oc get infraenv $cluster_name -n $cluster_name -ojsonpath='{.status.isoDownloadURL}'`

    # Create baremetal host
    cat baremetalhost.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
	    -e s/image_url/$image_url/g \
	    -e s/bmc_addr/$bmc_addr/g \
	    -e s/mac_addr/$mac_addr/g > $yaml_dir/baremetalhost-$i.yaml
    oc apply -f $yaml_dir/baremetalhost-$i.yaml

    # Call get kubeconfig script and put them in the cluster directories
    curr_file_path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
    mkdir -p kubeconfig
    ./get-kubeconfigs.sh $cluster_name $curr_file_path/kubeconfig

done < $input

