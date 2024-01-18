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

variable "name" {
  default     = "covalent-eks"
  description = "Name used to prefix AWS resources"
}

variable "aws_region" {
  default     = "us-east-1"
  description = "Region in which the cluster is deployed"
}

variable "aws_ecr_repo" {
  default     = "covalent-eks-task"
  description = "ECR repository used for task images"
}

variable "aws_s3_bucket" {
  default     = "covalent-eks-task"
  description = "S3 bucket used for file staging"
}

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "VPC CIDR range"
}

variable "instance_types" {
  default     = ["t2.medium"]
  description = "List of node instance types"
}

variable "disk_size" {
  default     = 8
  description = "Disk size per node"
}

variable "min_size" {
  default     = 1
  description = "Minimum number of worker nodes"
}

variable "max_size" {
  default     = 6
  description = "Maximum number of worker nodes"
}

variable "desired_size" {
  default     = 2
  description = "Desired number of worker nodes"
}
