resource "google_container_cluster" "primary" {
  name                = var.cluster_name
  location            = var.zone
  deletion_protection = false

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable IP alias for VPC-native networking
  ip_allocation_policy {}

  # Enable workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable maintenance policy
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Network configuration
  network    = "default"
  subnetwork = "default"

  # Private cluster configuration
  dynamic "private_cluster_config" {
    for_each = var.enable_private_nodes ? [1] : []
    content {
      enable_private_nodes    = true
      enable_private_endpoint = false
      master_ipv4_cidr_block  = "10.0.0.0/28"
    }
  }

  # Master authorized networks
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
    network_policy_config {
      disabled = true
    }
  }
}

# Create a separately managed node pool for cost optimization
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-nodes"
  location   = var.zone
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

    # Labels for cost tracking
    labels = {
      env         = "kubeflow"
      team        = "ml-platform"
      cost-center = "research"
    }

    # Taint to ensure only Kubeflow workloads schedule on these nodes
    taint {
      key    = "kubeflow"
      value  = "true"
      effect = "NO_SCHEDULE"
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