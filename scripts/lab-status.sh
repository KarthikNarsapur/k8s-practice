#!/usr/bin/env bash
###############################################################################
# lab-status.sh — quick view of environment state + your lab progress.
# Works whether the cluster is running, stopped, or destroyed.
###############################################################################
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

echo "== AWS environment (${PROJECT_NAME} @ ${AWS_REGION}) =="
states="$(aws ec2 describe-instances \
  --region "${AWS_REGION}" \
  --filters "Name=tag:Project,Values=${PROJECT_NAME}" \
            "Name=instance-state-name,Values=running,stopped,stopping,pending" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,InstanceType,State.Name]' \
  --output text 2>/dev/null || true)"

if [ -z "${states}" ]; then
  warn "No ${PROJECT_NAME} instances found. Cluster is DESTROYED (cost: \$0)."
  echo "  Bring it up with:  make up"
else
  echo "${states}" | while read -r name type state; do
    printf '  %-24s %-12s %s\n' "${name}" "${type}" "${state}"
  done
  running="$(echo "${states}" | grep -c running || true)"
  if [ "${running}" -gt 0 ]; then
    ok "Cluster is RUNNING (billing). Pause with: make pause  |  Destroy with: make down"
    echo
    echo "== Nodes =="
    kc "get nodes -o wide" 2>/dev/null || warn "API not reachable yet (cluster may still be booting)."
  else
    warn "Cluster is STOPPED (NAT+EBS still bill). Resume: make resume  |  Destroy: make down"
  fi
fi

echo
echo "== Lab progress (from PROGRESS.md) =="
if [ -f "${REPO_ROOT}/PROGRESS.md" ]; then
  awk '/^\| Lab /{p=1} p&&/^\|/{print} p&&/^$/{exit}' "${REPO_ROOT}/PROGRESS.md" || true
else
  warn "No PROGRESS.md found."
fi
