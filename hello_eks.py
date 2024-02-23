import os

import covalent as ct
from covalent.executor import KubernetesExecutor

k8s_config = os.environ["KUBECONFIG"] or os.path.join(os.environ["HOME"], ".kube/config")

# Change these before running!
region = "us-east-1"
account = ""
cluster_name = ""  # Corresponds to 'name' in .tfvars
aws_s3_bucket = ""  # Corresponds to 'aws_s3_bucket' in .tfvars

k8s_context = f"arn:aws:eks:{region}:{account}:cluster/{cluster_name}-cluster"
registry = f"{account}.dkr.ecr.{region}.amazonaws.com"
data_store = f"s3://{aws_s3_bucket}"

eks_executor = KubernetesExecutor(
    k8s_config_file=k8s_config,
    k8s_context=k8s_context,
    registry=registry,
    data_store=data_store,
    region=region,
)


@ct.electron(executor=eks_executor)
def join_words(a, b):
    return ", ".join([a, b])


@ct.electron
def excitement(a):
    return f"{a}!"


@ct.lattice
def simple_workflow(a, b):
    phrase = join_words(a, b)
    return excitement(phrase)


dispatch_id = ct.dispatch(simple_workflow)("Hello", "world")
print(dispatch_id)
