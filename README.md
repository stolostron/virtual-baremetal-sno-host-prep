# virtual-baremetal-sno-host-prep

[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)

## What is virtual-baremetal-sno-host-prep?

Example header: What is the `multicloud-operators-subscription` repository?

Example description: With `<repo_name>`, you can....

Go to the [Contributing guide](CONTRIBUTING.md) to learn how to get involved.

## Getting started

### Setup VM Hosts

1. Create all.yml:
```
cp vars/all.sample.yml vars/all.yml
```

2. Fill in all.yml according to the comments.

3. Create a inventory file. All hosts should be ssh accessible:
```
cat << EOF > inventory
[bastion]
host-name-of-bastion

[vmhosts]
host-name-of-vm-hosts-01 offset=1 enable_disk2=true disk2_device=/dev/nvme0n1 num_vm_disk2=10 num_vm_hdd=5
host-name-of-vm-hosts-02 offset=2 enable_disk2=false num_vm_disk2=7 num_vm_hdd=5
host-name-of-vm-hosts-03 offset=3 enable_disk2=true disk2_device=/dev/sdb num_vm_disk2=5 num_vm_hdd=5
host-name-of-vm-hosts-01 offset=4 enable_disk2=true disk2_device=/dev/sdc num_vm_disk2=10 num_vm_hdd=5
EOF
```
   Offset will be used to generate a public IP of the vmhost. (offset + public_ip_network_node_start)
   If enable_disk2 is set to true, will setup disk2 disks on the vmhost, and will use disk2_device for the disk2 disks. The disk2_device will be partitioned and formatted.
   num_vm_disk2 & num_vm_hdd will be the number of vms we will generate when running the 02-create-many-vms playbook.

   If using RH scale lab, you can also use the [generate_inventory](generate_inventory/README.md) script to scan all vms and generate.


3. Run the following command to setup vmhost:
```
ansible-playbook -i inventory ansible/01-setup-test-nodes.yml
```

Note: the public IP address will be used for VMs and SNOs, and they can be internal private IPs.

### Create a single SNO cluster
1. Create sno.yml:
```
cp vars/sno.sample.yml vars/sno.yml
```

2. Fill in the sno.yml with values you want. Note: cluster-name & ip & mac address should be unique within the test network. vnc port should be unique on each machine.

3. Run the following command to provision an SNO:
```
ansible-playbook -i inventory ansible/02-create-one-sno.yml
```

### Create many vms at once
This is a step just generate vms. It will NOT create any cluster resources on hub, and it will NOT install SNOs on the vm.

This will generate a `vms-inventory.csv` file with all useful inofrmation for other scripts to pickup and create SNO resources.
The file will be stored on bastion in `hub_config_dir` which set in the all.yml, and it will be using the following format:
```
cluster_name,domain_name,mac_addr,ip,prefix,gateway,machine_cidr,dns_resolver,bmc_addr,bmc_username,bmc_password
```

1. make sure you have `num_vm_disk2` and `num_vm_hdd` set properly in the inventory file
2. Run the following command to create SNOs
```
ansible-playbook -i inventory ansible/02-create-many-vms.yml
```

Note: if using the same invetory settings, modify num_vm_disk2 & num_vm_hdd and re-run the script won't affect any previously created vms (they won't be deleted), and final `vms-inventory.csv` ip address mapping may be updated globally, but each vm's mac address will stay the same.
Note: add `-f 30` to increase concurrency of the task

### Cleanup many vms at once
Run the following command will cleanup the vms created in the previous steps:
```
ansible-playbook -i inventory ansible/03-cleanup-many-vms.yml
```