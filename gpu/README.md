# GPU-based workloads on EKS with Karpenter

## Deploy a GPU workload

kubectl apply -f karpenter.yaml

kubectl apply -f workload.yaml

watch kubectl get pods,nodeclaims

kubectl describe pod image-processing-app

## Optimize bootstrap time

git clone https://github.com/aws-samples/bottlerocket-images-cache.git
cd bottlerocket-images-cache
./snapshot.sh -r eu-west-1 -s 100 docker.io/christianhxc/image-processing-app:latest

kubectl apply -f karpenter.yaml
kubectl scale deployment image-processing-app --replicas=0
kubectl delete nodeclaim --all

kubectl scale deployment image-processing-app --replicas=1
kubectl describe pod image-processing-app