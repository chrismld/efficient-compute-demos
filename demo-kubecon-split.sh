#!/usr/bin/env bash
set -euo pipefail
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source "${SCRIPTPATH}/lib/utils.sh"
CLUSTER_NAME=$EKS_CLUSTER_NAME
FILEPATH=/tmp/demo-kubecon


#FEATURE_GATES
#value: Drift=true,SpotToSpotConsolidation=true 

## Demo Workflow
## 1.) Deploy a default ec2nodeclass and nodepool
## 2.) Deploy 3 replicas of a sample application to see Karpenter in action
## 3.) Scale to 12
## 4.) Deploy a big Workload
## 5.) Allow consolidation on Graviton instances
## 6.) Allow consolidation on Spot instances
## 7.) Delete Big Pod and observe Spot-to-Spot consolidation
## 8.) Split OD & Spot with a spread within AZs
## 9.) Spot Interruption
## 10.) THAT'S IT!

###### TERMINAL 1
# alias t1='clear; figlet "Kubernetes CLI : K9S" | lolcat; read -n 1; k9s -n default -c deployment'
# t1
######

###### TERMINAL 2
# alias t2='clear; figlet "Viewing EKS Nodes" | lolcat ; read -n 1;  eks-node-viewer -extra-labels=karpenter.sh/nodepool,beta.kubernetes.io/arch,topology.kubernetes.io/zone'
# t2
######
 
###### TERMINAL 3
# alias t3='clear; figlet "Demo Script" | lolcat ; read -n 1;  sh ./demo-kubecon.sh'
# t3
######

###### TERMINAL 4
# alias t4='clear; figlet "Karpenter Logs" | lolcat ; read -n 1; kubectl stern -n karpenter karpenter --tail=1 --highlight message -o json | jq -r '.message | fromjson | "\(.time) \(.level) \(.message)"' | grep -v DEBUG'
# t4
#
# kubectl stern -n karpenter karpenter --tail=1
# kubectl stern -n karpenter karpenter --tail=100 | grep -v DEBUG | egrep  "found provisionable pod(s)|computed new nodeclaim(s) to fit pod(s)|created nodeclaim|registered nodeclaim|launched nodeclaim|initialized nodeclaim|disrupting via consolidation delete|launched nodeclaim|tainted node|deleted node|computed|"
# kubectl stern -n karpenter karpenter --tail=100 | grep -v DEBUG | egrep  "found provisionable pod|computed new nodeclaim|created nodeclaim|registered nodeclaim|launched nodeclaim|initialized nodeclaim|disrupting via consolidation delete|launched nodeclaim|tainted node|deleted node|computed|"
# k stern -n karpenter karpenter --tail=100  | grep -v DEBUG | awk -F "message" '{print "message: " $2}' | cut -d"," -f1
# kubectl stern -n karpenter karpenter --tail=100 --highlight message -o json | jq -r '.message | fromjson | "\(.time) \(.message)"'
######
######

###### TERMINAL 3 (use : to search for other objects)
# k9s -c nodeclaim
###### https://k9scli.io/topics/commands/

mkdir -p $FILEPATH

kubectl delete deployment tiny-workload &> /dev/null || true
kubectl delete deployment big-workload &> /dev/null || true
kubectl delete nodepool default &> /dev/null|| true
kubectl delete nodepool spot &> dev/null || true

clear
echo "Welcome to KubeCon Paris 2024: Karpenter Démo" | lolcat


echo "## 1.) Split OD & Spot with a spread within AZs" | lolcat

cat << EOF > $FILEPATH/node-pool-default.yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
  labels:
    demo: kubecon2024
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h
  template:
    metadata:
      labels:
        demo: kubecon2024
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
        - key: karpenter.k8s.aws/instance-size
          operator: NotIn
          values: ["nano", "micro"]
      nodeClassRef:
        name: default
EOF

cat << EOF > $FILEPATH/node-pool-spot.yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: spot
  labels:
    demo: kubecon2024
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h
  template:
    metadata:
      labels:
        demo: kubecon2024
    spec:
      requirements:
        - key: capacity-spread
          operator: In
          values: ["2", "3"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64", "arm64"]
        - key: karpenter.k8s.aws/instance-size
          operator: NotIn
          values: ["nano", "micro"]
      nodeClassRef:
        name: default
EOF

#kubectl scale deployment tiny-workload --replicas=0
# cmd "cat node-pool-default.yaml"
# cmd "cat node-pool-spot.yaml"
cmd "kubectl apply -f $FILEPATH/node-pool-default.yaml"
kubectl get nodepool default -o yaml | yq '.spec'

cmd "# -> look at the capacity-spread requirement on on-demand capacity"

cmd "kubectl apply -f $FILEPATH/node-pool-spot.yaml"
kubectl get nodepool spot -o yaml | yq '.spec'

cmd "# -> look at the capacity-spread requirement on on-demand capacity"


cat << EOF > $FILEPATH/deployment-default.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tiny-workload
  labels:
    demo: kubecon2024
spec:
  selector:
    matchLabels:
      app: tiny-workload
  replicas: 60
  template:
    metadata:
      labels:
        app: tiny-workload
        demo: kubecon2024
    spec:
      nodeSelector:
        demo: kubecon2024
      containers:
      - image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        name: tiny-workload
        resources:
          requests:
            cpu: "1512m"
            memory: 50Mi
      topologySpreadConstraints:
      - labelSelector:
          matchLabels:
            app: tiny-workload
        maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
      - labelSelector:
          matchLabels:
            app: tiny-workload
        maxSkew: 1
        topologyKey: capacity-spread
        whenUnsatisfiable: DoNotSchedule
EOF

# cmd "cat deployment-default.yaml"
cmd "kubectl apply -f $FILEPATH/deployment-default.yaml"
kubectl get deployment tiny-workload -o yaml | yq -r '.spec.template.spec'

cmd "#-> Look at the topologySpreadConstraints repartition"

clear
cmd "## THAT'S IT!" | lolcat

kubectl delete deployment tiny-workload
kubectl delete nodepool default
kubectl delete nodepool spot

