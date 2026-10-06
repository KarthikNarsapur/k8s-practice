# Lab 10 verification — sourced by lab-verify.sh (has kc/remote_exec/info/ok/err).
# Contract: on success 'ok "PASS: ..."' + return 0.
#           on failure err FAILED/Object/Hint (ONE hint, no solution) + return 1.
# Use return, not exit.

BAD_TAG="nginx:doesnotexist-9.9"

# 0. Deployment exists?
if ! kc "get deployment rbk -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: Deployment 'rbk' not found"
  err "Object: deployment/rbk in namespace ${NS}"
  err "Hint: The lab setup deploys 'rbk'. Re-run ./scripts/lab-start.sh 10 if it is missing."
  return 1
fi

# 1. Deployment healthy: all desired replicas available?
desired="$(kc "get deployment rbk -n ${NS} -o jsonpath={.spec.replicas}" | tr -d '[:space:]')"
available="$(kc "get deployment rbk -n ${NS} -o jsonpath={.status.availableReplicas}" | tr -d '[:space:]')"
desired="${desired:-0}"
available="${available:-0}"
if [ "${available}" != "${desired}" ] || [ "${desired}" = "0" ]; then
  err "FAILED: Deployment 'rbk' is not fully available"
  err "Object: deployment/rbk (available=${available}, desired=${desired})"
  err "Hint: A rollout that references a pullable image will become available. Inspect the current pods' status and the rollout history."
  return 1
fi
ok "PASS: deployment/rbk has all ${desired} replicas available"

# 2. Running a valid nginx image (NOT the bad tag).
image="$(kc "get deployment rbk -n ${NS} -o jsonpath={.spec.template.spec.containers[0].image}" | tr -d '[:space:]')"
if [ "${image}" = "${BAD_TAG}" ]; then
  err "FAILED: Deployment 'rbk' still points at the broken image"
  err "Object: deployment/rbk container image = ${image}"
  err "Hint: A Deployment keeps a revision history; there is a single command that returns it to a previous working revision."
  return 1
fi
case "${image}" in
  nginx:*|nginx) : ;;
  *)
    err "FAILED: Deployment 'rbk' is not running an nginx image"
    err "Object: deployment/rbk container image = ${image}"
    err "Hint: The known-good baseline used the official nginx image. Roll back to the revision that used it."
    return 1
    ;;
esac
ok "PASS: deployment/rbk is running a valid nginx image (${image})"

ok "PASS: rollback complete — rbk is healthy and off the broken image"

# ============================================================================
# Hard Challenges
# ============================================================================

# HC1 — Multi-Revision Forensics: multi-rev healthy on a valid nginx image.
BAD_TAG_HC1="nginx:doesnotexist-bad"
if ! kc "get deployment multi-rev -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: Deployment 'multi-rev' not found"
  err "Object: deployment/multi-rev in namespace ${NS}"
  err "Hint: The hard-challenge setup should have created it. Re-run lab-start if missing."
  return 1
fi

mr_image="$(kc "get deployment multi-rev -n ${NS} -o jsonpath={.spec.template.spec.containers[0].image}" 2>/dev/null | tr -d '[:space:]')"
if [ "${mr_image}" = "${BAD_TAG_HC1}" ]; then
  err "FAILED: multi-rev still points at the broken revision's image"
  err "Object: deployment/multi-rev container image = ${mr_image}"
  err "Hint: Multiple revisions exist; only some are healthy. Identify a working revision from the history and roll to it."
  return 1
fi
case "${mr_image}" in
  nginx:*|nginx) : ;;
  *)
    err "FAILED: multi-rev is not running a valid nginx image"
    err "Object: deployment/multi-rev container image = ${mr_image:-<none>}"
    err "Hint: Inspect the rollout history to find which revision used a pullable nginx image."
    return 1
    ;;
esac

mr_desired="$(kc "get deployment multi-rev -n ${NS} -o jsonpath={.spec.replicas}" 2>/dev/null | tr -d '[:space:]')"
mr_avail="$(kc "get deployment multi-rev -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
mr_desired="${mr_desired:-0}"
mr_avail="${mr_avail:-0}"
if [ "${mr_avail}" != "${mr_desired}" ] || [ "${mr_desired}" = "0" ]; then
  err "FAILED: multi-rev is not fully available"
  err "Object: deployment/multi-rev (available=${mr_avail}, desired=${mr_desired})"
  err "Hint: A healthy revision brings every replica up. Pick the revision whose pods all become Ready."
  return 1
