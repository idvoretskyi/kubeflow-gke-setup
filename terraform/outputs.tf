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
    compute_cost_estimate  = "~$${(var.initial_node_count * (var.spot_instances || var.preemptible ? 25 : 73)) * 24 * 30 / 100} per month for ${var.initial_node_count} x ${var.machine_type} nodes"
    storage_cost_estimate  = "~$${var.initial_node_count * var.disk_size_gb * 0.04} per month for persistent disks"
    region                 = local.region
    project                = local.project_id
    note                   = "Actual costs may vary based on usage patterns and regional pricing"
  }
}

# =============================================================================
# Learning Mode and Version Information
# =============================================================================

output "kubernetes_version" {
  description = "Kubernetes version running on the cluster (master)"
  value       = module.gke.cluster_version
}

output "node_version" {
  description = "Kubernetes version running on the nodes"
  value       = module.gke.node_version
}

output "learning_mode_info" {
  description = "Learning mode configuration details"
  value = {
    learning_mode_enabled = var.learning_mode
    release_channel       = var.release_channel
    spot_instances        = var.spot_instances
    private_nodes         = var.enable_private_nodes
    taints_disabled       = var.learning_mode
    description           = var.learning_mode ? "Learning mode: Taints disabled, pods can schedule freely" : "Production mode: Kubeflow taint applied to nodes"
  }
}

output "quick_start_commands" {
  description = "Quick start commands for learning and experimentation"
  value       = <<-EOT
    # 1. Configure kubectl
    gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${local.region} --project ${local.project_id}

    # 2. Verify cluster access
    kubectl cluster-info
    kubectl get nodes

    # 3. Check Kubernetes version
    kubectl version

    # 4. Access Kubeflow dashboard
    kubectl port-forward svc/kubeflow-dashboard -n kubeflow 8080:80
    # Then open: http://localhost:8080

    # 5. List Kubeflow components
    kubectl get pods -n kubeflow

    # 6. Run a sample notebook
    kubectl get notebooks -n kubeflow
  EOT
}