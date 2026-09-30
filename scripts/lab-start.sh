#!/usr/bin/env bash
###############################################################################
# lab-start.sh <lab-id>
# Prepares the environment for a lab: creates the lab namespace and applies
# whatever starting state the lab defines (setup.sh). For challenge labs this
# may deliberately create a BROKEN state for you to diagnose.
#
#   ./lab-start.sh 05
#   ./lab-start.sh t01
###############################################################################
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || die "Usage: lab-start.sh <lab-id>"
LAB_ID="$1"
D="$(require_lab "${LAB_ID}")"
LAB_NAME="$(basename "${D}")"

# shellcheck disable=SC1091
[ -f "${D}/meta.env" ] && source "${D}/meta.env"
NS="${LAB_NAMESPACE:-lab-${LAB_ID}}"

info "Starting lab: ${LAB_NAME}"
info "Namespace: ${NS}"

# Ensure namespace exists (idempotent).
kc "create namespace ${NS} --dry-run=client -o yaml | kubectl apply -f -" >/dev/null

export LAB_ID LAB_NAME LAB_DIR="${D}" NS AWS_REGION PROJECT_NAME

if [ -f "${D}/setup.sh" ]; then
  info "Running lab setup..."
  # setup.sh uses helper functions (kc/remote_apply) from lib.sh.
  # shellcheck disable=SC1090
  source "${D}/setup.sh"
else
  warn "No setup.sh for this lab; applying any manifests in ${D}/manifests/"
  if [ -d "${D}/manifests" ]; then
    for m in "${D}"/manifests/*.y*ml; do
      [ -e "${m}" ] || continue
      remote_apply "${m}"
    done
  fi
fi

ok "Lab ${LAB_ID} started."
# Mark In Progress in the tracker (no attempt bump on start).
progress_update "${LAB_ID}" "In Progress" "false" || true
echo
info "Read the challenge:   ${D}/README.md"
info "Verify your work:     ./scripts/lab-verify.sh ${LAB_ID}"
info "Reset the lab:        ./scripts/lab-reset.sh ${LAB_ID}"
