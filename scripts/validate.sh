#!/usr/bin/env bash

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
