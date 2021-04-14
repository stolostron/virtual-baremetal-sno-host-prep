#!/bin/bash -e

######## Passing arguments ########
if [ -z "$3" ]; then
echo 'To use: ./aiWorkload.sh CLUSTER_NAME BASE_DOMAIN MACHINE_NETWORK_CIDR PULL_SECRET SSH_KEY_PRIV SSH_KEY_PUB'
exit 1
fi

CL_NM=$1
BASE_DOMAIN=$2
MACHINE_NETWORK_CIDR=$3
PULL_SECRET=`cat $4 | base64 -w0`
SSH_KEY_PRIV=`cat $5 | base64 -w0`
SSH_KEY_PUB=`cat $6`

echo "Public Key Provided:"
echo $SSH_KEY_PUB

for i in `seq 1 1`; do
  ######## Current Deployment Number ########
  printf "\n"
  echo "Beginning Deployment Number $i"
  echo "------------------------------"
  printf "\n\n\n"

  ######## Set CLUSTER_NAME ########
  CLUSTER_NAME=$CL_NM$i

  ######## Apply creation manuscript ########
  echo "Creating Cluster Deployments..."
  
  echo "Applying creation manuscript..."
  cat manuscript.yaml | \
  sed "s/CLUSTER_NAME/$CLUSTER_NAME/g" | \
  sed "s/BASE_DOMAIN/$BASE_DOMAIN/g" | \
  sed "s~MACHINE_NETWORK_CIDR~$MACHINE_NETWORK_CIDR~g" | \
  sed "s~SSH_KEY_PUB~'$SSH_KEY_PUB'~g" | \
  sed "s~PULL_SECRET~'$PULL_SECRET'~g" | \
  sed "s~SSH_KEY_PRIV~'$SSH_KEY_PRIV'~g" | \
  oc apply -f -

#  for j in `seq 1 30`; do
#    export DISCOVERY_ISO_URL=`oc get installenv $CLUSTER_NAME -n $CLUSTER_NAME -ojsonpath='{.status.isoDownloadURL}'`
#    if [ ! -z $DISCOVERY_ISO_URL ]; then
#      echo "ISO retrieved!"
#      break
#    fi
#  done
#  echo "ISO download: $DISCOVERY_ISO_URL"

  ######## Generate rootfs ########
#  echo "Generating rootfs..."
#  export ASSISTED_SERVICE=`oc get route -n assisted-installer assisted-service -ojsonpath='{.spec.host}'`
#  export OPENSHIFT_VERSION=4.8
#  export ROOTFS_ISO_URL="http://$ASSISTED_SERVICE/api/assisted-install/v1/boot-files?file_type=rootfs.img&openshift_version=$OPENSHIFT_VERSION"
#  echo "Rootfs download: $ROOTFS_ISO_URL"

  ######## Current Deployment Number ########
  printf "\n\n\n"
  echo "------------------------------"
  echo "Deployment Number $i Completed"
done

printf "\n\n\n"
echo "Loop complete, thank you for flying"
echo "ISO Generation Airlines."
echo 'Have a nice day :)'
