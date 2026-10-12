#!/usr/bin/env bash
set -euo pipefail
info "Applying Lab 18 manifests (controller, backends, and broken HC Ingresses)..."
for manifest in "${LAB_DIR}"/manifests/*.yaml; do
  [ -f "${manifest}" ] || continue
  remote_apply "${manifest}" >/dev/null
done
ok "Setup applied. Wait for ingress-controller and backend Pods to become Ready."
