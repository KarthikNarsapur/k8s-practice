# Lab 03 verification — sourced by lab-verify.sh (has kc/remote_exec/info/ok/err).
# Contract: on failure print FAILED: + object + ONE hint, return non-zero.

# 1. Does the pod web exist and what phase is it in?
phase="$(kc "get pod web -n ${NS} -o jsonpath={.status.phase}" 2>/dev/null | tr -d '[:space:]')"
if [ -z "${phase}" ]; then
  err "FAILED: Pod web not found"
  err "Object: pod/web in namespace ${NS}"
  err "Hint: A Pod with two containers needs a manifest whose spec.containers list has two entries."
  return 1
fi
if [ "${phase}" != "Running" ]; then
  err "FAILED: Pod web is not Running (phase=${phase})"
  err "Object: pod/web in namespace ${NS}"
  err "Hint: Use 'kubectl describe' and inspect each container's State/Reason."
  return 1
fi
ok "PASS: pod web is Running"

# 2. Are the container names exactly server and sidecar?
names="$(kc "get pod web -n ${NS} -o jsonpath={.spec.containers[*].name}" 2>/dev/null | tr ' ' '\n' | sort | tr '\n' ',' )"
if [ "${names}" != "server,sidecar," ]; then
  err "FAILED: Container names are not exactly {server, sidecar}"
  err "Object: pod/web spec.containers[].name (found: ${names})"
  err "Hint: Each entry in the containers list has its own 'name' field — match them exactly."
  return 1
fi
ok "PASS: containers are named server and sidecar"

# 3. Are both containers ready (2/2)?
ready_count="$(kc "get pod web -n ${NS} -o jsonpath={.status.containerStatuses[*].ready}" 2>/dev/null | tr ' ' '\n' | grep -c '^true$' 2>/dev/null | tr -d '[:space:]')"
if [ "${ready_count}" != "2" ]; then
  err "FAILED: Not all containers are ready (ready=${ready_count}/2)"
  err "Object: pod/web status.containerStatuses[].ready"
  err "Hint: A busybox container exits immediately unless its command keeps it alive."
  return 1
fi
ok "PASS: both containers are ready (2/2)"

return 0
