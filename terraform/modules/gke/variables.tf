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

variable "zone" {
  description = "GCP zone for the zonal cluster (required). Only zonal clusters are supported for cost optimization."
  type        = string

  validation {
    condition     = length(var.zone) > 0
    error_message = "Zone must be specified. Only zonal clusters are supported (e.g., 'us-east1-c')."
  }
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

variable "master_authorized_networks" {
  description = "List of CIDR blocks authorized to access the Kubernetes master. Leave empty to disable external access to the master endpoint."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []

  validation {
    condition = alltrue([
      for network in var.master_authorized_networks :
      can(cidrhost(network.cidr_block, 0))
    ])
    error_message = "All cidr_block values must be valid CIDR notation (e.g., '203.0.113.0/24')."
  }
}

# =============================================================================
# GKE Version and Cluster Configuration
# =============================================================================

variable "release_channel" {
  description = "GKE release channel: RAPID (latest K8s 1.35), REGULAR (1.33), STABLE (1.33)"
  type        = string
  default     = "RAPID"
}

variable "enable_private_nodes" {
  description = "Enable private nodes (no public IPs on nodes). For demo/testing: false (no NAT cost). For production: true (more secure)."
  type        = bool
  default     = false
}

variable "spot_instances" {
  description = "Use Spot VMs instead of preemptible (newer API, same discount)"
  type        = bool
  default     = true
}