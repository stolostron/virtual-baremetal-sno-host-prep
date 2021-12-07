#!/bin/bash

# Usage
# ./scan_vmhost.sh hostname [inventory_file_path] [ssh_key] 
# will generate result like the following
# hostname enable_disk2=true num_vm_disk2=7 num_vm_hdd=4 disk2_device=/dev/disk2 disk2_above_t=true network1_nic=ens1f0

if [ -z "$1" ]; then
    echo "usage: ./scan_vmhost.sh hostname [inventory_file_path] [ssh_key] "
    exit 1
fi
if [ -z "$2" ]; then
    INVENTORY_PATH="inventory_vmhosts"
else
    INVENTORY_PATH="$2"
fi
if [ -z "$3" ]; then
    SSH_CMD="ssh"
else
    SSH_CMD="ssh -i $3"
fi


HOSTNAME=$1

HAS_MATCH=0
# default values, will always be reset
DISK1_NUM=1
DISK2_NUM=0
DISK2_NUM_TB=0
NETWORK1_NIC=ens1f0

# scan the configuration for host
while IFS="," read -r keyword num_hdd num_disk2 num_disk2_tb nic1_name; do 
  if [[ "$HOSTNAME" == *"$keyword"* ]]; then
    echo "use settings for $keyword."
    DISK1_NUM=$num_hdd
    DISK2_NUM=$num_disk2
    DISK2_NUM_TB=$num_disk2_tb
    NETWORK1_NIC=$nic1_name
    HAS_MATCH=1
    break
  fi
done <<EOT
$(sed 1d ./scalelab_machine_info)
EOT
 

if [ $HAS_MATCH -eq 0 ]; then
    echo "no match for configurations in scalelab_machine_info for hostname: $HOSTNAME"
    exit 1
fi

if [ ! -d "tmp/${HOSTNAME}" ]; then
    mkdir -p "tmp/${HOSTNAME}"
fi
echo "scanning ${HOSTNAME}"
# scan the disks & store results
${SSH_CMD} root@${HOSTNAME} lsblk -l > "tmp/${HOSTNAME}/lsblk.log"
if [ $? -ne 0 ]; then
    echo "failed to scan ${HOSTNAME}"
    exit 1
fi
${SSH_CMD} root@${HOSTNAME} ls -l /dev > "tmp/${HOSTNAME}/dev.log"
if [ $? -ne 0 ]; then
    echo "failed to scan ${HOSTNAME}"
    exit 1
fi
# scan network & store results
${SSH_CMD} root@${HOSTNAME} ifconfig > "tmp/${HOSTNAME}/ifconfig.log"
if [ $? -ne 0 ]; then
    echo "failed to scan ${HOSTNAME}"
    exit 1
fi

${SSH_CMD} root@${HOSTNAME} ifconfig ${NETWORK1_NIC} > "tmp/${HOSTNAME}/ifconfig-nic1.log"
if [ $? -ne 0 ]; then
    echo "failed to scan ${HOSTNAME} with ${NETWORK1_NIC}"
    exit 1
fi
HAS_SDA=0
HAS_SDB=0
HAS_SDC=0
ENABLE_DISK2=false
DISK2_TB=false
HAS_NVME=0


echo "checking disk"
cat "tmp/${HOSTNAME}/dev.log" | grep nvme0n1
if [ $? -eq 0 ]; then
    HAS_NVME=1
    NVME_AVAILABLE="nvme_available=true"
    echo "has nvme"
    ENABLE_DISK2=true
    DISK2_DEVICE="disk2_device=/dev/nvme0n1"
    cat "tmp/${HOSTNAME}/lsblk.log" | grep nvme | awk '{print $4}' | grep "T"
    if [ $? -eq 0 ]; then
        DISK2_TB=true
    fi

else 
    cat "tmp/${HOSTNAME}/dev.log" | grep sda
    if [ $? -eq 0 ]; then
        HAS_SDA=1
        echo "detected sda"
    fi
    cat "tmp/${HOSTNAME}/dev.log" | grep sdb
    if [ $? -eq 0 ]; then
        HAS_SDB=1
        echo "detected sdb"
        SDB_TB=0
        cat "tmp/${HOSTNAME}/lsblk.log" | grep sdb | grep boot
        if [ $? -eq 0 ]; then
            echo "sdb is boot drive, ignoring"
            HAS_SDB=0
        fi
        cat "tmp/${HOSTNAME}/lsblk.log" | grep sdb | awk '{print $4}' | grep "T"
        if [ $? -eq 0 ]; then
            SDB_TB=1
        fi
        
    fi
    cat "tmp/${HOSTNAME}/dev.log" | grep sdc
    if [ $? -eq 0 ]; then
        HAS_SDC=1
        echo "detected sdc"
        SDC_TB=0
        cat "tmp/${HOSTNAME}/lsblk.log" | grep sdc | grep boot
        if [ $? -eq 0 ]; then
            echo "sdc is boot drive, ignoring"
            HAS_SDC=0
        fi
        cat "tmp/${HOSTNAME}/lsblk.log" | grep sdc | awk '{print $4}' | grep "T"
        if [ $? -eq 0 ]; then
            SDC_TB=1
        fi
    fi
    echo "HAS_SDB: $HAS_SDB"
    echo "HAS_SDC: $HAS_SDC"

    if [ $HAS_SDB -eq 1 ]; then
        ENABLE_DISK2=true
        DISK2_DEVICE="disk2_device=/dev/sdb"
        if [ $SDB_TB -eq 1 ]; then
            DISK2_TB=true
        fi
    elif [ $HAS_SDC -eq 1 ]; then
        ENABLE_DISK2=true
        DISK2_DEVICE="disk2_device=/dev/sdc"
        if [ $SDC_TB -eq 1 ]; then
            DISK2_TB=true
        fi
    fi
fi

if [ $DISK2_NUM -eq 0 ] && [ $DISK2_NUM_TB -eq 0 ] ; then
    ENABLE_DISK2=false
fi

if [ "$ENABLE_DISK2" = 'true' ]; then
    if [ "$DISK2_TB" = 'true' ]; then
        DISK2_NUM=$DISK2_NUM_TB
    fi
fi
echo "checking network"
# check network
cat "tmp/${HOSTNAME}/ifconfig-nic1.log" | grep $NETWORK1_NIC
if [ $? -ne 0 ]; then
    echo "failed to get correct network1 device $NETWORK1_NIC"
    exit 1
fi

cat "tmp/${HOSTNAME}/ifconfig-nic1.log" | grep "inet 10."
if [ $? -eq 0 ]; then
    echo "Find 10. ip for given NIC $NETWORK1_NIC. Please double check the NIC configuration. Skipping $HOSTNAME."
    exit 1
fi

echo ${HOSTNAME} enable_disk2=${ENABLE_DISK2} num_vm_disk2=${DISK2_NUM} num_vm_hdd=${DISK1_NUM} ${DISK2_DEVICE} disk2_above_t=${DISK2_TB} network1_nic=${NETWORK1_NIC}

cat <<EOF >> ${INVENTORY_PATH}
${HOSTNAME} enable_disk2=${ENABLE_DISK2} num_vm_disk2=${DISK2_NUM} num_vm_hdd=${DISK1_NUM} ${DISK2_DEVICE} disk2_above_t=${DISK2_TB} network1_nic=${NETWORK1_NIC} ${NVME_AVAILABLE}
EOF
