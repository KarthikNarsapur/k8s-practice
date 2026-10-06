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

###############################################################################
# Hard Challenge checks
###############################################################################

# HC1 — ReplicaSet Ownership Investigation.
#   Desired state: rs-ownership is healthy at 3 ready replicas (self-healed if a
#   managed pod was deleted), AND the unmanaged 'stray-pod' still exists because
#   its labels do not satisfy the selector so the controller never owned or
#   recreated/deleted it.
if ! kc "get rs rs-ownership -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC1] ReplicaSet 'rs-ownership' not found"
  err "Object: replicaset/rs-ownership in namespace ${NS}"
  err "Hint: The hard-challenge setup should have created it. Re-run lab-start if missing."
  return 1
fi
own_ready="$(kc "get rs rs-ownership -n ${NS} -o jsonpath={.status.readyReplicas}" 2>/dev/null | tr -d '[:space:]')"
own_desired="$(kc "get rs rs-ownership -n ${NS} -o jsonpath={.spec.replicas}" 2>/dev/null | tr -d '[:space:]')"
own_ready="${own_ready:-0}"
own_desired="${own_desired:-0}"
if [ "${own_ready}" != "${own_desired}" ] || [ "${own_desired}" = "0" ]; then
  err "FAILED: [HC1] rs-ownership has not reconciled to its desired count"
  err "Object: replicaset/rs-ownership -> ready=${own_ready}, desired=${own_desired}"
  err "Hint: A ReplicaSet recreates a managed pod you delete, to close the gap between actual and desired. Give it a moment and recheck its pods."
  return 1
fi
# The stray pod must still be present (it is NOT managed, so nothing deletes it).
if ! kc "get pod stray-pod -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC1] the unmanaged pod 'stray-pod' is gone"
  err "Object: pod/stray-pod in namespace ${NS}"
  err "Hint: A pod the ReplicaSet does not own should be unaffected by it. Investigate which labels the selector actually requires versus what stray-pod carries — then leave it in place."
  return 1
fi
ok "PASS: [HC1] rs-ownership is at ${own_ready}/${own_desired} and the unmanaged stray-pod still exists"

# HC2 — Selector and Adoption.
#   The bare pod 'adopt-me' has labels that FULLY satisfy the rs-ownership
#   selector, so the controller acquires it: its ownerReferences must now name
#   rs-ownership (controller=true).
adopt_owner="$(kc "get pod adopt-me -n ${NS} -o jsonpath={.metadata.ownerReferences[0].name}" 2>/dev/null | tr -d '[:space:]')"
if [ "${adopt_owner}" != "rs-ownership" ]; then
  err "FAILED: [HC2] 'adopt-me' is not owned by rs-ownership"
  err "Object: pod/adopt-me -> ownerReferences[0].name=${adopt_owner:-<none>}"
  err "Hint: A bare pod whose labels match a ReplicaSet's selector is acquired by it. Check the pod's ownerReferences and whether its labels satisfy the full selector."
  return 1
fi
ok "PASS: [HC2] adopt-me was adopted by rs-ownership (ownerReferences names it)"

# HC3 — Replica Count Forensics.
#   rs-forensics could not meet its desired count because the pod template asked
#   for an impossible memory request, leaving pods Pending. Desired state:
#   ready == desired (the learner diagnosed and restored it).
if ! kc "get rs rs-forensics -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC3] ReplicaSet 'rs-forensics' not found"
  err "Object: replicaset/rs-forensics in namespace ${NS}"
  err "Hint: The hard-challenge setup should have created it. Re-run lab-start if missing."
  return 1
fi
fx_ready="$(kc "get rs rs-forensics -n ${NS} -o jsonpath={.status.readyReplicas}" 2>/dev/null | tr -d '[:space:]')"
fx_desired="$(kc "get rs rs-forensics -n ${NS} -o jsonpath={.spec.replicas}" 2>/dev/null | tr -d '[:space:]')"
fx_ready="${fx_ready:-0}"
fx_desired="${fx_desired:-0}"
if [ "${fx_ready}" != "${fx_desired}" ] || [ "${fx_desired}" = "0" ]; then
  err "FAILED: [HC3] rs-forensics desired and ready replicas do not match"
  err "Object: replicaset/rs-forensics -> ready=${fx_ready}, desired=${fx_desired}"
  err "Hint: When pods stay Pending the gap never closes. Read the pods' events for the scheduling reason, then adjust what the pod template asks for so they can be placed."
  return 1
fi
ok "PASS: [HC3] rs-forensics restored to ${fx_ready}/${fx_desired} ready replicas"

ok "PASS: Lab 07 base + hard challenges complete"
return 0
