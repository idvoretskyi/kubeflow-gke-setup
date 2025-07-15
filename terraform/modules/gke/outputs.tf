output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "endpoint" {
  description = "Endpoint of the GKE cluster"
  value       = google_container_cluster.primary.endpoint
}

output "ca_certificate" {
  description = "CA certificate of the GKE cluster"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
}

output "cluster_id" {
  description = "ID of the GKE cluster"
  value       = google_container_cluster.primary.id
}

output "node_pool_id" {
  description = "ID of the primary node pool"
  value       = google_container_node_pool.primary_nodes.id
}

output "service_account_email" {
  description = "Email of the GKE node service account"
  value       = google_service_account.gke_node_sa.email
}

output "cluster_version" {
  description = "Version of the GKE cluster"
  value       = google_container_cluster.primary.master_version
}

output "node_version" {
  description = "Version of the GKE nodes"
  value       = google_container_node_pool.primary_nodes.version
}