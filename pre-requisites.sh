#!/bin/bash

curl -sSL -o /tmp/eks-node-viewer_Linux_x86_64 https://github.com/awslabs/eks-node-viewer/releases/download/v0.6.0/eks-node-viewer_Linux_x86_64
sudo chmod 755 /tmp/eks-node-viewer_Linux_x86_64 && sudo mv /tmp/eks-node-viewer_Linux_x86_64 /usr/local/bin/eks-node-viewer

curl -SSL -o /tmp/yq_linux_amd64 https://github.com/mikefarah/yq/releases/download/v4.41.1/yq_linux_amd64
sudo chmod 755 /tmp/yq_linux_amd64 && sudo mv /tmp/yq_linux_amd64 /usr/local/bin/yq

curl -sSL -o /tmp/ec2-spot-interrupter_0.0.10_Linux_amd64.tar.gz https://github.com/aws/amazon-ec2-spot-interrupter/releases/download/v0.0.10/ec2-spot-interrupter_0.0.10_Linux_amd64.tar.gz

echo "alias eks-node-viewer='eks-node-viewer -extra-labels=karpenter.sh/nodepool,beta.kubernetes.io/arch,topology.kubernetes.io/zone'" >> ~/.bashrc

sudo yum install figlet pv -y
gem install lolcat

export EKS_CLUSTER_NAME="kubecon"
eksdemo create cluster $EKS_CLUSTER_NAME --vpc-cidr 10.254.0.0/16 -N 3 --version 1.29
eksdemo install autoscaling-karpenter -c $EKS_CLUSTER_NAME --chart-version v0.34.1 --version v0.34.1