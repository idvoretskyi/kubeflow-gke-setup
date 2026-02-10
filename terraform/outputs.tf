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
output "kubeflow_access_command" {
  description = "Command to securely access Kubeflow dashboard"
  value       = var.deploy_kubeflow ? module.kubeflow[0].port_forward_command : "Kubeflow not deployed"
}
output "kubeflow_dashboard_url" {
  description = "Local URL after running port-forward command"
  value       = var.deploy_kubeflow ? module.kubeflow[0].dashboard_url : "Kubeflow not deployed"
}
output "kubernetes_version" {
  description = "Kubernetes version running on the cluster"
  value       = module.gke.cluster_version
}
output "gpu_enabled" {
  description = "Whether GPU node pool is enabled"
  value       = var.enable_gpu
}
