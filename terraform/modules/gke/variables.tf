variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "zones" {
  description = "List of zones for the cluster"
  type        = list(string)
}

variable "machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
}

variable "preemptible" {
  description = "Use preemptible nodes for cost savings"
  type        = bool
}

variable "min_node_count" {
  description = "Minimum number of nodes in the cluster"
  type        = number
}

variable "max_node_count" {
  description = "Maximum number of nodes in the cluster"
  type        = number
}

variable "initial_node_count" {
  description = "Initial number of nodes in the cluster"
  type        = number
}

variable "disk_size_gb" {
  description = "Disk size in GB for each node"
  type        = number
}

variable "oauth_scopes" {
  description = "OAuth scopes for GKE nodes"
  type        = list(string)
}