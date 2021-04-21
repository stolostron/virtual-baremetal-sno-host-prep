#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset


if [ -z "$2" ]; then
    echo 'usage: ./generate.sh PULL_SECRET_PATH SSH_KEY_PATH [DNS_RESOLVER]'
    exit 1
fi
pull_secret_path=$1
ssh_key_path=$2
dns_resolver=${3}

pull_secret_base64=`cat $pull_secret_path | base64 -w 0`
public_key_base64=`cat "${ssh_key_path}.pub" | base64 -w 0`
private_key_base64=`cat "${ssh_key_path}" | base64 -w 0`

cluster_array=`yq e '.snoInventory' inventory-manifest.yaml`
addon_array=`yq e '.acmAddonConfig' inventory-manifest.yaml`

for i in ${cluster_array[@]}; do
    cluster_name=`yq e '.snoInventory[i].clusterName' inventory-manifest.yaml`
    base_domain=`yq e '.snoInventory[i].baseDomainName' inventory-manifest.yaml`
    mac_addr=`yq e '.snoInventory[i].networkInformation.macAddr' inventory-manifest.yaml`
    ip_addr=`yq e '.snoInventory[i].networkInformation.ip' inventory-manifest.yaml`
    gateway=`yq e '.snoInventory[i].networkInformation.gateway' inventory-manifest.yaml`
    public_ip_network_prefix=`yq e '.snoInventory[i].networkInformation.public_ip_network_prefix' inventory-manifest.yaml`
    bmc_addr=`yq e '.snoInventory[i].bmcAddr' inventory-manifest.yaml`
    bmc_username_base64=$(yq e '.snoInventory[i].bmcUsername' inventory-manifest.yaml | base64 -w 0)
    bmc_password_base64=$(yq e '.snoInventory[i].bmcPassword' inventory-manifest.yaml | base64 -w 0)

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

done

