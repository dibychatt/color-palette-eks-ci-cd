# Color Palette API – Secure GitOps CI/CD on AWS EKS

A **production-grade DevSecOps project** demonstrating how to design, secure, and operate a cloud-native application using **Terraform, AWS EKS, GitHub Actions, and Argo CD**, following **GitOps and least-privilege security principles**.

This repository is intentionally structured to reflect **real-world platform engineering practices**, not just a demo deployment.

---

## Project Intent

The goal of this project is to showcase how a backend application can be:

- Provisioned using **Infrastructure as Code**
- Built and scanned securely via **CI pipelines**
- Deployed using **GitOps (no kubectl in production)**
- Operated on **AWS EKS** with proper IAM boundaries
- Updated automatically using **immutable container images**

This project focuses on **correctness, security, and reproducibility**, not shortcuts.

---

## Architecture Overview

This project follows a **clean separation of concerns**:

- **Infrastructure provisioning** → Terraform
- **Build & security** → GitHub Actions (CI)
- **Deployment & reconciliation** → Argo CD (GitOps)
- **Runtime operations** → Amazon EKS

### High-Level System Architecture

```
┌──────────────────┐
│   Developer      │
│  (Git Commit)    │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────┐
│ GitHub Repository (main)     │
│                              │
│  - app/                      │
│  - k8s/ (Kustomize)          │
│  - argocd/                   │
│  - terraform/                │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ GitHub Actions (CI Pipeline)              │
│                                          │
│ ✓ Tests                                  │
│ ✓ SAST (Semgrep)                          │
│ ✓ Dependency Audit                        │
│ ✓ Docker Build                            │
│ ✓ Image Scan (Trivy)                      │
│ ✓ Push to ECR (immutable tag)             │
│ ✓ Update Kustomize image SHA              │
│ ✓ Create Pull Request                     │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ GitOps Boundary (Git = Source of Truth)  │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ Argo CD                                  │
│                                          │
│ ✓ Watches Git repo                        │
│ ✓ Auto-sync enabled                       │
│ ✓ Drift detection                         │
│ ✓ Self-healing                            │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ Amazon EKS                               │
│                                          │
│ - Deployment                             │
│ - Service (LoadBalancer)                 │
│ - ConfigMap / Secret                     │
│ - Health Probes                          │
│ - Auto-scaling ready                     │
└──────────────────────────────────────────┘
```

### Security Architecture (Identity & Access)

```
┌──────────────────────┐
│ GitHub Actions       │
│ (OIDC Token)         │
└─────────┬────────────┘
          │
          ▼
┌──────────────────────────────┐
│ AWS IAM Role                 │
│ GitHubActions-ECR-Push       │
│ (No static credentials)      │
└─────────┬────────────────────┘
          │
          ▼
┌──────────────────────────────┐
│ Amazon ECR                   │
│ - Encrypted                  │
│ - Immutable image tags       │
└──────────────────────────────┘
```

```
┌──────────────────────┐
│ Kubernetes Pod       │
│ ServiceAccount       │
└─────────┬────────────┘
          │ IRSA
          ▼
┌──────────────────────────────┐
│ AWS IAM Role (IRSA)           │
│ - Least privilege             │
│ - No node credentials         │
└──────────────────────────────┘
```

**Key security decisions:**

- No AWS keys in GitHub
- No node IAM permissions abuse
- Identity-based access everywhere

---

## Core Components

### Application

- Node.js REST API (containerized)
- Health & readiness probes
- Metrics endpoint (`/metrics`)
- Production-ready resource requests & limits

### CI – GitHub Actions

- Runs on every push to `main`
- Executes:
  - Unit tests
  - Semgrep (SAST)
  - `npm audit`
  - Docker build
  - Trivy image scan
- Pushes immutable images to **Amazon ECR**
- Automatically updates **Kustomize image SHA**

### CD – Argo CD

- Fully GitOps-based deployment
- Auto-sync enabled
- Drift detection + self-healing
- No manual cluster changes

### Infrastructure – Terraform

- VPC (public + private subnets)
- EKS cluster + managed node groups
- IAM roles and policies
- OIDC provider for secure authentication
- ECR repository with immutable tags

📄 Full infra details: [`terraform/README.md`](./terraform/README.md)

---

## Security & DevSecOps Practices

