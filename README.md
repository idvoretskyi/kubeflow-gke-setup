# Kubeflow on GKE Setup

Automated deployment of Kubeflow 1.10.0 on Google Kubernetes Engine using Terraform with security hardening and cost optimization.

## Overview

This repository provides production-ready infrastructure-as-code for deploying Kubeflow on GKE with:

- **Automated deployment** via single command with gcloud configuration auto-detection
- **Cost optimization** using preemptible nodes with autoscaling (1-10 nodes)
- **Security hardening** including private nodes, least-privilege IAM, and configurable network access
- **ML pipeline examples** demonstrating end-to-end workflows
- **CI/CD validation** with automated Terraform, Python, and shell script testing

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

**Compute**:
- GKE cluster with preemptible nodes (e2-standard-4)
- Autoscaling: 1-10 nodes based on demand
- 100GB SSD per node

**Platform**:
- Kubeflow 1.10.0 (Jupyter, Pipelines, Katib, KServe)
- Istio 1.19.3 service mesh
- cert-manager 1.13.2

**Security**:
- Private cluster (no public master endpoint by default)
- Workload Identity for pod-to-GCP authentication
- Least-privilege IAM service accounts
- Network policies and binary authorization
- Shielded nodes with Secure Boot

**Estimated Cost**: $50-150/month depending on workload

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
- Preemptible nodes (80% cost reduction vs standard nodes)
- Node autoscaling (1-10 based on workload)
- Automatic storage lifecycle (30-day retention)
- Resource usage export to BigQuery for analysis

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