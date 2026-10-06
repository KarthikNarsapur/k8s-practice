# Lab 12 verification — sourced by lab-verify.sh (has kc/remote_exec/info/ok/err).
# Contract: on success 'ok "PASS: ..."' + return 0.
#           on failure err FAILED/Object/Hint (ONE hint, no solution) + return 1.
# Use return, not exit.

# 0. Job exists?
if ! kc "get job pi -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: Job 'pi' not found"
  err "Object: job/pi in namespace ${NS}"
  err "Hint: A Job runs pods to completion. Create one — 'kubectl create job' can help, or apply a manifest with completions/parallelism."
  return 1
fi

# 1. status.succeeded == 3 ?
succeeded="$(kc "get job pi -n ${NS} -o jsonpath={.status.succeeded}" | tr -d '[:space:]')"
succeeded="${succeeded:-0}"
if [ "${succeeded}" != "3" ]; then
  err "FAILED: Job 'pi' has not completed 3 times"
  err "Object: job/pi (status.succeeded=${succeeded}, expected 3)"
  err "Hint: A Job finishes when the required number of completions succeed. Check completions/parallelism and whether the pods exit 0."
  return 1
fi
ok "PASS: job/pi status.succeeded == 3"

ok "PASS: Job 'pi' completed all 3 completions successfully"

###############################################################################
# Hard Challenge checks
###############################################################################

# HC1 — fail-job: exists AND has at least one succeeded pod.
if ! kc "get job fail-job -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC1] Job 'fail-job' not found"
  err "Object: job/fail-job in namespace ${NS}"
  err "Hint: The original Job's command exits non-zero. Delete it and recreate it with a command that exits 0."
  return 1
fi
fj_succeeded="$(kc "get job fail-job -n ${NS} -o jsonpath={.status.succeeded}" 2>/dev/null | tr -d '[:space:]')"
fj_succeeded="${fj_succeeded:-0}"
if [ "${fj_succeeded}" -lt 1 ] 2>/dev/null; then
  err "FAILED: [HC1] Job 'fail-job' has not succeeded"
  err "Object: job/fail-job (status.succeeded=${fj_succeeded})"
  err "Hint: The pod's command exits non-zero, which counts as a failure. Fix the command so the container exits 0."
  return 1
fi
ok "PASS: [HC1] fail-job has at least one successful completion (succeeded=${fj_succeeded})"

# HC2 — backoff-job: exists AND has at least one succeeded pod.
if ! kc "get job backoff-job -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC2] Job 'backoff-job' not found"
  err "Object: job/backoff-job in namespace ${NS}"
  err "Hint: The original Job failed beyond its retry limit. Delete it and recreate it with a command that succeeds."
  return 1
fi
bj_succeeded="$(kc "get job backoff-job -n ${NS} -o jsonpath={.status.succeeded}" 2>/dev/null | tr -d '[:space:]')"
bj_succeeded="${bj_succeeded:-0}"
if [ "${bj_succeeded}" -lt 1 ] 2>/dev/null; then
  err "FAILED: [HC2] Job 'backoff-job' has not succeeded"
  err "Object: job/backoff-job (status.succeeded=${bj_succeeded})"
  err "Hint: A Job that exceeds its retry limit is marked Failed and stops creating pods. Recreate it with a working command."
  return 1
fi
ok "PASS: [HC2] backoff-job has at least one successful completion (succeeded=${bj_succeeded})"

# HC3 — parallel-job: exists AND succeeded == 5.
if ! kc "get job parallel-job -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC3] Job 'parallel-job' not found"
  err "Object: job/parallel-job in namespace ${NS}"
  err "Hint: The Job should run 5 completions with up to 3 pods at a time. Confirm it was created and the pods exit 0."
  return 1
fi
pj_succeeded="$(kc "get job parallel-job -n ${NS} -o jsonpath={.status.succeeded}" 2>/dev/null | tr -d '[:space:]')"
pj_succeeded="${pj_succeeded:-0}"
if [ "${pj_succeeded}" != "5" ]; then
  err "FAILED: [HC3] Job 'parallel-job' has not completed all 5 runs"
  err "Object: job/parallel-job (status.succeeded=${pj_succeeded}, expected 5)"
  err "Hint: With parallelism=3 and completions=5 the Job runs up to three pods concurrently until five succeed. Check the pods' exit codes and events."
  return 1
fi
ok "PASS: [HC3] parallel-job status.succeeded == 5"

ok "PASS: Lab 12 base + hard challenges complete"
return 0
