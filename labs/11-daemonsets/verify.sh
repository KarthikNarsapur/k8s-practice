# Lab 11 verification — sourced by lab-verify.sh (has kc/remote_exec/info/ok/err).
# Contract: on success 'ok "PASS: ..."' + return 0.
#           on failure err FAILED/Object/Hint (ONE hint, no solution) + return 1.
# Use return, not exit.

# 0. DaemonSet exists?
if ! kc "get daemonset node-agent -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: DaemonSet 'node-agent' not found"
  err "Object: daemonset/node-agent in namespace ${NS}"
  err "Hint: A DaemonSet ensures one pod copy per matching node. There is no create generator for it — apply a manifest."
  return 1
fi

# 1. Compute the number of SCHEDULABLE nodes the same way a tolerationless
#    DaemonSet pod is placed: a node is "schedulable" for such a pod when it has
#    no NoSchedule / NoExecute taint. Count nodes whose taints array is empty or
#    absent. (The control-plane node normally carries a NoSchedule taint.)
schedulable="$(kc "get nodes -o jsonpath={range .items[*]}{.metadata.name}{\"|\"}{.spec.taints[*].effect}{\"\\n\"}{end}" \
  | awk -F'|' 'NF{ if ($2 !~ /NoSchedule/ && $2 !~ /NoExecute/) c++ } END{ print c+0 }')"

if [ "${schedulable}" = "0" ]; then
  err "FAILED: Could not determine the schedulable node count"
  err "Object: cluster nodes"
  err "Hint: Check 'kubectl get nodes' — the verifier counts nodes without a NoSchedule/NoExecute taint."
  return 1
fi
ok "PASS: cluster has ${schedulable} schedulable node(s) for a tolerationless DaemonSet"

# 2. desiredNumberScheduled == numberReady (all daemon pods are up)?
desired="$(kc "get daemonset node-agent -n ${NS} -o jsonpath={.status.desiredNumberScheduled}" | tr -d '[:space:]')"
ready="$(kc "get daemonset node-agent -n ${NS} -o jsonpath={.status.numberReady}" | tr -d '[:space:]')"
desired="${desired:-0}"
ready="${ready:-0}"
if [ "${ready}" != "${desired}" ] || [ "${desired}" = "0" ]; then
  err "FAILED: DaemonSet 'node-agent' pods are not all ready"
  err "Object: daemonset/node-agent (desiredNumberScheduled=${desired}, numberReady=${ready})"
  err "Hint: Inspect the DaemonSet's pods and events; every scheduled daemon pod must reach Ready."
  return 1
fi
ok "PASS: daemonset/node-agent desiredNumberScheduled == numberReady (${ready})"

# 3. desiredNumberScheduled equals the number of schedulable nodes?
if [ "${desired}" != "${schedulable}" ]; then
  err "FAILED: DaemonSet is not covering every schedulable node"
  err "Object: daemonset/node-agent (desiredNumberScheduled=${desired}, schedulable nodes=${schedulable})"
  err "Hint: A tolerationless DaemonSet skips tainted nodes. Compare where its pods landed with 'kubectl get nodes' and consider node selectors/tolerations."
  return 1
fi
ok "PASS: daemonset/node-agent runs on all ${schedulable} schedulable node(s)"

ok "PASS: DaemonSet 'node-agent' is one-pod-per-node and fully ready"
return 0
