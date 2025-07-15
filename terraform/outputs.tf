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
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${local.region} --project ${local.project_id}"
}

output "detected_config" {
  description = "Detected gcloud configuration"
  value = {
    project_id = local.project_id
    region     = local.region
    zones      = local.zones
    account    = local.current_account
  }
}

output "kubeflow_endpoint" {
  description = "Kubeflow dashboard endpoint"
  value       = module.kubeflow.endpoint
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    cluster_management_fee = "Free (GKE Autopilot charges apply only for running workloads)"
    compute_cost_estimate  = "~$${(var.initial_node_count * (var.preemptible ? 25 : 73)) * 24 * 30 / 100} per month for ${var.initial_node_count} x ${var.machine_type} nodes"
    storage_cost_estimate  = "~$${var.initial_node_count * var.disk_size_gb * 0.04} per month for persistent disks"
    region                 = local.region
    project                = local.project_id
    note                   = "Actual costs may vary based on usage patterns and regional pricing"
  }
}