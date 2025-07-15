#!/bin/bash

# Kubeflow on GKE Deployment Script
# This script deploys a cost-effective Kubeflow cluster on Google Kubernetes Engine

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local tools=("terraform" "gcloud" "kubectl")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All prerequisites are installed."
}

# Check if user is authenticated with gcloud
check_gcloud_auth() {
    print_status "Checking gcloud authentication..."
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q @; then
        print_error "No active gcloud authentication found."
        print_error "Please run 'gcloud auth login' and try again."
        exit 1
    fi
    
    print_success "gcloud authentication is active."
}

# Check if terraform.tfvars exists and validate gcloud config
check_terraform_vars() {
    print_status "Checking Terraform configuration..."
    
    # Check if gcloud project is configured
    local current_project=$(gcloud config get-value project 2>/dev/null || echo "")
    local current_region=$(gcloud config get-value compute/region 2>/dev/null || echo "")
    local current_zone=$(gcloud config get-value compute/zone 2>/dev/null || echo "")
    
    if [ -z "$current_project" ]; then
        print_error "No default project configured in gcloud."
        print_error "Please run: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
    
    print_success "Detected gcloud configuration:"
    print_success "  Project: $current_project"
    print_success "  Region: ${current_region:-"(will derive from zone or use default)"}"
    print_success "  Zone: ${current_zone:-"(not set)"}"
    
    # Create terraform.tfvars if it doesn't exist
    if [ ! -f "terraform/terraform.tfvars" ]; then
        print_status "Creating terraform.tfvars from template..."
        cp terraform/terraform.tfvars.example terraform/terraform.tfvars
        print_success "Created terraform.tfvars - you can customize it if needed."
    else
        print_success "terraform.tfvars already exists."
    fi
    
    print_success "Terraform configuration is ready."
}

# Enable required GCP APIs
enable_gcp_apis() {
    print_status "Enabling required GCP APIs..."
    
    local apis=(
        "container.googleapis.com"
        "compute.googleapis.com"
        "storage.googleapis.com"
        "bigquery.googleapis.com"
        "cloudbuild.googleapis.com"
        "monitoring.googleapis.com"
        "logging.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        print_status "Enabling $api..."
        gcloud services enable $api --quiet
    done
    
    print_success "GCP APIs enabled."
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan the deployment
    print_status "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    # Apply the deployment
    print_status "Applying Terraform deployment..."
    terraform apply tfplan
    
    cd ..
    
    print_success "Infrastructure deployment completed."
}

# Configure kubectl
configure_kubectl() {
    print_status "Configuring kubectl..."
    
    # Get cluster credentials using the kubeconfig command from Terraform
    local kubeconfig_cmd=$(cd terraform && terraform output -raw kubeconfig_command 2>/dev/null || echo "")
    
    if [ -z "$kubeconfig_cmd" ]; then
        print_error "Could not determine kubeconfig command from Terraform output."
        exit 1
    fi
    
    eval $kubeconfig_cmd
    
    print_success "kubectl configured successfully."
}

# Wait for Kubeflow to be ready
wait_for_kubeflow() {
    print_status "Waiting for Kubeflow to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Checking Kubeflow readiness... (attempt $attempt/$max_attempts)"
        
        # Check if all pods in kubeflow namespace are ready
        if kubectl get pods -n kubeflow --no-headers | grep -q "0/"; then
            print_status "Some pods are not ready yet. Waiting..."
            sleep 30
            ((attempt++))
        else
            print_success "Kubeflow is ready!"
            return 0
        fi
    done
    
    print_warning "Kubeflow pods are still not ready after $max_attempts attempts."
    print_warning "You can check the status manually with: kubectl get pods -n kubeflow"
}

# Display deployment information
display_info() {
    print_status "Retrieving deployment information..."
    
    cd terraform
    
    echo ""
    echo "==================== DEPLOYMENT SUMMARY ===================="
    echo ""
    
    # Detected configuration
    echo "Detected gcloud Configuration:"
    terraform output detected_config 2>/dev/null || echo "  Configuration not available"
    echo ""
    
    # Cluster information
    echo "Cluster Information:"
    echo "  Name: $(terraform output -raw cluster_name 2>/dev/null || echo 'N/A')"
    echo ""
    
    # Kubeflow endpoint
    local kubeflow_endpoint=$(terraform output -raw kubeflow_endpoint 2>/dev/null || echo 'N/A')
    echo "Kubeflow Dashboard: $kubeflow_endpoint"
    echo ""
    
    # Cost estimation
    echo "Cost Estimation:"
    terraform output estimated_monthly_cost 2>/dev/null || echo "  Cost estimation not available"
    echo ""
    
    # Kubectl configuration
    echo "kubectl Configuration:"
    echo "  $(terraform output -raw kubeconfig_command 2>/dev/null || echo 'N/A')"
    echo ""
    
    # Useful commands
    echo "Useful Commands:"
    echo "  Check cluster status: kubectl get nodes"
    echo "  Check Kubeflow pods: kubectl get pods -n kubeflow"
    echo "  Get services: kubectl get svc -n kubeflow"
    echo "  Monitor logs: kubectl logs -n kubeflow -l app.kubernetes.io/name=centraldashboard"
    echo ""
    
    echo "=========================================================="
    
    cd ..
}

# Main deployment function
main() {
    print_status "Starting Kubeflow on GKE deployment..."
    
    # Check prerequisites
    check_prerequisites
    check_gcloud_auth
    check_terraform_vars
    
    # Enable GCP APIs
    enable_gcp_apis
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Configure kubectl
    configure_kubectl
    
    # Wait for Kubeflow
    wait_for_kubeflow
    
    # Display information
    display_info
    
    print_success "Kubeflow on GKE deployment completed successfully!"
    print_status "You can now access your Kubeflow dashboard and start building ML pipelines."
}

# Handle script arguments
case "${1:-}" in
    "destroy")
        print_status "Destroying infrastructure..."
        cd terraform
        terraform destroy -auto-approve
        cd ..
        print_success "Infrastructure destroyed."
        ;;
    "info")
        display_info
        ;;
    "")
        main
        ;;
    *)
        echo "Usage: $0 [destroy|info]"
        echo "  (no args) - Deploy Kubeflow on GKE"
        echo "  destroy   - Destroy the infrastructure"
        echo "  info      - Display deployment information"
        exit 1
        ;;
esac