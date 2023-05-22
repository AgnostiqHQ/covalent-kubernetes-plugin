import os
import pytest
from kubernetes import client, config

import subprocess
import threading


class Command:
    """
    Enables to run subprocess commands in a different thread
    with TIMEOUT option!
    Based on jcollado's solution:
    http://stackoverflow.com/questions/1191374/subprocess-with-timeout/4825933#4825933
    """

    def __init__(self, cmd):
        self.cmd = cmd
        self.process = None

    def run(self, timeout=0, **kwargs):
        def target(**kwargs):
            self.process = (
                subprocess.Popen(  # pylint: disable=consider-using-with
                    self.cmd, **kwargs
                )
            )
            self.process.communicate()

        thread = threading.Thread(target=target, kwargs=kwargs)
        thread.start()

        thread.join(timeout)
        if thread.is_alive():
            self.process.terminate()
            thread.join()

        return self.process.returncode

def is_minikube_running() -> bool:
    try:
        cmd = Command("minikube status")
        returncode = cmd.run(timeout=3, shell=True)
        if returncode == 0:
            config.load_kube_config(
                config_file=os.getenv("KUBECONFIG", default="~/.kube/config")
            )
            client.CoreV1Api().list_namespaced_pod("default")
            return True
        return False
    except (config.config_exception.ConfigException, ConnectionRefusedError):
        return False

def has_k8s():
    if os.environ.get("SKIP_K8S_TESTS", None) == "true":
        return False
    current_os = os.environ.get("GITHUB_MATRIX_OS")
    current_python = os.environ.get("GITHUB_MATRIX_PYTHON")
    if (
        current_os is not None
        and current_os != "ubuntu-latest"
        or current_python is not None
        and current_python != "3.9"
    ):
        return False
    return is_minikube_running()


def k8s_test(f):
    mark = pytest.mark.kubernetes
    skip = pytest.mark.skipif(
        not has_k8s(), reason="kubernetes is unavailable or skipped"
    )
    return mark(skip(f))

