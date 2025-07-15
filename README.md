# Kubeflow on GKE Setup

Deploy Kubeflow on Google Kubernetes Engine (GKE) with Terraform - cost-optimized and automated.

## Features

- **🚀 One-command deployment** with auto-configuration
- **💰 Cost-optimized** with preemptible nodes and autoscaling
- **🔒 Secure** with private nodes and workload identity
- **📊 Sample ML pipeline** included

## Quick Start

### Prerequisites

- GCP account with billing enabled
- `gcloud`, `terraform`, and `kubectl` installed

### Deploy

```bash
# 1. Clone and setup
git clone https://github.com/idvoretskyi/kubeflow-gke-setup.git
cd kubeflow-gke-setup

# 2. Set your GCP project
gcloud config set project YOUR_PROJECT_ID

# 3. Deploy everything
./scripts/deploy.sh
```

That's it! The script auto-detects your gcloud configuration and deploys everything.

## What You Get

- **GKE cluster** with preemptible nodes (1-10 auto-scaling)
- **Kubeflow 1.8.0** with Jupyter notebooks, pipelines, and model serving
- **Cost estimation**: ~$50-150/month depending on usage
- **Security**: Private nodes, workload identity, network policies

## Sample ML Pipeline

```bash
# Generate sample data
cd examples/sample-ml-app
python data_generator.py

# Run ML pipeline
python run_pipeline.py \
    --kubeflow-endpoint http://YOUR_CLUSTER_IP \
    --bucket-name your-gcs-bucket \
    --data-file sample_datasets/classification_data.csv
```

## Management

```bash
# Check status
./scripts/deploy.sh info

# Destroy everything
./scripts/deploy.sh destroy

# Monitor cluster
kubectl get pods -n kubeflow
```

## Troubleshooting

**Authentication issues:**
```bash
gcloud auth login
```

**Check your config:**
```bash
./scripts/check-config.sh
```

**Common commands:**
```bash
kubectl get nodes                    # Check cluster
kubectl get pods -n kubeflow        # Check Kubeflow
kubectl logs POD_NAME -n kubeflow   # Check logs
```

## Architecture

- **Terraform** for infrastructure as code
- **GKE** with cost-optimized configuration
- **Kubeflow** with Istio service mesh
- **Auto-detection** of gcloud project/region

## Cost Optimization

- **Preemptible nodes**: Up to 80% cost savings
- **Autoscaling**: 1-10 nodes based on demand
- **Efficient resources**: e2-standard-4 instances
- **Storage**: 100GB SSD per node

## Contributing

1. Fork the repository
2. Make your changes
3. Test with `./scripts/deploy.sh`
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file.