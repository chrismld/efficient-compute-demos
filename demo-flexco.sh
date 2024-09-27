#!/usr/bin/env bash
set -euo pipefail
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source "${SCRIPTPATH}/lib/utils.sh"
CLUSTER_NAME="karpenter-blueprints"

## Demo Workflow
## - Deploy a default nodepool and ec2nodeclass
## - Deploy a sample application to see Karpenter in action
## - Consolidation
## - Split OD & Spot with a spread within AZs
## - Spot Interruption

###### TERMINAL 1
# kube-ops-view
# watch kubectl get nodeclaims
# kl
# ~./sh demo-flexco.sh
######

###### TERMINAL 2
# knodes
######

###### TERMINAL 3 (use : to search for other objects)
# k9s -c nodeclaim
###### https://k9scli.io/topics/commands/

echo "## - Deploy a default nodepool and ec2nodeclass"

cat << EOF > node-pool-default.yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
  labels:
    demo: compute-optimization
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h
  template:
    metadata:
      labels:
        demo: compute-optimization
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand", "spot"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r", "i", "d"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
      nodeClassRef:
        name: default
EOF

cat << EOF > ec2nodeclass-default.yaml
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
  labels:
    demo: compute-optimization
spec:
  role: karpenter-${CLUSTER_NAME}
  amiFamily: AL2
  subnetSelectorTerms:
  - tags:
      karpenter.sh/discovery: ${CLUSTER_NAME}
  securityGroupSelectorTerms:
  - tags:
      karpenter.sh/discovery: ${CLUSTER_NAME}
EOF

# cmd "cat node-pool-default.yaml"
# cmd "cat ec2nodeclass-default.yaml"
cmd "kubectl apply -f node-pool-default.yaml"
cmd "kubectl apply -f ec2nodeclass-default.yaml"

cmd "echo ..."
echo "## - Deploy a sample application to see Karpenter in action"

cat << EOF > deployment-default.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate-workload
  labels:
    demo: compute-optimization
spec:
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
      containers:
      - image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        name: inflate-workload
        resources:
          requests:
            cpu: "256m"
            memory: 512Mi
EOF

# cmd "cat deployment-default.yaml"
cmd "kubectl apply -f deployment-default.yaml"
cmd "kubectl scale deployment inflate-workload --replicas=10"

cmd "echo ..."
echo "## - Split OD & Spot with a spread within AZs"

cat << EOF > node-pool-default.yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
  labels:
    demo: compute-optimization
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h
  template:
    metadata:
      labels:
        demo: compute-optimization
    spec:
      requirements:
        - key: capacity-spread
          operator: In
          values: ["1"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64", "arm64"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r", "i", "d"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
      nodeClassRef:
        name: default
EOF

cat << EOF > node-pool-spot.yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: spot
  labels:
    demo: compute-optimization
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h
  template:
    metadata:
      labels:
        demo: compute-optimization
    spec:
      requirements:
        - key: capacity-spread
          operator: In
          values: ["2", "3", "4", "5"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64", "arm64"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r", "i", "d"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
      nodeClassRef:
        name: default
EOF

cmd "kubectl scale deployment inflate-workload --replicas=0"
# cmd "cat node-pool-default.yaml"
# cmd "cat node-pool-spot.yaml"
cmd "kubectl apply -f node-pool-default.yaml"
cmd "kubectl apply -f node-pool-spot.yaml"

cat << EOF > deployment-default.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate-workload
  labels:
    demo: compute-optimization
spec:
  selector:
    matchLabels:
      app: inflate-workload
  replicas: 30
  template:
    metadata:
      labels:
        app: inflate-workload
        demo: compute-optimization
    spec:
      nodeSelector:
        demo: compute-optimization
      containers:
      - image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        name: inflate-workload
        resources:
          requests:
            cpu: "256m"
            memory: 512Mi
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

# cmd "cat deployment-default.yaml"
cmd "kubectl apply -f deployment-default.yaml"

cmd "echo ..."
echo "## - Spot Interruption"
echo "ec2-spot-interrupter --interactive"

## GO TO ANOTHER TERMINAL AND RUN THAT COMMAND, CHOOSE ONE INSTANCE
## MONITOR IN ANOTHER TAB THE KUBERNETES NODES TO SEE THAT THE INTERRUPTION IS BEING HANDLED
## $>watch kubectl get nodes

cmd "echo ..."
echo "## - THAT'S IT!"

cmd "kubectl scale deployment inflate-workload --replicas=0"
