resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone != "" ? var.zone : var.region
  # For zonal clusters: node_locations should be null (nodes in same zone as control plane)
  # For regional clusters: node_locations can specify additional zones
  node_locations      = var.zone == "" && length(var.zones) > 0 ? var.zones : null
  deletion_protection = false

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network policy - disabled for learning mode (can cause conflicts with Dataplane V2)
  # Enable manually for production use with proper Dataplane configuration
  # network_policy {
  #   enabled = true
  # }

  # Enable IP alias for VPC-native networking
  ip_allocation_policy {}

  # Enable workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Binary authorization disabled for learning mode
  # Uncomment for production use (requires Binary Authorization API)
  # binary_authorization {
  #   evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  # }

  # Resource usage export disabled for learning mode
  # Uncomment for production cost tracking
  # resource_usage_export_config {
  #   enable_network_egress_metering       = true
  #   enable_resource_consumption_metering = true
  #   bigquery_destination {
  #     dataset_id = google_bigquery_dataset.gke_usage.dataset_id
  #   }
  # }

  # Enable maintenance policy
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Cluster autoscaling (node auto-provisioning) - disabled for simplicity in learning mode
  # cluster_autoscaling {
  #   enabled = true
  #   auto_provisioning_defaults {
  #     oauth_scopes    = var.oauth_scopes
  #     service_account = google_service_account.gke_node_sa.email
  #   }
  #   resource_limits {
  #     resource_type = "cpu"
  #     minimum       = 1
  #     maximum       = 100
  #   }
  #   resource_limits {
  #     resource_type = "memory"
  #     minimum       = 1
  #     maximum       = 1000
  #   }
  # }

  # Monitoring and logging - use defaults for learning mode
  # monitoring_config {
  #   enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  # }

  # logging_config {
  #   enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  # }

  # Cost management - disabled for learning mode (requires GKE Enterprise or additional setup)
  # cost_management_config {
  #   enabled = true
  # }

  # Network configuration
  network    = "default"
  subnetwork = "default"

  # Private cluster configuration
  # For learning mode, private nodes can be disabled for easier access
  dynamic "private_cluster_config" {
    for_each = var.enable_private_nodes ? [1] : []
    content {
      enable_private_nodes    = true
      enable_private_endpoint = false
      master_ipv4_cidr_block  = "10.0.0.0/28"
    }
  }

  # Master authorized networks
  # Configurable list of authorized networks for enhanced security
  # Default: empty list (no external access, only via GCP Console)
  # To allow specific IPs: set master_authorized_networks variable
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  # Release channel for automatic updates
  # RAPID = Latest K8s (1.35), REGULAR = Balanced (1.33), STABLE = Production (1.33)
  release_channel {
    channel = var.release_channel
  }

  # Enable shielded nodes
  enable_shielded_nodes = true

  # Addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    # Network policy addon disabled for learning mode
    network_policy_config {
      disabled = true
    }
  }
}

# Create a separately managed node pool for cost optimization
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-nodes"
  location   = var.zone != "" ? var.zone : var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.initial_node_count

  # Enable autoscaling
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  # Enable auto-upgrade and auto-repair
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    # Use Spot VMs (recommended) or preemptible for cost savings (60-91% discount)
    spot            = var.spot_instances
    preemptible     = var.spot_instances ? false : var.preemptible
    machine_type    = var.machine_type
    disk_size_gb    = var.disk_size_gb
    disk_type       = "pd-ssd"
    service_account = google_service_account.gke_node_sa.email
    oauth_scopes    = var.oauth_scopes

    # Enable workload identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Shielded instance config
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Labels for cost tracking and learning mode identification
    labels = {
      env           = "kubeflow"
      team          = "ml-platform"
      cost-center   = "research"
      learning-mode = var.learning_mode ? "enabled" : "disabled"
    }

    # Taints for Kubeflow workloads - disabled in learning mode for easier experimentation
    dynamic "taint" {
      for_each = var.learning_mode ? [] : [1]
      content {
        key    = "kubeflow"
        value  = "true"
        effect = "NO_SCHEDULE"
      }
    }

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# Service account for GKE nodes
resource "google_service_account" "gke_node_sa" {
  account_id   = "${var.cluster_name}-node-sa"
  display_name = "GKE Node Service Account for ${var.cluster_name}"
  description  = "Service account for GKE nodes in ${var.cluster_name}"
}

# IAM bindings for the node service account
resource "google_project_iam_member" "gke_node_sa_bindings" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/storage.objectViewer"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# BigQuery dataset for cost tracking
resource "google_bigquery_dataset" "gke_usage" {
  dataset_id                  = "${replace(var.cluster_name, "-", "_")}_usage"
  friendly_name               = "GKE Usage Data for ${var.cluster_name}"
  description                 = "Dataset containing GKE resource usage data"
  location                    = "US"
  default_table_expiration_ms = 2592000000 # 30 days

  access {
    role          = "OWNER"
    user_by_email = google_service_account.gke_node_sa.email
  }
}