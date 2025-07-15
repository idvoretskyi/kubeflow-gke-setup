#!/bin/bash

# Check current gcloud configuration script
# This script helps verify your gcloud configuration before deployment

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

print_status "Checking your current gcloud configuration..."

echo ""
echo "======================= GCLOUD CONFIGURATION ======================="
echo ""

# Check authentication
print_status "Authentication:"
current_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null || echo "")
if [ -n "$current_account" ]; then
    print_success "  Active account: $current_account"
else
    print_error "  No active authentication found"
    print_error "  Please run: gcloud auth login"
    echo ""
fi

# Check project
print_status "Project:"
current_project=$(gcloud config get-value project 2>/dev/null || echo "")
if [ -n "$current_project" ]; then
    print_success "  Current project: $current_project"
else
    print_warning "  No default project set"
    print_warning "  Please run: gcloud config set project YOUR_PROJECT_ID"
    echo ""
fi

# Check region
print_status "Region:"
current_region=$(gcloud config get-value compute/region 2>/dev/null || echo "")
if [ -n "$current_region" ]; then
    print_success "  Current region: $current_region"
else
    print_warning "  No default region set"
    print_warning "  Will use default: us-central1"
    print_warning "  To set region: gcloud config set compute/region YOUR_REGION"
    echo ""
fi

# Check zone
print_status "Zone:"
current_zone=$(gcloud config get-value compute/zone 2>/dev/null || echo "")
if [ -n "$current_zone" ]; then
    print_success "  Current zone: $current_zone"
    
    # Extract region from zone if region is not set
    if [ -z "$current_region" ]; then
        zone_region=$(echo $current_zone | cut -d'-' -f1,2)
        print_success "  Region derived from zone: $zone_region"
    fi
else
    print_warning "  No default zone set"
    print_warning "  This is optional - zones will be auto-generated"
    echo ""
fi

# Check billing
if [ -n "$current_project" ]; then
    print_status "Billing:"
    billing_account=$(gcloud billing projects describe $current_project --format="value(billingAccountName)" 2>/dev/null || echo "")
    if [ -n "$billing_account" ]; then
        print_success "  Billing is enabled for project $current_project"
    else
        print_warning "  Could not verify billing status"
        print_warning "  Please ensure billing is enabled for your project"
    fi
    echo ""
fi

# Check quotas (basic check)
if [ -n "$current_project" ] && [ -n "$current_region" ]; then
    print_status "Checking basic quotas..."
    
    # Check if APIs are enabled
    container_api=$(gcloud services list --enabled --filter="name:container.googleapis.com" --format="value(name)" 2>/dev/null || echo "")
    if [ -n "$container_api" ]; then
        print_success "  Container API is enabled"
    else
        print_warning "  Container API is not enabled (will be enabled during deployment)"
    fi
    
    compute_api=$(gcloud services list --enabled --filter="name:compute.googleapis.com" --format="value(name)" 2>/dev/null || echo "")
    if [ -n "$compute_api" ]; then
        print_success "  Compute API is enabled"
    else
        print_warning "  Compute API is not enabled (will be enabled during deployment)"
    fi
    echo ""
fi

# Summary
echo "========================== SUMMARY =========================="
echo ""

final_project=${current_project:-"NOT_SET"}
final_region=${current_region:-$(echo $current_zone | cut -d'-' -f1,2 2>/dev/null || echo "us-central1")}
final_zones="[\"${final_region}-a\", \"${final_region}-b\", \"${final_region}-c\"]"

echo "Configuration that will be used for deployment:"
echo "  Project ID: $final_project"
echo "  Region: $final_region"
echo "  Zones: $final_zones"
echo "  Account: $current_account"
echo ""

# Check if ready for deployment
if [ -n "$current_account" ] && [ -n "$current_project" ]; then
    print_success "✅ Ready for deployment!"
    echo ""
    echo "To deploy Kubeflow on GKE:"
    echo "  ./scripts/deploy.sh"
    echo ""
else
    print_error "❌ Not ready for deployment!"
    echo ""
    echo "Required actions:"
    if [ -z "$current_account" ]; then
        echo "  1. Authenticate with gcloud: gcloud auth login"
    fi
    if [ -z "$current_project" ]; then
        echo "  2. Set default project: gcloud config set project YOUR_PROJECT_ID"
    fi
    echo ""
fi

# Show useful commands
echo "======================== USEFUL COMMANDS ========================"
echo ""
echo "Configure gcloud:"
echo "  gcloud auth login                                    # Authenticate"
echo "  gcloud config set project YOUR_PROJECT_ID           # Set project"
echo "  gcloud config set compute/region us-central1        # Set region"
echo "  gcloud config set compute/zone us-central1-a        # Set zone"
echo ""
echo "View current configuration:"
echo "  gcloud config list                                  # Show all config"
echo "  gcloud auth list                                    # Show accounts"
echo "  gcloud projects list                                # List projects"
echo ""
echo "Enable required APIs manually (optional):"
echo "  gcloud services enable container.googleapis.com     # GKE API"
echo "  gcloud services enable compute.googleapis.com       # Compute API"
echo "  gcloud services enable storage.googleapis.com       # Storage API"
echo ""
echo "================================================================="