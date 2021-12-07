# Generate Inventory
The scripts only works with RH scale lab, and will require the inventory.json file be downloaded first.

1. Fill in exclude_hosts with hostnames you want to exclude. 
   hostname should be complete path.
   ```
   cp exclude_hosts.sample exclude_hosts
   vi exclude_hosts
   ```

2. Review and modify the `scalelab_machine_info` file, and modify the number of machine & default nic of each host type. Example like the following:
   ```
   keyword,num_hdd,num_disk2,num_disk2_tb,nic1_name
   ``` 
   - `keyword` will be used to match the given host name, and to tell what type of machine it is. e.g. for `e26-h09-000-r640` hostname, we will match r640, and thus will use r640 settings. hostname which doesn't contain any keywords will be skipped, and results will be in `tmp/skipped_hosts`.
   - `num_hdd`,`num_disk2`,`num_disk2_tb`, when generating a inventory file, how many SNOs we want to create on the host. `num_hdd` is the number of SNOs we will use default disk, and `num_disk2` is number of SNOs we will use for extra disks which are smaller than 1TB. `num_disk2_tb` will be used if extra disk greater than 1TB. If both `num_disk2` and `num_disk2_tb` are set to 0, will disable the disk2 for that machine.
   - `nic1_name` will be used to search for the NIC we will use to do the expirement. If cannot search the target NIC, the machine will not be added to the final inventory. Failed results will be generated in `tmp/skipped_hosts`.


3. Run the following command:
   ```
   ./generate_inventory.sh cloudname cloudinventory.json [ssh_key]
   ```
   `cloudname` is the id of cloud name in scale lab, e.g. `cloud01`

   `cloudinventory.json` is the json file we can download from the scale lab.
   sample format like the following:
   ```
   {
    "nodes": [
        {
            "arch": "x86_64",
            "cpu": "2",
            "disk": "20",
            "mac": [
                ...
            ],
            "memory": "1024",
            ...
        },...
    ]
   ```

   `ssh_key` is the key you want to use when running ssh command against the hosts.

   Note: if you want to setup publickey on remote cluster, use the following env var before running the script:
   ```
   GENERATE_INVENTORY_COPY_PUBLIC_KEY=true ./generate_inventory.sh cloudname [ssh_key]
   ```

3. inventory file will be generated at `tmp/inventory/${cloudname}.local.complete`