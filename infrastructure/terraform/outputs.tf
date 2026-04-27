output "gke_cluster_name" {
  value = module.gke.cluster_name
}

output "registry_url" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/realworld-app-${var.environment}"
}