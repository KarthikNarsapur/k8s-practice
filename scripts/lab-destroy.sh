#!/usr/bin/env bash
###############################################################################
# lab-destroy.sh <lab-id> | --all
# Removes a lab's cluster state entirely (namespace + any cluster-scoped
# objects). Does NOT touch AWS infrastructure — use 'terraform destroy' for
# that (see scripts/aws-destroy hint / README).
#
#   ./lab-destroy.sh 05
#   ./lab-destroy.sh --all
###############################################################################
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || die "Usage: lab-destroy.sh <lab-id> | --all"

destroy_one() {
  local id="$1" d
  d="$(lab_dir "${id}")"
  [ -n "${d}" ] || { warn "Lab ${id} not found, skipping."; return; }

  # shellcheck disable=SC1091
  ( [ -f "${d}/meta.env" ] && source "${d}/meta.env"
    local ns="${LAB_NAMESPACE:-lab-${id}}"
    export LAB_ID="${id}" LAB_DIR="${d}" NS="${ns}" AWS_REGION PROJECT_NAME

    info "Destroying lab ${id} (${ns})..."
    if [ -f "${d}/teardown.sh" ]; then
      # shellcheck disable=SC1090
      source "${d}/teardown.sh"
    fi
    kc "delete namespace ${ns} --ignore-not-found --wait=false" >/dev/null || true
    ok "Lab ${id} destroyed."
  )
}

if [ "$1" = "--all" ]; then
  for d in "${LABS_DIR}"/*/; do
    [ -d "${d}" ] || continue
    id="$(basename "${d}" | cut -d- -f1)"
    destroy_one "${id}"
  done
else
  destroy_one "$1"
fi
