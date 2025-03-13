# Scaling workloads with KEDA and Karpenter

## TODO

Setup the k6 tests in the Kubernetes cluster
Create a real-world k6 test

## Tools setup

```
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda 
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
helm install k6-operator grafana/k6-operator 
```

## Demo - Phase I

kubectl apply -f nodepool.yaml
kubectl apply -f workload.yaml
kubectl apply -f graviton.yaml
kubectl apply -f x86.yaml


eks-node-viewer --node-selector karpenter.sh/nodepool=multiarch
watch kubectl top nodes -l karpenter.sh/nodepool=multiarch

watch kubectl get hpa

```
kubectl delete configmap k6-test-scripts
kubectl create configmap k6-test-scripts \
 --from-file=manifests/load-test.js \
 --from-file=manifests/perf-test-x86.js \
 --from-file=manifests/perf-test-graviton.js
```

kubectl delete job load-test-1
kubectl apply -f manifests/k6-load-test.yaml
kubectl logs -l k6_cr=load-test -f

echo "Show main.go"
echo "Show ServiceMonitor, ScaledObject"
echo "Go back to the terminal 1"

## Demo - Phase II

kubectl delete scaledobject montecarlo-pi-latency
kubectl scale deployment montecarlo-pi --replicas=0

kubectl scale deployment montecarlo-pi-graviton --replicas=17
kubectl scale deployment montecarlo-pi-x86 --replicas=17

kubectl apply -f manifests/perf-test-x86.yaml

kubectl apply -f manifests/perf-test-graviton.yaml


watch kubectl top nodes -l karpenter.sh/nodepool=x86
watch kubectl top nodes -l karpenter.sh/nodepool=graviton

eks-node-viewer --extra-labels karpenter.sh/nodepool
eks-node-viewer --node-selector karpenter.sh/nodepool=x86
eks-node-viewer --node-selector karpenter.sh/nodepool=graviton

echo "Show multiarch pipeline"
echo "Show buildspec.yml, buildspec-manifest.yml"
echo "Go back to the terminal 2"

echo "Change the nodeSelector to request Spot"

kubectl apply -f manifests/workload.yaml

echo "Use Amazon Q to analyze the results"

```
Help me do the math or at least explain in a simple way the price-performance improvements you get with Graviton. I've done a performance test comparing both x86 and Graviton, and here's what I got:

For x86, the estimated monthly payment will be $559.238, and these are the results I got from the k6 performance test:

[K6 PERFORMANCE TEST RESULTS FOR x86]

[/K6 PERFORMANCE TEST RESULTS FOR x86]

For Graviton, the estimated monthly payment will be $498.035, and these are the results I got from the k6 performance test:

[K6 PERFORMANCE TEST RESULTS FOR Graviton]

[/K6 PERFORMANCE TEST RESULTS FOR Graviton]
```

cat <<EOF | kubectl apply -f -

EOF

## Demo Story

### Act I - Why?
* How to build Efficient EKS clusters? Cost-optimized and performance compliant ... automatically!
* Autoscaling is the answer, and in Kubernetes you need to do it both for the worklaod and nodes.
* Karpenter takes care of the nodes, and KEDA of the workloads. They both work in tandem.

### Act II - Preparing
* Setup the cluster, verify we have Karpenter and KEDA controllers running.
* Deploy Prometheus
* Deploy the Service Monitor to scrape metrics from the Monte Carlo PI service
* Delloy the ScaledObject to scale the service based on latency using KEDA

### Act III - Elasticity
* Deploy a Monte Carlo PI service, instrumented to expose latency metrics for Prometheus
* Run a small load test using k6 to see KEDA scaling the workload, and Karpenter scaling the nodes.

### Act IV - Price Performance with Graviton

The aim is to take the application to use almost 100% CPU, the compare the throughput and latency we get.

* Set a static number of replicas as we'd like to reduce any variance (due to scaling out) in the performance test.
* Duplicate the workload to use Graviton instances (highlight that thanks to Karpenter it's easy to migrate).
* Run performance tests with k6 in parallel to compare results
* While waiting for the test to finish, explain multi-arch builds for Graviton.
* Analyze results, and explain the math about why Graviton offers better price-peformance.

### Act V - Deep EC2 discounts with Spot
* Update the Graviton nodepool to use Spot instances
* Wait for Karpenter consolidation to kick-in to replace On-Demand with Spot instances
* While waiting, explain what Spot is, how it works, the trade-offs, and how Karpenter automates this.
* Compare the price of Graviton Spot with x86 On-Demand

### Act VI - Conclusions
* KEDA helps you build efficient workloads
* Karpenter helps you build efficient EKS clusters ... therefore, doubling the efficiency.
* When doing performance tests, don't focus oly on CPU utilization, and make sure you have a clear mission what you'd like to test.
* KEDA + Karpenter + Graviton + Spot is a deal breaker for efficiency, sustainability, and cost-optimization.
* Here are the demo resources we used: https://github.com/chrismld/efficient-compute-demos