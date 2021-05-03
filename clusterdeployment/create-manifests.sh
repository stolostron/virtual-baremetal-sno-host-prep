#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

# Create manifests of SNO clusters that will be installed via Assisted Installer.
# Please provide the hardware information of VM Hosts in inventory-manifest.csv,
# as well as which addons you would like to enable or disable in addon.json.
# Usage:
#   ./create-manifests.sh PULL_SECRET_PATH SSH_KEY_PATH'

if [ -z "$2" ]; then
    echo 'usage: ./create-manifests.sh PULL_SECRET_PATH SSH_KEY_PATH'
    exit 1
fi
pull_secret_path=$1
ssh_key_path=$2

generate_manifest_yamls() {
    local row=$1
    # TODO(taragu) find an alternative to read, because of its differences between gnu and zsh.
    IFS="," read cluster_name base_domain mac_addr ip_addr public_ip_network_prefix gateway machine_network_cidr dns_resolver bmc_addr bmc_username_base64 bmc_password_base64 <<< $row

    local yaml_dir=clusters/"$cluster_name"/manifest
    mkdir -p "$yaml_dir"

    echo "====== Generating manifests for $cluster_name  ======"
	sed -e s/cluster_name/"$cluster_name"/g \
	    -e "s~public_key~'$public_key'~g" \
	    -e s~machine_network_cidr~"$machine_network_cidr"~g \
        -e s/base_domain/"$base_domain"/g \
        templates/clusterdeployment.yaml.template > "$yaml_dir"/500-clusterdeployment.yaml

	sed -e s/cluster_name/"$cluster_name"/g \
	    -e s/bmc_username_base64/"$bmc_username_base64"/g \
        -e s/bmc_password_base64/"$bmc_password_base64"/g \
        templates/bmh-secret.yaml.template > "$yaml_dir"/200-bmh-secret.yaml

	sed -e s/cluster_name/"$cluster_name"/g \
        -e "s~public_key~'$public_key'~g" \
        templates/infraenv.yaml.template > "$yaml_dir"/800-infraenv.yaml

	sed -e s/cluster_name/"$cluster_name"/g \
        templates/managedcluster.yaml.template > "$yaml_dir"/700-managedcluster.yaml

	sed -e s/cluster_name/"$cluster_name"/g \
        templates/namespace.yaml.template > "$yaml_dir"/100-namespace.yaml

    sed -e s/cluster_name/"$cluster_name"/g \
        -e "s~dns_resolver~'$dns_resolver'~g" \
        -e "s~ip_addr~'$ip_addr'~g" \
        -e "s~mac_addr~'$mac_addr'~g" \
        -e "s~gateway~'$gateway'~g" \
        -e s/public_ip_network_prefix/"$public_ip_network_prefix"/g \
        templates/nmstate.yaml.template > "$yaml_dir"/300-nmstate.yaml

	sed -e s/cluster_name/"$cluster_name"/g \
	    -e s/pull_secret_base64/"$pull_secret_base64"/g \
        templates/pull-secret.yaml.template > "$yaml_dir"/400-pull-secret.yaml

	sed -e s/cluster_name/"$cluster_name"/g \
	    -e s/private_key_base64/"$private_key_base64"/g \
        templates/private-key.yaml.template > "$yaml_dir"/400-private-key.yaml

	sed -e s/cluster_name/"$cluster_name"/g \
        templates/klusterletaddonconfig.yaml.template > "$yaml_dir"/600-klusterletaddonconfig.yaml
    # Append addon enable info
    for k in $(jq '.acmAddonConfig | keys | .[]' addon.json); do
	    addonName=$(jq -r ".acmAddonConfig[$k].addonName" addon.json);
        enabled=$(jq -r ".acmAddonConfig[$k].enabled" addon.json);
        # Need to write to yaml; cannot use yq because bastion machine doesn't have yq
        echo -e "\n  $addonName:\n    enabled: $enabled" >> "$yaml_dir"/600-klusterletaddonconfig.yaml
        # TODO(taragu) for observaility addons that use labels
        # put this in klusterletaddonconfig.yaml.template: labels: {}
        # sed -e "s/{}/    - $addonName/1/" $yaml_dir/600-klusterletaddonconfig.yaml
    done

	sed -e s/cluster_name/"$cluster_name"/g \
	    -e "s~bmc_addr~'$bmc_addr'~g" \
	    -e "s~mac_addr~'$mac_addr'~g" \
        templates/baremetalhost.yaml.template > "$yaml_dir"/900-baremetalhost.yaml
}

pull_secret_base64=$(base64 -w 0 "$pull_secret_path")
public_key=$(cat "${ssh_key_path}.pub")
private_key_base64=$(base64 -w 0 "${ssh_key_path}")

input=inventory-manifest.csv
# TODO(taragu) find an alternative to read, because of its differences between gnu and zsh.
sed 1d $input | while  IFS="," read row; do
    generate_manifest_yamls "$row"
done