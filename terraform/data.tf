# Data sources for dynamic configuration from gcloud
# Get current gcloud project
data "external" "gcloud_project" {
  program = ["bash", "-c", "echo '{\"project\":\"'$(gcloud config get-value project 2>/dev/null || echo '')'\"}' "]
}
# Get current gcloud region
data "external" "gcloud_region" {
  program = ["bash", "-c", "echo '{\"region\":\"'$(gcloud config get-value compute/region 2>/dev/null || echo '')'\"}' "]
}
# Get current gcloud zone for fallback region detection
data "external" "gcloud_zone" {
  program = ["bash", "-c", "echo '{\"zone\":\"'$(gcloud config get-value compute/zone 2>/dev/null || echo '')'\"}' "]
}
# Get current gcloud account for verification
data "external" "gcloud_account" {
  program = ["bash", "-c", "echo '{\"account\":\"'$(gcloud config get-value account 2>/dev/null || echo '')'\"}' "]
}
# Local values for processing the gcloud configuration
locals {
  # Get project from gcloud config or fallback to variable
  detected_project = data.external.gcloud_project.result.project
  project_id       = local.detected_project != "" ? local.detected_project : var.project_id
  # Get region from gcloud config or derive from zone or fallback to variable
  detected_region = data.external.gcloud_region.result.region
  detected_zone   = data.external.gcloud_zone.result.zone
  # Extract region from zone if region is not set (e.g., us-central1-a -> us-central1)
  region_from_zone = local.detected_zone != "" ? join("-", slice(split("-", local.detected_zone), 0, 2)) : ""
  # Priority: explicit region > region from zone > variable
  region = local.detected_region != "" ? local.detected_region : (
    local.region_from_zone != "" ? local.region_from_zone : var.region
  )
  # Zone for zonal cluster deployment (required - only zonal clusters supported)
  # Priority: explicit zone variable > detected zone from gcloud > default zone in region
  zone = var.zone != "" ? var.zone : (
    local.detected_zone != "" ? local.detected_zone : "${local.region}-b"
  )
  # Account information for verification
  current_account = data.external.gcloud_account.result.account
}