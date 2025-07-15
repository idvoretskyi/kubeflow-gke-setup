locals {
  kubeflow_version = "1.8.0"
  kustomize_version = "5.0.1"
}

# Create namespace for Kubeflow
resource "kubernetes_namespace" "kubeflow" {
  metadata {
    name = "kubeflow"
    labels = {
      "app.kubernetes.io/name" = "kubeflow"
      "app.kubernetes.io/version" = local.kubeflow_version
    }
  }
}

resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
    labels = {
      "app.kubernetes.io/name" = "istio-system"
    }
  }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
    labels = {
      "app.kubernetes.io/name" = "cert-manager"
    }
  }
}

# Install cert-manager using Helm
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.13.2"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = kubernetes_namespace.cert_manager.metadata[0].name
  }

  depends_on = [kubernetes_namespace.cert_manager]
}

# Install Istio using Helm
resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = "1.19.3"
  namespace  = kubernetes_namespace.istio_system.metadata[0].name

  depends_on = [kubernetes_namespace.istio_system]
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = "1.19.3"
  namespace  = kubernetes_namespace.istio_system.metadata[0].name

  depends_on = [helm_release.istio_base]
}

# Install Kubeflow using manifest files
resource "kubernetes_manifest" "kubeflow_manifests" {
  count = length(local.kubeflow_manifests)
  
  manifest = yamldecode(local.kubeflow_manifests[count.index])
  
  depends_on = [
    kubernetes_namespace.kubeflow,
    helm_release.cert_manager,
    helm_release.istiod
  ]
}

# Local values for Kubeflow manifests
locals {
  kubeflow_manifests = [
    # Core Kubeflow components
    file("${path.module}/manifests/kubeflow-core.yaml"),
    file("${path.module}/manifests/kubeflow-pipeline.yaml"),
    file("${path.module}/manifests/kubeflow-notebook.yaml"),
    file("${path.module}/manifests/kubeflow-katib.yaml"),
    file("${path.module}/manifests/kubeflow-serving.yaml"),
  ]
}

# Create a service account for Kubeflow
resource "kubernetes_service_account" "kubeflow_sa" {
  metadata {
    name      = "kubeflow-service-account"
    namespace = kubernetes_namespace.kubeflow.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.kubeflow_gcp_sa.email
    }
  }
}

# Create GCP service account for Kubeflow
resource "google_service_account" "kubeflow_gcp_sa" {
  account_id   = "${var.cluster_name}-kubeflow-sa"
  display_name = "Kubeflow Service Account for ${var.cluster_name}"
  description  = "Service account for Kubeflow workloads"
}

# IAM bindings for Kubeflow service account
resource "google_project_iam_member" "kubeflow_sa_bindings" {
  for_each = toset([
    "roles/storage.admin",
    "roles/bigquery.admin",
    "roles/ml.admin",
    "roles/cloudsql.client",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.kubeflow_gcp_sa.email}"
}

# Workload Identity binding
resource "google_service_account_iam_binding" "kubeflow_workload_identity" {
  service_account_id = google_service_account.kubeflow_gcp_sa.name
  role               = "roles/iam.workloadIdentityUser"
  
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${kubernetes_namespace.kubeflow.metadata[0].name}/${kubernetes_service_account.kubeflow_sa.metadata[0].name}]"
  ]
}

# Create LoadBalancer service for Kubeflow Central Dashboard
resource "kubernetes_service" "kubeflow_dashboard" {
  metadata {
    name      = "kubeflow-dashboard-lb"
    namespace = kubernetes_namespace.kubeflow.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "kubeflow-dashboard"
    }
  }

  spec {
    type = "LoadBalancer"
    
    selector = {
      "app.kubernetes.io/name" = "centraldashboard"
    }

    port {
      port        = 80
      target_port = 8082
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_manifest.kubeflow_manifests]
}

# Create Cloud Storage bucket for Kubeflow artifacts
resource "google_storage_bucket" "kubeflow_artifacts" {
  name          = "${var.project_id}-kubeflow-artifacts"
  location      = "US"
  force_destroy = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

# Grant storage access to Kubeflow service account
resource "google_storage_bucket_iam_member" "kubeflow_storage_access" {
  bucket = google_storage_bucket.kubeflow_artifacts.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.kubeflow_gcp_sa.email}"
}