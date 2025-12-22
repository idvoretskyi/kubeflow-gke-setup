# Enable required GCP APIs for Kubeflow deployment
# These services must be enabled before creating resources

resource "google_project_service" "required_apis" {
  for_each = toset([
    "container.googleapis.com",            # GKE
    "compute.googleapis.com",              # Compute Engine
    "storage.googleapis.com",              # Cloud Storage
    "bigquery.googleapis.com",             # BigQuery for cost tracking
    "cloudbuild.googleapis.com",           # Cloud Build
    "monitoring.googleapis.com",           # Cloud Monitoring
    "logging.googleapis.com",              # Cloud Logging
    "cloudresourcemanager.googleapis.com", # Resource Manager
    "iam.googleapis.com",                  # IAM
  ])

  project = local.project_id
  service = each.value

  disable_on_destroy         = false
  disable_dependent_services = false
}
