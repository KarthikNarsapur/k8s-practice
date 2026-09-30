# Lab 08 verification — sourced by lab-verify.sh (has kc/remote_exec/info/err).
# Contract: on failure print FAILED: + object + ONE conceptual hint, return 1.
# Never reveal the fix here.

# 1. Does the Deployment 'app' exist?
if ! kc "get deploy app -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: Deployment not found"
  err "Object: deployment/app in namespace ${NS}"
  err "Hint: A Deployment is the standard object for stateless apps. There is an imperative 'kubectl create' subcommand for it, or apply a manifest."
  return 1
fi

# 2. availableReplicas must be 3.
avail="$(kc "get deploy app -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
if [ "${avail}" != "3" ]; then
  err "FAILED: Available replicas is not 3"
  err "Object: deployment/app -> status.availableReplicas=${avail:-0}"
  err "Hint: Check spec.replicas and whether all pods are Ready via 'kubectl get deploy,pods -n ${NS}' and 'kubectl describe deploy app -n ${NS}'."
  return 1
fi
ok "PASS: deployment/app has 3 available replicas"

# 3. Exactly one ReplicaSet owned by 'app' exists, and it has 3 ready.
#    Find RS objects whose ownerReferences name == app and controller == true.
owned_count="$(kc "get rs -n ${NS} -o jsonpath={range.items[?(@.metadata.ownerReferences[0].name=='app')]}{.metadata.name}{'\n'}{end}" 2>/dev/null | grep -c . || true)"
owned_count="$(echo "${owned_count}" | tr -d '[:space:]')"
if [ "${owned_count}" != "1" ]; then
  err "FAILED: Expected exactly one ReplicaSet owned by deployment/app"
  err "Object: replicasets in ${NS} owned by deployment/app -> found ${owned_count:-0}"
  err "Hint: A fresh Deployment with no rollouts owns exactly one ReplicaSet. Look at each RS's ownerReferences via 'kubectl get rs -n ${NS} -o wide'."
  return 1
fi
ok "PASS: exactly one ReplicaSet is owned by deployment/app"

# 4. That owned ReplicaSet reports 3 ready replicas.
rs_name="$(kc "get rs -n ${NS} -o jsonpath={range.items[?(@.metadata.ownerReferences[0].name=='app')]}{.metadata.name}{'\n'}{end}" 2>/dev/null | grep . | head -1 | tr -d '[:space:]')"
rs_ready="$(kc "get rs ${rs_name} -n ${NS} -o jsonpath={.status.readyReplicas}" 2>/dev/null | tr -d '[:space:]')"
if [ "${rs_ready}" != "3" ]; then
  err "FAILED: The owned ReplicaSet does not have 3 ready replicas"
  err "Object: replicaset/${rs_name} -> status.readyReplicas=${rs_ready:-0}"
  err "Hint: The Deployment delegates pod management to its ReplicaSet. Inspect it with 'kubectl describe rs ${rs_name} -n ${NS}'."
  return 1
fi
ok "PASS: replicaset/${rs_name} has 3 ready replicas"

return 0