fi
ok "PASS: deployment/multi-rev is healthy on a valid nginx image (${mr_image})"

# HC2 — Rollback Investigation: rev-inspect healthy on a valid nginx image.
BAD_TAG_HC2="nginx:doesnotexist-broken"
if ! kc "get deployment rev-inspect -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: Deployment 'rev-inspect' not found"
  err "Object: deployment/rev-inspect in namespace ${NS}"
  err "Hint: The hard-challenge setup should have created it. Re-run lab-start if missing."
  return 1
fi

ri_image="$(kc "get deployment rev-inspect -n ${NS} -o jsonpath={.spec.template.spec.containers[0].image}" 2>/dev/null | tr -d '[:space:]')"
if [ "${ri_image}" = "${BAD_TAG_HC2}" ]; then
  err "FAILED: rev-inspect still points at the broken image"
  err "Object: deployment/rev-inspect container image = ${ri_image}"
  err "Hint: Inspect the rollout history and ReplicaSets, then roll back to the revision that worked."
  return 1
fi
case "${ri_image}" in
  nginx:*|nginx) : ;;
  *)
    err "FAILED: rev-inspect is not running a valid nginx image"
    err "Object: deployment/rev-inspect container image = ${ri_image:-<none>}"
    err "Hint: The healthy baseline used an official nginx image. Roll back to it."
    return 1
    ;;
esac

ri_desired="$(kc "get deployment rev-inspect -n ${NS} -o jsonpath={.spec.replicas}" 2>/dev/null | tr -d '[:space:]')"
ri_avail="$(kc "get deployment rev-inspect -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
ri_desired="${ri_desired:-0}"
ri_avail="${ri_avail:-0}"
if [ "${ri_avail}" != "${ri_desired}" ] || [ "${ri_desired}" = "0" ]; then
  err "FAILED: rev-inspect is not fully available"
  err "Object: deployment/rev-inspect (available=${ri_avail}, desired=${ri_desired})"
  err "Hint: After choosing the right revision, every replica should become Ready."
  return 1
fi
ok "PASS: deployment/rev-inspect is healthy on a valid nginx image (${ri_image})"

# HC3 — Post-Rollback Verification: post-rbk healthy on a valid nginx image
#        (not the bad 'nginx:nope' tag).
BAD_TAG_HC3="nginx:nope"
if ! kc "get deployment post-rbk -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: Deployment 'post-rbk' not found"
  err "Object: deployment/post-rbk in namespace ${NS}"
  err "Hint: The hard-challenge setup should have created it. Re-run lab-start if missing."
  return 1
fi

pr_image="$(kc "get deployment post-rbk -n ${NS} -o jsonpath={.spec.template.spec.containers[0].image}" 2>/dev/null | tr -d '[:space:]')"
if [ "${pr_image}" = "${BAD_TAG_HC3}" ]; then
  err "FAILED: post-rbk still points at the broken image"
  err "Object: deployment/post-rbk container image = ${pr_image}"
  err "Hint: Roll back off the broken tag, then confirm the active ReplicaSet and pod template match the recovered image."
  return 1
fi
case "${pr_image}" in
  nginx:*|nginx) : ;;
  *)
    err "FAILED: post-rbk is not running a valid nginx image"
    err "Object: deployment/post-rbk container image = ${pr_image:-<none>}"
    err "Hint: Roll back to a revision that used a real, pullable nginx image."
    return 1
    ;;
esac

pr_desired="$(kc "get deployment post-rbk -n ${NS} -o jsonpath={.spec.replicas}" 2>/dev/null | tr -d '[:space:]')"
pr_avail="$(kc "get deployment post-rbk -n ${NS} -o jsonpath={.status.availableReplicas}" 2>/dev/null | tr -d '[:space:]')"
pr_desired="${pr_desired:-0}"
pr_avail="${pr_avail:-0}"
if [ "${pr_avail}" != "${pr_desired}" ] || [ "${pr_desired}" = "0" ]; then
  err "FAILED: post-rbk is not fully available"
  err "Object: deployment/post-rbk (available=${pr_avail}, desired=${pr_desired})"
  err "Hint: Verify the rollback finished — all replicas on the active ReplicaSet should be Ready."
  return 1
fi
ok "PASS: deployment/post-rbk is healthy on a valid nginx image (${pr_image})"

return 0
