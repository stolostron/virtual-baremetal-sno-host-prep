#!/bin/bash -e

CURR_FILE_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

if [ -z "$3" ]; then
echo 'usage: ./create.sh CLUSTER_NAME BASE_DOMAIN MACHINE_NETWORK_CIDR [PULL_SECRET_PATH] [SSH_KEY_PATH] [MAC_ADDRESS] [STATIC_IP] [IP_PREFIX] [IP_GATEWAY] [DNS_RESOLVER]'
exit 1
fi
CLUSTER_NAME=$1
BASE_DOMAIN=$2
MACHINE_NETWORK_CIDR=$3

if [ -z "$5" ]; then
if [ -d "$CURR_FILE_PATH/ssh/default" ]; then
echo 'using existing ssh'
SSH_KEY_PATH="$CURR_FILE_PATH/ssh/default/id_rsa"
else
echo 'creating ssh-key for login'
mkdir -p "$CURR_FILE_PATH/ssh/default"
ssh-keygen -q -t rsa -N '' -f "$CURR_FILE_PATH/ssh/default/id_rsa" <<<y 2>&1 >/dev/null
SSH_KEY_PATH="$CURR_FILE_PATH/ssh/default/id_rsa"
fi
else
SSH_KEY_PATH=$5
fi

SET_STATIC_IP=0

if [ ! -z "$9" ]; then
SET_STATIC_IP=1
MAC_ADDRESS=$6
STATIC_IP=$7
IP_PREFIX=$8
IP_GATEWAY=$9
DNS_RESOLVER=${10}
fi

if [ -z "$4" ]; then
read -p "please provide pull-secret file path (absolute is better): " PULL_SECRET_PATH
else
PULL_SECRET_PATH=$4
fi

echo "ssh key path: $SSH_KEY_PATH"
SSH_PUBLIC_KEY=`cat "${SSH_KEY_PATH}.pub"`
echo "public key: $SSH_PUBLIC_KEY"

echo "create namespace"
oc create ns $CLUSTER_NAME ||  echo 'failed to create, skipping'
 
echo "create private key secret"
oc create secret generic assisted-deployment-ssh-private-key -n $CLUSTER_NAME \
--from-file="$SSH_KEY_PATH" --type=Opaque || echo 'failed to create, skipping'

echo "create pull secret"
oc create secret generic assisted-deployment-pull-secret -n $CLUSTER_NAME \
--from-file=.dockerconfigjson="$PULL_SECRET_PATH" \
--type=kubernetes.io/dockerconfigjson ||  echo 'failed to create, skipping'

cat clusterdeployment.yaml | sed "s/CLUSTER_NAME/$CLUSTER_NAME/g" | \
sed "s/BASE_DOMAIN/$BASE_DOMAIN/g" | \
sed "s~MACHINE_NETWORK_CIDR~$MACHINE_NETWORK_CIDR~g" | \
sed "s~SSH_PUBLIC_KEY~'$SSH_PUBLIC_KEY'~g" | \
oc apply -f -

if [ "$SET_STATIC_IP" -eq 1 ]; then 

cat nmstate.yaml | sed "s/CLUSTER_NAME/$CLUSTER_NAME/g" | \
sed "s~MAC_ADDRESS~'$MAC_ADDRESS'~g" | \
sed "s~STATIC_IP~'$STATIC_IP'~g" | \
sed "s~IP_PREFIX~$IP_PREFIX~g" | \
sed "s~IP_GATEWAY~'$IP_GATEWAY'~g" | \
sed "s~DNS_RESOLVER~'$DNS_RESOLVER'~g" | \
oc apply -f -

cat installenv-nmstate.yaml | sed "s/CLUSTER_NAME/$CLUSTER_NAME/g" | \
sed "s~SSH_PUBLIC_KEY~'$SSH_PUBLIC_KEY'~g" | \
oc apply -f -
else
cat installenv.yaml | sed "s/CLUSTER_NAME/$CLUSTER_NAME/g" | \
sed "s~SSH_PUBLIC_KEY~'$SSH_PUBLIC_KEY'~g" | \
oc apply -f -
fi