This project intentionally avoids insecure shortcuts.

- ✅ **No long-lived AWS credentials**
- ✅ GitHub Actions uses **OIDC → IAM role assumption**
- ✅ EKS uses **IAM Roles for Service Accounts (IRSA)**
- ✅ ECR repositories:
  - Encrypted
  - Immutable tags
- ✅ Least-privilege IAM policies
- ✅ Git is the **single source of truth**

> In production, secrets should be managed using **External Secrets / AWS Secrets Manager**.
> Kubernetes `Secret` manifests here are placeholders for demonstration.

---

## CI/CD Workflow (Step-by-Step)

### CI Flow

1. Developer pushes code to `main`
2. GitHub Actions pipeline starts
3. Pipeline performs:
   - Dependency install
   - Tests
   - SAST (Semgrep)
   - Dependency vulnerability scan
4. Docker image is built
5. Image is scanned using Trivy
6. Image is pushed to Amazon ECR with **commit SHA**
7. `k8s/overlays/dev/kustomization.yaml` is updated automatically
8. A pull request is created with the new image SHA

### CD Flow (GitOps)

1. PR is merged to `main`
2. Argo CD detects the Git change
3. Argo CD syncs the manifests
4. Kubernetes rolls out the new version
5. If drift occurs, Argo CD self-heals

### GitOps Deployment Flow (Exact Lifecycle)

```
Code Change
   │
   ▼
CI Pipeline
   │
   ├─ Build + Scan Image
   ├─ Push to ECR (SHA)
   └─ Update Git (kustomization.yaml)
           │
           ▼
        Git Commit
           │
           ▼
      Argo CD Detects Drift
           │
           ▼
      Kubernetes Reconcile
           │
           ▼
      New Pods Rolled Out
```

**Important:** No `kubectl apply` is required or encouraged after setup.

---

## Kubernetes Structure

```
k8s/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   ├── secrets.yaml
│   ├── hpa.yaml
│   ├── namespace.yaml
│   └── kustomization.yaml
└── overlays/
    └── dev/
        ├── kustomization.yaml
        └── servicemonitor.yaml
```

### Key Design Choices

- **Kustomize** for environment-specific overlays
- Image tags updated automatically via CI
- Probes ensure safe rollouts
- HPA included (disabled by default for demo)

---

## Repository Structure

```
color-palette-eks-ci-cd/
├── app/          # Application source (owned by devs)
├── terraform/    # Platform provisioning (owned by platform team)
├── k8s/          # Declarative runtime state (GitOps)
├── argocd/       # CD definitions
└── README.md     # Single source of explanation
```

This mirrors how **real orgs split ownership** between application and platform teams.

---

## Argo CD Application

Argo CD manages the deployment using this configuration:

- Watches `k8s/overlays/dev`
- Auto-sync enabled
- Prunes removed resources
- Automatically creates namespaces

This enforces **true GitOps discipline** — Git defines reality.

---

## Manual Setup (One-Time)

Some steps must be done manually once, as they are **outside Git's scope**:

### AWS

- Create AWS account
- Configure:
  - S3 backend for Terraform state
  - IAM role for GitHub Actions (OIDC trust)
  - IAM admin role for EKS access

### GitHub

- Add repository secrets:
  - `AWS_ACCOUNT_ID`
  - `GH_PAT` (for PR creation)
- Enable GitHub Actions permissions:
  - `id-token: write`
  - `contents: read`

### Argo CD

- Install Argo CD in the cluster
- Apply `argocd/application-dev.yaml`
- Access Argo CD UI

These steps are documented because **real systems always require some bootstrapping**.

---

## Challenges & Learnings

This project involved solving real production-style problems. Below are the key challenges and how they were resolved.

### 1️⃣ IAM & EKS Access Changes (Newer EKS Versions)

**Problem:** Newer EKS versions no longer rely solely on `aws-auth` ConfigMap for cluster access. Initial attempts to access the cluster using traditional mappings resulted in permission issues.

**Root Cause:**
- EKS introduced Access Entries + Access Policies as the preferred model
- Legacy approaches silently fail or behave inconsistently

**Solution:**
- Adopted `aws_eks_access_entry` and `aws_eks_access_policy_association`
- Explicitly granted admin access using `AmazonEKSClusterAdminPolicy`
- Removed reliance on manual `aws-auth` edits

