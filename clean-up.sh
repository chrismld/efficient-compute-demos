#!/usr/bin/env bash
set -euo pipefail
set -x
kubectl delete deployment inflate-workload > /dev/null 2>&1 || :
kubectl delete --all nodeclaim > /dev/null 2>&1 || :
kubectl delete --all nodepool > /dev/null 2>&1 || :
kubectl delete --all ec2nodeclass > /dev/null 2>&1 || :
rm -rf *.yaml