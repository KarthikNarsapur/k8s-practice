# Lab 02 verification — sourced by lab-verify.sh (has kc/remote_exec/info/ok/err).
# Contract: on failure print FAILED: + object + ONE hint, return non-zero.

# 1. Does the pod kb-pod exist in the namespace?
phase="$(kc "get pod kb-pod -n ${NS} -o jsonpath={.status.phase}" 2>/dev/null | tr -d '[:space:]')"
if [ -z "${phase}" ]; then
  err "FAILED: Pod kb-pod not found"
  err "Object: pod/kb-pod in namespace ${NS}"
  err "Hint: Create it imperatively with the correct image; 'kubectl run' is the fastest path."
  return 1
fi
ok "PASS: pod kb-pod exists in ${NS}"

# 2. Is it Running?
if [ "${phase}" != "Running" ]; then
  err "FAILED: Pod kb-pod is not Running (phase=${phase})"
  err "Object: pod/kb-pod in namespace ${NS}"
  err "Hint: Inspect why with 'kubectl describe' and read the Events section."
  return 1
fi
ok "PASS: pod kb-pod is Running"

# 3. Does it carry annotation lab02/done=yes?
ann="$(kc "get pod kb-pod -n ${NS} -o jsonpath={.metadata.annotations.lab02/done}" 2>/dev/null | tr -d '[:space:]')"
if [ "${ann}" != "yes" ]; then
  err "FAILED: Required annotation missing or wrong"
  err "Object: annotation lab02/done on pod/kb-pod"
  err "Hint: Metadata can be attached to a live object without editing its YAML."
  return 1
fi
ok "PASS: pod kb-pod has annotation lab02/done=yes"

return 0
