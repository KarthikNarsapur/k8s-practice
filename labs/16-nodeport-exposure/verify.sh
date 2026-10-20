#!/usr/bin/env bash
# Verifiers use structured jsonpath fields, never human-readable kubectl table parsing.
fail_check() { err "FAILED: $1"; err "Object: $2"; err "Hint: $3"; return 1; }
value() {
  local out
  out="$(kc "$1" 2>/dev/null | tr -d '[:space:]' || true)"
  case "${out}" in None|"<no value>") out="";; esac
  printf '%s' "${out}"
}

check_nodeport() {
  local name="$1" label="$2" expected="$3" selector type port target node endpoint
  if ! kc "get service ${name} -n ${NS}" >/dev/null 2>&1; then
    fail_check "Service '${name}' not found" "service/${name}" "Create or repair the requested NodePort Service in the lab namespace."
    return 1
  fi
  selector="$(value "get service ${name} -n ${NS} -o jsonpath={.spec.selector.app}")"
  type="$(value "get service ${name} -n ${NS} -o jsonpath={.spec.type}")"
  port="$(value "get service ${name} -n ${NS} -o jsonpath={.spec.ports[0].port}")"
  target="$(value "get service ${name} -n ${NS} -o jsonpath={.spec.ports[0].targetPort}")"
  node="$(value "get service ${name} -n ${NS} -o jsonpath={.spec.ports[0].nodePort}")"
  endpoint="$(value "get endpoints ${name} -n ${NS} -o jsonpath={.subsets[0].addresses[0].ip}")"
  if [ "${selector}" != "${label}" ] || [ "${type}" != "NodePort" ] || [ "${port}" != "80" ] || [ "${target}" != "80" ] || [ "${node}" != "${expected}" ]; then
    fail_check "Service '${name}' has incorrect selector, type, or port fields" "service/${name}: selector=${selector:-empty}, type=${type:-empty}, port=${port:-empty}, targetPort=${target:-empty}, nodePort=${node:-empty}" "Check the distinct roles of Service port, targetPort, and nodePort, along with the selected Pod labels."
    return 1
  fi
  if [ -z "${endpoint}" ] || [ "${endpoint}" = "None" ] || [ "${endpoint}" = "<no value>" ]; then
    fail_check "Service '${name}' has no ready endpoint" "endpoints/${name}" "A valid NodePort still needs a selector that matches ready Pods."
    return 1
  fi
  ok "PASS: ${name} has correct NodePort configuration and a ready endpoint"
}
check_nodeport "node-a" "app-a" "30081" || return 1
check_nodeport "node-b" "app-b" "30082" || return 1
check_nodeport "node-c" "app-c" "30083" || return 1
check_nodeport "node-d" "app-d" "30084" || return 1
check_nodeport "hc-node-e" "app-e" "30085" || return 1
check_nodeport "hc-node-f" "app-f" "30086" || return 1
check_nodeport "hc-node-g" "app-g" "30087" || return 1
check_nodeport "hc-node-h" "app-h" "30088" || return 1
ok "PASS: Lab 16 base + four hard challenges complete"
return 0
