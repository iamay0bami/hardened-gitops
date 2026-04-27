# Artifact Registry is the modern replacement for GCR.
# It's regional, private by default, and supports vulnerability scanning.
resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = "realworld-app-${var.environment}"
  description   = "Docker images for the RealWorld app (${var.environment})"
  format        = "DOCKER"

  # Enable container vulnerability scanning on every push.
  # This is a passive scan — our active Trivy gate runs in CI before push.
  docker_config {
    immutable_tags = var.environment == "production" ? true : false
  }
}

# Only the node SA and CI service account can pull/push images.
# No public access.
resource "google_artifact_registry_repository_iam_member" "node_pull" {
  location   = google_artifact_registry_repository.app.location
  repository = google_artifact_registry_repository.app.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.node_sa_email}"
}