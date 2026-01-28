# Kubeflow on GKE Setup

Automated deployment of Kubeflow 1.10.0 on Google Kubernetes Engine using Terraform - perfect for **learning, demos, and experimentation** with cost optimization and security hardening.

## Overview

This repository provides a **learning-friendly** infrastructure-as-code deployment for Kubeflow on GKE with:

- **Latest Kubernetes** via GKE RAPID channel (currently K8s 1.35)
- **Learning mode** that simplifies pod scheduling and networking for beginners
- **Cost optimization** using Spot VMs with autoscaling (60-91% savings)
- **Automated deployment** with gcloud configuration auto-detection
- **ML pipeline examples** demonstrating end-to-end workflows
- **Security hardening** for production readiness when needed

### Release Channels

| Channel | K8s Version | Best For |
|---------|-------------|----------|
| **RAPID** (default) | 1.35 | Learning, demos, testing latest features |
| REGULAR | 1.33 | Balanced stability and features |
| STABLE | 1.33 | Production workloads |

## Quick Start

### Prerequisites

- GCP account with billing enabled
- `gcloud`, `terraform`, and `kubectl` installed

### Deployment

```bash
git clone https://github.com/idvoretskyi/kubeflow-gke-setup.git
cd kubeflow-gke-setup/terraform

# Configure your GCP project
gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default login

# Initialize and deploy
terraform init
terraform plan
terraform apply
```

Terraform auto-detects gcloud configuration and provisions all infrastructure.

## Infrastructure Components

**Kubernetes**:
- GKE cluster with **RAPID release channel** (Kubernetes 1.35)
- Spot VMs for cost savings (e2-standard-4)
- Autoscaling: 1-10 nodes based on demand
- 100GB SSD per node

**Platform**:
- Kubeflow 1.10.0 (Jupyter, Pipelines, Katib, KServe)
- Istio 1.19.3 service mesh
- cert-manager 1.13.2

**Learning Mode Features**:
- Node taints disabled for easy pod scheduling
- Simplified networking for beginners
- Quick start commands in Terraform output

**Security** (can be configured for production):
- Private cluster (configurable)
- Workload Identity for pod-to-GCP authentication
- Least-privilege IAM service accounts
- Network policies and binary authorization
- Shielded nodes with Secure Boot

**Estimated Cost**: $30-100/month with Spot VMs (60-91% savings vs on-demand)

## Usage

### Running ML Pipelines

```bash
cd examples/sample-ml-app
python data_generator.py
python run_pipeline.py \
    --kubeflow-endpoint http://YOUR_CLUSTER_IP \
    --bucket-name your-gcs-bucket \
    --data-file sample_datasets/classification_data.csv
```

### Cluster Management

```bash
cd terraform

# View current state
terraform show

# View outputs (cluster endpoint, etc.)
terraform output

# Destroy infrastructure
terraform destroy

# Monitor Kubeflow components
kubectl get pods -n kubeflow
```

## Configuration

### Learning Mode vs Production Mode

This project defaults to **learning mode** for easier experimentation:

```hcl
# terraform/terraform.tfvars

# Learning mode (default) - easier for demos and learning
learning_mode = true           # No node taints, pods schedule freely
release_channel = "RAPID"      # Latest Kubernetes (1.35)
spot_instances = true          # Cost savings

# Production mode - stricter security
learning_mode = false          # Node taints enabled
release_channel = "STABLE"     # Production-ready Kubernetes
spot_instances = false         # On-demand VMs for reliability
```

### Release Channel Selection

Choose the GKE release channel based on your needs:

```hcl
# Latest features for learning (Kubernetes 1.35)
release_channel = "RAPID"

# Balanced for most use cases (Kubernetes 1.33)
release_channel = "REGULAR"

# Production stability (Kubernetes 1.33)
release_channel = "STABLE"
```

### Master Authorized Networks

By default, the Kubernetes API is not publicly accessible. To enable access from specific IP addresses:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
master_authorized_networks = [
  {
    cidr_block   = "YOUR_IP/32"
    display_name = "Workstation"
  }
]
```

Apply configuration:

```bash
cd terraform
terraform apply
```

Without configured authorized networks, cluster access is limited to GCP Console and Cloud Shell.

## Architecture

**Infrastructure**:
- Modular Terraform codebase with separate GKE and Kubeflow modules
- Auto-detection of gcloud project, region, and zone configuration
- Automated BigQuery dataset creation for cost tracking

**Security Model**:
- Private GKE cluster with configurable master authorized networks
- Workload Identity binding between Kubernetes and GCP service accounts
- IAM roles following least-privilege principle:
  - `storage.objectAdmin` (not `storage.admin`)
  - `bigquery.dataEditor` (not `bigquery.admin`)
  - `aiplatform.user` (not `ml.admin`)
- Network policies and binary authorization enabled

**Cost Controls**:
- Spot VMs (60-91% cost reduction vs on-demand)
- Node autoscaling (1-10 based on workload)
- Automatic storage lifecycle (30-day retention)
- Resource usage export to BigQuery for analysis

**Learning Mode**:
- Configurable node taints (disabled by default in learning mode)
- RAPID release channel for latest Kubernetes features
- Helpful output commands for quick start

## Troubleshooting

Verify Terraform configuration:
```bash
cd terraform
terraform validate
terraform plan
```

Check gcloud authentication:
```bash
gcloud auth application-default login
gcloud config list
```

Common diagnostics:
```bash
kubectl get nodes
kubectl get pods -n kubeflow
kubectl logs <pod-name> -n kubeflow
```

## Development

**Testing**:
```bash
cd terraform
terraform fmt -check -recursive      # Check formatting
terraform validate                    # Validate configuration
cd ../examples/sample-ml-app
python -m py_compile *.py             # Python syntax
```

**CI/CD**:
- Automated validation via GitHub Actions
- Terraform format and validation checks
- Python syntax verification

## Recent Changes

**Learning Platform Enhancement** (January 2025):
- Added **RAPID release channel** support for latest Kubernetes (1.35)
- Introduced **learning mode** that disables node taints for easier experimentation
- Replaced preemptible with **Spot VMs** (newer API, same cost savings)
- Added configurable release channel (RAPID/REGULAR/STABLE)
- Enhanced outputs with quick start commands and version information
- Updated documentation for learning/demo use cases

**Security** (December 2024):
- Reduced IAM permissions to least-privilege roles
- Configurable master authorized networks (default: no public access)
- Added CIDR validation for network configurations

**Code Quality**:
- Fixed Python package version inconsistencies across pipeline components
- Refactored bash scripts with shared utility library (`scripts/lib/common.sh`)
- Updated Terraform syntax for Helm provider v3.x compatibility

## License

MIT License - see [LICENSE](LICENSE) file.