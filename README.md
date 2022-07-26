&nbsp;

<div align="center">

<img src="https://raw.githubusercontent.com/AgnostiqHQ/covalent/master/doc/source/_static/covalent_readme_banner.svg" width=150%>

&nbsp;

</div>

## Covalent Kubernetes Plugin

Covalent is a Pythonic workflow tool used to execute tasks on advanced computing hardware. This executor plugin interfaces Covalent with [Kubernetes](https://kubernetes.io/) clusters. In order for workflows to be deployable, users must be authenticated to an existing Kubernetes cluster. Users can view their Kubernetes configuration file and validate the connection using the commands

```
kubectl config view
kubectl get nodes
```

Users who simply wish to test the plugin on minimal infrastructure should skip to the deployment instructions in the following sections.

To use this plugin with Covalent, simply install it using `pip`:

```
pip install covalent-kubernetes-plugin
```

Users can optionally enable support for AWS Elastic Kubernetes Service using

```
pip install covalent-kubernetes-plugin[aws]
```

The following shows a reference of a Covalent [configuration](https://covalent.readthedocs.io/en/latest/how_to/config/customization.html):

```
[executors.k8s]
base_image = "python:3.8-slim-bullseye"
k8s_config_file = "/home/will/.kube/config"
k8s_context = "minikube"
registry = "localhost"
registry_credentials_file = ""
data_store = "/tmp"
vcpu = "500m"
memory = "1G"
cache_dir = "/home/will/.cache/covalent"
poll_freq = 10
```

This describes a configuration for a minimal local deployment with images and data stores also located on the local machine.

<!--1. Mount a shared folder on minikube node using the command `minikube mount ~/tmp-dir:/host`-->
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

## How to install and test minikube

First, install `kubectl` as well as `minikube` following the instructions [here](https://kubernetes.io/docs/tasks/tools/). One or both of these may be available through your system's package manager.

Next, create a basic `minikube` cluster:

```
minikube start
```

From here you can view the UI using the command `minikube dashboard` which should open a page in your browser.

Next, create a job specification. Put the following contents in a file called `job.yaml`:

```
apiVersion: batch/v1
kind: Job
metadata:
  name: test
spec:
  template:
    spec:
      containers:
      - name: test
	image: "hello-world:latest"
      restartPolicy: Never
  backoffLimit: 4
```

Deploy the test job using the command

```
kubectl apply -f job.yaml
```

which should return `job.batch/test created`. You can view the status move from pending to succeeded on the dashboard. After some time, query the status of the job with

```
kubectl describe jobs/test
```

which returns somethign which looks like

```
Name:             test
Namespace:        default
Selector:         controller-uid=eaa319c3-4440-4411-b178-6289398cdb6a
Labels:           controller-uid=eaa319c3-4440-4411-b178-6289398cdb6a
                  job-name=test
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
    certificate-authority: /home/will/.minikube/ca.crt
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
    client-certificate: /home/will/.minikube/profiles/minikube/client.crt
    client-key: /home/will/.minikube/profiles/minikube/client.key
```

### Cleanup

When you are done, delete the cluster:

```
minikube delete
```


## How to provision and test AWS Elastic Kubernetes Service

This section assumes you have already downloaded and configured the AWS CLI tool with an IAM user who has permissions to create an EKS cluster. To get started with EKS, install `eksctl`:

```
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

Next, run the following:

```
eksctl create cluster -f infra/cluster.yaml
```

To get information about the cluster that has been created:

```
eksctl get cluster --name ckp-test-cluster --region us-east-1
```

and to view the list of nodes, use `kubectl get nodes`.

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
    - userarn: arn:aws:iam::356198252393:user/newuser
      username: newuser
```

If you still encounter permissions errors, consider adding a [role and role binding](https://eksworkshop.com/beginner/090_rbac/create_role_and_binding/) to the cluster.

### Deploying a job

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
      rolearn: arn:aws:iam::<account_id>:role/eksctl-ckp-test-cluster-nodegroup-NodeInstanceRole-1VH95YLZKOX47
      username: system:node:{{EC2PrivateDNSName}}
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::<account_id>:role/eksctl-ckp-test-cluster-nodegroup-NodeInstanceRole-1NDG6XAZXQKJM
      username: system:node:{{EC2PrivateDNSName}}
  mapUsers: |
    - userarn: "arn:aws:iam::<account_id>:user/will"
      username: will
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"mapUsers":"- userarn: \"arn:aws:iam::<account_id>:user/will\"\n  username: will\n"},"kind":"ConfigMap","metadata":{"annotations":{},"name":"aws-auth","namespace":"kube-system"}}
  creationTimestamp: "2022-07-24T20:35:29Z"
  name: aws-auth
  namespace: kube-system
  resourceVersion: "59802"
  uid: 1d93c228-9a21-447b-a28d-c09593d0b573

> kubectl config view --minify
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://0A418BB2CE053D6E26E86072C9B2BAFF.yl4.us-east-1.eks.amazonaws.com
  name: ckp-test-cluster.us-east-1.eksctl.io
contexts:
- context:
    cluster: ckp-test-cluster.us-east-1.eksctl.io
    user: Administrator@ckp-test-cluster.us-east-1.eksctl.io
  name: Administrator@ckp-test-cluster.us-east-1.eksctl.io
current-context: Administrator@ckp-test-cluster.us-east-1.eksctl.io
kind: Config
preferences: {}
users:
- name: Administrator@ckp-test-cluster.us-east-1.eksctl.io
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      args:
      - eks
      - get-token
      - --cluster-name
      - ckp-test-cluster
      - --region
      - us-east-1
      command: aws
      env:
      - name: AWS_STS_REGIONAL_ENDPOINTS
        value: regional
      - name: AWS_PROFILE
        value: Administrator
      interactiveMode: IfAvailable
      provideClusterInfo: false
```

### Cleanup

When you are done, delete the cluster:

```
eksctl delete cluster -f infra/cluster.yaml
```

## Release Notes

Release notes are available in the [Changelog](https://github.com/AgnostiqHQ/covalent-kubernetes-plugin/blob/main/CHANGELOG.md).

## Citation

Please use the following citation in any publications:

> W. J. Cunningham, S. K. Radha, F. Hasan, J. Kanem, S. W. Neagle, and S. Sanand.
> *Covalent.* Zenodo, 2022. https://doi.org/10.5281/zenodo.5903364

## License

Covalent is licensed under the GNU Affero GPL 3.0 License. Covalent may be distributed under other licenses upon request. See the [LICENSE](https://github.com/AgnostiqHQ/covalent/blob/master/LICENSE) file or contact the [support team](mailto:support@agnostiq.ai) for more details.
