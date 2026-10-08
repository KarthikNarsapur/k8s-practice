# Lab 11 verification — sourced by lab-verify.sh
# Contract: on success 'ok "PASS: ..."' + return 0.
#           on failure err FAILED/Object/Hint (ONE hint, no solution) + return 1.
# Use return, not exit.

###############################################################################
# 0. DaemonSet exists
###############################################################################

if ! kc "get daemonset node-agent -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: DaemonSet 'node-agent' not found"
  err "Object: daemonset/node-agent in namespace ${NS}"
  err "Hint: A DaemonSet ensures one pod copy per matching node. Apply a DaemonSet manifest."
  return 1
fi


###############################################################################
# 1. Determine nodes eligible for a tolerationless DaemonSet
#
# A node is considered eligible when:
#   - it is Ready
#   - it is not cordoned/unschedulable
#   - it has no NoSchedule / NoExecute taint
#
# This intentionally matches the behavior expected by this lab rather than
# blindly counting every object returned by `kubectl get nodes`.
###############################################################################

schedulable="$(
  kc "get nodes -o json" |
  python3 -c '
import json
import sys

data = json.load(sys.stdin)
count = 0

for node in data.get("items", []):
    spec = node.get("spec", {})
    status = node.get("status", {})

    # Ignore cordoned / unschedulable nodes.
    if spec.get("unschedulable", False):
        continue

    # Require Ready=True.
    ready = False
    for condition in status.get("conditions", []):
        if condition.get("type") == "Ready":
            ready = condition.get("status") == "True"
            break

    if not ready:
        continue

    # A tolerationless pod cannot land on NoSchedule / NoExecute taints.
    taints = spec.get("taints", [])

    blocked = any(
        taint.get("effect") in ("NoSchedule", "NoExecute")
        for taint in taints
    )

    if not blocked:
        count += 1

print(count)
'
)"

schedulable="${schedulable:-0}"

if [ "${schedulable}" = "0" ]; then
  err "FAILED: Could not determine the schedulable node count"
  err "Object: cluster nodes"
  err "Hint: Check 'kubectl get nodes' and inspect Ready state, unschedulable state, and NoSchedule/NoExecute taints."
  return 1
fi

ok "PASS: cluster has ${schedulable} schedulable node(s) for a tolerationless DaemonSet"


###############################################################################
# 2. node-agent — desired == ready
###############################################################################

desired="$(
  kc "get daemonset node-agent -n ${NS} \
    -o jsonpath={.status.desiredNumberScheduled}" |
  tr -d '[:space:]'
)"

ready="$(
  kc "get daemonset node-agent -n ${NS} \
    -o jsonpath={.status.numberReady}" |
  tr -d '[:space:]'
)"

desired="${desired:-0}"
ready="${ready:-0}"

if [ "${ready}" != "${desired}" ] || [ "${desired}" = "0" ]; then
  err "FAILED: DaemonSet 'node-agent' pods are not all ready"
  err "Object: daemonset/node-agent (desiredNumberScheduled=${desired}, numberReady=${ready})"
  err "Hint: Inspect the DaemonSet's pods and events; every scheduled daemon pod must reach Ready."
  return 1
fi

ok "PASS: daemonset/node-agent desiredNumberScheduled == numberReady (${ready})"


###############################################################################
# 3. node-agent covers every eligible node
###############################################################################

if [ "${desired}" != "${schedulable}" ]; then
  err "FAILED: DaemonSet is not covering every schedulable node"
  err "Object: daemonset/node-agent (desiredNumberScheduled=${desired}, schedulable nodes=${schedulable})"
  err "Hint: Compare the nodes covered by the DaemonSet with node taints and scheduling state."
  return 1
fi

ok "PASS: daemonset/node-agent runs on all ${schedulable} schedulable node(s)"
ok "PASS: DaemonSet 'node-agent' is one-pod-per-node and fully ready"


###############################################################################
# Hard Challenge checks
###############################################################################


###############################################################################
# HC1 — ssd-agent
#
# The DaemonSet should run exactly on nodes carrying disk=ssd.
###############################################################################

if ! kc "get daemonset ssd-agent -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC1] DaemonSet 'ssd-agent' not found"
  err "Object: daemonset/ssd-agent in namespace ${NS}"
  err "Hint: Confirm the lab setup created ssd-agent in the lab-11 namespace."
  return 1
fi

ssd_desired="$(
  kc "get daemonset ssd-agent -n ${NS} \
    -o jsonpath={.status.desiredNumberScheduled}" 2>/dev/null |
  tr -d '[:space:]'
)"

ssd_ready="$(
  kc "get daemonset ssd-agent -n ${NS} \
    -o jsonpath={.status.numberReady}" 2>/dev/null |
  tr -d '[:space:]'
)"

ssd_desired="${ssd_desired:-0}"
ssd_ready="${ssd_ready:-0}"


