#!/usr/bin/env bash
###############################################################################
# aws-start.sh — Start previously-stopped cluster EC2 instances.
# The cluster (kubelet, control-plane static pods) restarts automatically.
# Give it a couple of minutes, then check: ./scripts/lab-verify.sh 01
###############################################################################
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

ids="$(aws ec2 describe-instances \
  --region "${AWS_REGION}" \
  --filters "Name=tag:Project,Values=${PROJECT_NAME}" \
            "Name=instance-state-name,Values=stopped,stopping" \
  --query 'Reservations[].Instances[].InstanceId' --output text)"

[ -n "${ids}" ] || { warn "No stopped ${PROJECT_NAME} instances."; exit 0; }

info "Starting: ${ids}"
# shellcheck disable=SC2086
aws ec2 start-instances --region "${AWS_REGION}" --instance-ids ${ids} >/dev/null
ok "Start requested. Allow ~2-3 min for the cluster to become Ready."
