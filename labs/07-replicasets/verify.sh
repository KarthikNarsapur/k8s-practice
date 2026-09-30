# Lab 07 verification — sourced by lab-verify.sh (has kc/remote_exec/info/err).
# Contract: on failure print FAILED: + object + ONE conceptual hint, return 1.
# Never reveal the fix here.

# 1. Does the ReplicaSet exist?
if ! kc "get rs rs-web -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: ReplicaSet not found"
  err "Object: replicaset/rs-web in namespace ${NS}"
  err "Hint: The starting state should have created it. Re-run lab-start, then inspect with 'kubectl get rs -n ${NS}'."
  return 1
fi

# 2. spec.replicas must be 4.
desired="$(kc "get rs rs-web -n ${NS} -o jsonpath={.spec.replicas}" 2>/dev/null | tr -d '[:space:]')"
if [ "${desired}" != "4" ]; then
  err "FAILED: Desired replica count is not 4"
  err "Object: replicaset/rs-web -> spec.replicas=${desired:-<none>}"
  err "Hint: A ReplicaSet's desired count is a mutable field. There is a kubectl verb that changes it without editing YAML."
  return 1
fi
ok "PASS: rs-web desired replicas = 4"

# 3. status.readyReplicas must be 4.
ready="$(kc "get rs rs-web -n ${NS} -o jsonpath={.status.readyReplicas}" 2>/dev/null | tr -d '[:space:]')"
if [ "${ready}" != "4" ]; then
  err "FAILED: Ready replicas is not 4"
  err "Object: replicaset/rs-web -> status.readyReplicas=${ready:-0}"
  err "Hint: Desired and actual can differ while pods start or after you delete one. Watch 'kubectl get pods -n ${NS} -w' and check events with 'kubectl describe rs rs-web -n ${NS}'."
  return 1
fi
ok "PASS: rs-web ready replicas = 4"

return 0
