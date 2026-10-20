# Lab t01 verification — sourced by lab-verify.sh (has kc/remote_exec/info/ok/err and $NS).
# Contract: on success print 'ok "PASS: ..."' and 'return 0'.
#           on failure print FAILED / Object / ONE conceptual hint, then 'return 1'.
# NEVER reveal the fix here.

# The generic failure response for this lab (single hint, no solution).
fail_unstable() {
  local detail="${1:-health check failed}"
  err "FAILED: broken-app not stable"
  err "Object: deployment/broken-app pods (namespace ${NS})"
  err "Check: ${detail}"
  err "Hint: Inspect the current Deployment status and Pod states to identify which stability condition is failing."
  return 1
}

# 1. Deployment must exist.
if ! kc "get deployment broken-app -n ${NS}" >/dev/null 2>&1; then
  fail_unstable "Deployment lookup failed (check cluster access and namespace)"
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
  fail_unstable "replicas: desired=${desired}, available=${available}, ready=${ready}"
  return 1
fi

# 3. Every pod must be Running (not CrashLoopBackOff / Error / etc.).
bad_phase="$(kc "get pods -n ${NS} -l app=broken-app -o custom-columns=NAME:.metadata.name,PHASE:.status.phase --no-headers" 2>/dev/null | awk 'NF >= 2 && $2 != "Running" {print $1"="$2}')"
if [ -n "${bad_phase}" ]; then
  fail_unstable "Pods not Running: ${bad_phase}"
  return 1
fi

# 4. Restart counts must be low and stable (an intermittently crashing pod
#    inflates this even if momentarily Running). Allow a small threshold to
#    tolerate a single benign restart during rollout.
max_restarts="$(kc "get pods -n ${NS} -l app=broken-app -o jsonpath={.items[*].status.containerStatuses[*].restartCount}" 2>/dev/null | tr ' ' '\n' | sort -rn | head -1)"
max_restarts="${max_restarts:-0}"
if ! [[ "${max_restarts}" =~ ^[0-9]+$ ]] || [ "${max_restarts}" -gt 2 ]; then
  fail_unstable "max restart count is '${max_restarts}' (expected a numeric value <= 2)"
  return 1
fi

# 5. All containers must currently be in the 'running' state (not waiting).
waiting="$(kc "get pods -n ${NS} -l app=broken-app -o jsonpath={.items[*].status.containerStatuses[*].state.waiting.reason}" 2>/dev/null | tr -d '[:space:]')"
if [ -n "${waiting}" ]; then
  fail_unstable "container waiting reason(s): ${waiting}"
  return 1
fi

ok "PASS: broken-app has ${available}/${desired} replicas available and ready"
ok "PASS: all broken-app pods are Running with stable restart counts (max=${max_restarts})"

###############################################################################
# Hard Challenge checks
###############################################################################

# Shared helper for hard-challenge troubleshooting failures — single generic
# hint per deployment, never the fix.
fail_hc() {
  local name="$1" tag="$2"
  err "FAILED: [${tag}] ${name} is not healthy"
  err "Object: deployment/${name} in namespace ${NS}"
  err "Hint: Inspect pods, events, logs, and the pod spec. There may be more than one problem to fix."
  return 1
}

# HC1 — config-crash: must be Running and stable.
if ! kc "get deployment config-crash -n ${NS}" >/dev/null 2>&1; then
  fail_hc config-crash HC1
  return 1
fi
cc_desired="$(kc "get deployment config-crash -n ${NS} -o jsonpath={.spec.replicas}" 2>/dev/null | tr -d '[:space:]')"
cc_avail="$(kc "get deployment config-crash -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
cc_ready="$(kc "get deployment config-crash -n ${NS} -o jsonpath={.status.readyReplicas}" 2>/dev/null | tr -d '[:space:]')"
cc_desired="${cc_desired:-0}"; cc_avail="${cc_avail:-0}"; cc_ready="${cc_ready:-0}"
if [ "${cc_avail}" != "${cc_desired}" ] || [ "${cc_ready}" != "${cc_desired}" ] || [ "${cc_desired}" = "0" ]; then
  fail_hc config-crash HC1
  return 1
