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
return 0
