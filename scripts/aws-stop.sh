#!/usr/bin/env bash
###############################################################################
# aws-stop.sh — Stop all cluster EC2 instances to pause compute billing.
# EBS volumes persist, so the cluster comes back on aws-start.sh.
# NOTE: the NAT Gateway keeps costing money while stopped. To stop ALL charges,
# run 'terraform destroy' instead.
###############################################################################
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

ids="$(aws ec2 describe-instances \
  --region "${AWS_REGION}" \
  --filters "Name=tag:Project,Values=${PROJECT_NAME}" \
            "Name=instance-state-name,Values=running,pending" \
  --query 'Reservations[].Instances[].InstanceId' --output text)"

[ -n "${ids}" ] || { warn "No running ${PROJECT_NAME} instances."; exit 0; }

info "Stopping: ${ids}"
# shellcheck disable=SC2086
aws ec2 stop-instances --region "${AWS_REGION}" --instance-ids ${ids} >/dev/null
ok "Stop requested. Compute billing pauses once instances reach 'stopped'."
warn "NAT Gateway still incurs cost. Run 'terraform destroy' to stop everything."
