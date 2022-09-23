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
