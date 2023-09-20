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

name = "covalent-eks"
aws_region = "us-east-1"
aws_ecr_repo = "covalent-eks-task"
aws_s3_bucket = "covalent-eks-task"
vpc_cidr = "10.0.0.0/16"
instance_types = ["t2.medium"]
disk_size = 8
min_size = 1
max_size = 6
desired_size = 2
