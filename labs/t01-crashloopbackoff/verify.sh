# Lab t01 verification — sourced by lab-verify.sh (has kc/remote_exec/info/ok/err and $NS).
# Contract: on success print 'ok "PASS: ..."' and 'return 0'.
#           on failure print FAILED / Object / ONE conceptual hint, then 'return 1'.
# NEVER reveal the fix here.

# The generic failure response for this lab (single hint, no solution).
fail_unstable() {
  err "FAILED: broken-app not stable"
  err "Object: deployment/broken-app pods (namespace ${NS})"
  err "Hint: A container that exits immediately will be restarted forever — inspect what command the container runs and what its logs/last state say."
  return 1
}

# 1. Deployment must exist.
if ! kc "get deployment broken-app -n ${NS}" >/dev/null 2>&1; then
  fail_unstable
  return 1
fi

# 2. Desired vs available replicas: all replicas must be available.
desired="$(kc "get deployment broken-app -n ${NS} -o jsonpath={.spec.replicas}" 2>/dev/null | tr -d '[:space:]')"
available="$(kc "get deployment broken-app -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
ready="$(kc "get deployment broken-app -n ${NS} -o jsonpath={.status.readyReplicas}" 2>/dev/null | tr -d '[:space:]')"
desired="${desired:-0}"
available="${available:-0}"
ready="${ready:-0}"

if [ "${available}" != "${desired}" ] || [ "${ready}" != "${desired}" ] || [ "${desired}" = "0" ]; then
  fail_unstable
  return 1
fi

# 3. Every pod must be Running (not CrashLoopBackOff / Error / etc.).
bad_phase="$(kc "get pods -n ${NS} -l app=broken-app --no-headers" 2>/dev/null | awk '$3 != "Running" {print $1"="$3}')"
if [ -n "${bad_phase}" ]; then
  fail_unstable
  return 1
fi

# 4. Restart counts must be low and stable (an intermittently crashing pod
#    inflates this even if momentarily Running). Allow a small threshold to
#    tolerate a single benign restart during rollout.
max_restarts="$(kc "get pods -n ${NS} -l app=broken-app -o jsonpath={.items[*].status.containerStatuses[*].restartCount}" 2>/dev/null | tr ' ' '\n' | sort -rn | head -1)"
max_restarts="${max_restarts:-0}"
if [ "${max_restarts}" -gt 2 ]; then
  fail_unstable
  return 1
fi

# 5. All containers must currently be in the 'running' state (not waiting).
waiting="$(kc "get pods -n ${NS} -l app=broken-app -o jsonpath={.items[*].status.containerStatuses[*].state.waiting.reason}" 2>/dev/null | tr -d '[:space:]')"
if [ -n "${waiting}" ]; then
  fail_unstable
  return 1
fi

ok "PASS: broken-app has ${available}/${desired} replicas available and ready"
ok "PASS: all broken-app pods are Running with stable restart counts (max=${max_restarts})"
return 0
