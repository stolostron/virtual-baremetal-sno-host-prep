#!/bin/bash -e

######## Setting variables ########
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
D=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "Public Key Provided:"
echo $SSH_KEY_PUB

for i in `seq 1 1`; do
  ######## Current Deployment Number ########
  printf "\n"
  echo "Beginning Deployment Number $i"
  echo "------------------------------"
  printf "\n"

  ######## Set CLUSTER_NAME ########
  CLUSTER_NAME=$CL_NM$i

  ######## Apply creation manuscript ########
  echo "$D : Applying creation manuscript..."
  cat manuscript.yaml | \
  sed "s/CLUSTER_NAME/$CLUSTER_NAME/g" | \
  sed "s/BASE_DOMAIN/$BASE_DOMAIN/g" | \
  sed "s~MACHINE_NETWORK_CIDR~$MACHINE_NETWORK_CIDR~g" | \
  sed "s~SSH_KEY_PUB~'$SSH_KEY_PUB'~g" | \
  sed "s~PULL_SECRET~'$PULL_SECRET'~g" | \
  sed "s~SSH_KEY_PRIV~'$SSH_KEY_PRIV'~g" | \
  oc apply -f -
  echo "$D : Manuscript applied!!"

  ######## Current Deployment Number ########
  printf "\n"
  echo "------------------------------"
  echo "Deployment Number $i Completed"
done

printf "\n\n\n"
echo "Loop complete, thank you for flying"
echo "ISO Generation Airlines."
echo 'Have a nice day :)'
