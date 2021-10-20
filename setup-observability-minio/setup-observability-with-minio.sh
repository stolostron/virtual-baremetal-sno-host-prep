#!/bin/bash
NS=${NS:-open-cluster-management-observability}
# step 1
oc create namespace $NS
# step 2
# NOTE: step 2 not needed for GA builds
oc get secret multiclusterhub-operator-pull-secret -n open-cluster-management -o yaml | oc apply -n $NS -f -
# step 3
oc get secret thanos-object-storage -n $NS -o yaml
# step 4
cat > multiclusterobservability_cr.yaml <<EOF
apiVersion: observability.open-cluster-management.io/v1beta2
kind: MultiClusterObservability
metadata:
  name: observability
spec:
  enableDownsampling: true
  imagePullPolicy: Always
  observabilityAddonSpec:
    enableMetrics: true
    interval: 300
  storageConfig:
    alertmanagerStorageSize: 1Gi
    compactStorageSize: 100Gi
    metricObjectStorage:
      key: thanos.yaml
      name: thanos-object-storage
    receiveStorageSize: 200Gi
    ruleStorageSize: 1Gi
    storageClass: localstorage-sc # upate if needed
    storeStorageSize: 10Gi
EOF