**Learning:** EKS access control is now IAM-native — treating it as Kubernetes-only is a mistake.

### 2️⃣ OIDC Trust Policy Pitfalls (IRSA)

**Problem:** Pods failed to pull images or assume roles even though IRSA was configured.

**Root Cause:**
- Incorrect `sub` condition in IAM trust policy
- Mismatch between:
  - Kubernetes namespace
  - ServiceAccount name
  - OIDC issuer URL format

**Solution:**
- Created OIDC provider directly from EKS identity
- Used strict trust conditions: `"system:serviceaccount:<namespace>:<serviceaccount>"`
- Validated issuer URL formatting (`https://` stripped)

**Learning:** IRSA failures are usually string mismatches, not IAM permission issues.

### 3️⃣ AWS LoadBalancer Behavior on EKS

**Problem:** Kubernetes `Service` of type `LoadBalancer` did not create an external endpoint as expected.

**Root Cause:**
- AWS Load Balancer Controller was:
  - Missing
  - Misconfigured
  - Lacking IAM permissions
- Manual controller installation caused crashes

**Solution:**
- Allowed EKS to manage classic LoadBalancer via Service directly
- Deferred ALB/NLB controller to Terraform-managed lifecycle
- Avoided manual controller installs that violate GitOps

**Learning:** In GitOps, manual controller installs create drift and instability.

### 4️⃣ GitOps Drift from Manual Changes

**Problem:** Argo CD showed `OutOfSync`, `Missing`, and unexpectedly reverting resources.

**Root Cause:**
- Manual `kubectl patch` on Services
- Git state and cluster state diverged

**Solution:**
- Treated Git as the only source of truth
- Reverted manual changes
- Moved all configuration back into Kustomize manifests
- Enabled `selfHeal: true` and `prune: true`

**Learning:** If you fix things manually, GitOps will break you back.

### 5️⃣ Secure CI Without Static AWS Credentials

**Problem:** CI needed to push images to ECR without storing AWS keys in GitHub.

**Solution:**
- Used GitHub Actions OIDC
- Created a tightly scoped IAM role:
  - No long-lived credentials
  - Trusts only GitHub repo + branch
- Used `aws-actions/configure-aws-credentials`

**Learning:** OIDC is the correct way to integrate CI with cloud providers in 2025+.

### 6️⃣ Immutable Image Tag Workflow

**Problem:** ECR repository enforced immutable tags, preventing re-push of `latest`.

**Solution:**
- Used commit SHA as image tag
- Automated Kustomize `newTag` update in CI
- Created a pull request instead of force-pushing

**Result:**
- Every deployment is:
  - Traceable
  - Auditable
  - Reproducible

**Learning:** Immutability forces better GitOps discipline — and that's a good thing.

### Key Takeaways

- Modern EKS requires IAM-first thinking
- GitOps only works when humans stop fixing things manually
- Security and automation must be designed together
- Tooling is easy — operational correctness is hard

This project reflects real-world debugging, not idealized tutorials.

---

## Design Decisions & Trade-offs

- **LoadBalancer Service** used for simplicity
  → In production, ALB + Ingress would be preferred

- **Secrets in manifests (demo)**
  → Explicitly documented replacement with External Secrets

- **Public EKS endpoint enabled**
  → Documented toggle for private-only clusters

- **HPA included but disabled**
  → Demonstrates readiness without forcing metrics dependency

---

## How to Run

1. Provision infrastructure using Terraform
2. Configure GitHub Actions OIDC role
3. Install Argo CD
4. Push application code
5. Let GitOps handle the rest

Manual deployment is intentionally discouraged.

---

## Scaling Considerations

| Area          | Next Step                           |
|---------------|-------------------------------------|
| Environments  | Add `staging/` and `prod/` overlays |
| Promotion     | Image promotion instead of rebuild  |
| Security      | OPA / Kyverno policies              |
| Secrets       | AWS Secrets Manager + ESO           |
| Deployments   | Canary / Blue-Green                 |
| Observability | Centralized Prometheus + Loki       |

---

## Future Improvements

- External Secrets integration
- Policy-as-Code (OPA / Kyverno)
- Multi-environment promotion (dev → staging → prod)
- Canary or Blue-Green deployments
- Centralized observability stack

---
