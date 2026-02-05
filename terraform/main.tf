terraform {
  required_version = ">= 1.12.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0" # v3.0+ fixes compatibility with Terraform >= 1.12.1
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  project = local.project_id
  region  = local.region
}

provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

provider "helm" {
  kubernetes = {
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
}

data "google_client_config" "default" {}

module "gke" {
  source = "./modules/gke"

  # Wait for required APIs to be enabled
  depends_on = [google_project_service.required_apis]

  project_id   = local.project_id
  cluster_name = var.cluster_name
  region       = local.region
  zone         = local.zone

  # Cost-effective configuration for demo/testing
  machine_type       = var.machine_type
  preemptible        = var.preemptible
  spot_instances     = var.spot_instances
  min_node_count     = var.min_node_count
  max_node_count     = var.max_node_count
  initial_node_count = var.initial_node_count

  # Kubeflow-specific requirements
  disk_size_gb = var.disk_size_gb
  oauth_scopes = var.oauth_scopes

  # GKE version and learning mode
  release_channel      = var.release_channel
  learning_mode        = var.learning_mode
  enable_private_nodes = var.enable_private_nodes
}

module "kubeflow" {
  source = "./modules/kubeflow"

  depends_on = [module.gke]

  project_id   = local.project_id
  cluster_name = var.cluster_name
  region       = local.region
  domain       = var.domain
}