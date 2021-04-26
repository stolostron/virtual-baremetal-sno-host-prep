# SNO Cluster Deployment

## Prerequisite
You must have your VM hosts setup according to https://github.com/taragu/acm-ai-sno-tools/tree/main/ai_sno_test.

## Create SNO clusters
First, edit the [`inventory-manifest.csv` file](https://github.com/open-cluster-management/acm-ai-sno-tools/blob/main/clusterdeployment/inventory-manifest.csv) with the hardware information of your VM hosts. The first row of the file indicates the columns. Please keep this line and start a new line with the inventories.

Then provide the addons you would like to enable or disabled in all VM hosts in the `addon.json` file.

On the Bastion machine, run script [`create-resources.sh`](https://github.com/open-cluster-management/acm-ai-sno-tools/blob/main/clusterdeployment/create-resources.sh) to create the SNO clusters:
```sh
./create-resources.sh pull/secret/path private-key-path
```

If the script is exited without errors, manifests should be created for each inventory. The generated manifests are under `/clusters`. Under `/clusters`, directories will be created for each SNO clusters, with the directory name being the cluster name. Before continuing to the next step, we recommend spot checking the manifests of one of the generated clusters.

You can now run the script to apply these manifests for all clusters:
```sh
./apply-resources.sh clusters/
```
You can specify two optional parameters to this script: number of concurrent applies (default value is 1000) and the number of seconds (default value is 0) to wait in between each batch of concurrent applies. A monitoring script that measures the progress of the installation will also be started in the background. Its output will be saved in `managedsnocluster.csv`.

## Debug

After resources are applied, you can check the progress of the Assisted Installer installation of the SNO cluster by checking events:
```sh
curl `oc get infraenv -n cluster-name cluster-name \
  -ojsonpath='{.status.isoDownloadURL}' | \
  sed 's~downloads/image~events~g'`
```

If the SNO cluster is created successfully, you can download the `kubeconfig` of a SNO cluster with:
```sh
./getkubeconfigs.sh cluster-name cluster-directory
```
The `kubeconfig` file will be downloaded to `cluster-directory/kubeconfig`.