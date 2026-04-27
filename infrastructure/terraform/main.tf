provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Enable required GCP APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "container.googleapis.com",        # GKE
    "artifactregistry.googleapis.com", # Container registry
    "secretmanager.googleapis.com",    # Secret Manager
    "cloudkms.googleapis.com",         # KMS for envelope encryption
  ])

  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

module "gke" {
  source = "./modules/gke"

  project_id   = var.project_id
  region       = var.region
  cluster_name = "${var.cluster_name}-${var.environment}"
  environment  = var.environment

  depends_on = [google_project_service.apis]
}

module "registry" {
  source = "./modules/registry"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  depends_on = [google_project_service.apis]
}