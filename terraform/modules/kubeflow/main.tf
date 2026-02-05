locals {
  kubeflow_version  = "1.10.0"
  kustomize_version = "5.0.1"
}

# Create namespace for Kubeflow
resource "kubernetes_namespace_v1" "kubeflow" {
  metadata {
    name = "kubeflow"
    labels = {
      "app.kubernetes.io/name"    = "kubeflow"
      "app.kubernetes.io/version" = local.kubeflow_version
    }
  }
}

resource "kubernetes_namespace_v1" "istio_system" {
  metadata {
    name = "istio-system"
    labels = {
      "app.kubernetes.io/name" = "istio-system"
    }
  }
}

resource "kubernetes_namespace_v1" "cert_manager" {
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
  namespace  = kubernetes_namespace_v1.cert_manager.metadata[0].name

  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "global.leaderElection.namespace"
      value = kubernetes_namespace_v1.cert_manager.metadata[0].name
    }
  ]

  depends_on = [kubernetes_namespace_v1.cert_manager]
}

# Install Istio using Helm
resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = "1.19.3"
  namespace  = kubernetes_namespace_v1.istio_system.metadata[0].name

  depends_on = [kubernetes_namespace_v1.istio_system]
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = "1.19.3"
  namespace  = kubernetes_namespace_v1.istio_system.metadata[0].name

  depends_on = [helm_release.istio_base]
}

# Local values for Kubeflow manifests - split multi-document YAML files
locals {
  # Read raw manifest files
  manifest_files = {
    core     = file("${path.module}/manifests/kubeflow-core.yaml")
    pipeline = file("${path.module}/manifests/kubeflow-pipeline.yaml")
    notebook = file("${path.module}/manifests/kubeflow-notebook.yaml")
    katib    = file("${path.module}/manifests/kubeflow-katib.yaml")
    serving  = file("${path.module}/manifests/kubeflow-serving.yaml")
  }

  # Split each file by --- and flatten into a list of individual YAML documents
  # Filter out empty documents
  all_manifests = flatten([
    for name, content in local.manifest_files : [
      for doc in split("\n---\n", content) :
      trimspace(doc) if trimspace(doc) != "" && !startswith(trimspace(doc), "#")
    ]
  ])
}

# Install Kubeflow using manifest files
resource "kubernetes_manifest" "kubeflow_manifests" {
  count = length(local.all_manifests)

  manifest = yamldecode(local.all_manifests[count.index])

  depends_on = [
    kubernetes_namespace_v1.kubeflow,
    helm_release.cert_manager,
    helm_release.istiod
  ]
}

# Create a service account for Kubeflow
resource "kubernetes_service_account_v1" "kubeflow_sa" {
  metadata {
    name      = "kubeflow-service-account"
    namespace = kubernetes_namespace_v1.kubeflow.metadata[0].name
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
# Following principle of least privilege with granular permissions
resource "google_project_iam_member" "kubeflow_sa_bindings" {
  for_each = toset([
    "roles/storage.objectAdmin",     # Changed from storage.admin - sufficient for object operations
    "roles/bigquery.dataEditor",     # Changed from bigquery.admin - sufficient for data operations
    "roles/aiplatform.user",         # Changed from ml.admin - sufficient for AI Platform usage
    "roles/cloudsql.client",         # Unchanged - appropriate for Cloud SQL access
    "roles/monitoring.metricWriter", # Unchanged - appropriate for metrics
    "roles/logging.logWriter"        # Unchanged - appropriate for logs
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
    "serviceAccount:${var.project_id}.svc.id.goog[${kubernetes_namespace_v1.kubeflow.metadata[0].name}/${kubernetes_service_account_v1.kubeflow_sa.metadata[0].name}]"
  ]
}

# Create ClusterIP service for Kubeflow Central Dashboard
# For secure access, use kubectl port-forward instead of public LoadBalancer
resource "kubernetes_service_v1" "kubeflow_dashboard" {
  metadata {
    name      = "kubeflow-dashboard-svc"
    namespace = kubernetes_namespace_v1.kubeflow.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "kubeflow-dashboard"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = "centraldashboard"
    }

    port {
      port        = 80
      target_port = 8082
      protocol    = "TCP"
      name        = "http"
    }
  }

  depends_on = [kubernetes_manifest.kubeflow_manifests]
}

# OPTIONAL: For production deployments with HTTPS, uncomment the configuration below
# This creates an Ingress with Google-managed SSL certificate

# Uncomment to enable HTTPS access via Ingress
# resource "google_compute_global_address" "kubeflow_ip" {
#   name = "${var.cluster_name}-kubeflow-ip"
# }

# resource "google_compute_managed_ssl_certificate" "kubeflow_cert" {
#   name = "${var.cluster_name}-kubeflow-cert"
#
#   managed {
#     domains = [var.domain]  # Set domain variable, e.g., "kubeflow.example.com"
#   }
# }

# resource "kubernetes_ingress_v1" "kubeflow_ingress" {
#   metadata {
#     name      = "kubeflow-ingress"
#     namespace = kubernetes_namespace_v1.kubeflow.metadata[0].name
#     annotations = {
#       "kubernetes.io/ingress.class"                    = "gce"
#       "kubernetes.io/ingress.global-static-ip-name"   = google_compute_global_address.kubeflow_ip.name
#       "ingress.gcp.kubernetes.io/pre-shared-cert"     = google_compute_managed_ssl_certificate.kubeflow_cert.name
#       "kubernetes.io/ingress.allow-http"               = "false"  # Force HTTPS only
#     }
#   }
#
#   spec {
#     rule {
#       host = var.domain
#       http {
#         path {
#           path      = "/*"
#           path_type = "ImplementationSpecific"
#           backend {
#             service {
#               name = kubernetes_service_v1.kubeflow_dashboard.metadata[0].name
#               port {
#                 number = 80
#               }
#             }
#           }
#         }
#       }
#     }
#   }
#
#   depends_on = [
#     kubernetes_service_v1.kubeflow_dashboard,
#     google_compute_managed_ssl_certificate.kubeflow_cert
#   ]
# }

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
# Using objectAdmin instead of admin - sufficient for artifact storage operations
resource "google_storage_bucket_iam_member" "kubeflow_storage_access" {
  bucket = google_storage_bucket.kubeflow_artifacts.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.kubeflow_gcp_sa.email}"
}