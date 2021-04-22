[comment]: # ( Copyright Contributors to the Open Cluster Management project )

# create iso with AI

make sure you have AI running on your cluster with ACM+Hive

run the following command to create a cluster, and you will have iso ready after awhile:
```
./create.sh CLUSTER_NAME BASE_DOMAIN MACHINE_NETWORK_CIDR [PULL_SECRET_PATH] [SSH_KEY_PATH] [MAC] [IP]
```

If PULL_SECRET_PATH is not given, will ask user to provide one.
If SSH_KEY_PATH is not given, will generate one in ssh folder, and will use existing ones if the ssh folder contains old ssh keys with same cluster name.