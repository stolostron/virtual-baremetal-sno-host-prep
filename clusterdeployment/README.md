# SNO Cluster Deployment

## Prerequisite
You must have your VM hosts setup according to https://github.com/taragu/acm-ai-sno-tools/tree/main/ai_sno_test.

## Create SNO clusters
First, edit the [`inventory-manifest.csv` file](https://github.com/open-cluster-management/acm-ai-sno-tools/blob/main/clusterdeployment/inventory-manifest.csv) with the hardware information of your VM hosts.

Then provide the addons you would like to enable or disabled in all VM hosts in the `addon.json` file.

On the Bastion machine, run script [`create-resources.sh`](https://github.com/open-cluster-management/acm-ai-sno-tools/blob/main/clusterdeployment/create-resources.sh) to create the SNO clusters:
```sh
./create-resources.sh pull/secret/path private-key-path
```

After the script is completed creating and applying resources, directories will be created for each SNO clusters, with the directory name being the cluster name.

You can download the `kubeconfig` of a SNO cluster with:
```sh
./getkubeconfigs.sh cluster-name cluster-directory
```
The `kubeconfig` file will be downloaded to `cluster-directory/kubeconfig`.


## Debug
After `create-resources.sh` script is exited without errors, resources will be created on the VM hosts. You can monitor the progress with the number of agents deployed and the number of provisioned BMH:
```sh
while true; do
    date
    echo "agent num: "
    oc get agent --all-namespaces | wc -l
    echo "bmh provisioned num:"
    oc get bmh --all-namespaces | grep provisioned | wc -l
    sleep 5
done
```