# Terraform – AWS EKS Infrastructure

This Terraform project provisions a secure, production-ready AWS EKS platform including:

- Custom VPC (public + private subnets)
- Amazon EKS cluster with managed node groups
- IAM roles and access control
- Amazon ECR repository
- IRSA (IAM Roles for Service Accounts)
- Remote Terraform state in S3

This infrastructure is designed to work seamlessly with GitHub Actions CI, ArgoCD GitOps, and Kustomize-based deployments.

## Architecture Overview

```
Terraform
├── VPC
│   ├── Public Subnets (LoadBalancers, NAT)
│   ├── Private Subnets (EKS worker nodes)
│   └── NAT Gateway per AZ
│
├── EKS
│   ├── Control Plane (API + Audit logs)
│   ├── Managed Node Groups
│   ├── IAM Access Entries
│   └── OIDC Provider (for IRSA)
│
├── ECR
│   ├── Immutable image repository
│   ├── Scan-on-push enabled
│   └── IRSA role for image pull
│
└── Remote State
    └── S3 backend (encrypted)
```

## Folder Structure

```
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── README.md
└── modules/
    ├── vpc/
    ├── eks/
    └── ecr/
```

## Modules Breakdown

### 1️⃣ VPC Module (`modules/vpc`)

Creates a high-availability VPC for EKS.

**What it creates:**

- VPC with DNS enabled
- Public subnets (for LoadBalancers)
- Private subnets (for EKS nodes)
- Internet Gateway
- NAT Gateways (one per AZ)
- Route tables and associations

**Why this matters:**

- EKS worker nodes are isolated in private subnets
- Internet access is routed securely via NAT
- Required AWS tags are added for Kubernetes load balancers

### 2️⃣ EKS Module (`modules/eks`)

Creates a fully managed EKS cluster.

**What it creates:**

- EKS control plane
- Managed node groups
- IAM roles for cluster and nodes
- Cluster logging (API, audit, scheduler, etc.)
- OIDC provider for IRSA
- EKS addons (VPC CNI, CoreDNS, kube-proxy)
- Admin access via IAM role (no aws-auth hacks)

**Security highlights:**

- IRSA enabled
- No hardcoded credentials
- Fine-grained access using `aws_eks_access_entry`

### 3️⃣ ECR + IRSA Module (`modules/ecr`)

Creates an immutable ECR repository and a secure IRSA role.

**What it creates:**

- ECR repository with:
  - Immutable image tags
  - Scan on push enabled
  - Encryption at rest
- IAM role for Kubernetes ServiceAccount
- Least-privilege ECR pull permissions

**Used by:**

- GitHub Actions → push images
- Kubernetes Pods → pull images securely via IRSA

## Remote State (Important)

Terraform state is stored remotely in S3:

```hcl
backend "s3" {
  bucket  = "tfstate-eks-secure-seenu-d9e9f7"
  key     = "prod/eks-cluster.tfstate"
  region  = "us-east-1"
  encrypt = true
}
```

**Benefits:**

- ✔ Prevents state loss
- ✔ Enables team collaboration
- ✔ Encrypted at rest

## Prerequisites

Before running Terraform, ensure:

- AWS CLI configured
- Terraform >= 1.6.0
- IAM permissions to create:
  - VPC, EKS, IAM, ECR, S3
- S3 bucket already exists for state backend

## Configuration (`terraform.tfvars`)

Environment-specific values live here:

```hcl
region         = "us-east-1"
cluster_name   = "my-eks-cluster"

availability_zones = ["us-east-1a", "us-east-1b"]

public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
```

👉 Modify this file to create new environments (dev/staging/prod).

## How to Deploy

From the `terraform/` directory:

```bash
terraform init
terraform validate
terraform plan
terraform apply -var-file="terraform.tfvars"
```

⏱️ Apply takes 10–15 minutes due to EKS provisioning.

## Outputs

After successful apply:

```bash
terraform output
```

You will get:

- EKS cluster endpoint
- Cluster name
- OIDC provider ARN
- ECR repository URL
- IRSA role ARN

These outputs are used by:

- GitHub Actions CI
- ArgoCD
- Kubernetes manifests

## How This Fits the Overall Flow

```
Terraform
    ↓
EKS + ECR + IRSA
    ↓
GitHub Actions (OIDC)
    ↓
Push image to ECR (SHA tagged)
    ↓
Auto-update Kustomize overlay
    ↓
ArgoCD syncs to EKS
    ↓
Application exposed via LoadBalancer
```

## Notes / Design Decisions

- No static AWS credentials anywhere
- Immutable container images
- GitOps-first approach
- Environment separation via Kustomize
- Terraform only manages infra, not app deploys