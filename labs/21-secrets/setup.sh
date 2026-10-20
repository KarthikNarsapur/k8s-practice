#!/usr/bin/env bash
set -euo pipefail
info "Lab 21: prepare four intentionally incorrect hard-challenge Secrets."
for manifest in "${LAB_DIR}"/manifests/*.yaml; do
  [ -f "${manifest}" ] || continue
  remote_apply "${manifest}" >/dev/null
done
ok "Setup applied. Complete all four basic and four hard challenges from README.md."
