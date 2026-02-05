variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "domain" {
  description = <<-EOT
    Domain name for Kubeflow HTTPS ingress (optional).
    Required only if you uncomment the HTTPS Ingress configuration in main.tf.
    Example: "kubeflow.example.com"
    You must point this domain's DNS A record to the ingress IP output.
  EOT
  type        = string
  default     = ""
}