# Lab 01 verification — sourced by lab-verify.sh (has kc/remote_exec/info/err).
# Contract: on failure print FAILED: + object + ONE hint, return non-zero.

# 1. All nodes Ready?
not_ready="$(kc "get nodes --no-headers" | awk '$2 != "Ready" {print $1}')"
if [ -n "${not_ready}" ]; then
  err "FAILED: Node readiness"
  err "Object: node(s) -> ${not_ready}"
  err "Hint: A node is only Ready once its CNI pod is running. Check the calico-system namespace."
  return 1
fi
ok "PASS: all nodes are Ready"

# 2. Control-plane node carries the investigation label?
labeled="$(kc "get nodes -l node-role.kubernetes.io/control-plane -o jsonpath={.items[0].metadata.labels.lab01/investigated}" 2>/dev/null | tr -d '[:space:]')"
if [ "${labeled}" != "true" ]; then
  err "FAILED: Investigation proof missing"
  err "Object: node label lab01/investigated on the control-plane node"
  err "Hint: After you have inspected the static pods and crictl containers, label the control-plane node to record it."
  return 1
fi
ok "PASS: control-plane node labelled lab01/investigated=true"

return 0
