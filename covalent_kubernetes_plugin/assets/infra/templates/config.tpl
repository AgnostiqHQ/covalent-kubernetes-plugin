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

apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${certificate_data}
    server: ${cluster_endpoint}
  name: arn:aws:eks:${aws_region}:${account_id}:cluster/${cluster_name}
contexts:
- context:
    cluster: arn:aws:eks:${aws_region}:${account_id}:cluster/${cluster_name}
    user: arn:aws:eks:${aws_region}:${account_id}:cluster/${cluster_name}
  name: arn:aws:eks:${aws_region}:${account_id}:cluster/${cluster_name}
current-context: arn:aws:eks:${aws_region}:${account_id}:cluster/${cluster_name}
kind: Config
preferences: {}
users:
- name: arn:aws:eks:${aws_region}:${account_id}:cluster/${cluster_name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1
      interactiveMode: Never
      command: aws
      args:
        - --region
        - ${aws_region}
        - eks
        - get-token
        - --cluster-name
        - ${cluster_name}
