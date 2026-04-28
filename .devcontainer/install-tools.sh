#!/bin/bash
set -e

echo ">>> Installing Kind..."
curl -Lo /usr/local/bin/kind \
  https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x /usr/local/bin/kind

echo ">>> Installing Trivy (security scanner)..."
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sh -s -- -b /usr/local/bin latest

echo ">>> Installing Syft (SBOM generator)..."
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
  | sh -s -- -b /usr/local/bin

echo ">>> Installing Checkov (IaC scanner)..."
pip3 install checkov --quiet

echo ">>> Verifying all tools..."
kind version
trivy --version
syft --version
checkov --version
terraform version
helm version --short
kubectl version --client

echo ">>> All tools ready."