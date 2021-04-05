# Install Assisted Installer with ACM

## Note: This tool will be deprecated once ACM bundled with Assisted Installer

Please make sure you have done `oc login` on your hub correctly.

Please make sure you are using the latest ACM snapshot where clusterdeployment crd contains AI support.

## To Install
Use the following command to install

```
./install.sh [bundle-image] [pv-ai-postgres] [pv-ai-bucket]
```

bundle-image is the bundle of assisted service, this is optional, and will use the latest image we have bundled.

pv-ai-postgres & pv-ai-bucket if not given, will use local, and will select one of the available node (worker preferred) for pv settings. Will defaultly allocate 100 GB.


## To Delete
Use the following command to delete

```
./delete.sh
```

