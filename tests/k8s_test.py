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

import os
import re
import subprocess

import covalent as ct
import pytest
from kubernetes import config

from covalent_kubernetes_plugin import KubernetesExecutor
from tests.conftest import k8s_test


@pytest.fixture(scope="session")
def minikube_env_variables():
    old_environ = dict(os.environ)
    output = subprocess.check_output(
        ["minikube", "-p", "minikube", "docker-env"]
    )
    export_re = re.compile('export ([A-Z_]+)="(.*)"\\n')
    export_pairs = export_re.findall(output.decode("UTF-8"))
    for k, v in export_pairs:
        os.environ[k] = v

    yield

    os.environ.clear()
    os.environ.update(old_environ)

@pytest.fixture
def load_kube_config():
    config.load_kube_config(os.getenv("KUBECONFIG", default="~/.kube/config"))

@k8s_test
@pytest.mark.usefixtures("load_kube_config")
def test_k8s_executor():
    local_k8s_executor = KubernetesExecutor(
        k8s_context="minikube"
    )

    @ct.electron(executor=local_k8s_executor)
    def join_words(a, b):
        return ", ".join([a, b])

    @ct.electron(executor=local_k8s_executor)
    def excitement(a):
        return f"{a}!"

    @ct.lattice
    def simple_workflow(a, b):
        phrase = join_words(a, b)
        return excitement(phrase)

    dispatch_id = ct.dispatch(simple_workflow)("Hello", "World")
    result = ct.get_result(dispatch_id, wait=True)
    print(result.status)
