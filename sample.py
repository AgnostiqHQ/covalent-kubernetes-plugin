import covalent as ct
from covalent_kubernetes_plugin.k8s import KubernetesExecutor

local_k8s_executor = KubernetesExecutor(
    k8s_context="minikube",
    vcpu="100m",
    memory="500Mi",
    data_store="/tmp"
)

# Run on a local cluster
@ct.electron(executor=local_k8s_executor)
def join_words(a, b):
    return ", ".join([a, b])

# Run on the cloud
@ct.electron(executor=local_k8s_executor)
def excitement(a):
    return f"{a}!"

# Construct a workflow
@ct.lattice
def simple_workflow(a, b):
    phrase = join_words(a, b)
    return excitement(phrase)

# Dispatch the workflow
dispatch_id = ct.dispatch(simple_workflow)("Hello", "World")
print(dispatch_id)