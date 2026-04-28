# ── Kind cluster ──────────────────────────────────────────────────────────────
resource "kind_cluster" "main" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      extra_port_mappings {
        container_port = 80
        host_port      = 8080
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 8443
        protocol       = "TCP"
      }
    }

    node {
      role = "worker"
      labels = {
        "environment" = "staging"
        "workload"    = "app"
      }
    }

    node {
      role = "worker"
      labels = {
        "environment" = "production"
        "workload"    = "app"
      }
    }
  }
}

# ── Providers wired to the cluster ────────────────────────────────────────────
provider "kubernetes" {
  host                   = kind_cluster.main.endpoint
  client_certificate     = kind_cluster.main.client_certificate
  client_key             = kind_cluster.main.client_key
  cluster_ca_certificate = kind_cluster.main.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.main.endpoint
    client_certificate     = kind_cluster.main.client_certificate
    client_key             = kind_cluster.main.client_key
    cluster_ca_certificate = kind_cluster.main.cluster_ca_certificate
  }
}

# ── Namespaces ────────────────────────────────────────────────────────────────
locals {
  namespaces = [
    "argocd",
    "vault",
    "external-secrets",
    "staging",
    "production",
    "kyverno",
  ]
}

resource "kubernetes_namespace" "namespaces" {
  for_each = toset(local.namespaces)

  metadata {
    name = each.value
    labels = {
      "managed-by"  = "terraform"
      "environment" = each.value
    }
  }

  depends_on = [kind_cluster.main]
}

# ── ArgoCD ────────────────────────────────────────────────────────────────────
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = "argocd"

  values = [
    <<-YAML
      server:
        insecure: true
        extraArgs:
          - --insecure
      configs:
        params:
          server.insecure: "true"
        cm:
          users.anonymous.enabled: "false"
          application.resourceTrackingMethod: annotation
    YAML
  ]

  depends_on = [kubernetes_namespace.namespaces]
}

# ── HashiCorp Vault (dev mode — free, no storage needed) ─────────────────────
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_version
  namespace  = "vault"

  values = [
    <<-YAML
      server:
        dev:
          enabled: true
          devRootToken: "root"
        standalone:
          enabled: false
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "250m"
      ui:
        enabled: true
        serviceType: ClusterIP
      injector:
        enabled: true
    YAML
  ]

  depends_on = [kubernetes_namespace.namespaces]
}

# ── External Secrets Operator ─────────────────────────────────────────────────
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.9.13"
  namespace  = "external-secrets"

  values = [
    <<-YAML
      installCRDs: true
      resources:
        requests:
          cpu: "50m"
          memory: "128Mi"
        limits:
          cpu: "100m"
          memory: "256Mi"
    YAML
  ]

  depends_on = [
    kubernetes_namespace.namespaces,
    helm_release.vault,
  ]
}

# ── Kyverno policy engine ─────────────────────────────────────────────────────
resource "helm_release" "kyverno" {
  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  version    = "3.2.6"
  namespace  = "kyverno"

  values = [
    <<-YAML
      admissionController:
        replicas: 1
      backgroundController:
        resources:
          limits:
            memory: "256Mi"
      cleanupController:
        resources:
          limits:
            memory: "128Mi"
      reportsController:
        resources:
          limits:
            memory: "128Mi"
    YAML
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