fi
cc_bad="$(kc "get pods -n ${NS} -l app=config-crash -o custom-columns=NAME:.metadata.name,PHASE:.status.phase --no-headers" 2>/dev/null | awk 'NF >= 2 && $2 != "Running" {print $1}')"
if [ -n "${cc_bad}" ]; then
  fail_hc config-crash HC1
  return 1
fi
ok "PASS: [HC1] config-crash has ${cc_avail}/${cc_desired} replicas available and Running"

# HC2 — sched-crash: must be Running and stable (no Pending, no CrashLoop).
if ! kc "get deployment sched-crash -n ${NS}" >/dev/null 2>&1; then
  fail_hc sched-crash HC2
  return 1
fi
sc_desired="$(kc "get deployment sched-crash -n ${NS} -o jsonpath={.spec.replicas}" 2>/dev/null | tr -d '[:space:]')"
sc_avail="$(kc "get deployment sched-crash -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
sc_ready="$(kc "get deployment sched-crash -n ${NS} -o jsonpath={.status.readyReplicas}" 2>/dev/null | tr -d '[:space:]')"
sc_desired="${sc_desired:-0}"; sc_avail="${sc_avail:-0}"; sc_ready="${sc_ready:-0}"
if [ "${sc_avail}" != "${sc_desired}" ] || [ "${sc_ready}" != "${sc_desired}" ] || [ "${sc_desired}" = "0" ]; then
  fail_hc sched-crash HC2
  return 1
fi
sc_bad="$(kc "get pods -n ${NS} -l app=sched-crash -o custom-columns=NAME:.metadata.name,PHASE:.status.phase --no-headers" 2>/dev/null | awk 'NF >= 2 && $2 != "Running" {print $1}')"
if [ -n "${sc_bad}" ]; then
  fail_hc sched-crash HC2
  return 1
fi
ok "PASS: [HC2] sched-crash has ${sc_avail}/${sc_desired} replicas available and Running"

# HC3 — incident-app: Deployment healthy AND the service must select the pods
#        (correct selector).
if ! kc "get deployment incident-app -n ${NS}" >/dev/null 2>&1; then
  fail_hc incident-app HC3
  return 1
fi
ia_desired="$(kc "get deployment incident-app -n ${NS} -o jsonpath={.spec.replicas}" 2>/dev/null | tr -d '[:space:]')"
ia_avail="$(kc "get deployment incident-app -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
ia_ready="$(kc "get deployment incident-app -n ${NS} -o jsonpath={.status.readyReplicas}" 2>/dev/null | tr -d '[:space:]')"
ia_desired="${ia_desired:-0}"; ia_avail="${ia_avail:-0}"; ia_ready="${ia_ready:-0}"
if [ "${ia_avail}" != "${ia_desired}" ] || [ "${ia_ready}" != "${ia_desired}" ] || [ "${ia_desired}" = "0" ]; then
  fail_hc incident-app HC3
  return 1
fi
ia_bad="$(kc "get pods -n ${NS} -l app=incident-app -o custom-columns=NAME:.metadata.name,PHASE:.status.phase --no-headers" 2>/dev/null | awk 'NF >= 2 && $2 != "Running" {print $1}')"
if [ -n "${ia_bad}" ]; then
  fail_hc incident-app HC3
  return 1
fi
# The service must select at least one endpoint (selector must match the pods).
ia_ep_count="$(kc "get endpoints incident-svc -n ${NS} -o jsonpath={.subsets[*].addresses[*].ip}" 2>/dev/null | wc -w | tr -d '[:space:]')"
ia_ep_count="${ia_ep_count:-0}"
if [ "${ia_ep_count}" -lt 1 ]; then
  err "FAILED: [HC3] Service 'incident-svc' has no endpoints"
  err "Object: service/incident-svc endpoints (namespace ${NS})"
  err "Hint: A Service selects pods by label. If the selector does not match any running pod, the endpoints list is empty."
  return 1
fi
ok "PASS: [HC3] incident-app has ${ia_avail}/${ia_desired} replicas Running and incident-svc has endpoints"

ok "PASS: Lab t01 base + hard challenges complete"
return 0
