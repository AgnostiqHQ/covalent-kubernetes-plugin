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

## How to install and test minikube

First, install `kubectl` as well as `minikube` following the instructions[here](https://kubernetes.io/docs/tasks/tools/). One or both of these may be available through your system's package manager.

Next, create a basic `minikube` cluster:

```
minikube start
```

From here you can view the UI using the command `minikube dashboard` which should open a page in your browser.

Next, create a job specification. Put the following contents in a file called `job.yaml`

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
