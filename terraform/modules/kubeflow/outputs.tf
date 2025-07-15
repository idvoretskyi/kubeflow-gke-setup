output "endpoint" {
  description = "Kubeflow dashboard endpoint"
  value       = "http://${kubernetes_service.kubeflow_dashboard.status[0].load_balancer[0].ingress[0].ip}"
}

output "kubeflow_namespace" {
  description = "Kubeflow namespace"
  value       = kubernetes_namespace.kubeflow.metadata[0].name
}

output "service_account_email" {
  description = "Email of the Kubeflow GCP service account"
  value       = google_service_account.kubeflow_gcp_sa.email
}

output "artifacts_bucket" {
  description = "Name of the Kubeflow artifacts bucket"
  value       = google_storage_bucket.kubeflow_artifacts.name
}

output "artifacts_bucket_url" {
  description = "URL of the Kubeflow artifacts bucket"
  value       = google_storage_bucket.kubeflow_artifacts.url
}