#!/usr/bin/env bash
set -euo pipefail
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source "${SCRIPTPATH}/lib/utils.sh"
CLUSTER_NAME="karpenter-blueprints-self"
IAM_ROLE_NAME="karpenter-karpenter-blueprints-self"

## Demo Workflow
## - Deploy a default nodepool and ec2nodeclass
## - Deploy a sample application to see Karpenter in action
## - Optimize the CPU and Memory requests => will produce underutilized nodes
## - Move to Graviton instances
## - Move to Spot instances
## - Split OD & Spot

echo "## - Deploy a default nodepool and ec2nodeclass"

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
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-size
          operator: NotIn
          values: [nano, micro, small, medium, large]
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

cat << EOF > ec2nodeclass-default.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
  labels:
    demo: compute-optimization
spec:
  role: "${IAM_ROLE_NAME}"
  amiSelectorTerms:
    - alias: "al2023@latest"
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

# cmd "cat node-pool-default.yaml"
# cmd "cat ec2nodeclass-default.yaml"
cmd "kubectl apply -f ec2nodeclass-default.yaml"
cmd "kubectl apply -f node-pool-default.yaml"

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
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-size
          operator: NotIn
          values: [nano, micro, small, medium, large]
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
        demo: compute-optimization
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
        demo: compute-optimization
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
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand","spot"]
        - key: karpenter.k8s.aws/instance-size
          operator: NotIn
          values: [nano, micro, small, medium, large]
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
        demo: compute-optimization
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
          values: [nano, micro, small, medium, large]
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
          values: [nano, micro, small, medium, large]
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
  strategy:
    type: Recreate
EOF

# cmd "cat deployment-default.yaml"
cmd "kubectl apply -f deployment-default.yaml"
cmd "kubectl scale deployment inflate-workload --replicas=0"

echo "Cleaning up ..."
kubectl delete deployment inflate-workload > /dev/null 2>&1 || :
kubectl delete --all nodepool > /dev/null 2>&1 || :
kubectl delete --all ec2nodeclass > /dev/null 2>&1 || :
rm -rf *.yaml