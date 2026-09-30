#!/usr/bin/env bash
###############################################################################
# lib.sh — shared helpers for the lab engine.
#
# The cluster API server is NOT exposed to the internet. All kubectl runs on
# the control-plane node, which we reach through AWS SSM Session Manager
# (aws ssm send-command). This mirrors the security model: no public API,
# no SSH.
###############################################################################
set -euo pipefail

# Resolve repo root (this file lives in scripts/).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LABS_DIR="${REPO_ROOT}/labs"

# Region + project can be overridden via env; defaults match Terraform.
AWS_REGION="${AWS_REGION:-${K8S_LAB_REGION:-us-east-1}}"
PROJECT_NAME="${PROJECT_NAME:-k8s-lab}"

color() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
info()  { echo "$(color '0;36' "[info]") $*"; }
ok()    { echo "$(color '0;32' "[ ok ]") $*"; }
warn()  { echo "$(color '1;33' "[warn]") $*"; }
err()   { echo "$(color '0;31' "[fail]") $*" >&2; }

die() { err "$*"; exit 1; }

# --- Find the control-plane instance id by tag ---
cp_instance_id() {
  aws ec2 describe-instances \
    --region "${AWS_REGION}" \
    --filters "Name=tag:Role,Values=control-plane" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null
}

# --- Run an arbitrary shell command on the control-plane via SSM ---
# Usage: remote_exec "<bash command>"
# Prints the command's stdout; returns the remote exit code.
remote_exec() {
  local cmd="$1"
  local iid
  iid="$(cp_instance_id)"
  [ -n "${iid}" ] && [ "${iid}" != "None" ] || die "No running control-plane instance found. Is the cluster up?"

  local sid
  sid="$(aws ssm send-command \
    --region "${AWS_REGION}" \
    --instance-ids "${iid}" \
    --document-name "AWS-RunShellScript" \
    --comment "lab-engine" \
    --parameters "commands=[\"export KUBECONFIG=/etc/kubernetes/admin.conf; ${cmd//\"/\\\"}\"]" \
    --query 'Command.CommandId' --output text)"

  # Wait for completion.
  aws ssm wait command-executed \
    --region "${AWS_REGION}" \
    --command-id "${sid}" \
    --instance-id "${iid}" >/dev/null 2>&1 || true

  local status
  status="$(aws ssm get-command-invocation \
    --region "${AWS_REGION}" \
    --command-id "${sid}" \
    --instance-id "${iid}" \
    --query 'Status' --output text)"

  aws ssm get-command-invocation \
    --region "${AWS_REGION}" \
    --command-id "${sid}" \
    --instance-id "${iid}" \
    --query 'StandardOutputContent' --output text

  # Surface stderr on failure for debugging.
  if [ "${status}" != "Success" ]; then
    aws ssm get-command-invocation \
      --region "${AWS_REGION}" \
      --command-id "${sid}" \
      --instance-id "${iid}" \
      --query 'StandardErrorContent' --output text >&2
    return 1
  fi
  return 0
}

# --- Convenience: run kubectl on the control-plane ---
kc() {
  remote_exec "kubectl $*"
}

# --- Copy a local manifest to the control-plane and kubectl apply/delete it ---
# Usage: remote_apply <local_file>    /    remote_delete <local_file>
remote_manifest() {
  local action="$1" file="$2"
  [ -f "${file}" ] || die "Manifest not found: ${file}"
  local b64
  b64="$(base64 -w0 "${file}" 2>/dev/null || base64 "${file}" | tr -d '\n')"
  local remote="/tmp/lab-$(basename "${file}")"
  remote_exec "echo '${b64}' | base64 -d > ${remote}; kubectl ${action} -f ${remote}"
}
remote_apply()  { remote_manifest "apply"  "$1"; }
remote_delete() { remote_manifest "delete --ignore-not-found" "$1"; }

# --- Lab discovery ---
lab_dir() {
  local id="$1"
  # Accept "05" or "5" or "t01"; match a directory that starts with the id.
  local match
  match="$(find "${LABS_DIR}" -maxdepth 1 -type d -name "${id}-*" 2>/dev/null | head -1)"
  if [ -z "${match}" ]; then
    # zero-pad single digits
    local padded
    padded="$(printf '%02d' "$((10#${id}))" 2>/dev/null || echo "${id}")"
    match="$(find "${LABS_DIR}" -maxdepth 1 -type d -name "${padded}-*" 2>/dev/null | head -1)"
  fi
  echo "${match}"
}

require_lab() {
  local id="$1" d
  d="$(lab_dir "${id}")"
  [ -n "${d}" ] && [ -d "${d}" ] || die "Lab '${id}' not found under ${LABS_DIR}/"
  echo "${d}"
}

###############################################################################
# Progress tracking — persists to PROGRESS.md in the repo (NOT in the cluster),
# so it survives 'terraform destroy' / stop / start. Each lab has a table row
# keyed by its id in the first column: | 05 | Topic | Status | Attempts | Done |
###############################################################################
PROGRESS_FILE="${REPO_ROOT}/PROGRESS.md"

# Normalise a lab id for matching the table row (e.g. 5 -> 05, keep t01).
_progress_key() {
  local id="$1"
  case "${id}" in
    t*) echo "${id}" ;;
    *)  printf '%02d' "$((10#${id}))" 2>/dev/null || echo "${id}" ;;
  esac
}

# Update the row for a lab. Args: <id> <new_status> <bump_attempts:true|false>
progress_update() {
  local id status bump key
  id="$1"; status="$2"; bump="${3:-false}"
  key="$(_progress_key "${id}")"
  [ -f "${PROGRESS_FILE}" ] || { warn "No PROGRESS.md; skipping tracker update."; return 0; }

  # Match a markdown table row whose first cell is exactly the key.
  awk -v key="${key}" -v status="${status}" -v bump="${bump}" -v today="$(date +%Y-%m-%d)" '
    BEGIN { FS="|"; OFS="|" }
    {
      # A data row looks like: | 05 | Topic | Status | Attempts | Completed |
      line=$0
      # trim first-cell whitespace for comparison
      c1=$2; gsub(/^[ \t]+|[ \t]+$/,"",c1)
      if (c1==key && NF>=6) {
        # $4=Status, $5=Attempts, $6=Completed (with surrounding spaces)
        $4=" " status " "
        att=$5; gsub(/[^0-9]/,"",att); if (att=="") att=0
        if (bump=="true") att=att+1
        $5=" " att " "
        if (status=="Completed") $6=" " today " "
        print
        next
      }
      print line
    }
  ' "${PROGRESS_FILE}" > "${PROGRESS_FILE}.tmp" && mv "${PROGRESS_FILE}.tmp" "${PROGRESS_FILE}"
}
