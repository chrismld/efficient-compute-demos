#!/usr/bin/env bash

set -euo pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

source "${SCRIPTPATH}/lib/utils.sh"

CLUSTER_NAME="karpenter-blueprints"

## Demo Workflow
## - Deploy a default ec2nodeclass and nodepool
## - Deploy a sample application
## - Scale up the deployment
## - Scale down the deployment
## - Move to Spot instances
## - Optimize the CPU requests
## - Move to Graviton instances
## - Optional: Split OD & Spot

function create_manifests() {

cat << EOF > node-pool-default.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
  labels:
    demo: compute-optimization
spec:
  template:
    metadata:
      labels:
        demo: compute-optimization
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      requirements:
        - key: capacity-spread
          operator: In
          values: ["1"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-size
          operator: NotIn
          values: [nano, micro, small, medium]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: "karpenter.k8s.aws/instance-generation"
          operator: Gt
          values: ["2"]
  limits:
    cpu: 1000
    memory: 1000Gi
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 0s
    budgets:
    - nodes: "100%"
EOF

cat << EOF > node-pool-spot.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: spot
  labels:
    demo: compute-optimization
spec:
  template:
    metadata:
      labels:
        demo: compute-optimization
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      requirements:
        - key: capacity-spread
          operator: In
          values: ["2", "3", "4", "5"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: karpenter.k8s.aws/instance-size
          operator: NotIn
          values: [nano, micro, small, medium]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        - key: "karpenter.k8s.aws/instance-generation"
          operator: Gt
          values: ["2"]
  limits:
    cpu: 1000
    memory: 1000Gi
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 0s
    budgets:
    - nodes: "100%"
EOF

cat << EOF > ec2nodeclass-default.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
  labels:
    demo: compute-optimization
spec:
  role: "karpenter-${CLUSTER_NAME}"
  amiSelectorTerms:
    - alias: "bottlerocket@latest"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${CLUSTER_NAME}
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${CLUSTER_NAME}
  tags:
    Name: karpenter.sh/nodepool/default
    NodeType: "efficient-demo"
EOF

cat << EOF > deployment-default.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate-workload
  labels:
    demo: compute-optimization
spec:
  strategy:
    type: Recreate #RollingUpdate
  #  rollingUpdate:
  #    maxUnavailable: 100%
  #    maxSurge: 100%
  selector:
    matchLabels:
      app: inflate-workload
  replicas: 0
  template:
    metadata:
      labels:
        app: inflate-workload
        demo: compute-optimization
    spec:
      nodeSelector:
        demo: compute-optimization
        kubernetes.io/arch: amd64
        karpenter.sh/capacity-type: on-demand
      containers:
      - image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        name: inflate-workload
        resources:
          requests:
            cpu: "1"
            memory: 512M
EOF

cat << EOF >> deployment-default-ts.yaml
      topologySpreadConstraints:
      - labelSelector:
          matchLabels:
            app: inflate-workload
        maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
      - labelSelector:
          matchLabels:
            app: inflate-workload
        maxSkew: 1
        topologyKey: capacity-spread
        whenUnsatisfiable: DoNotSchedule
EOF

}


function deploy_nodepool() {
echo "## - Deploying the default ec2nodeclass and nodepool"

cmd "kubectl apply -f ec2nodeclass-default.yaml; kubectl apply -f node-pool-default.yaml"
cmd "echo ..."
}


function deploy_app() {
local replicas=${1:-10}
echo "## - Deploying the sample application with $replicas replicas"

sed -i "s|replicas: .*|replicas: $replicas|g" deployment-default.yaml
cmd "kubectl apply -f deployment-default.yaml"
cmd "echo ..."
}


function scale_app() {
local replicas=${1:-10}
echo "## - Scaling the application to $replicas replicas"

sed -i "s|replicas: .*|replicas: $replicas|g" deployment-default.yaml
cmd "kubectl scale deployment inflate-workload --replicas=$replicas"
cmd "echo ..."
}


function move_to_spot() {
echo "## - Move to Spot instances"

sed -i 's|"on-demand"|"on-demand","spot"|g' node-pool-default.yaml
sed -i 's|karpenter.sh/capacity-type: on-demand|karpenter.sh/capacity-type: spot|g' deployment-default.yaml

cmd "kubectl apply -f node-pool-default.yaml; kubectl apply -f deployment-default.yaml"
cmd "echo ..."
}


function move_to_graviton() {
echo "## - Move to Graviton instances"

sed -i 's|"amd64"|"amd64","arm64"|g' node-pool-default.yaml
sed -i 's|kubernetes.io/arch: amd64|kubernetes.io/arch: arm64|g' deployment-default.yaml

cmd "kubectl apply -f node-pool-default.yaml; kubectl apply -f deployment-default.yaml"
cmd "echo ..."
}


function optimise() {
echo "## - Optimize the CPU and Memory requests"

sed -i 's|cpu: "1"|cpu: "256m"|g' deployment-default.yaml

cmd "kubectl apply -f deployment-default.yaml"
cmd "echo ..."
}


function od_spot_split() {
local replicas=${1:-10}
echo "## - Split OD & Spot"

sed -i 's|"on-demand","spot"|"on-demand"|g' node-pool-default.yaml
sed -i "s|replicas: .*|replicas: $replicas|g" deployment-default.yaml
sed -i '/.*kubernetes.io\/arch: .*/d; /.*karpenter.sh\/capacity-type: .*/d' deployment-default.yaml
cat deployment-default-ts.yaml >> deployment-default.yaml

cmd "kubectl apply -f node-pool-default.yaml; kubectl apply -f node-pool-spot.yaml"
cmd "kubectl apply -f deployment-default.yaml"
cmd "echo ..."
}


function cleanup() {
echo "## - Cleaning up ..."

kubectl scale deployment inflate-workload --replicas=0
kubectl delete deployment inflate-workload > /dev/null 2>&1 || :
kubectl delete --all nodepool > /dev/null 2>&1 || :
kubectl delete --all ec2nodeclass > /dev/null 2>&1 || :
rm -rf *.yaml
}


function main() {
  clear
  create_manifests
  deploy_nodepool
  deploy_app 10 #Number of replicas
  scale_app 20  #Number of replicas
  scale_app 10  #Number of replicas
  move_to_spot
  optimise
  move_to_graviton
  # od_spot_split 30 #Number of replicas
  cleanup
}

main
