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

## Demo manifests

kubectl apply -f nodepool.yaml
kubectl apply -f workload.yaml
kubectl apply -f graviton.yaml
kubectl apply -f x86.yaml


eks-node-viewer --node-selector karpenter.sh/nodepool=general-purpose
watch kubectl top nodes -l karpenter.sh/nodepool=general-purpose

watch kubectl get scaledobject,hpa,pods

```
kubectl create configmap k6-test-scripts \
 --from-file=manifests/load-test.js \
 --from-file=manifests/perf-test-x86.js \
 --from-file=manifests/perf-test-graviton.js

```

```
kubectl apply -f manifests/k6-load-test.yaml
kubectl logs -l k6_cr=load-test --tail=-1

kubectl apply -f manifests/k6-perf-test.yaml
kubectl logs -l k6_cr=perf-test --tail=-1
```

k6 run -e MY_HOSTNAME=$(kubectl get service montecarlo-pi --output=jsonpath='{.status.loadBalancer.ingress[0].hostname}') --address="" load-test.js

cat <<EOF | kubectl apply -f -
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

----------

kubectl delete scaledobject montecarlo-pi-latency
kubectl scale deployment montecarlo-pi --replicas=0

kubectl scale deployment montecarlo-pi-graviton --replicas=17
kubectl scale deployment montecarlo-pi-x86 --replicas=17

k6 run -e MY_HOSTNAME=$(kubectl get service montecarlo-pi-x86 --output=jsonpath='{.status.loadBalancer.ingress[0].hostname}') --address="" perf-test.js
k6 run -e MY_HOSTNAME=$(kubectl get service montecarlo-pi-graviton --output=jsonpath='{.status.loadBalancer.ingress[0].hostname}') --address="" perf-test.js

watch kubectl top nodes -l karpenter.sh/nodepool=x86
watch kubectl top nodes -l karpenter.sh/nodepool=graviton

eks-node-viewer --node-selector karpenter.sh/nodepool=x86
eks-node-viewer --node-selector karpenter.sh/nodepool=graviton

### Analyze Performance Test Results with Amazon Q

```
Help me do the math or at least explain in a simple way the price-performance improvements you get with Graviton. I've done a performance test comparing both x86 and Graviton, and here's what I got:

For x86, the estimated monthly payment will be $559.238, and these are the results I got from the k6 performance test:

[K6 PERFORMANCE TEST RESULTS FOR x86]

[/K6 PERFORMANCE TEST RESULTS FOR x86]

For Graviton, the estimated monthly payment will be $498.035, and these are the results I got from the k6 performance test:

[K6 PERFORMANCE TEST RESULTS FOR Graviton]

[/K6 PERFORMANCE TEST RESULTS FOR Graviton]
```

## Demo Story

### Act I - Why?
* How to build Efficient EKS clusters? Cost-optimized and performance compliant ... automatically!
* Autoscaling is the answer, and in Kubernetes you need to do it both for the worklaod and nodes.
* Karpenter takes care of the nodes, and KEDA of the workloads. They both work in tandem.

### Act II - Preparing
* Setup the cluster, verify we have Karpenter and KEDA controllers running.

### Act III - Elasticity
* Deploy a Monte Carlo PI service, instrumented to expose latency metrics for Prometheus
* Deploy Prometheus
* Deploy the Service Monitor to scrape metrics from the Monte Carlo PI service
* Delloy the ScaledObject to scale the service based on latency using KEDA
* Run a small load test using k6 to see KEDA scaling the workload, and Karpenter scaling the nodes.
* (Optional) If time permits or it's a recoding session, we can see how KEDA scales down the workload when there's not load.

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