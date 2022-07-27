terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.23"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "name" {
  default     = "covalent-eks"
  description = "Name used to prefix AWS resources"
}

variable "aws_region" {
  default     = "us-east-1"
  description = "Region in which the cluster is deployed"
}

variable "aws_ecr_repo" {
  default     = "covalent-eks-task"
  description = "ECR repository used for task images"
}

variable "aws_s3_bucket" {
  default     = "covalent-eks-task"
  description = "S3 bucket used for file staging"
}

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "VPC CIDR range"
}

variable "instance_types" {
  default     = ["t2.medium"]
  description = "List of node instance types"
}

variable "disk_size" {
  default     = 8
  description = "Disk size per node"
}

variable "min_size" {
  default     = 1
  description = "Minimum number of worker nodes"
}

variable "max_size" {
  default     = 6
  description = "Maximum number of worker nodes"
}

variable "desired_size" {
  default     = 2
  description = "Desired number of worker nodes"
}

locals {
  cluster_name = "${var.name}-cluster"

  common_tags = {
    Environment = "dev"
    Origin      = "covalent-k8s-plugin"
  }
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.name}-vpc"
  cidr = var.vpc_cidr

  azs = ["${var.aws_region}a", "${var.aws_region}b"]

  public_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 0),
    cidrsubnet(var.vpc_cidr, 8, 1)
  ]

  private_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 2),
    cidrsubnet(var.vpc_cidr, 8, 3)
  ]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true

  tags = merge(
    {
      Name = module.vpc.name
    },
    local.common_tags
  )

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.name}-cluster" = "owned"
  }
}

resource "aws_ecr_repository" "ecr_repository" {
  name = var.aws_ecr_repo
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = var.s3_bucket
}

data "aws_iam_policy_document" "s3_access_document" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket}",
      "arn:aws:s3:::${var.s3_bucket}/*",
    ]
  }
}

resource "aws_iam_policy" "s3_access_policy" {
  name = "CovalentEKSS3Access"
  path = "/"
  policy = data.aws_iam_policy_document.s3_access_document.json
}

resource "aws_iam_role" "eks_iam_role" {
  name = "eks-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = {
    "Terraform" = "true"
  }
}

resource "aws_iam_role_policy_attachment" "eks_iam_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_iam_role.name
}

resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Terraform = "true"
  }
}

resource "aws_iam_role_policy_attachment" "worker_node_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "worker_node_s3_attachment" {
  policy_arn = aws_iam_policy.s3_access_policy.arn
  role = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "cni_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_readonly_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_eks_cluster" "eks_cluster" {
  depends_on = [
    aws_iam_role_policy_attachment.eks_iam_policy_attachment,
    module.vpc.public_subnets,
    module.vpc.private_subnets
  ]

  name     = local.cluster_name
  role_arn = aws_iam_role.eks_iam_role.arn

  vpc_config {
    subnet_ids = concat(module.vpc.public_subnets, module.vpc.private_subnets)
  }

  tags = merge(
    {
      Name = local.cluster_name
    },
    local.common_tags
  )
}

resource "aws_eks_node_group" "private_node_group" {
  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy_attachment,
    aws_iam_role_policy_attachment.cni_policy_attachment,
    aws_iam_role_policy_attachment.ecr_readonly_policy_attachment
  ]

  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${local.cluster_name}-private-ng"
  node_role_arn   = aws_iam_role.eks_node_role.arn

  subnet_ids      = module.vpc.private_subnets

  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"
  instance_types = var.instance_types
  disk_size      = var.disk_size

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  update_config {
    max_unavailable = 2
  }

  tags = merge(
    {
      Name = local.cluster_name
    },
    local.common_tags
  )
}

data "template_file" "config" {
  template = file("${path.module}/templates/config.tpl")
  vars = {
    certificate_data  = aws_eks_cluster.eks_cluster.certificate_authority[0].data
    cluster_endpoint  = aws_eks_cluster.eks_cluster.endpoint
    aws_region        = var.aws_region
    cluster_name      = local.cluster_name
    account_id        = data.aws_caller_identity.current.account_id
  }
}

resource "local_file" "config" {
  content  = data.template_file.config.rendered
  filename = "${path.module}/${local.cluster_name}_config"
}

data "aws_iam_policy_document" "cluster_autoscaler_sts_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_ca_oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks_ca_oidc_provider.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_sts_policy.json
  name               = "${var.name}-cluster-autoscaler"
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name = "${var.name}-cluster-autoscaler"

  policy = jsonencode({
    Statement = [{
      Action = [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeLaunchTemplateVersions"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_ca_iam_policy_attach" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

data "tls_certificate" "tls" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_ca_oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.tls.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

output "name" {
  value       = var.name
  description = "Exported name"
}

output "cluster_name" {
  value       = local.cluster_name
  description = "Exported EKS cluster name"
}

output "kubeconfig" {
  value       = local_file.config.filename
  description = "Exported kubectl config"
}

output "eks_ca_iam_role_arn" {
  value = aws_iam_role.cluster_autoscaler.arn
  description = "AWS IAM role ARN for EKS Cluster Autoscaler"
}
