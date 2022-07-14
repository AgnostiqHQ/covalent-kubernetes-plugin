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

"""Kubernetes executor plugin for the Covalent dispatcher."""

import base64
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any, Dict, List, Tuple

import boto3
import cloudpickle as pickle
import docker
from covalent._shared_files.logger import app_log
from covalent._shared_files.util_classes import DispatchInfo
from covalent._workflow.transport import TransportableObject
from covalent.executor import BaseExecutor

from kubernetes import client,config
import kubernetes.client
from kubernetes.client.rest import ApiException

import eks_token

# TODO: Remove any references to AWS
_EXECUTOR_PLUGIN_DEFAULTS = {
    "credentials": os.environ.get("AWS_SHARED_CREDENTIALS_FILE")
    or os.path.join(os.environ["HOME"], ".aws/credentials"),
    "profile": os.environ.get("AWS_PROFILE") or "",
    "s3_bucket_name": "covalent-tmp",
    "ecr_repo_name": "covalent",
    "eks_cluster_name": "covalent-cluster",
    "cache_dir": "/tmp/covalent",
    "poll_freq": 10,
}

executor_plugin_name  = "KubernetesExecutor"

# TODO: Update docstrings

class KubeAuth():

    def __init__(self,
                 cluster_endpoint,
                 cluster_certificate
    ):
        self.cluster_endpoint = cluster_endpoint,
        self.cluster_certificate = cluster_certificate

    def _write_cafile(self,data: str) -> tempfile.NamedTemporaryFile:
        # protect yourself from automatic deletion
        cafile = tempfile.NamedTemporaryFile(delete=False)
        cadata_b64 = data
        cadata = base64.b64decode(cadata_b64)
        cafile.write(cadata)
        cafile.flush()
        return cafile


    def authenticate(self):
        config = self.get_config()

        #print(config.api_key)
        
        with kubernetes.client.ApiClient(configuration = config) as api_client:

            core_api = kubernetes.client.CoreV1Api(api_client=api_client)

            try:
                response = core_api.list_namespace()
                return True
            except:
                #print(response)
                #print("Authentication failure")
                return False


class BearerAuth(KubeAuth):

    def __init__(self,
                 token,
                 **kwargs
                 
    ):
        super().__init__(**kwargs)

        self.token = token
        
    def get_config(self):
        kconfig = kubernetes.config.kube_config.Configuration(
            host=self.cluster_endpoint[0],
            api_key={'authorization': 'Bearer ' + self.token}
        )
        kconfig.ssl_ca_cert = self._write_cafile(self.cluster_certificate).name
        
        return kconfig

# eks = boto3.client('eks')

        
# response = eks.describe_cluster(name="covalent-cluster")

# my_token = eks_token.get_token("covalent-cluster")
        

# auth = BearerAuth(token = my_token['status']['token'] , cluster_endpoint = response['cluster']['endpoint'],
#                   cluster_certificate = response['cluster']['certificateAuthority']["data"])

# auth.authenticate()
    
