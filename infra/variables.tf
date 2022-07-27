# Copyright 2021 Agnostiq Inc.
#
# This file is part of Covalent.
#
# Licensed under the GNU Affero General Public License 3.0 (the "License").
# A copy of the License may be obtained with this software package or at
#
#      https://www.gnu.org/licenses/agpl-3.0.en.html
#
# Use of this file is prohibited except in compliance with the License. Any
# modifications or derivative works of this file must retain this copyright
# notice, and modified files must contain a notice indicating that they have
# been altered from the originals.
#
# Covalent is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the License for more details.
#
# Relief from the License may be granted by purchasing a commercial license.

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
