#!/bin/bash
set -e

echo ">>> Installing Kind..."
curl -Lo "$HOME/kind" \
  https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x "$HOME/kind"
sudo mv "$HOME/kind" /usr/local/bin/kind

echo ">>> Installing Trivy (security scanner)..."
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sudo sh -s -- -b /usr/local/bin latest

echo ">>> Installing Syft (SBOM generator)..."
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
  | sudo sh -s -- -b /usr/local/bin

echo ">>> Installing Checkov (IaC scanner)..."
pip3 install checkov --quiet --user
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

echo ">>> Verifying all tools..."
kind version
trivy --version
syft --version
terraform version
helm version --short
kubectl version --client

echo ">>> All tools ready."