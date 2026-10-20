#!/usr/bin/env bash
set -euo pipefail
info "Applying Lab 19 workloads, broken Services, and network probe..."
for manifest in "${LAB_DIR}"/manifests/*.yaml; do
  [ -f "${manifest}" ] || continue
  remote_apply "${manifest}" >/dev/null
done
ok "Setup applied. Diagnose all four basic and four hard connectivity paths."
