#!/bin/bash -e

######## How to use script ########
if [ -z "$3" ]; then
echo 'To use: ./aiWorkload.sh LOOP_NUMBER CLUSTER_NAME BASE_DOMAIN MACHINE_NETWORK_CIDR PULL_SECRET SSH_KEY_PRIV SSH_KEY_PUB'
printf "\n"
echo 'LOOP_NUMBER = Desired number of loop iterations'
echo 'CLUSTER_NAME = Desired base cluster name'
echo 'BASE_DOMAIN = Base domian of cluster'
echo 'MACHINE_NETWORK_CIDR = Machine network CIDR for baremetal SNOs'
echo 'PULL_SECRET = Pull secret, please provide direct path'
echo 'SSH_KEY_PRIV = Private ssh key, please provide direct path'
echo 'SSH_KEY_PUB = Public ssh key, please provide direct path'
printf "\n"
echo 'Note) Assisted Service pod must already be installed.'
printf "\n\n"
exit 1
fi

######## Setting parameters ########
LOOP_NUMBER=$1
CL_NM=$2
BASE_DOMAIN=$3
MACHINE_NETWORK_CIDR=$4
PULL_SECRET=`cat $5 | base64 -w0`
SSH_KEY_PRIV=`cat $6 | base64 -w0`
SSH_KEY_PUB=`cat $7`

echo "Public Key Provided:"
echo $SSH_KEY_PUB
echo "------------------------------"

for i in `seq 1 $LOOP_NUMBER`; do
  ######## Current Deployment Number ########
  printf "\n"
  echo "Beginning Deployment Number $i"
  echo "------------------------------"
  printf "\n"

  ######## Set Date ######## 
  D=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  ######## Set CLUSTER_NAME ########
  CLUSTER_NAME=$CL_NM$i

  ######## Apply generation manuscript ########
  echo "$D : Applying generation manuscript..."
  echo "$D : This may take a second..."
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
echo "Loop complete, thank you for generating ISOs"
echo "through Assisted Service."
echo 'Have a nice day :)'
printf "\n\n"
