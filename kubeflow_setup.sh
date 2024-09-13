#!/bin/bash

# Project and Zone Configuration
PROJECT_ID="your-project-id"  # Replace with your actual project ID
ZONE="your-zone"              # Replace with your desired zone (e.g., us-central1-a)
CLUSTER_NAME="kubeflow-cluster"

# Cost-Effective Cluster Configuration
MACHINE_TYPE="e2-small"        # Consider smaller machine types for cost optimization
NUM_NODES=3                    # Start with a minimal number of nodes
PREEMPTIBLE_NODES=true          # Use preemptible nodes if your workload allows

# Create the GKE Cluster
gcloud container clusters create $CLUSTER_NAME \
    --project $PROJECT_ID \
    --zone $ZONE \
    --machine-type $MACHINE_TYPE \
    --num-nodes $NUM_NODES \
    --preemptible \
    --enable-ip-alias \
    --enable-autoscaling --min-nodes 1 --max-nodes 5 # Enable autoscaling for flexibility

# Get Cluster Credentials
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID

# Install Kubeflow
KF_DIR=~/kfctl
mkdir -p $KF_DIR
cd $KF_DIR

curl --silent https://raw.githubusercontent.com/kubeflow/kfctl/master/scripts/download-kfctl.sh | bash
./kfctl apply -V -f https://raw.githubusercontent.com/kubeflow/manifests/master/kfdef/kfctl_gcp_iap.v1.3.0.yaml

echo "Kubeflow deployment initiated. It might take a while to complete. You can monitor the progress using 'kubectl get pods -n kubeflow' "