class KubernetesExecutor(BaseExecutor):
    """Kubernetes executor plugin class."""

    def __init__(
        self,
            auth: KubeAuth,
        s3_bucket_name: str,
        ecr_repo_name: str,
        eks_cluster_name: str,
        docker_base_image: str,
        poll_freq: int,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.auth = auth
        self.s3_bucket_name = s3_bucket_name
        self.ecr_repo_name = ecr_repo_name
        self.eks_cluster_name = eks_cluster_name
        self.poll_freq = poll_freq
        self.cache_dir = _EXECUTOR_PLUGIN_DEFAULTS["cache_dir"]
        self.docker_base_image = docker_base_image

    def execute(
        self,
            function: TransportableObject,
        args: List,
        kwargs: Dict,
        dispatch_id: str,
        results_dir: str,
        node_id: int = -1,
    ) -> Tuple[Any, str, str]:
        
        
        dispatch_info = DispatchInfo(dispatch_id)
        result_filename = f"result-{dispatch_id}-{node_id}.pkl"
        task_results_dir = os.path.join(results_dir, dispatch_id)
        image_tag = f"{dispatch_id}-{node_id}"
        container_name = f"covalent-task-{image_tag}"
        job_name = f"job-{dispatch_id}-{node_id}"

        eks = boto3.client('eks')

        
        if self.auth.authenticate() is False:
            raise Exception("Authentication failure")
        
        kconfig = self.auth.get_config()
        
        api_client = kubernetes.client.ApiClient(configuration=kconfig)

        

        Path(self.cache_dir).mkdir(parents=True, exist_ok=True)

        
        with self.get_dispatch_context(dispatch_info):
            ecr_repo_uri = self._package_and_upload(
                function,
                image_tag,
                self.docker_base_image,
                task_results_dir,
                result_filename,
                args,
                kwargs,
            )


            container = client.V1Container(
                name = container_name,
                image = ecr_repo_uri
            )

            pod_template = client.V1PodTemplateSpec(
                spec=client.V1PodSpec(restart_policy="Never", containers=[container])
            )

            metadata = client.V1ObjectMeta(name = job_name)

            job = client.V1Job(
                api_version="batch/v1",
                kind="Job",
                metadata=metadata,
                spec=client.V1JobSpec(backoff_limit=0, template=pod_template),
            )

            #print(job)

            batch_api = client.BatchV1Api(api_client = api_client)
            batch_api.create_namespaced_job("default", job)
            

            self._poll_ecs_task(job_name,api_client)

            results = self._query_result(result_filename, task_results_dir, image_tag)

            #batch_api.delete_namespaced_job(name=job_name, namespace = "default")

            return results, "", ""

    def _format_exec_script(
        self,
        func_filename: str,
        result_filename: str,
        docker_working_dir: str,
        args: List,
        kwargs: Dict,
    ) -> str:
        """Create an executable Python script which executes the task.

        Args:
            func_filename: Name of the pickled function.
            result_filename: Name of the pickled result.
            docker_working_dir: Name of the working directory in the container.
            args: Positional arguments consumed by the task.
            kwargs: Keyword arguments consumed by the task.

        Returns:
            script: String object containing the executable Python script.
        """

        exec_script = """
import os
import boto3
import cloudpickle as pickle

local_func_filename = os.path.join("{docker_working_dir}", "{func_filename}")
local_result_filename = os.path.join("{docker_working_dir}", "{result_filename}")

s3 = boto3.client("s3")
s3.download_file("{s3_bucket_name}", "{func_filename}", local_func_filename)

with open(local_func_filename, "rb") as f:
    function = pickle.load(f)

result = function(*{args}, **{kwargs})

with open(local_result_filename, "wb") as f:
    pickle.dump(result, f)

s3.upload_file(local_result_filename, "{s3_bucket_name}", "{result_filename}")
""".format(
            func_filename=func_filename,
            args=args,
            kwargs=kwargs,
            s3_bucket_name=self.s3_bucket_name,
            result_filename=result_filename,
            docker_working_dir=docker_working_dir,
        )

        return exec_script

    def _format_dockerfile(self, exec_script_filename: str, docker_working_dir: str, docker_base_image:str) -> str:
        """Create a Dockerfile which wraps an executable Python task.
        
        Args:
            exec_script_filename: Name of the executable Python script.
            docker_working_dir: Name of the working directory in the container.

        Returns:
            dockerfile: String object containing a Dockerfile.
        """

        dockerfile = """
FROM {docker_base_image}

RUN apt-get update && apt-get install -y \\
  gcc \\
  && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir --use-feature=in-tree-build boto3 cloudpickle

WORKDIR {docker_working_dir}

COPY {func_basename} {docker_working_dir}

ENTRYPOINT [ "python" ]
CMD ["{docker_working_dir}/{func_basename}"]
""".format( docker_base_image = docker_base_image,
            func_basename=os.path.basename(exec_script_filename),
            docker_working_dir=docker_working_dir,
        )

        return dockerfile

    def _package_and_upload(
        self,
        function: TransportableObject,
        image_tag: str,
        docker_base_image: str,
        task_results_dir: str,
        result_filename: str,
        args: List,
        kwargs: Dict,
    ) -> str:
        """Package a task using Docker and upload it to AWS ECR.
        
        Args:
            function: A callable Python function.
            image_tag: Tag used to identify the Docker image.
            task_results_dir: Local directory where task results are stored.
            result_filename: Name of the pickled result.
            args: Positional arguments consumed by the task.
            kwargs: Keyword arguments consumed by the task.

        Returns:
            ecr_repo_uri: URI of the repository where the image was uploaded.
        """

        func_filename = f"func-{image_tag}.pkl"
        docker_working_dir = "/opt/covalent"

        with tempfile.NamedTemporaryFile(dir=self.cache_dir) as function_file:
            # Write serialized function to file
            pickle.dump(function.get_deserialized(), function_file)
            function_file.flush()

            # Upload pickled function to S3
            s3 = boto3.client("s3")
            s3.upload_file(function_file.name, self.s3_bucket_name, func_filename)

        with tempfile.NamedTemporaryFile(
            dir=self.cache_dir, mode="w"
        ) as exec_script_file, tempfile.NamedTemporaryFile(
            dir=self.cache_dir, mode="w"
        ) as dockerfile_file:
            # Write execution script to file
            exec_script = self._format_exec_script(
                func_filename,
                result_filename,
                docker_working_dir,
                args,
                kwargs,
            )
            exec_script_file.write(exec_script)
            exec_script_file.flush()

            # Write Dockerfile to file
            dockerfile = self._format_dockerfile(exec_script_file.name, docker_working_dir,docker_base_image)
            dockerfile_file.write(dockerfile)
            dockerfile_file.flush()

            local_dockerfile = os.path.join(task_results_dir, f"Dockerfile_{image_tag}")
            shutil.copyfile(dockerfile_file.name, local_dockerfile)

            # Build the Docker image
            docker_client = docker.from_env()
            image, build_log = docker_client.images.build(
                path=self.cache_dir, dockerfile=dockerfile_file.name, tag=image_tag
            )

        # ECR config
        ecr = boto3.client("ecr")

        ecr_username = "AWS"
        ecr_credentials = ecr.get_authorization_token()["authorizationData"][0]
        ecr_password = (
            base64.b64decode(ecr_credentials["authorizationToken"])
            .replace(b"AWS:", b"")
            .decode("utf-8")
        )
        ecr_registry = ecr_credentials["proxyEndpoint"]
        ecr_repo_uri = f"{ecr_registry.replace('https://', '')}/{self.ecr_repo_name}:{image_tag}"

        response = docker_client.login(username=ecr_username, password=ecr_password, registry=ecr_registry)

        
        # Tag the image
        image.tag(ecr_repo_uri, tag=image_tag)

        # Push to ECR
        response = docker_client.images.push(ecr_repo_uri, tag=image_tag)

        return ecr_repo_uri

    def get_status(self,name:str, api_client, name_space: str = "default") :
        """Query the status of a previously submitted EKS job.

        Args:
            name: EKS job name.
            name_space: name_space of job job.

        Returns:
            exit_code: Exit code, if the task has completed, else -1.
        """


        # Create an instance of the API class
        api_instance = kubernetes.client.BatchV1Api(api_client = api_client)
        
        try:
            job = api_instance.read_namespaced_job_status(name,name_space)
            with open('/home/poojith/agnostiq/tempfilename1.txt', 'w') as f:
                    print(job, file=f)
            if job.status.succeeded is not None:
                if job.status.succeeded > 0:
                    return 1
                elif job.status.active > 0:
                    return 0
                return -2
        except:
            return -1

    def _poll_ecs_task(self, name: str, api_client, name_space:str = "default") -> None:
        """Poll an EKS task until completion.

        Args:
            name: EKS job name.
            name_space: name_space of job.

        Returns:
            None
        """

        exit_code = self.get_status(name,api_client,name_space)

        while exit_code != 1:
            time.sleep(self.poll_freq)
            exit_code = self.get_status(name,api_client,name_space)

            if exit_code == -1:
                api_instance = kubernetes.client.BatchV1Api(api_client = api_client)
                job = api_instance.read_namespaced_job_status(name,name_space)

                app_log.debug("Error while polling job")
                app_log.debug(job)

                with open('/home/poojith/agnostiq/tempfilename.txt', 'w') as f:
                    print(job, file=f)
                raise Exception("Error while polling job")
                break
        

    def _query_result(
        self,
        result_filename: str,
        task_results_dir: str,
        image_tag: str,
    ) -> Tuple[Any, str, str]:
        """Query and retrieve a completed task's result.

        Args:
            result_filename: Name of the pickled result file.
            task_results_dir: Local directory where task results are stored.
            task_arn: ARN used to identify an ECS task.
            image_tag: Tag used to identify the Docker image.

        Returns:
            result: The task's result, as a Python object.
            logs: The stdout and stderr streams corresponding to the task.
            empty_string: A placeholder empty string.
        """

        local_result_filename = os.path.join(task_results_dir, result_filename)

        s3 = boto3.client("s3")
        s3.download_file(self.s3_bucket_name, result_filename, local_result_filename)

        with open(local_result_filename, "rb") as f:
            result = pickle.load(f)
        os.remove(local_result_filename)

        return result

    def _write_cafile(self,data: str) -> tempfile.NamedTemporaryFile:
        # protect yourself from automatic deletion
        cafile = tempfile.NamedTemporaryFile(delete=False)
        cadata_b64 = data
        cadata = base64.b64decode(cadata_b64)
        cafile.write(cadata)
        cafile.flush()
        return cafile

    def k8s_api_client(self,endpoint: str, token: str, cafile: str) -> kubernetes.client.CoreV1Api:
        kconfig = kubernetes.config.kube_config.Configuration(
            host=endpoint,
            api_key={'authorization': 'Bearer ' + token}
        )
        kconfig.ssl_ca_cert = cafile
        kclient = kubernetes.client.ApiClient(configuration=kconfig)
        return kclient

