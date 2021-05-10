# Generate Inventory
The scripts only works with RH scale lab, and will require the inventory.json file be downloaded first.

1. Fill in exclude_hosts with hostnames you want to exclude. 
   hostname should be complete path.
   ```
   cp exclude_hosts.sample exclude_hosts
   vi exclude_hosts
   ```

2. Run the following command:
   ```
   ./generate_inventory.sh cloudname cloudinventory.json [ssh_key]
   ```
   cloudname is the id of cloud name in scale lab, e.g. `cloud01`
   cloudinventory.json is the file we can download from the scale lab.
   ssh_key is the key you want to use

   Note: if you want to setup publickey on remote cluster, use the following env var before running the script:
   ```
   GENERATE_INVENTORY_COPY_PUBLIC_KEY=true ./generate_inventory.sh cloudname [ssh_key]
   ```

3. To add offset for each vmhost, run the following:

   ```
   LINE_COUNT=0; IFS='';  while read -r line; do echo "$line offset=$LINE_COUNT" >> tmp/inventory.complete; LINE_COUNT=$((LINE_COUNT+1)) ; done < tmp/inventory
   ```