&nbsp;

<div align="center">

<img src="https://raw.githubusercontent.com/AgnostiqHQ/covalent/master/doc/source/_static/covalent_readme_banner.svg" width=150%>

&nbsp;

</div>

## Covalent Kubernetes Plugin

To use the plugin:

1. Mount a shared folder on minikube node using the command `minikube mount ~/tmp-dir:/host`
```
import covalent as ct
from covalent_kubernetes_plugin.k8s import KubernetesExecutor

local_k8s_executor = KubernetesExecutor(docker_base_image = "python:3.8-slim-buster",
                             poll_freq= 10,s3_bucket=False,k8_context = "minikube")

eks_k8s_executor = KubernetesExecutor(docker_base_image = "python:3.8-slim-buster",
                             poll_freq= 10,s3_bucket=True,k8_context = "poojith@covalent-cluster.us-west-2.eksctl.io")


# Construct tasks as "electrons"
@ct.electron(executor=local_k8s_executor)
def join_words(a, b):
    return ", ".join([a, b])

@ct.electron(executor = eks_k8s_executor)
def excitement(a):
    return f"{a}!"

# Construct a workflow of tasks
@ct.lattice
def simple_workflow(a, b):
    phrase = join_words(a, b)
    return excitement(phrase)

# Dispatch the workflow
dispatch_id = ct.dispatch(simple_workflow)("Hello", "World")

```


