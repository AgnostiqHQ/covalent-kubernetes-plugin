&nbsp;

<div align="center">

<img src="https://raw.githubusercontent.com/AgnostiqHQ/covalent-kubernetes-plugin/main/assets/covalent-k8s-banner.jpg" width=150%>

&nbsp;

</div>

## Covalent Kubernetes Plugin

Covalent is a Pythonic workflow tool used to execute tasks on advanced computing hardware. This executor plugin interfaces Covalent with [Kubernetes](https://kubernetes.io/) clusters. In order for workflows to be deployable, users must be authenticated to an existing Kubernetes cluster. Users can view their Kubernetes configuration file and validate the connection using the commands

```
kubectl config view
kubectl get nodes
```

Users who simply wish to test the plugin on minimal infrastructure should skip to the deployment instructions in the following sections.

### Installation

To use this plugin with Covalent, simply install it using `pip`:

```
pip install covalent-kubernetes-plugin
```

Users can optionally enable support for AWS Elastic Kubernetes Service using

```
pip install covalent-kubernetes-plugin[aws]
```

You will also need to install [Docker](https://docs.docker.com/get-docker/) to use this plugin.

### Configuration

The following shows a reference of a Covalent [configuration](https://covalent.readthedocs.io/en/latest/how_to/config/customization.html):

```
[executors.k8s]
base_image = "python:3.8-slim-bullseye"
k8s_config_file = "/home/user/.kube/config"
k8s_context = "minikube"
registry = "localhost"
registry_credentials_file = ""
data_store = "/tmp"
vcpu = "500m"
memory = "1G"
cache_dir = "/home/user/.cache/covalent"
poll_freq = 10
```

This describes a configuration for a minimal local deployment with images and data stores also located on the local machine.

### Example workflow

Next, interact with the Kubernetes backend via Covalent by declaring an executor class object and attaching it to an electron:

```
import covalent as ct
from covalent_kubernetes_plugin.k8s import KubernetesExecutor

local_k8s_executor = KubernetesExecutor(
    k8s_context="minikube"
    vcpu="100m",
    memory="500Mi"
)

eks_executor = KubernetesExecutor(
    k8s_context=user@covalent-eks-cluster.us-east-1.eksctl.io,
    image_repo="covalent-eks-task",
    registry="<account_id>.dkr.ecr.us-east-1.amazonaws.com",
    data_store="s3://<bucket_name>/<file_path>/",
    vcpu="2.0",
    memory="4G"
)

# Run on a local cluster
@ct.electron(executor=local_k8s_executor)
def join_words(a, b):
    return ", ".join([a, b])

# Run on the cloud
@ct.electron(executor=eks_executor)
def excitement(a):
    return f"{a}!"

# Construct a workflow
@ct.lattice
def simple_workflow(a, b):
    phrase = join_words(a, b)
    return excitement(phrase)

# Dispatch the workflow
dispatch_id = ct.dispatch(simple_workflow)("Hello", "World")

```

For more information about how to get started with Covalent, check out the project [homepage](https://github.com/AgnostiqHQ/covalent) and the official [documentation](https://covalent.readthedocs.io/en/latest/).

## Local deployment with minikube

First, install `kubectl` as well as `minikube` following the instructions [here](https://kubernetes.io/docs/tasks/tools/). One or both of these may be available through your system's package manager.

### Cluster deployment

Next, create a basic `minikube` cluster:

```
minikube start
```

From here you can view the UI using the command `minikube dashboard` which should open a page in your browser.

Before deploying the job, you will need to mount the Covalent cache directory so the Covalent server can communicate with the task container:

```
minikube mount ~/.cache/covalent:/data
```

If you experience a `Connection refused` error, ensure that the subnet used by minikube is whitelisted in your firewall. If you use `iptables`, you can use these commands:

```
iptables -A INPUT -s 192.168.49.0/24 -j ACCEPT
iptables-save
```

### Task deployment

Next, deploy the test job using the command

```
kubectl apply -f infra/sample_job.yaml
```

which should return `job.batch/covalent-k8s-test created`. You can view the status move from pending to succeeded on the dashboard. After some time, query the status of the job with

```
kubectl describe jobs/covalent-k8s-test
```

which returns

```
Name:             test
Namespace:        default
Selector:         controller-uid=eaa319c3-4440-4411-b178-6289398cdb6a
Labels:           controller-uid=eaa319c3-4440-4411-b178-6289398cdb6a
                  job-name=covalent-k8s-test
Annotations:      <none>
Parallelism:      1
Completions:      1
Completion Mode:  NonIndexed
Start Time:       Thu, 21 Jul 2022 14:25:55 -0400
Completed At:     Thu, 21 Jul 2022 14:26:06 -0400
Duration:         11s
Pods Statuses:    0 Active (0 Ready) / 1 Succeeded / 0 Failed
Pod Template:
  Labels:  controller-uid=eaa319c3-4440-4411-b178-6289398cdb6a
           job-name=test
  Containers:
   test:
    Image:        hello-world:latest
    Port:         <none>
    Host Port:    <none>
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
Events:
  Type    Reason            Age   From            Message
  ----    ------            ----  ----            -------
  Normal  SuccessfulCreate  112s  job-controller  Created pod: test-5fs64
  Normal  Completed         101s  job-controller  Job completed
```

You are now ready to use the Covalent Kubernetes Plugin with your minikube cluster!

### Reference configuration

The steps above generated the following authentication and configuration settings:

```
> kubectl config view --minify
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /home/user/.minikube/ca.crt
    extensions:
    - extension:
        last-update: Sun, 24 Jul 2022 16:09:01 EDT
        provider: minikube.sigs.k8s.io
        version: v1.26.0
      name: cluster_info
    server: https://192.168.59.100:8443
  name: minikube
contexts:
- context:
    cluster: minikube
    extensions:
    - extension:
        last-update: Sun, 24 Jul 2022 16:09:01 EDT
        provider: minikube.sigs.k8s.io
        version: v1.26.0
      name: context_info
    namespace: default
    user: minikube
  name: minikube
current-context: minikube
kind: Config
preferences: {}
users:
- name: minikube
  user:
    client-certificate: /home/user/.minikube/profiles/minikube/client.crt
    client-key: /home/user/.minikube/profiles/minikube/client.key
```

### Cleanup

When you are done using your cluster, delete it:

```
minikube delete
```


## AWS Elastic Kubernetes Service deployment with Terraform

This section assumes you have already downloaded and configured the AWS CLI tool with an IAM user who has permissions to create an EKS cluster. To get started, [download and install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli).

### Cluster deployment

You can edit the input variables by copying the file `infra/defaults.tfvars` to `infra/.tfvars` and editing the contents.

Next, run the following:

```
make deploy
```

It may take 15 to 20 minutes to deploy this infrastructure. Note that AWS charges \$0.10 per hour for EKS clusters and EC2 instances [vary in price](https://aws.amazon.com/ec2/pricing/). **Running this command will cost money on AWS.**

To view the Kubernetes dashboard, update your `KUBECONFIG` environment variable as instructed in the deployment output, run `kubectl proxy` and then navigate to the [dashboard](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#!/login). It may take some time for resources to initially appear.

### Adding users

Initially only the user who created the cluster will be able to access it. To view the auth config map, run

```
kubectl -n kube-system get configmap aws-auth -o yaml
```

We can add another IAM user `newuser` as a cluster administrator using

```
kubectl -n kube-system edit configmap aws-auth
```

and inserting the following entry:

```
data:
  mapUsers: |
    - userarn: arn:aws:iam::<account_id>:user/newuser
      username: newuser
      groups:
      - system:masters
```

The IAM user should not need any additional permissions.

### Task deployment

Make sure the context is properly set, check with

```
kubectl config get-contexts
```

If it is set to anything other than the EKS cluster, execute

```
kubectl config use-context <my-cluster-name>
```

You can now deploy a job using the same method as you did with `minikube`.

To view the status of jobs, run

```
kubectl describe jobs --selector=job-name=test
```

### Reference configuration

The steps above generated the following authentication and configuration settings:

```
> kubectl get configmap -n kube-system aws-auth -o yaml
apiVersion: v1
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::<account_id>:role/covalent-eks-cluster-nodegroup-NodeInstanceRole-1VH95YLZKOX47
      username: system:node:{{EC2PrivateDNSName}}
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::<account_id>:role/covalent-eks-cluster-nodegroup-NodeInstanceRole-1NDG6XAZXQKJM
      username: system:node:{{EC2PrivateDNSName}}
  mapUsers: |
    - userarn: "arn:aws:iam::<account_id>:user/newuser"
      username: newuser
      groups:
      - system:masters
kind: ConfigMap

> kubectl config view --minify
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://0A418BB2CE053D6E26E86072C9B2BAFF.yl4.us-east-1.eks.amazonaws.com
  name: arn:aws:eks:us-east-1:836486484887:cluster/covalent-eks-cluster
contexts:
- context:
    cluster: arn:aws:eks:us-east-1:836486484887:cluster/covalent-eks-cluster
    user: arn:aws:eks:us-east-1:836486484887:cluster/covalent-eks-cluster
  name: arn:aws:eks:us-east-1:836486484887:cluster/covalent-eks-cluster
current-context: arn:aws:eks:us-east-1:836486484887:cluster/covalent-eks-cluster
kind: Config
preferences: {}
users:
- name: arn:aws:eks:us-east-1:836486484887:cluster/covalent-eks-cluster
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      args:
      - --region
      - us-east-1
      - eks
      - get-token
      - --cluster-name
      - covalent-eks-cluster
      command: aws
      env: null
      interactiveMode: IfAvailable
      provideClusterInfo: false
```

### Cleanup

When you are done, delete the cluster:

```
make clean
```

## Release Notes

Release notes are available in the [Changelog](https://github.com/AgnostiqHQ/covalent-kubernetes-plugin/blob/main/CHANGELOG.md).

## Citation

Please use the following citation in any publications:

> W. J. Cunningham, S. K. Radha, F. Hasan, J. Kanem, S. W. Neagle, and S. Sanand.
> *Covalent.* Zenodo, 2022. https://doi.org/10.5281/zenodo.5903364

## License

Covalent is licensed under the Apache License 2.0. See the [LICENSE](https://github.com/AgnostiqHQ/covalent/blob/master/LICENSE) file or contact the [support team](mailto:support@agnostiq.ai) for more details.
