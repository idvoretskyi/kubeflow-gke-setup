output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint of the GKE cluster"
  value       = module.gke.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "CA certificate of the GKE cluster"
  value       = module.gke.ca_certificate
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --zone ${local.zone} --project ${local.project_id}"
}

output "detected_config" {
  description = "Detected gcloud configuration"
  value = {
    project_id = local.project_id
    region     = local.region
    zone       = local.zone
    account    = local.current_account
  }
}

output "kubeflow_endpoint" {
  description = "Kubeflow dashboard endpoint (WARNING: HTTP only, use kubectl port-forward for secure access or configure HTTPS ingress for production)"
  value       = module.kubeflow.endpoint
}

output "kubernetes_version" {
  description = "Kubernetes version running on the cluster"
  value       = module.gke.cluster_version
}