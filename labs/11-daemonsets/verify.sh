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
schedulable="$(kc "get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints[*].effect' --no-headers" \
  | awk '{
      taints="";
      for (i=2; i<=NF; i++) taints=taints $i " ";
      if (taints !~ /NoSchedule/ && taints !~ /NoExecute/) c++
    }
    END { print c+0 }')"

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

###############################################################################
# Hard Challenge checks
###############################################################################

# HC1 — ssd-agent: runs only on nodes labeled disk=ssd.
if ! kc "get daemonset ssd-agent -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC1] DaemonSet 'ssd-agent' not found"
  err "Object: daemonset/ssd-agent in namespace ${NS}"
  err "Hint: A DaemonSet with a nodeSelector only lands on nodes carrying that label. Confirm the setup created it, or re-run lab-start."
  return 1
fi
ssd_desired="$(kc "get daemonset ssd-agent -n ${NS} -o jsonpath={.status.desiredNumberScheduled}" 2>/dev/null | tr -d '[:space:]')"
ssd_ready="$(kc "get daemonset ssd-agent -n ${NS} -o jsonpath={.status.numberReady}" 2>/dev/null | tr -d '[:space:]')"
ssd_desired="${ssd_desired:-0}"
ssd_ready="${ssd_ready:-0}"
if [ "${ssd_ready}" != "${ssd_desired}" ]; then
  err "FAILED: [HC1] DaemonSet 'ssd-agent' pods are not all ready"
  err "Object: daemonset/ssd-agent (desiredNumberScheduled=${ssd_desired}, numberReady=${ssd_ready})"
  err "Hint: Every scheduled daemon pod must reach Ready. Inspect the pods and node labels the selector targets."
  return 1
fi
ssd_labeled="$(kc "get nodes -l disk=ssd --no-headers" 2>/dev/null | grep -c . || true)"
ssd_labeled="${ssd_labeled:-0}"
if [ "${ssd_desired}" != "${ssd_labeled}" ]; then
  err "FAILED: [HC1] 'ssd-agent' is not scheduled on exactly the disk=ssd nodes"
  err "Object: daemonset/ssd-agent (desiredNumberScheduled=${ssd_desired}, nodes labeled disk=ssd=${ssd_labeled})"
  err "Hint: A nodeSelector restricts a DaemonSet to the matching nodes only — compare its desired count to how many nodes carry that label."
  return 1
fi
ok "PASS: [HC1] ssd-agent runs on exactly the ${ssd_labeled} node(s) labeled disk=ssd"

# HC2 — taint-agent: tolerates the control-plane taint, so it runs on ALL nodes.
if ! kc "get daemonset taint-agent -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC2] DaemonSet 'taint-agent' not found"
  err "Object: daemonset/taint-agent in namespace ${NS}"
  err "Hint: A DaemonSet that tolerates a node's taint can be placed there. Confirm the setup created it, or re-run lab-start."
  return 1
fi
taint_desired="$(kc "get daemonset taint-agent -n ${NS} -o jsonpath={.status.desiredNumberScheduled}" 2>/dev/null | tr -d '[:space:]')"
taint_ready="$(kc "get daemonset taint-agent -n ${NS} -o jsonpath={.status.numberReady}" 2>/dev/null | tr -d '[:space:]')"
taint_desired="${taint_desired:-0}"
taint_ready="${taint_ready:-0}"
if [ "${taint_ready}" != "${taint_desired}" ] || [ "${taint_desired}" = "0" ]; then
  err "FAILED: [HC2] DaemonSet 'taint-agent' pods are not all ready"
  err "Object: daemonset/taint-agent (desiredNumberScheduled=${taint_desired}, numberReady=${taint_ready})"
  err "Hint: Every scheduled daemon pod must reach Ready. Inspect the pods and events."
  return 1
fi
total_nodes="$(kc "get nodes --no-headers" 2>/dev/null | grep -c . || true)"
total_nodes="${total_nodes:-0}"
if [ "${taint_desired}" != "${total_nodes}" ]; then
  err "FAILED: [HC2] 'taint-agent' is not running on every node"
  err "Object: daemonset/taint-agent (desiredNumberScheduled=${taint_desired}, total nodes=${total_nodes})"
  err "Hint: A tolerationless DaemonSet skips tainted nodes; one that tolerates the control-plane taint should cover every node. Check its tolerations."
  return 1
fi
ok "PASS: [HC2] taint-agent tolerates the control-plane taint and runs on all ${total_nodes} node(s)"

# HC3 — zone-agent: after one worker lost zone=east, desired should match ready.
if ! kc "get daemonset zone-agent -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC3] DaemonSet 'zone-agent' not found"
  err "Object: daemonset/zone-agent in namespace ${NS}"
  err "Hint: A DaemonSet tracks the set of nodes matching its selector as labels change. Confirm the setup created it, or re-run lab-start."
  return 1
fi
zone_desired="$(kc "get daemonset zone-agent -n ${NS} -o jsonpath={.status.desiredNumberScheduled}" 2>/dev/null | tr -d '[:space:]')"
zone_ready="$(kc "get daemonset zone-agent -n ${NS} -o jsonpath={.status.numberReady}" 2>/dev/null | tr -d '[:space:]')"
zone_desired="${zone_desired:-0}"
zone_ready="${zone_ready:-0}"
if [ "${zone_ready}" != "${zone_desired}" ]; then
  err "FAILED: [HC3] DaemonSet 'zone-agent' pods are not all ready"
  err "Object: daemonset/zone-agent (desiredNumberScheduled=${zone_desired}, numberReady=${zone_ready})"
  err "Hint: When a node loses the selector label, its daemon pod is removed and 'desired' drops. desired and ready should still match on the remaining nodes."
  return 1
fi
ok "PASS: [HC3] zone-agent desiredNumberScheduled == numberReady (${zone_ready}) after the label change"

ok "PASS: Lab 11 base + hard challenges complete"
return 0
