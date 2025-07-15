terraform {
  required_version = ">= 1.12.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
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
  kubernetes {
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
}

data "google_client_config" "default" {}

module "gke" {
  source = "./modules/gke"

  project_id     = local.project_id
  cluster_name   = var.cluster_name
  region         = local.region
  zones          = local.zones
  
  # Cost-effective configuration
  machine_type       = var.machine_type
  preemptible        = var.preemptible
  min_node_count     = var.min_node_count
  max_node_count     = var.max_node_count
  initial_node_count = var.initial_node_count
  
  # Kubeflow-specific requirements
  disk_size_gb = var.disk_size_gb
  oauth_scopes = var.oauth_scopes
}

module "kubeflow" {
  source = "./modules/kubeflow"
  
  depends_on = [module.gke]
  
  project_id   = local.project_id
  cluster_name = var.cluster_name
  region       = local.region
  domain       = var.domain
}