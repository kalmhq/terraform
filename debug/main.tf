locals {
  common_tags = {
    Terraform   = "true"
    Environment = "test"
  }
}

terraform {
  required_providers {
    kubernetes = {
      version = "~> 1.13.3"
    }
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}
data "aws_eks_cluster" "cluster" {
  name = module.eks-cluster.cluster_id
}
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks-cluster.cluster_id
}
data "tls_certificate" "eks-tls-cert" {
  url = module.eks-cluster.cluster_oidc_issuer_url
}
######################################
# Data sources to get VPC and subnets
######################################
data "aws_vpc" "default" {
  tags = {
    # Name = "tmp-eks-vpc-bluelight-VPC"
    Name = module.vpc.name
  }
  depends_on = [module.vpc]
}
data "aws_subnet_ids" "private-subnets" {
  vpc_id = data.aws_vpc.default.id
  tags = {
    SubnetType : "private-subnet"
  }
}
data "aws_subnet_ids" "public-subnets" {
  vpc_id = data.aws_vpc.default.id
  tags = {
    SubnetType : "public-subnet"
  }
}
data "aws_subnet" "private-subnet" {
  for_each = data.aws_subnet_ids.private-subnets.ids
  id       = each.value
}
data "aws_subnet" "public-subnet" {
  for_each = data.aws_subnet_ids.public-subnets.ids
  id       = each.value
}
######################################
# EKS
######################################
//resource "aws_iam_openid_connect_provider" "k8s-oidc-provider" {
//  client_id_list = [
//    "sts.amazonaws.com"
//  ]
//  thumbprint_list = [
//    data.tls_certificate.eks-tls-cert.certificates.0.sha1_fingerprint
//  ]
//  url = module.eks-cluster.cluster_oidc_issuer_url
//  depends_on = [
//    module.eks-cluster
//  ]
//}
//module "iam_eks_airflow_worker_role" {
//  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
//  version = "~> 3.0"
//  depends_on = [
//    aws_iam_openid_connect_provider.k8s-oidc-provider
//  ]
//
//  create_role = true
//  role_name = "eks-${local.common_tags.Environment}-airflow-service-account-role"
//  role_description = "IAM Role mapped to the kubernetes airflow service account resource."
//
//  oidc_fully_qualified_subjects = [
//    "system:serviceaccount:default:airflow",
//  ]
//  provider_url = module.eks-cluster.cluster_oidc_issuer_url
//  role_policy_arns = [
//    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
////    "arn:aws:iam::aws:policy/AmazonRDSDataFullAccess",
//  ]
//  number_of_role_policy_arns = 2
//
//  tags = local.common_tags
//}
//module "iam_eks_alb_ingress_controller_role" {
//  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
//  version = "~> 3.0"
//  depends_on = [
//    aws_iam_openid_connect_provider.k8s-oidc-provider
//  ]
//
//  create_role = true
//  role_name = "eks-${local.common_tags.Environment}-aws-load-balancer-controller-service-account-role"
//  role_description = "IAM Role mapped to the kubernetes ALB controller service account resource."
//
//  oidc_fully_qualified_subjects = [
//    "system:serviceaccount:kube-system:aws-load-balancer-controller",
//  ]
//  provider_url = module.eks-cluster.cluster_oidc_issuer_url
//  role_policy_arns = [
//    "arn:aws:iam::871806762109:policy/AWSLoadBalancerControllerIAMPolicy",
//    "arn:aws:iam::871806762109:policy/AWSLoadBalancerControllerAdditionalIAMPolicy",
//  ]
//  number_of_role_policy_arns = 2
//
//  tags = local.common_tags
//}
module "kubernetes_api_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/kubernetes-api"
  version = "~> 3.0"
  name    = "eks-standard-${local.common_tags.Environment}-sg"
  vpc_id  = data.aws_vpc.default.id
  ingress_cidr_blocks = setunion(
    [for s in data.aws_subnet.private-subnet : s.cidr_block],
    [for s in data.aws_subnet.public-subnet : s.cidr_block]
  )
  tags = local.common_tags
}
module "eks-cluster" {
  source                    = "terraform-aws-modules/eks/aws"
  cluster_name              = "kalm-${local.common_tags.Environment}"
  cluster_version           = "1.19"
  subnets                   = setunion(data.aws_subnet_ids.private-subnets.ids, data.aws_subnet_ids.public-subnets.ids)
  vpc_id                    = data.aws_vpc.default.id
  cluster_security_group_id = module.kubernetes_api_security_group.this_security_group_id
  workers_group_defaults = {
    root_volume_type = "gp2"
  }
  worker_groups = [
    {
      instance_type = "m5.large"
      # asg_min_size  = 3
      asg_max_size = 5
      subnets      = data.aws_subnet_ids.private-subnets.ids
    }
  ]
  tags = local.common_tags
}
