# Generate Inventory

1. Fill in exclude_hosts with hostnames you want to exclude. 
   hostname should be complete path.
   ```
   cp exclude_hosts.sample exclude_hosts
   vi exclude_hosts
   ```

2. Run the following command:
   ```
   ./generate_inventory.sh cloudname [ssh_key]
   ```
   cloudname is the id of cloud name in scale lab, e.g. `cloud01`
   ssh_key is the key you want to use

   Note: if you want to setup publickey on remote cluster, use the following env var before running the script:
   ```
   GENERATE_INVENTORY_COPY_PUBLIC_KEY=true ./generate_inventory.sh cloudname [ssh_key]
   ```
