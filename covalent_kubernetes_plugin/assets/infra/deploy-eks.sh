#!/bin/bash
#
# Copyright 2021 Agnostiq Inc.
#
# This file is part of Covalent.
#
# Licensed under the Apache License 2.0 (the "License"). A copy of the
# License may be obtained with this software package or at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Use of this file is prohibited except in compliance with the License.
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Deploy EKS cluster for Covalent Kubernetes Plugin

set -eu -o pipefail

echo "Validating dependencies..."

terraform --version &> /dev/null
if [ $? -ne 0 ] ; then
  echo "You need to install Terraform"
  echo "https://learn.hashicorp.com/tutorials/terraform/install-cli"
  exit 1
fi

jq --version &> /dev/null
if [ $? -ne 0 ] ; then
  echo "You need to install jq"
  echo "https://stedolan.github.io/jq/download/"
  exit 1
fi

STATEPATH=$HOME/.cache/covalent
mkdir -p $STATEPATH
TFSTATE=$STATEPATH/terraform.tfstate

echo -e "\nDeploying core infrastructure..."

terraform init
terraform apply -auto-approve -state=$TFSTATE
outputs=`terraform output -json -state=$TFSTATE`

export KUBECONFIG=`jq -r '.kubeconfig.value' <<< $outputs`

cluster_name=`jq -r '.cluster_name.value' <<< $outputs`
autoscaler_role=`jq -r '.eks_ca_iam_role_arn.value' <<< $outputs`
sed "s|%CLUSTERNAME%|$cluster_name|;s|%ASROLE%|$autoscaler_role|" < cluster_autoscaler.yml > cluster_autoscaler.yml

echo -e "\nEnabling node autoscaler..."

kubectl apply -f cluster_autoscaler.yml

echo -e "\nDeploying Kubernetes dashboard..."

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.5/aio/deploy/recommended.yaml
kubectl apply -f eks-admin-service-account.yaml

token=`kubectl -n kube-system describe secret $(kubectl -n kube-system get secret |
  grep eks-admin | awk '{print $1}')`

echo
echo "Created Kubernetes cluster: $cluster_name"
echo "Please apply the following to your environment:"
echo "export KUBECONFIG=$KUBECONFIG"
echo
echo "You may view your resources using"
echo " > kubectl get nodes"
echo
echo "View the Kubernetes dashboard at http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#!/login"
echo "Token: $token"
