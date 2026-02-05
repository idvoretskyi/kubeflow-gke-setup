variable "project_id" {
  description = "GCP project ID (will auto-detect from gcloud config if not provided)"
  type        = string
  default     = "placeholder-project-id"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "kubeflow-cluster"
}

variable "region" {
  description = "GCP region (will auto-detect from gcloud config if not provided)"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for zonal cluster (will auto-detect from gcloud config if not provided). For demo/testing, zonal is more cost-effective than regional."
  type        = string
  default     = ""
}

variable "machine_type" {
  description = "Machine type for GKE nodes (e2-standard-4 for production, e2-medium for demo/testing)"
  type        = string
  default     = "e2-medium"
}

variable "preemptible" {
  description = "Use preemptible nodes for cost savings"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum number of nodes in the cluster"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes in the cluster (5 for demo, 10 for production)"
  type        = number
  default     = 5
}

variable "initial_node_count" {
  description = "Initial number of nodes in the cluster (2 for demo, 3 for production)"
  type        = number
  default     = 2
}

variable "disk_size_gb" {
  description = "Disk size in GB for each node (50 for demo, 100 for production)"
  type        = number
  default     = 50
}

variable "oauth_scopes" {
  description = "OAuth scopes for GKE nodes"
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/trace.append"
  ]
}

variable "domain" {
  description = "Domain name for Kubeflow (optional)"
  type        = string
  default     = ""
}

# =============================================================================
# GKE Version and Cluster Configuration
# =============================================================================

variable "release_channel" {
  description = <<-EOT
    GKE release channel for automatic Kubernetes version management.
    - RAPID: Latest K8s features (currently 1.35)
    - REGULAR: Balanced stability and features (currently 1.33)
    - STABLE: Most stable, production-ready (currently 1.33)
  EOT
  type        = string
  default     = "RAPID"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "UNSPECIFIED"], var.release_channel)
    error_message = "Release channel must be one of: RAPID, REGULAR, STABLE, UNSPECIFIED."
  }
}

variable "enable_private_nodes" {
  description = "Enable private nodes (no public IPs on nodes). Recommended for production."
  type        = bool
  default     = true
}

variable "spot_instances" {
  description = "Use Spot VMs instead of preemptible (newer, recommended). Spot VMs provide same 60-91% discount."
  type        = bool
  default     = true
}