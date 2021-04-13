#!/bin/bash -e

######## Passing arguments ########
if [ -z "$3" ]; then
echo 'To use: ./aiWorkload.sh CLUSTER_NAME BASE_DOMAIN MACHINE_NETWORK_CIDR PULL_SECRET SSH_KEY_PRIV SSH_KEY_PUBLIC'
exit 1
fi

CL_NM=$1
BASE_DOMAIN=$2
MACHINE_NETWORK_CIDR=$3
PULL_SECRET=$4
SSH_KEY_PRIV=$5
SSH_KEY_PUBLIC=$6

SSH_KEY_PUB=`cat $SSH_KEY_PUBLIC`
echo "Public key provided: $SSH_KEY_PUB"

for i in `seq 1 100`; do
  ######## Current Deployment Number ########
  printf "\n"
  echo "Beginning Deployment Number $i"
  echo "------------------------------"
  printf "\n\n\n"

  ######## Set CLUSTER_NAME ########
  CLUSTER_NAME=$CL_NM$i

  ######## Generate ISO Steps ########
  echo "Generating ISO download URL..."

  echo "Creating project..."
  oc new-project $CLUSTER_NAME \
  || echo '...creation failed, step skipped.'

  echo "Creating pull secret..." 
  oc create secret generic assisted-deployment-pull-secret -n $CLUSTER_NAME \
  --from-file=.dockerconfigjson=$PULL_SECRET \
  --type=kubernetes.io/dockerconfigjson \
  || echo '...creation failed, step skipped.'

  echo "Creating private key secret..."
  oc create secret generic assisted-deployment-ssh-private-key -n $CLUSTER_NAME \
  --from-file=ssh-privatekey=$SSH_KEY_PRIV \
  --type=Opaque \
  || echo '...creation failed, step skipped.'

  # echo "Applying cluster deployment..."
  echo "Applying cluster deployment and install environment..."
  cat clusterDep.yaml | \
  sed "s/CLUSTER_NAME/$CLUSTER_NAME/g" | \
  sed "s/BASE_DOMAIN/$BASE_DOMAIN/g" | \
  sed "s~MACHINE_NETWORK_CIDR~$MACHINE_NETWORK_CIDR~g" | \
  sed "s~SSH_KEY_PUB~'$SSH_KEY_PUB'~g" | \
  oc apply -f -

  echo "Process complete, retrieving ISO download url..."
  for j in `seq 1 30`; do
    export DISCOVERY_ISO_URL=`oc get installenv $CLUSTER_NAME -n $CLUSTER_NAME -ojsonpath='{.status.isoDownloadURL}'`
    if [ ! -z $DISCOVERY_ISO_URL ]; then
      echo "ISO retrieved!"
      break
    fi
  done
  echo "ISO download: $DISCOVERY_ISO_URL"

  ######## Generate rootfs ########
  echo "Generating rootfs..."
  export ASSISTED_SERVICE=`oc get route -n assisted-installer assisted-service -ojsonpath='{.spec.host}'`
  export OPENSHIFT_VERSION=4.8
  export ROOTFS_ISO_URL="http://$ASSISTED_SERVICE/api/assisted-install/v1/boot-files?file_type=rootfs.img&openshift_version=$OPENSHIFT_VERSION"
  echo "Rootfs download: $ROOTFS_ISO_URL"

  ######## Current Deployment Number ########
  printf "\n\n\n"
  echo "------------------------------"
  echo "Deployment Number $i Completed"
done

printf "\n\n\n"
echo "Loop complete, thank you for flying"
echo "ISO Generation Airlines."
echo 'Have a nice day :)'
