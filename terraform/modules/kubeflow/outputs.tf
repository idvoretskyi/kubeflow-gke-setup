output "endpoint" {
  description = "Kubeflow dashboard service name (use kubectl port-forward for secure local access)"
  value       = kubernetes_service_v1.kubeflow_dashboard.metadata[0].name
}
output "port_forward_command" {
  description = "Command to securely access Kubeflow dashboard via kubectl port-forward"
  value       = "kubectl port-forward -n ${kubernetes_namespace_v1.kubeflow.metadata[0].name} svc/${kubernetes_service_v1.kubeflow_dashboard.metadata[0].name} 8080:80"
}
output "dashboard_url" {
  description = "URL to access Kubeflow dashboard after running port-forward command"
  value       = "http://localhost:8080"
}
# Uncomment when using HTTPS Ingress configuration in main.tf
# output "https_endpoint" {
#   description = "HTTPS endpoint for Kubeflow dashboard"
#   value       = "https://${var.domain}"
# }
#
# output "ingress_ip" {
#   description = "Static IP address for the Ingress (point your DNS A record to this IP)"
#   value       = google_compute_global_address.kubeflow_ip.address
# }
output "kubeflow_namespace" {
  description = "Kubeflow namespace"
  value       = kubernetes_namespace_v1.kubeflow.metadata[0].name
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