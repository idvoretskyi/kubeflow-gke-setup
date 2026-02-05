# Kubeflow on GKE

Deploy a production-ready Kubeflow 1.11.0 environment on Google Kubernetes Engine using Terraform. This setup is cost-optimized using Spot VMs and GKE autoscaling.

## Quick Start

### Prerequisites
- Google Cloud account with billing enabled.
- `gcloud`, `terraform`, and `kubectl` installed.

### Deployment
1. Clone the repository and navigate to the terraform directory:
   ```bash
   git clone https://github.com/idvoretskyi/kubeflow-gke-setup.git
   cd kubeflow-gke-setup/terraform
   ```
2. Configure Google Cloud:
   ```bash
   gcloud config set project YOUR_PROJECT_ID
   gcloud auth application-default login
   ```
3. Initialize and deploy:
   ```bash
   terraform init
   terraform apply
   ```

## Infrastructure
- **GKE Cluster**: Zonal cluster with Spot VMs and 1-10 nodes autoscaling.
- **Kubeflow 1.11.0**: Includes Jupyter, Pipelines, Katib, and KServe.
- **Service Mesh**: Istio 1.28.0 and cert-manager 1.16.1.
- **Security**: Private nodes, Workload Identity, and shielded nodes.
- **Cost**: Estimated $30-100/month (60-91% savings vs on-demand).

## Configuration

Customize the deployment by editing `terraform.tfvars`:
```bash
cp terraform.tfvars.example terraform.tfvars
```

| Variable | Default | Description |
|----------|---------|-------------|
| `release_channel` | `RAPID` | GKE release channel (RAPID/REGULAR/STABLE) |
| `spot_instances` | `true` | Use Spot VMs for cost savings |
| `enable_private_nodes` | `true` | Deploy nodes without public IPs |
| `machine_type` | `e2-medium` | GCE instance type for nodes |
| `min_node_count` / `max_node_count` | 1 / 5 | Node pool autoscaling limits |
| `enable_gpu` | `false` | Enable a single T4 GPU node |

## Accessing the Dashboard

The Kubeflow dashboard is not exposed to the public internet by default. Use port forwarding for secure access:

1. Run the access command:
   ```bash
   kubectl port-forward -n kubeflow svc/kubeflow-dashboard-svc 8080:80
   ```
2. Open `http://localhost:8080` in your browser.

## Running Pipelines

Follow the example in `examples/sample-ml-app`:
```bash
cd ../examples/sample-ml-app
python data_generator.py
python run_pipeline.py \
    --kubeflow-endpoint http://localhost:8080 \
    --bucket-name your-gcs-bucket \
    --data-file sample_datasets/classification_data.csv
```

## Security and Production

For production environments requiring HTTPS, Google-managed SSL certificates, and Identity-Aware Proxy (IAP), see [terraform/modules/kubeflow/SECURITY.md](terraform/modules/kubeflow/SECURITY.md).

## Cleanup

To remove all resources and stop billing:
```bash
cd terraform
terraform destroy
```

## License
MIT License. See [LICENSE](LICENSE) for details.
