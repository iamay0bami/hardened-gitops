output "cluster_name" {
  description = "Kind cluster name"
  value       = kind_cluster.main.name
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig"
  value       = kind_cluster.main.kubeconfig_path
}

output "registry_url" {
  description = "GitHub Container Registry URL"
  value       = "ghcr.io/iamay0bami/realworld-app"
}
