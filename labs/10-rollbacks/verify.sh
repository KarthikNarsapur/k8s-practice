# Lab 10 verification — sourced by lab-verify.sh (has kc/remote_exec/info/ok/err).
# Contract: on success 'ok "PASS: ..."' + return 0.
#           on failure err FAILED/Object/Hint (ONE hint, no solution) + return 1.
# Use return, not exit.

BAD_TAG="nginx:doesnotexist-9.9"

# 0. Deployment exists?
if ! kc "get deployment rbk -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: Deployment 'rbk' not found"
  err "Object: deployment/rbk in namespace ${NS}"
  err "Hint: The lab setup deploys 'rbk'. Re-run ./scripts/lab-start.sh 10 if it is missing."
  return 1
fi

# 1. Deployment healthy: all desired replicas available?
desired="$(kc "get deployment rbk -n ${NS} -o jsonpath={.spec.replicas}" | tr -d '[:space:]')"
available="$(kc "get deployment rbk -n ${NS} -o jsonpath={.status.availableReplicas}" | tr -d '[:space:]')"
desired="${desired:-0}"
available="${available:-0}"
if [ "${available}" != "${desired}" ] || [ "${desired}" = "0" ]; then
  err "FAILED: Deployment 'rbk' is not fully available"
  err "Object: deployment/rbk (available=${available}, desired=${desired})"
  err "Hint: A rollout that references a pullable image will become available. Inspect the current pods' status and the rollout history."
  return 1
fi
ok "PASS: deployment/rbk has all ${desired} replicas available"

# 2. Running a valid nginx image (NOT the bad tag).
image="$(kc "get deployment rbk -n ${NS} -o jsonpath={.spec.template.spec.containers[0].image}" | tr -d '[:space:]')"
if [ "${image}" = "${BAD_TAG}" ]; then
  err "FAILED: Deployment 'rbk' still points at the broken image"
  err "Object: deployment/rbk container image = ${image}"
  err "Hint: A Deployment keeps a revision history; there is a single command that returns it to a previous working revision."
  return 1
fi
case "${image}" in
  nginx:*|nginx) : ;;
  *)
    err "FAILED: Deployment 'rbk' is not running an nginx image"
    err "Object: deployment/rbk container image = ${image}"
    err "Hint: The known-good baseline used the official nginx image. Roll back to the revision that used it."
    return 1
    ;;
esac
ok "PASS: deployment/rbk is running a valid nginx image (${image})"

ok "PASS: rollback complete — rbk is healthy and off the broken image"
return 0
