# Lab 04 verification — sourced by lab-verify.sh (has kc/remote_exec/info/ok/err).
# Contract: on failure print FAILED: + object + ONE hint, return non-zero.

# 1. Does the pod stable exist?
phase="$(kc "get pod stable -n ${NS} -o jsonpath={.status.phase}" 2>/dev/null | tr -d '[:space:]')"
if [ -z "${phase}" ]; then
  err "FAILED: Pod stable not found"
  err "Object: pod/stable in namespace ${NS}"
  err "Hint: You need a long-lived Pod that does not exit — a plain web server image keeps running on its own."
  return 1
fi
ok "PASS: pod stable exists in ${NS}"

# 2. Is it Running?
if [ "${phase}" != "Running" ]; then
  err "FAILED: Pod stable is not Running (phase=${phase})"
  err "Object: pod/stable in namespace ${NS}"
  err "Hint: A container that exits or crashes will not hold a steady Running phase — check its command and Events."
  return 1
fi
ok "PASS: pod stable is Running"

return 0
