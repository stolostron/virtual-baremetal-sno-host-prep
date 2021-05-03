#!/bin/bash

# Usage
# ./generate_inventory.sh cloudname [ssh_key]

if [ -z $1 ]; then
    echo "cloudname not given"
    exit 1
fi

if [ ! -d "tmp/inventory"  ]; then
    mkdir -p "tmp/inventory"
fi

if [ $GENERATE_INVENTORY_COPY_PUBLIC_KEY = 'true' ]; then
    if [ ! -z "$2" ]; then
        WITH_SSH_KEY="-i $2"
    else
        WITH_SSH_KEY=""
    fi
    read -s -p "Enter password for ssh: " TEMP_SSH_PASSWORD
fi
# getting cloud
curl -s http://quads.rdu2.scalelab.redhat.com/cloud/${1}_ocpinventory.json > tmp/inventory/cloud.json
if [ $? -ne 0 ]; then
    echo 'failed to get json'
    exit 1
fi
if [ -f "tmp/inventory/$1.local" ]; then
    rm "tmp/inventory/$1.local"
fi

for hostname in `jq -r '.nodes[]|.pm_addr' tmp/inventory/cloud.json | sed 's/^mgmt-//g'`; do
    # check if it's excluded
    IS_EXCLUDED=0
    for exclude_host in `cat exclude_hosts`; do
        if [ "$exclude_host" = "$hostname" ]; then
            IS_EXCLUDED=1
            break
        fi
    done
    if [ ${IS_EXCLUDED} -eq 0 ]; then
        if [ $GENERATE_INVENTORY_COPY_PUBLIC_KEY = 'true' ]; then
            sshpass -p "$TEMP_SSH_PASSWORD" ssh-copy-id ${WITH_SSH_KEY} root@$hostname
            if [ $? -ne 0 ]; then
                echo "failed to add key to $hostname. skipping"
                continue
            fi
        fi
        ./scan_vmhost.sh $hostname "tmp/inventory/$1.local" $2
    fi
done





