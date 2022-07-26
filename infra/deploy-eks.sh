#!/bin/bash

set -eu -o pipefail

TFSTATE=$HOME/.cache/covalent/terraform.tfstate

terraform init
terraform apply -auto-approve -state=$TFSTATE

export KUBECONFIG=`terraform output | awk -F '=' '/kubeconfig/ {print $2}'`
cluster_name=`terraform output | awk -F '=' '/cluster_name/ {print $2}'`
autoscaler_role=`terraform output | awk -F '=' '/eks_ca_iam_role_arn/ {print $2}'`
sed "s/%CLUSTERNAME%/$cluster_name/g;s/%ASROLE%/$autoscaler_role/g" templates/cluster_autoscaler_tmeplate.yml > cluster_autoscaler.yml

kubectl apply -f cluster_autoscaler.yml
echo "Please apply the following to your environment:"
echo "export KUBECONFIG=`terraform output | awk -F '=' '/kubeconfig/ {print $2}'`"
echo
echo "You may view your resources using"
echo " > kubectl get nodes"
