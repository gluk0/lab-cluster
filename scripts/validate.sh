#!/usr/bin/env bash
# Validates that every layer of the repo renders with kustomize.
# Run from anywhere: ./scripts/validate.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LAYERS=(
  clusters/homelab
  infrastructure/networking
  infrastructure
  infrastructure/configs
  apps
)

for layer in "${LAYERS[@]}"; do
  echo "==> kustomize build ${layer}"
  kubectl kustomize "${REPO_ROOT}/${layer}" > /dev/null
done

echo "OK: all layers build cleanly."
echo
echo "With cluster access, also run:"
echo "  flux check"
echo "  flux diff kustomization networking --path ./infrastructure/networking"
echo "  flux diff kustomization infrastructure --path ./infrastructure"
echo "  flux diff kustomization configs --path ./infrastructure/configs"
echo "  flux diff kustomization apps --path ./apps"
