variable "project_id" {
  description = "GCP project ID (will auto-detect from gcloud config if not provided)"
  type        = string
  default     = ""
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

variable "zones_override" {
  description = "Override zones (if not provided, will generate from region)"
  type        = list(string)
  default     = null
}

variable "machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-4"
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
  description = "Maximum number of nodes in the cluster"
  type        = number
  default     = 10
}

variable "initial_node_count" {
  description = "Initial number of nodes in the cluster"
  type        = number
  default     = 3
}

variable "disk_size_gb" {
  description = "Disk size in GB for each node"
  type        = number
  default     = 100
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