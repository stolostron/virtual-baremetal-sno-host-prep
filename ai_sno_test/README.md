# AI SNO TEST

## Setup VM Hosts

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
host-name-of-vm-hosts-01 offset=1
host-name-of-vm-hosts-02 offset=2
host-name-of-vm-hosts-03 offset=3
host-name-of-vm-hosts-01 offset=4
EOF
```
   Offset will be used to generate a public IP of the vmhost. (offset + public_ip_network_node_start)

3. Run the following command to setup vmhost:
```
ansible-playbook -i inventory ansible/01-setup-test-nodes.yml
```

Note: the public IP address will be used for VMs and SNOs.

## Create an SNO cluster
1. Create sno.yml:
```
cp vars/sno.sample.yml vars/sno.yml
```

2. Fill in the sno.yml with values you want. Note: cluster-name & ip & mac address should be unique within the test network. vnc port should be unique on each machine.

3. Run the following command to setup vmhost:
```
ansible-playbook -i inventory ansible/02-create-one-sno.yml
```
