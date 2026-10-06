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

# ============================================================================
# Hard Challenges
# ============================================================================

# HC1 — Failed Rolling Update: rollme-fail must be recovered off the bad tag and
#        back to full availability.
BAD_TAG_HC1="nginx:doesnotexist-99.99"
if ! kc "get deploy rollme-fail -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: Deployment 'rollme-fail' not found"
  err "Object: deployment/rollme-fail in namespace ${NS}"
  err "Hint: The hard-challenge setup should have created it. Re-run lab-start if missing."
  return 1
fi

rf_image="$(kc "get deploy rollme-fail -n ${NS} -o jsonpath={.spec.template.spec.containers[0].image}" 2>/dev/null | tr -d '[:space:]')"
if [ "${rf_image}" = "${BAD_TAG_HC1}" ]; then
  err "FAILED: rollme-fail still points at the broken image"
  err "Object: deployment/rollme-fail -> image=${rf_image}"
  err "Hint: A stuck rollout can be recovered by returning the pod template to a pullable image. The old ReplicaSet still remembers it."
  return 1
fi
case "${rf_image}" in
  nginx:*|nginx) : ;;
  *)
    err "FAILED: rollme-fail is not running a valid nginx image"
    err "Object: deployment/rollme-fail -> image=${rf_image:-<none>}"
    err "Hint: The healthy baseline used an official nginx image. Recover to a tag that actually exists."
    return 1
    ;;
esac

rf_desired="$(kc "get deploy rollme-fail -n ${NS} -o jsonpath={.spec.replicas}" 2>/dev/null | tr -d '[:space:]')"
rf_avail="$(kc "get deploy rollme-fail -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
rf_desired="${rf_desired:-0}"
rf_avail="${rf_avail:-0}"
if [ "${rf_avail}" != "${rf_desired}" ] || [ "${rf_desired}" = "0" ]; then
  err "FAILED: rollme-fail is not fully available"
  err "Object: deployment/rollme-fail -> available=${rf_avail}, desired=${rf_desired}"
  err "Hint: An ImagePullBackOff keeps new pods from becoming Ready. Fix the image, then the rollout can finish."
  return 1
fi
ok "PASS: rollme-fail recovered to a valid nginx image with all ${rf_desired} replicas available"

# HC2 — maxSurge/maxUnavailable: surge-test rolled to nginx:1.25, 6/6 available
#        and updated.
if ! kc "get deploy surge-test -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: Deployment 'surge-test' not found"
  err "Object: deployment/surge-test in namespace ${NS}"
  err "Hint: The hard-challenge setup should have created it. Re-run lab-start if missing."
  return 1
fi

st_image="$(kc "get deploy surge-test -n ${NS} -o jsonpath={.spec.template.spec.containers[0].image}" 2>/dev/null | tr -d '[:space:]')"
if [ "${st_image}" != "nginx:1.25" ]; then
  err "FAILED: surge-test image is not nginx:1.25"
  err "Object: deployment/surge-test -> image=${st_image:-<none>}"
  err "Hint: Roll the Deployment forward by updating its image. The strategy keeps the service fully available while it rolls."
  return 1
fi

st_avail="$(kc "get deploy surge-test -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
st_updated="$(kc "get deploy surge-test -n ${NS} -o jsonpath={.status.updatedReplicas}" 2>/dev/null | tr -d '[:space:]')"
if [ "${st_avail}" != "6" ] || [ "${st_updated}" != "6" ]; then
  err "FAILED: surge-test rollout not complete"
  err "Object: deployment/surge-test -> availableReplicas=${st_avail:-0}, updatedReplicas=${st_updated:-0} (want 6/6)"
  err "Hint: With maxUnavailable=0 the controller surges new pods before removing old ones. Wait for the rollout to finish."
  return 1
fi
ok "PASS: surge-test rolled to nginx:1.25 with 6/6 updated and available replicas"

# HC3 — Rollout Availability Investigation: avail-check must be fixed off the bad
#        tag so all desired replicas are available.
BAD_TAG_HC3="nginx:1.25-nonexistent"
if ! kc "get deploy avail-check -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: Deployment 'avail-check' not found"
  err "Object: deployment/avail-check in namespace ${NS}"
  err "Hint: The hard-challenge setup should have created it. Re-run lab-start if missing."
  return 1
fi

ac_image="$(kc "get deploy avail-check -n ${NS} -o jsonpath={.spec.template.spec.containers[0].image}" 2>/dev/null | tr -d '[:space:]')"
if [ "${ac_image}" = "${BAD_TAG_HC3}" ]; then
  err "FAILED: avail-check still points at the broken image"
  err "Object: deployment/avail-check -> image=${ac_image}"
  err "Hint: Pods cannot become Ready if the image tag does not exist in the registry. Change the image to one that does."
  return 1
fi
case "${ac_image}" in
  nginx:*|nginx) : ;;
  *)
    err "FAILED: avail-check is not running a valid nginx image"
    err "Object: deployment/avail-check -> image=${ac_image:-<none>}"
    err "Hint: Use a real, pullable nginx tag so the pods can start."
    return 1
    ;;
esac

ac_desired="$(kc "get deploy avail-check -n ${NS} -o jsonpath={.spec.replicas}" 2>/dev/null | tr -d '[:space:]')"
ac_avail="$(kc "get deploy avail-check -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
ac_desired="${ac_desired:-0}"
ac_avail="${ac_avail:-0}"
if [ "${ac_avail}" != "${ac_desired}" ] || [ "${ac_desired}" = "0" ]; then
  err "FAILED: avail-check is not fully available"
  err "Object: deployment/avail-check -> available=${ac_avail}, desired=${ac_desired}"
  err "Hint: Diagnose whether the problem is image pull, scheduling, or readiness, then restore full availability."
  return 1
fi
ok "PASS: avail-check recovered to a valid nginx image with all ${ac_desired} replicas available"

return 0
