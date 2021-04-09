#!/bin/bash -e

CURR_FILE_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# ./install.sh [bundle-image] [pv-ai-postgres] [pv-ai-bucket]
if [ -z $1 ]; then
echo 'bundle-image not set, will use default: '
AI_BUNDLE_IMAGE=quay.io/hanqiuzh/test-images:ai-index
else
AI_BUNDLE_IMAGE=$1
fi

if [ -z $2 ]; then
echo 'pv of postgres not set, will use default'
PV_AI_POSTGRES=assisted-installer-local-pv-postgres
else
PV_AI_POSTGRES=$2
fi

if [ -z $3 ]; then
echo 'pv of bucket not set, will use default'
PV_AI_BUCKET=assisted-installer-local-pv-bucket
else
PV_AI_BUCKET=$3
fi


echo "detect available worker nodes for pv if needed"
WORKER_NODE_COUNT=`oc get nodes  -lnode-role.kubernetes.io/worker="" | grep -v NAME | wc -l`
if [ "$WORKER_NODE_COUNT" -gt 0 ] ; then
USE_NODE_NAME=`oc get nodes  -lnode-role.kubernetes.io/worker="" | grep -v NAME | cut -d' ' -f1 | head -n1`
else
USE_NODE_NAME=`oc get nodes  -lnode-role.kubernetes.io/worker="" | grep -v NAME |`
echo 'no worker node detected, will use the first node'
fi
NODE_HOST_NAME=`oc get node $USE_NODE_NAME -ojsonpath="{.metadata.labels['kubernetes\.io/hostname']}"`


if [ "$PV_AI_POSTGRES" = assisted-installer-local-pv-postgres ]; then
echo "create pv for postgres on node $USE_NODE_NAME , hostname: $NODE_HOST_NAME"
cat "$CURR_FILE_PATH/deploy/local-pv-postgres.yaml" | sed "s/PV_AI_POSTGRES/$PV_AI_POSTGRES/g" | sed "s/NODE_HOST_NAME/$NODE_HOST_NAME/g" | oc apply -f -
fi

if [ "$PV_AI_BUCKET" = assisted-installer-local-pv-bucket ]; then
echo "create pv for bucket on node $USE_NODE_NAME , hostname: $NODE_HOST_NAME"
cat "$CURR_FILE_PATH/deploy/local-pv-bucket.yaml" | sed "s/PV_AI_BUCKET/$PV_AI_BUCKET/g" | sed "s/NODE_HOST_NAME/$NODE_HOST_NAME/g" | oc apply -f -
fi


echo 'create namespace of assisted-installer'
oc get ns assisted-installer || oc create ns assisted-installer 

echo 'create pvcs'
cat "$CURR_FILE_PATH/deploy/pvc-postgres.yaml" | sed "s/PV_AI_POSTGRES/$PV_AI_POSTGRES/g" | oc apply -f -
cat "$CURR_FILE_PATH/deploy/pvc-bucket.yaml" | sed "s/PV_AI_BUCKET/$PV_AI_BUCKET/g" | oc apply -f -


echo 'create catalogsource'
cat "$CURR_FILE_PATH/deploy/catalogsource.yaml" | sed "s~AI_BUNDLE_IMAGE~$AI_BUNDLE_IMAGE~g" | oc apply -f -

echo 'check if the cluster is baremetal'
USE_ONPREM=1
oc get cm cluster-config-v1 -n kube-system | grep baremetal || USE_ONPREM=0
if [ "$USE_ONPREM" = 1 ]; then
echo 'use onprem'
oc apply -f "$CURR_FILE_PATH/deploy/subscription-onprem.yaml"
else
echo 'use baremetal'
oc apply -f "$CURR_FILE_PATH/deploy/subscription-bm.yaml"
fi

echo 'sleep 30 before check pods'
sleep 30
oc get po -n assisted-insatller
PODS_COUNT=`oc get po -n assisted-insatller | grep -i running | wc -l`
if [ "$PODS_COUNT" -lt 3 ]; then
    echo "oops expected 3 pods, but only get $PODS_COUNT running pods, something can be wrong"
else 
    echo "congratulations. AI is ready!"
fi


echo 'setup configmap for 4.8 images'
oc patch configmap -n assisted-installer  --type merge  assisted-service-config -p '{"data":{"OPENSHIFT_VERSIONS":"{\"4.8\":{\"display_name\":\"4.8\",\"release_image\":\"registry.ci.openshift.org/ocp/release:4.8.0-0.nightly-2021-04-05-174735\",\"rhcos_image\":\"https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.7/4.7.0/rhcos-4.7.0-x86_64-live.x86_64.iso\",\"rhcos_version\":\"47.83.202102090044-0\",\"support_level\":\"production\"}}"}}'

echo 'expose metal-ui'
oc expose svc -n assisted-installer ocp-metal-ui

echo 'fix proxy url'
oc get cm -n assisted-installer ocp-metal-ui  -oyaml | sed 's/assisted-service-assisted-installer.apps.han-new.rdu2.scalelab.redhat.com:8090/assisted-service:8090/g' | oc apply -f -

echo 'restart assisted-installer pods'
oc delete po -n assisted-installer --all

echo 'pause mch'
oc annotate -n open-cluster-management `oc get mch -oname -n open-cluster-management | head -n1` mch-pause=true --overwrite=true

echo 'enable hive feature-gate'
oc patch hiveconfig hive  --type merge -p '{"spec":{"targetNamespace":"hive","logLevel":"debug","featureGates":{"custom":{"enabled":["AlphaAgentInstallStrategy"]},"featureSet":"Custom"}}}'

echo 'add baremetal role for assisted-service'
oc create clusterrole assisted-baremetal-host --verb='get,list,watch,create,update,patch,delete' --resource=baremetalhosts.metal3.io,baremetalhosts.metal3.io/status,clusterdeployments.hive.openshift.io,clusterdeployments.hive.openshift.io/finalizers,clusterdeployments.hive.openshift.io/status

oc create clusterrolebinding assisted-baremetal-host \
  --clusterrole=assisted-baremetal-host \
  --serviceaccount=assisted-installer:default