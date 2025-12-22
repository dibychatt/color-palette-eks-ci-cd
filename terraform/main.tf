terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "tfstate-eks-secure-seenu-d9e9f7"
    key          = "prod/eks-cluster.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  admin_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eks-admin-role"
}


# -------------------
# VPC Module
# -------------------
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  cluster_name         = var.cluster_name
}

# -------------------
# EKS Module
# -------------------
module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  allowed_cidrs   = var.allowed_cidrs
  subnet_ids      = module.vpc.private_subnet_ids
  node_groups     = var.node_groups
  admin_role_arn  = local.admin_role_arn
}

# -------------------
# ECR + IRSA Module
# -------------------
module "ecr" {
  source = "./modules/ecr"

  repository_name     = "sample-app"
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = replace(module.eks.oidc_issuer_url, "https://", "")

  namespace            = "default"
  service_account_name = "sample-app-sa"
}