# Kubeflow on GKE Setup

Production-grade, cost-optimized deployment of Kubeflow 1.10.0 on Google Kubernetes Engine using Terraform.

## Quick Start

**Prerequisites**: GCP account with billing enabled, `gcloud`, `terraform`, `kubectl` installed.

```bash
git clone https://github.com/idvoretskyi/kubeflow-gke-setup.git
cd kubeflow-gke-setup/terraform

gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default login

terraform init
terraform plan
terraform apply
```

Terraform auto-detects your gcloud configuration (project, region, zone).

## What Gets Deployed

- **GKE zonal cluster** with Spot VMs and autoscaling (1-10 nodes)
- **Kubeflow 1.10.0** with Jupyter, Pipelines, Katib, KServe
- **Istio 1.19.3** service mesh + **cert-manager 1.13.2**
- **Security**: private nodes, Workload Identity, least-privilege IAM, shielded nodes

**Estimated cost**: $30-100/month with Spot VMs (60-91% savings vs on-demand).

## Configuration

Copy and edit the example tfvars:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Key variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `release_channel` | `RAPID` | GKE release channel (RAPID/REGULAR/STABLE) |
| `spot_instances` | `true` | Use Spot VMs for cost savings |
| `enable_private_nodes` | `true` | Private nodes (no public IPs) |
| `machine_type` | `e2-medium` | Node machine type |
| `min_node_count` / `max_node_count` | 1 / 5 | Autoscaling range |

To allow API access from specific IPs:

```hcl
master_authorized_networks = [
  { cidr_block = "YOUR_IP/32", display_name = "Workstation" }
]
```

## Usage

```bash
# View outputs (endpoints, kubeconfig command, etc.)
terraform -chdir=terraform output

# Access Kubeflow dashboard securely via port-forward
# Get the exact command from Terraform outputs:
terraform -chdir=terraform output kubeflow_access_command

# Or run directly:
kubectl port-forward -n kubeflow svc/kubeflow-dashboard-svc 8080:80
# Then open http://localhost:8080

# Run ML pipelines
cd examples/sample-ml-app
python data_generator.py
python run_pipeline.py \
    --kubeflow-endpoint http://localhost:8080 \
    --bucket-name your-gcs-bucket \
    --data-file sample_datasets/classification_data.csv

# Destroy
terraform -chdir=terraform destroy
```

## Security

### Secure Dashboard Access

The Kubeflow dashboard is **not exposed to the public internet** by default. Access is via `kubectl port-forward`, which provides:

- ✅ **No public exposure** - dashboard only accessible via authenticated kubectl
- ✅ **Encrypted transit** - kubectl creates an encrypted tunnel to GKE
- ✅ **Authentication** - requires valid GKE/Google Cloud credentials
- ✅ **Zero cost** - no load balancer fees

### HTTPS for Production (Optional)

For production deployments requiring HTTPS, see [terraform/modules/kubeflow/SECURITY.md](terraform/modules/kubeflow/SECURITY.md) for:
- Google-managed SSL certificates
- HTTPS Ingress configuration
- Identity-Aware Proxy (IAP) setup
- Cost and architecture considerations

## License

MIT License - see [LICENSE](LICENSE) file.
