resource "google_container_cluster" "primary" {
  name               = var.cluster_name
  location           = var.region
  node_locations     = var.zones
  deletion_protection = false

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable network policy
  network_policy {
    enabled = true
  }

  # Enable IP alias for VPC-native networking
  ip_allocation_policy {}

  # Enable workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable binary authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Enable resource usage export
  resource_usage_export_config {
    enable_network_egress_metering       = true
    enable_resource_consumption_metering = true
    bigquery_destination {
      dataset_id = google_bigquery_dataset.gke_usage.dataset_id
    }
  }

  # Enable maintenance policy
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Enable cluster autoscaling
  cluster_autoscaling {
    enabled = true
    auto_provisioning_defaults {
      min_cpu_platform = "Intel Haswell"
      oauth_scopes     = var.oauth_scopes
      service_account  = google_service_account.gke_node_sa.email
    }
    resource_limits {
      resource_type = "cpu"
      minimum       = 1
      maximum       = 100
    }
    resource_limits {
      resource_type = "memory"
      minimum       = 1
      maximum       = 1000
    }
  }

  # Enable monitoring and logging
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # Enable cost management
  cost_management_config {
    enabled = true
  }

  # Network configuration
  network    = "default"
  subnetwork = "default"

  # Enable private nodes for security
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "10.0.0.0/28"
  }

  # Master authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All networks"
    }
  }

  # Release channel for automatic updates
  release_channel {
    channel = "REGULAR"
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
      disabled = false
    }
  }
}

# Create a separately managed node pool for cost optimization
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-nodes"
  location   = var.region
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
    preemptible     = var.preemptible
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
      env        = "kubeflow"
      team       = "ml-platform"
      cost-center = "research"
    }

    # Taints for Kubeflow workloads
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