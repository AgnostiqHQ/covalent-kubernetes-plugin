&nbsp;

<div align="center">

<img src="https://raw.githubusercontent.com/AgnostiqHQ/covalent/master/doc/source/_static/covalent_readme_banner.svg" width=150%>

&nbsp;

</div>

## Covalent Kubernetes Plugin

To use the plugin:

1. Run the command `aws eks describe-cluster --name covalent-cluster` and note down the cluster.endpoint and cluster.certificateAuthority.data values.
2. Run the command `aws eks get-token --cluster-name covalent-cluster` and note down the status.token value.
3. Authentication code:
```
from covalent_kubernetes_plugin.k8s import BearerAuth
from covalent_kubernetes_plugin.k8s import KubernetesExecutor

certificate = ""
endpoint = "https://66AEA523CA0D5284DBA05C15F9BB97DC.sk1.us-west-2.eks.amazonaws.com"
token = ""

auth = BearerAuth(token = token, cluster_endpoint = endpoint, cluster_certificate = certificate)


executor = KubernetesExecutor(auth = auth, s3_bucket_name = "covalent-tmp", ecr_repo_name = "covalent", docker_base_image = "python:3.8-slim-buster",
                           eks_cluster_name = "covalent-cluster",  poll_freq= 10)
```


