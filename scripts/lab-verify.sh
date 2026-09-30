#!/usr/bin/env bash
###############################################################################
# lab-verify.sh <lab-id>
# Runs the lab's verification checks against the live cluster.
#
# Contract (enforced by convention in each verify.sh):
#   - On success: print PASS lines and exit 0.
#   - On failure: print FAILED: <what>, the relevant object, and exactly ONE
#     conceptual hint. NEVER print the solution.
#
#   ./lab-verify.sh 05
###############################################################################
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || die "Usage: lab-verify.sh <lab-id>"
LAB_ID="$1"
D="$(require_lab "${LAB_ID}")"

# shellcheck disable=SC1091
[ -f "${D}/meta.env" ] && source "${D}/meta.env"
NS="${LAB_NAMESPACE:-lab-${LAB_ID}}"
export LAB_ID LAB_DIR="${D}" NS AWS_REGION PROJECT_NAME

[ -f "${D}/verify.sh" ] || die "Lab ${LAB_ID} has no verify.sh"

info "Verifying lab ${LAB_ID} ($(basename "${D}"))..."
echo "--------------------------------------------------------------------"

# verify.sh is sourced so it can use kc()/remote_exec() from lib.sh.
# It is responsible for its own PASS/FAIL output and exit code.
set +e
# shellcheck disable=SC1090
source "${D}/verify.sh"
rc=$?
set -e

echo "--------------------------------------------------------------------"
if [ "${rc}" -eq 0 ]; then
  ok "Lab ${LAB_ID} PASSED."
  # Persist progress in PROGRESS.md (survives destroy/stop). Count this attempt
  # and mark the lab Completed with today's date.
  progress_update "${LAB_ID}" "Completed" "true"
  info "PROGRESS.md updated: lab ${LAB_ID} marked Completed."
else
  warn "Lab ${LAB_ID} not complete yet. Review the hint above and try again."
  warn "The solution is in ${D}/solution.md — open it only if you're truly stuck."
  # Count the attempt and mark In Progress (unless already Completed).
  progress_update "${LAB_ID}" "In Progress" "true"
fi
exit "${rc}"
