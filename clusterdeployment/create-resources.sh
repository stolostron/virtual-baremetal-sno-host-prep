#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

if [ -z "$2" ]; then
    echo 'usage: ./create-resources.sh PULL_SECRET_PATH SSH_KEY_PATH'
    exit 1
fi
pull_secret_path=$1
ssh_key_path=$2

generate_manifest_yamls() {
    row=$1
    IFS="," read cluster_name base_domain mac_addr ip_addr public_ip_network_prefix gateway machine_network_cidr dns_resolver bmc_addr bmc_username_base64 bmc_password_base64 <<< $row

    echo "=============== creating resources for cluster $cluster_name ==============="
    echo "$cluster_name, $base_domain, $mac_addr, $ip_addr, $gateway, $machine_network_cidr, $public_ip_network_prefix, $bmc_addr, $bmc_username_base64, $bmc_password_base64"

    yaml_dir=`echo $cluster_name/manifest`
    mkdir -p $yaml_dir

    cat clusterdeployment.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
	    -e "s~public_key~'$public_key'~g" \
	    -e s~machine_network_cidr~$machine_network_cidr~g \
            -e s/base_domain/$base_domain/g > $yaml_dir/500-clusterdeployment.yaml

    cat bmh-secret.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
	    -e s/bmc_username_base64/$bmc_username_base64/g \
            -e s/bmc_password_base64/$bmc_password_base64/g > $yaml_dir/200-bmh-secret.yaml

    cat infraenv.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
            -e "s~public_key~'$public_key'~g" > $yaml_dir/800-infraenv.yaml
    
    cat managedcluster.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g > $yaml_dir/700-managedcluster.yaml

    cat namespace.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g > $yaml_dir/100-namespace.yaml

    cat nmstate.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
	    -e "s~dns_resolver~'$dns_resolver'~g" \
	    -e "s~ip_addr~'$ip_addr'~g" \
	    -e "s~mac_addr~'$mac_addr'~g" \
	    -e "s~gateway~'$gateway'~g" \
	    -e s/public_ip_network_prefix/$public_ip_network_prefix/g > $yaml_dir/300-nmstate.yaml

    cat pull-secret.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
	    -e s/pull_secret_base64/$pull_secret_base64/g > $yaml_dir/400-pull-secret.yaml

    cat private-key.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
	    -e s/private_key_base64/$private_key_base64/g > $yaml_dir/400-private-key.yaml

    cat klusterletaddonconfig.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g > $yaml_dir/600-klusterletaddonconfig.yaml
    addon_array=`jq '.acmAddonConfig[].addonName' addon.json`
    # Append addon enable info
    for k in $(jq '.acmAddonConfig | keys | .[]' addon.json); do
	addonName=$(jq -r ".acmAddonConfig[$k].addonName" addon.json);
	enabled=$(jq -r ".acmAddonConfig[$k].enabled" addon.json);
	# Need to write to yaml; cannot use yq because bastion machine doesn't have yq
	echo -e "\n  $addonName:\n    enabled: $enabled" >> $yaml_dir/600-klusterletaddonconfig.yaml
    done

    cat baremetalhost.yaml.template | \
	sed -e s/cluster_name/$cluster_name/g \
	    -e "s~bmc_addr~'$bmc_addr'~g" \
	    -e "s~mac_addr~'$mac_addr'~g" > $yaml_dir/900-baremetalhost.yaml
}

pull_secret_base64=`cat $pull_secret_path | base64 -w 0`
public_key=`cat "${ssh_key_path}.pub"`
private_key_base64=`cat "${ssh_key_path}" | base64 -w 0`

cluster_array=`awk -F"," '{print $1}' inventory-manifest.csv`

input=inventory-manifest.csv
sed 1d $input | while  IFS="," read row; do
    generate_manifest_yamls $row

    echo "====== about to apply resources ======"
    KUBECONFIG=/root/bm/kubeconfig oc apply -f $yaml_dir
done

