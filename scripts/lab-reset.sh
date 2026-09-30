#!/usr/bin/env bash
###############################################################################
# lab-reset.sh <lab-id>
# Resets a lab back to its starting state: deletes the lab namespace (and any
# cluster-scoped objects the lab registered in teardown.sh), then re-runs
# lab-start. Use this when you've made a mess and want a clean slate.
#
#   ./lab-reset.sh 05
###############################################################################
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

[ $# -ge 1 ] || die "Usage: lab-reset.sh <lab-id>"
LAB_ID="$1"
D="$(require_lab "${LAB_ID}")"

# shellcheck disable=SC1091
[ -f "${D}/meta.env" ] && source "${D}/meta.env"
NS="${LAB_NAMESPACE:-lab-${LAB_ID}}"
export LAB_ID LAB_DIR="${D}" NS AWS_REGION PROJECT_NAME

info "Resetting lab ${LAB_ID} ($(basename "${D}"))..."

# Lab-specific teardown for cluster-scoped objects (RBAC, PVs, etc.).
if [ -f "${D}/teardown.sh" ]; then
  # shellcheck disable=SC1090
  source "${D}/teardown.sh"
fi

# Delete the namespace (removes all namespaced objects).
info "Deleting namespace ${NS} (waiting for full removal)..."
kc "delete namespace ${NS} --ignore-not-found --wait=true" >/dev/null || true

ok "Lab ${LAB_ID} torn down."

# Re-create fresh starting state.
info "Re-starting lab ${LAB_ID}..."
"${SCRIPT_DIR}/lab-start.sh" "${LAB_ID}"
