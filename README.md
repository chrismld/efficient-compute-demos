# AWS Efficient Compute Demos

Welcome! This repository containts pre-baked demos to showcase how to build for efficiency using AWS compute services. You can use these demos for a conference talk, or simply to play around with services such as Amazon EKS with Karpenter.

All demos are built with the intention of automating the story using bash scripts, and avoid wasting time or making errors when copy/past commands for a demo. Each bash script is using another bash library to simulate you're typing in the console. You can find this library at the `/lib` folder.

For instance, you could include within your demo bash script a command to create a file such as a Kubernetes `deployment` manifest, and simulate you're typing the `apply` command like this:

```
cmd "kubectl apply -f deployment.yaml"
```

PR's are always welcome, and feel free to reuse or create your own demo based on the ones you find in this repository.

## How to run a demo?

Simply run the bash script, and press enter every time you want to continue with the next step. 

For instance, you could start a demo like this:

```
sh demo-karpenter.sh
```

## Demos

Here's the list of demos you can find in this repository:

[**1. Running efficient compute Amazon EKS clusters using Karpenter, Spot, and Graviton:** ](/demo-karpenter.sh) This demo has been used to showcase the value proposition of Karpenter, and how you can make the cluster more efficient (and cost-optimized) using Graviton and Spot. Here's a recording of the demo at the [DevOps Barcelona conference](https://www.youtube.com/watch?v=LLcF6IO6BQw&t=1096s).

[**2. Karpenter Consolidation, On-Demand/Spot split, and Spot interruptions:** ](/demo-flexco.sh) This demo is a simplified version of the previous demo, with the addition of showing how Spot interruptions are being handled with Karpenter.

[**3. Karpenter Consolidation, On-Demand/Spot split, and Spot interruptions for KubeCon Paris:** ](/demo-kubecon.sh) This demo was used at the KubeCon Paris 2024, and it's showcasing the value proposition of Karpenter by deploying a workload little by little, and then enable Consolidation to optimize the cluster.

## References

- [Karpenter Blueprints for Amazon EKS](https://github.com/aws-samples/karpenter-blueprints) to create the clusters used for the Karpenter demos.
- [eksdemo](https://github.com/awslabs/eksdemo) used for creating the Amazon EKS cluster for the Kubecon demos ([pre-requisites.sh](pre-requisites.sh))
