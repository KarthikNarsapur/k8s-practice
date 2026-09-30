# Lab 09 verification — sourced by lab-verify.sh (has kc/remote_exec/info/err).
# Contract: on failure print FAILED: + object + ONE conceptual hint, return 1.
# Never reveal the fix here.

# 1. Does the Deployment 'rollme' exist?
if ! kc "get deploy rollme -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: Deployment not found"
  err "Object: deployment/rollme in namespace ${NS}"
  err "Hint: The starting state should have created it. Re-run lab-start, then inspect with 'kubectl get deploy -n ${NS}'."
  return 1
fi

# 2. Container image must be nginx:1.25.
image="$(kc "get deploy rollme -n ${NS} -o jsonpath={.spec.template.spec.containers[0].image}" 2>/dev/null | tr -d '[:space:]')"
if [ "${image}" != "nginx:1.25" ]; then
  err "FAILED: Container image is not nginx:1.25"
  err "Object: deployment/rollme -> spec.template.spec.containers[0].image=${image:-<none>}"
  err "Hint: Changing the image updates the pod template, which triggers a rolling update. There is a 'kubectl set image' verb, or edit the template."
  return 1
fi
ok "PASS: rollme image is nginx:1.25"

# 3. All 4 replicas available and up to date.
avail="$(kc "get deploy rollme -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
updated="$(kc "get deploy rollme -n ${NS} -o jsonpath={.status.updatedReplicas}" 2>/dev/null | tr -d '[:space:]')"
if [ "${avail}" != "4" ] || [ "${updated}" != "4" ]; then
  err "FAILED: Rollout not fully complete"
  err "Object: deployment/rollme -> availableReplicas=${avail:-0}, updatedReplicas=${updated:-0} (want 4/4)"
  err "Hint: A rollout is done only when every replica is updated AND available. Track it with 'kubectl rollout status deploy/rollme -n ${NS}'."
  return 1
fi
ok "PASS: rollme has 4/4 updated and available replicas"

# 4. observedGeneration must be current (controller has processed latest spec).
gen="$(kc "get deploy rollme -n ${NS} -o jsonpath={.metadata.generation}" 2>/dev/null | tr -d '[:space:]')"
obs="$(kc "get deploy rollme -n ${NS} -o jsonpath={.status.observedGeneration}" 2>/dev/null | tr -d '[:space:]')"
if [ -z "${gen}" ] || [ "${obs}" != "${gen}" ]; then
  err "FAILED: Deployment status is stale"
  err "Object: deployment/rollme -> metadata.generation=${gen:-<none>}, status.observedGeneration=${obs:-<none>}"
  err "Hint: observedGeneration lags metadata.generation while the controller is still reconciling. Let the rollout finish and re-check."
  return 1
fi
ok "PASS: rollme observedGeneration is current (${obs})"

return 0
