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

INTERVAL_SECOND=2
CONCURRENT_MAX=20
STOP_LOOP=false
function ctrl_c() {
    STOP_LOOP=true
    echo "Trapped CTRL-C: terminate all child process"
    for pid in ${pids[*]}; do
        kill -9 $pid
    done
}
# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

# Maintain 3 arrays (because we have 3 vmhosts), and 3 indexes.
# Each array stores the cluster manifest dirs of clusters that are NOT
# on the same host.
# We want to organize information this way so that we can apply the clusters
# that are not on the same host at the same time, and rate limit only if
# we are applying on the same host.
host0=()
host1=()
host2=()
host3=()
i0=0
i1=0
i2=0
i3=0

# Takes a cluster name and ip address and store it in its appropriate queue
# enqueue() {
#     ip=$2
#     last_section_ip=$((${-+"(${ip//./"+256*("}))))"}>>24&255)))
#     # This will be the position in the current inner array
#     index=$(($last_section_ip%4))
#     if [[ index -eq 0 ]]; then
# 	host0+=($1)
#     fi
#     if [[ index -eq 1 ]]; then
# 	host1+=($1)
#     fi
#     if [[ index -eq 2 ]]; then
# 	host2+=($1)
#     fi
#     if [[ index -eq 3 ]]; then
# 	host3+=($1)
#     fi
# }

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

    # cat nmstate.yaml.template | \
    # 	sed -e s/cluster_name/$cluster_name/g \
    # 	    -e "s~dns_resolver~'$dns_resolver'~g" \
    # 	    -e "s~ip_addr~'$ip_addr'~g" \
    # 	    -e "s~mac_addr~'$mac_addr'~g" \
    # 	    -e "s~gateway~'$gateway'~g" \
    # 	    -e s/public_ip_network_prefix/$public_ip_network_prefix/g > $yaml_dir/300-nmstate.yaml

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

    # enqueue $cluster_name $ip_addr
}

pull_secret_base64=`cat $pull_secret_path | base64 -w 0`
public_key=`cat "${ssh_key_path}.pub"`
private_key_base64=`cat "${ssh_key_path}" | base64 -w 0`

cluster_array=`awk -F"," '{print $1}' inventory-manifest.csv`

input=inventory-manifest.csv
sed 1d $input | while  IFS="," read row; do
    generate_manifest_yamls $row
    # echo "====== about to apply resources ======"
    # KUBECONFIG=/root/bm/kubeconfig oc apply -f $yaml_dir
done



#echo "====== About to apply resources ======"
# # We want to base the concurrency off of the number of times we go through
# # the while loop, not the number of oc apply we have. This is because there
# # can be multiple oc applies but they are okay if they are on different vmhosts.
# loop_count=0
# while [[ $i0+$i1+$i2+$i3 -l ${#host0[@]}+${#host1[@]}+${#host2[@]}+${#host03[@]} ]]; do
#     [ "$STOP_LOOP" = "true" ] && break;
#     sleep $INTERVAL_SECOND
#     # TODOTARA how much time to sleep?
#     while [ $loop_count % $CONCURRENT_MAX == 0 ] ; do sleep 10; done
    
#     if  [[ $i0 -l ${#host0[@]} ]]; then
# 	# Arrays in Bash are indexed from zero, and in zsh they're indexed from one
# 	KUBECONFIG=/root/bm/kubeconfig oc apply -f $hosts[$i0+1]
# 	(($i0++))
#     fi
#     if  [[ $i1 -l ${#host1[@]} ]]; then
# 	# Arrays in Bash are indexed from zero, and in zsh they're indexed from one
# 	KUBECONFIG=/root/bm/kubeconfig oc apply -f $hosts[$i1+1]
# 	(($i1++))
#     fi
#     if  [[ $i2 -l ${#host2[@]} ]]; then
# 	# Arrays in Bash are indexed from zero, and in zsh they're indexed from one
# 	KUBECONFIG=/root/bm/kubeconfig oc apply -f $hosts[$i2+1]
# 	(($i2++))
#     fi
#     if  [[ $i3 -l ${#host3[@]} ]]; then
# 	# Arrays in Bash are indexed from zero, and in zsh they're indexed from one
# 	KUBECONFIG=/root/bm/kubeconfig oc apply -f $hosts[$i3+1]
# 	(($i3++))
#     fi
# done
# echo "======= Finished applying resources ======"
