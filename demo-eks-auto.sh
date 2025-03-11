#!/usr/bin/env bash
set -euo pipefail
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source "${SCRIPTPATH}/lib/utils.sh"

## Demo Workflow
## - Deploy a sample application to see EKS Auto in action
## - Optimize the CPU and Memory requests => will produce underutilized nodes
## - Move to Graviton instances
## - Move to Spot instances
## - Split OD & Spot

cmd "echo ..."
echo "## - Deploy a sample application to see EKS Auto in action"

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
        kubernetes.io/arch: amd64
        karpenter.sh/capacity-type: on-demand
      containers:
      - image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        name: inflate-workload
        resources:
          requests:
            cpu: "1"
            memory: 512M
  strategy:
    type: Recreate
EOF

# cmd "cat deployment-default.yaml"
cmd "kubectl apply -f deployment-default.yaml"
cmd "kubectl scale deployment inflate-workload --replicas=10"

cmd "echo ..."
echo "## - Move to Graviton instances"

cat << EOF > node-pool-default.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  labels:
    app.kubernetes.io/managed-by: eks
  name: general-purpose
spec:
  disruption:
    budgets:
    - nodes: 10%
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
  template:
    metadata: {}
    spec:
      expireAfter: 336h
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: default
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
      - key: eks.amazonaws.com/instance-category
        operator: In
        values:
        - c
        - m
        - r
      - key: eks.amazonaws.com/instance-generation
        operator: Gt
        values:
        - "4"
      - key: kubernetes.io/arch
        operator: In
        values:
        - amd64
        - arm64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      terminationGracePeriod: 24h0m0s
EOF

cmd "kubectl apply -f node-pool-default.yaml"


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
  replicas: 10
  template:
    metadata:
      labels:
        app: inflate-workload
        demo: compute-optimization
    spec:
      nodeSelector:
        kubernetes.io/arch: arm64
        karpenter.sh/capacity-type: on-demand
      containers:
      - image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        name: inflate-workload
        resources:
          requests:
            cpu: "1"
            memory: 512M
  strategy:
    type: Recreate
EOF

# cmd "cat deployment-default.yaml"
cmd "kubectl apply -f deployment-default.yaml"

cmd "echo ..."
echo "## - Optimize the CPU and Memory requests => will produce underutilized nodes"

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
  replicas: 10
  template:
    metadata:
      labels:
        app: inflate-workload
        demo: compute-optimization
    spec:
      nodeSelector:
        kubernetes.io/arch: arm64
        karpenter.sh/capacity-type: on-demand
      containers:
      - image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        name: inflate-workload
        resources:
          requests:
            cpu: "256m"
            memory: 512Mi
  strategy:
    type: Recreate
EOF

# cmd "cat deployment-default.yaml"
cmd "kubectl apply -f deployment-default.yaml"

cmd "echo ..."
echo "## - Move to Spot instances"

cat << EOF > node-pool-default.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  labels:
    app.kubernetes.io/managed-by: eks
  name: general-purpose
spec:
  disruption:
    budgets:
    - nodes: 10%
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
  template:
    metadata: {}
    spec:
      expireAfter: 336h
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: default
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
        - spot
      - key: eks.amazonaws.com/instance-category
        operator: In
        values:
        - c
        - m
        - r
      - key: eks.amazonaws.com/instance-generation
        operator: Gt
        values:
        - "4"
      - key: kubernetes.io/arch
        operator: In
        values:
        - amd64
        - arm64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      terminationGracePeriod: 24h0m0s
EOF

# cmd "cat node-pool-default.yaml"
cmd "kubectl apply -f node-pool-default.yaml"

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
  replicas: 10
  template:
    metadata:
      labels:
        app: inflate-workload
        demo: compute-optimization
    spec:
      nodeSelector:
        kubernetes.io/arch: arm64
        karpenter.sh/capacity-type: spot
      containers:
      - image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        name: inflate-workload
        resources:
          requests:
            cpu: "256m"
            memory: 512Mi
  strategy:
    type: Recreate
EOF

# cmd "cat deployment-default.yaml"
cmd "kubectl apply -f deployment-default.yaml"

cmd "echo ..."
echo "## - Split OD & Spot"

cat << EOF > node-pool-default.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  labels:
    app.kubernetes.io/managed-by: eks
  name: general-purpose
spec:
  disruption:
    budgets:
    - nodes: 10%
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
  template:
    metadata: {}
    spec:
      expireAfter: 336h
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: default
      requirements:
      - key: capacity-spread
          operator: In
          values: ["1"]
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
      - key: eks.amazonaws.com/instance-category
        operator: In
        values:
        - c
        - m
        - r
      - key: eks.amazonaws.com/instance-generation
        operator: Gt
        values:
        - "4"
      - key: kubernetes.io/arch
        operator: In
        values:
        - amd64
        - arm64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      terminationGracePeriod: 24h0m0s
EOF

cat << EOF > node-pool-spot.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  labels:
    app.kubernetes.io/managed-by: eks
  name: spot
spec:
  disruption:
    budgets:
    - nodes: 10%
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
  template:
    metadata: {}
    spec:
      expireAfter: 336h
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: default
      requirements:
      - key: capacity-spread
          operator: In
          values: ["2", "3", "4", "5"]
      - key: capacity-spread
          operator: In
          values: ["1"]
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - spot
      - key: eks.amazonaws.com/instance-category
        operator: In
        values:
        - c
        - m
        - r
      - key: eks.amazonaws.com/instance-generation
        operator: Gt
        values:
        - "4"
      - key: kubernetes.io/arch
        operator: In
        values:
        - amd64
        - arm64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      terminationGracePeriod: 24h0m0s
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
  strategy:
    type: Recreate
EOF

# cmd "cat deployment-default.yaml"
cmd "kubectl apply -f deployment-default.yaml"
cmd "kubectl scale deployment inflate-workload --replicas=0"

echo "Cleaning up ..."
kubectl delete deployment inflate-workload > /dev/null 2>&1 || :

cat << EOF > node-pool-default.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  labels:
    app.kubernetes.io/managed-by: eks
  name: general-purpose
spec:
  disruption:
    budgets:
    - nodes: 10%
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
  template:
    metadata: {}
    spec:
      expireAfter: 336h
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: default
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
      - key: eks.amazonaws.com/instance-category
        operator: In
        values:
        - c
        - m
        - r
      - key: eks.amazonaws.com/instance-generation
        operator: Gt
        values:
        - "4"
      - key: kubernetes.io/arch
        operator: In
        values:
        - amd64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      terminationGracePeriod: 24h0m0s
EOF

kubectl apply -f node-pool-default.yaml

rm -rf *.yaml