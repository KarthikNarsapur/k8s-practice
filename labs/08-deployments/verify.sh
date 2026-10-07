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
#    Find RS objects whose controller ownerReference is Deployment/app.
owned_count="$(
  kc "get rs -n ${NS} -o json" 2>/dev/null |
    jq '[.items[]
          | select(any(.metadata.ownerReferences[]?;
                       .kind == "Deployment"
                       and .name == "app"
                       and .controller == true))]
         | length'
)"

owned_count="$(echo "${owned_count}" | tr -d '[:space:]')"

if [ "${owned_count}" != "1" ]; then
  err "FAILED: Expected exactly one ReplicaSet owned by deployment/app"
  err "Object: replicasets in ${NS} owned by deployment/app -> found ${owned_count:-0}"
  err "Hint: A fresh Deployment with no rollouts owns exactly one ReplicaSet. Look at each RS's ownerReferences via 'kubectl get rs -n ${NS} -o wide'."
  return 1
fi

ok "PASS: exactly one ReplicaSet is owned by deployment/app"

# 4. That owned ReplicaSet reports 3 ready replicas.
rs_name="$(
  kc "get rs -n ${NS} -o json" 2>/dev/null |
    jq -r '.items[]
      | select(any(.metadata.ownerReferences[]?;
                   .kind == "Deployment"
                   and .name == "app"
                   and .controller == true))
      | .metadata.name' |
    head -1 |
    tr -d '[:space:]'
)"

rs_ready="$(kc "get rs ${rs_name} -n ${NS} -o jsonpath={.status.readyReplicas}" 2>/dev/null | tr -d '[:space:]')"
if [ "${rs_ready}" != "3" ]; then
  err "FAILED: The owned ReplicaSet does not have 3 ready replicas"
  err "Object: replicaset/${rs_name} -> status.readyReplicas=${rs_ready:-0}"
  err "Hint: The Deployment delegates pod management to its ReplicaSet. Inspect it with 'kubectl describe rs ${rs_name} -n ${NS}'."
  return 1
fi
ok "PASS: replicaset/${rs_name} has 3 ready replicas"

# ============================================================================
# Hard Challenges
# ============================================================================

# HC1 — Deployment Controller Forensics: trace-app (nginx:1.25, 3 replicas,
#        two RS — the active one and the old one scaled to 0).
if ! kc "get deploy trace-app -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: Deployment 'trace-app' not found"
  err "Object: deployment/trace-app in namespace ${NS}"
  err "Hint: The hard-challenge setup should have created it. Re-run lab-start if missing."
  return 1
fi

ta_image="$(kc "get deploy trace-app -n ${NS} -o jsonpath={.spec.template.spec.containers[0].image}" 2>/dev/null | tr -d '[:space:]')"
if [ "${ta_image}" != "nginx:1.25" ]; then
  err "FAILED: trace-app image is not nginx:1.25"
  err "Object: deployment/trace-app -> image=${ta_image:-<none>}"
  err "Hint: The setup rolls trace-app from nginx:1.24 to nginx:1.25. If the image differs, the setup may not have finished."
  return 1
fi

ta_rs_count="$(
  kc "get rs -n ${NS} -o json" 2>/dev/null |
    jq '[.items[]
          | select(any(.metadata.ownerReferences[]?;
                       .kind == "Deployment"
                       and .name == "trace-app"
                       and .controller == true))]
         | length'
)"

ta_rs_count="$(echo "${ta_rs_count}" | tr -d '[:space:]')"
if [ "${ta_rs_count}" != "2" ]; then
  err "FAILED: Expected 2 ReplicaSets owned by trace-app"
  err "Object: replicasets owned by deployment/trace-app -> found ${ta_rs_count:-0}"
  err "Hint: A Deployment keeps old ReplicaSets scaled to 0 after a rollout. Two template revisions produce two ReplicaSets."
  return 1
fi

ta_avail="$(kc "get deploy trace-app -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
if [ "${ta_avail}" != "3" ]; then
  err "FAILED: trace-app does not have 3 available replicas"
  err "Object: deployment/trace-app -> availableReplicas=${ta_avail:-0}"
  err "Hint: Ensure the rollout completed. All 3 replicas should be running on the active ReplicaSet."
  return 1
fi
ok "PASS: deployment/trace-app has 2 ReplicaSets and 3 available replicas at nginx:1.25"

# HC2 — Template Change Investigation: tmpl-change (nginx:1.25 + env var,
#        2 RS, 2 available replicas).
if ! kc "get deploy tmpl-change -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: Deployment 'tmpl-change' not found"
  err "Object: deployment/tmpl-change in namespace ${NS}"
  err "Hint: The hard-challenge setup should have created it. Re-run lab-start if missing."
  return 1
fi

tc_rs_count="$(kc "get rs -n ${NS} -o jsonpath={range.items[?(@.metadata.ownerReferences[0].name=='tmpl-change')]}{.metadata.name}{'\n'}{end}" 2>/dev/null | grep -c . || true)"
tc_rs_count="$(echo "${tc_rs_count}" | tr -d '[:space:]')"
if [ "${tc_rs_count}" != "2" ]; then
  err "FAILED: Expected 2 ReplicaSets owned by tmpl-change"
  err "Object: replicasets owned by deployment/tmpl-change -> found ${tc_rs_count:-0}"
  err "Hint: Any change to the pod template creates a new ReplicaSet. Env vars are part of the template."
  return 1
fi

tc_avail="$(kc "get deploy tmpl-change -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
if [ "${tc_avail}" != "2" ]; then
  err "FAILED: tmpl-change does not have 2 available replicas"
  err "Object: deployment/tmpl-change -> availableReplicas=${tc_avail:-0}"
  err "Hint: Both replicas must be available after the template change. Check pod status."
  return 1
fi
ok "PASS: deployment/tmpl-change has 2 ReplicaSets and 2 available replicas"

# HC3 — ReplicaSet/Deployment Mismatch: broken-deploy (learner must fix the
#        excessive memory request so all 3 replicas become Ready).
if ! kc "get deploy broken-deploy -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: Deployment 'broken-deploy' not found"
  err "Object: deployment/broken-deploy in namespace ${NS}"
  err "Hint: The hard-challenge setup should have created it. Re-run lab-start if missing."
  return 1
fi

bd_desired="$(kc "get deploy broken-deploy -n ${NS} -o jsonpath={.spec.replicas}" 2>/dev/null | tr -d '[:space:]')"
bd_avail="$(kc "get deploy broken-deploy -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
bd_desired="${bd_desired:-0}"
bd_avail="${bd_avail:-0}"
if [ "${bd_avail}" != "${bd_desired}" ] || [ "${bd_desired}" = "0" ]; then
  err "FAILED: broken-deploy replicas not fully available"
  err "Object: deployment/broken-deploy -> available=${bd_avail}, desired=${bd_desired}"
  err "Hint: Pods that request more resources than any node can provide will stay Pending indefinitely. Inspect pod events."
  return 1
fi
ok "PASS: deployment/broken-deploy has all ${bd_desired} replicas available"

return 0