# Zero is valid here.
# If there are zero disk=ssd nodes, desired=0 and ready=0 is correct.
if [ "${ssd_ready}" != "${ssd_desired}" ]; then
  err "FAILED: [HC1] DaemonSet 'ssd-agent' pods are not all ready"
  err "Object: daemonset/ssd-agent (desiredNumberScheduled=${ssd_desired}, numberReady=${ssd_ready})"
  err "Hint: Every scheduled daemon pod must reach Ready. Inspect the pods and node labels."
  return 1
fi


ssd_labeled="$(
  kc "get nodes -l disk=ssd --no-headers" 2>/dev/null |
  grep -c . || true
)"

ssd_labeled="${ssd_labeled:-0}"

if [ "${ssd_desired}" != "${ssd_labeled}" ]; then
  err "FAILED: [HC1] 'ssd-agent' is not scheduled on exactly the disk=ssd nodes"
  err "Object: daemonset/ssd-agent (desiredNumberScheduled=${ssd_desired}, nodes labeled disk=ssd=${ssd_labeled})"
  err "Hint: Compare the DaemonSet nodeSelector with the node labels."
  return 1
fi

ok "PASS: [HC1] ssd-agent runs on exactly the ${ssd_labeled} node(s) labeled disk=ssd"


###############################################################################
# HC2 — taint-agent
#
# This DaemonSet contains tolerations for the control-plane taint and therefore
# should run on every node in this lab.
###############################################################################

if ! kc "get daemonset taint-agent -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC2] DaemonSet 'taint-agent' not found"
  err "Object: daemonset/taint-agent in namespace ${NS}"
  err "Hint: Confirm the lab setup created taint-agent in the lab-11 namespace."
  return 1
fi

taint_desired="$(
  kc "get daemonset taint-agent -n ${NS} \
    -o jsonpath={.status.desiredNumberScheduled}" 2>/dev/null |
  tr -d '[:space:]'
)"

taint_ready="$(
  kc "get daemonset taint-agent -n ${NS} \
    -o jsonpath={.status.numberReady}" 2>/dev/null |
  tr -d '[:space:]'
)"

taint_desired="${taint_desired:-0}"
taint_ready="${taint_ready:-0}"


if [ "${taint_ready}" != "${taint_desired}" ] || [ "${taint_desired}" = "0" ]; then
  err "FAILED: [HC2] DaemonSet 'taint-agent' pods are not all ready"
  err "Object: daemonset/taint-agent (desiredNumberScheduled=${taint_desired}, numberReady=${taint_ready})"
  err "Hint: Inspect taint-agent pods and verify that its tolerations allow the intended nodes."
  return 1
fi


total_nodes="$(
  kc "get nodes --no-headers" 2>/dev/null |
  grep -c . || true
)"

total_nodes="${total_nodes:-0}"

if [ "${taint_desired}" != "${total_nodes}" ]; then
  err "FAILED: [HC2] 'taint-agent' is not running on every node"
  err "Object: daemonset/taint-agent (desiredNumberScheduled=${taint_desired}, total nodes=${total_nodes})"
  err "Hint: Check taint-agent tolerations and compare its desired count with the total node count."
  return 1
fi

ok "PASS: [HC2] taint-agent runs on all ${total_nodes} node(s)"


###############################################################################
# HC3 — zone-agent
#
# After the lab removes zone=east from one worker, zone-agent should reconcile
# its Pod set to the remaining matching nodes.
###############################################################################

if ! kc "get daemonset zone-agent -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC3] DaemonSet 'zone-agent' not found"
  err "Object: daemonset/zone-agent in namespace ${NS}"
  err "Hint: Confirm the lab setup created zone-agent in the lab-11 namespace."
  return 1
fi

zone_desired="$(
  kc "get daemonset zone-agent -n ${NS} \
    -o jsonpath={.status.desiredNumberScheduled}" 2>/dev/null |
  tr -d '[:space:]'
)"

zone_ready="$(
  kc "get daemonset zone-agent -n ${NS} \
    -o jsonpath={.status.numberReady}" 2>/dev/null |
  tr -d '[:space:]'
)"

zone_desired="${zone_desired:-0}"
zone_ready="${zone_ready:-0}"


# Zero is technically valid for a selector with zero matching nodes.
if [ "${zone_ready}" != "${zone_desired}" ]; then
  err "FAILED: [HC3] DaemonSet 'zone-agent' pods are not all ready"
  err "Object: daemonset/zone-agent (desiredNumberScheduled=${zone_desired}, numberReady=${zone_ready})"
  err "Hint: Inspect zone-agent and verify that its desired and ready counts match the remaining matching nodes."
  return 1
fi


ok "PASS: [HC3] zone-agent desiredNumberScheduled == numberReady (${zone_ready}) after the label change"


###############################################################################
# Final
###############################################################################

ok "PASS: Lab 11 base + hard challenges complete"

return 0
