# 🏗️ Deep-Dive Infrastructure Architecture & Workflow

This diagram provides a high-resolution view of the **Robust EKS Infrastructure** deployment logic, script internal functions, and the Azure CI/CD pipeline lifecycle.

---

## 🗺️ 1. Full-Stack Data & Control Flow Diagram

```text
[ SOURCE CONTROL ] (Git: config.yaml)
      │
      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. CONFIGURATION LAYER (Terragrunt Root: terragrunt.hcl)                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  [ yamldecode ] <── Reads config.yaml                                       │
│      │                                                                      │
│  [ locals { } ] ─── Merges YAML inputs with project-wide defaults           │
│      │               (Names, Prefixes, Regions, Account IDs)                │
│      │                                                                      │
│  [ generate ] ───── Dynamically creates configuration files:                │
│      │               ├── provider.tf (via templates/provider.tftpl)         │
│      │               ├── terraform.tf (via templates/terraform.tftpl)       │
│      │               └── backend.tf (State storage in S3/DynamoDB)          │
│      │                                                                      │
│  [ inputs = { } ] ─ Inject into Child Modules (VPC, EKS, RDS, etc.)         │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. EXECUTION SCRIPTS (PowerShell Layer)                                     │
├──────────────────────────────────────┬──────────────────────────────────────┤
│  [ setup-backend.ps1 ]               │  [ terraform.ps1 ]                   │
│  ├── Check-AWS-CLI                   │  ├── Test-Prerequisites (v2, IAM)    │
│  ├── Check-Identity (STS)            │  ├── Setup-Backend (Bucket/Table)    │
│  ├── Create-S3-Bucket (Versioning)   │  ├── Clean-TerraformCache            │
│  ├── Create-Dynamo-Table (Locking)   │  └── Run-Command (init, plan, apply) │
│  └── Update-Terragrunt-HCL           │                                      │
└──────────────────────────────────────┴────────────────┬─────────────────────┘
                                                        │
                                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 3. INFRASTRUCTURE RESOURCE DEPENDENCY TREE                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  (Layer 1: Core Networking)                                                 │
│   [ modules/vpc ] ───────► (VPC, Subnets, IGW, NAT, Route Tables)           │
│                                       │                                     │
│  (Layer 2: Access & Auth)             ▼                                     │
│   [ modules/iam ] ──────────► (Cluster Roles, Node Roles, OIDC)             │
│   [ modules/security-group ] ──► (EKS SG, RDS SG, ALB SG)                   │
│                                       │                                     │
│  (Layer 3: Control Plane)             ▼                                     │
│   [ modules/eks-cluster ] ───► (K8s Control Plane, Logging, Addons)         │
│                                       │                                     │
│  (Layer 4: Data & State)              ▼                                     │
│   [ modules/secrets-manager ] ──► (External Secret JSON mapping)            │
│   [ modules/rds ] ──────────────► (PostgreSQL Multi-AZ Instance)            │
│   [ modules/efs ] ──────────────► (Shared Persistent Storage)               │
│                                       │                                     │
│  (Layer 5: Compute)                   ▼                                     │
│   [ modules/eks-node-group ] ──► (EC2 Managed Node Groups, Spot/OD)         │
│                                       │                                     │
│  (Layer 6: Traffic & Apps)            ▼                                     │
│   [ modules/alb-ingress ] ───► (Load Balancer Controller)                   │
│   [ modules/acm ] ───────────► (SSL/TLS Cert Management)                    │
│   [ modules/istio ] ─────────► (Service Mesh: Ingress/Egress Gateway)       │
│   [ modules/argocd ] ────────► (GitOps Operator)                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ 2. Script Internal Logical Map

### A. `setup-backend.ps1` Functionality Breakdown
1.  **Identity Verification**: Runs `aws sts get-caller-identity` to ensure the correct account/region is targetted.
2.  **State Protection**: Creates an S3 bucket with **Versioning** (prevents state loss) and **Public Access Block** (security compliance).
3.  **Conflict Prevention**: Initializes a DynamoDB table with `LockID` as the Primary Key. Terragrunt uses this to lock the state file during updates, preventing two users from changing infrastructure at the same time.
4.  **HCL Integration**: Injects the `remote_state` block into `terragrunt.hcl` if it doesn't exist, linking the local code to the newly created cloud resources.

### B. `terraform.ps1` Operational Lifecycle
1.  **Pre-flight Checks**: Confirms `aws`, `terraform`, and `terragrunt` are installed and reachable in the system PATH.
2.  **Cache Management**: Deletes `.terraform/` and `.terragrunt-cache/` folders before `init` to resolve dependency conflicts or "ghost" files from previous runs.
3.  **Command Translation**:
    - `init` → `terragrunt run-all init`
    - `plan` → `terragrunt run-all plan -out=tfplan`
    - `apply` → `terragrunt run-all apply tfplan`

---

## ☁️ 3. Azure CI/CD Pipeline: High-Resolution Phase Map

The pipeline follows a **Modular Execution** strategy to ensure high availability and rollback capability.

### Stage: EXECUTE (Terragrunt Action)

#### Phase 1: Environment Provisioning (Tooling)
- **Tool Install**: Dynamically downloads and installs specific versions of `terraform`, `terragrunt`, `yq`, and `kubectl`.
- **Identity Login**: Uses the `awsServiceConnection` to assume the required IAM role for the runner.

#### Phase 2: Security & Certificate Handling (Certs/Secrets)
- **PFX Extraction**:
    - `openssl pkcs12` extracts the **Private Key** (node), **Public Cert** (clcerts), and **CA Chain** (cacerts).
    - Files are placed in `certs/` and used by the `modules/acm` module to import organization-specific certificates into AWS.
- **Secrets Zip**: Unzips `slingshot-aws-secret.zip` into a directory that is then mapped to AWS Secrets Manager using the `secrets-manager` module.

#### Phase 3: Dynamic Config Transformation (yq Logic)
- **EKS Public-to-Private**:
    1.  Pipeline reads `beginning_eks_access_toggle_private`.
    2.  If `false`, it sets `endpoint_public_access = true` in `config.yaml`.
    3.  Infra is deployed (allowing the pipeline runner to configure the cluster).
    4.  Pipeline reads `ending_eks_access_toggle_private`.
    5.  If `true`, it updates `endpoint_public_access = false` and re-applies, locking the cluster from the internet.

#### Phase 4: Phased Deployment (The Order)
1.  **VPC / Core**: Establishes the network boundary.
2.  **Secrets Manager**: Injects secrets (needed by applications).
3.  **ACM**: Imports SSL certificates (needed by Load Balancers).
4.  **EKS Cluster**: Creates the control plane.
5.  **Node Groups**: Joins EC2 workers to the cluster.
6.  **Add-ons**: Deploys Helm charts (ArgoCD, Istio, Monitoring) via the EKS controller.

---

## 🎛️ 4. Resource Toggles & Variable Mapping

### The "Enable Switch" Logic
In `live/prod/*/terragrunt.hcl`:
```hcl
skip = !try(include.root.inputs.resources.rds, true)
```
- **Scenario A**: `resources: { rds: true }` → `skip = false` (Module executes).
- **Scenario B**: `resources: { rds: false }` → `skip = true` (Module skipped).

### The Injection Path
1.  **User Definition**: `database: { instance_class: "db.t3.medium" }` in `config.yaml`.
2.  **Terragrunt Load**: Root `terragrunt.hcl` exposes this as `include.root.inputs.database`.
3.  **Module Mapping**: Child `terragrunt.hcl` passes `database = include.root.inputs.database`.
4.  **Terraform Execution**: `module.rds` receives the object and uses `var.database.instance_class`.
