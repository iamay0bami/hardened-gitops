# Dedicated VPC so the cluster is not on the default network
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false # Principle of least privilege — no auto subnets
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = "10.0.0.0/18"
  region        = var.region
  network       = google_compute_network.vpc.id

  # Secondary ranges are required for GKE pods and services
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.48.0.0/14"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.52.0.0/20"
  }

  # Enable Private Google Access so nodes can reach GCP APIs without a public IP
  private_ip_google_access = true
}

# Dedicated service account for GKE nodes — NOT the default compute SA.
# This follows least-privilege: only grant what the nodes actually need.
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE Node Service Account for ${var.cluster_name}"
}

# Minimal roles for the node SA:
# - logging.logWriter: send logs to Cloud Logging
# - monitoring.metricWriter: send metrics
# - artifactregistry.reader: pull images from our private registry
locals {
  node_sa_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
  ]
}

resource "google_project_iam_member" "node_sa_roles" {
  for_each = toset(local.node_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# GKE Autopilot cluster — the key security and cost choice.
# Autopilot enforces security best practices by default:
# - Workload Identity is always on
# - Shielded nodes are always on
# - Node auto-upgrade is always on
# - No SSH access to nodes
resource "google_container_cluster" "primary" {
  provider = google-beta

  name     = var.cluster_name
  location = var.region

  # Autopilot mode — fully managed nodes
  enable_autopilot = true

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  # Private cluster: nodes have no public IPs.
  # This is a hard security requirement.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Keep public endpoint for kubectl access via RBAC
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Workload Identity: allows Kubernetes service accounts to act as
  # GCP service accounts. This is how pods will access Secret Manager
  # without storing credentials anywhere.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Restrict which IPs can call the Kubernetes API server.
  # In a real setup, replace with your VPN/office CIDR.
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0" # TODO: Tighten this to your CI runner IPs
      display_name = "All (tighten before production)"
    }
  }

  # Binary Authorization: only allow images that have been verified
  # (we'll configure the policy in a later step)
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Deletion protection — prevents accidental terraform destroy
  deletion_protection = var.environment == "production" ? true : false

  release_channel {
    channel = "REGULAR" # Stable updates, not bleeding edge
  }

  # Cluster-level logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }
}