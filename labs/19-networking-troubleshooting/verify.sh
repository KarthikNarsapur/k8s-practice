#!/usr/bin/env bash
fail_check() { err "FAILED: $1"; err "Object: $2"; err "Hint: $3"; return 1; }
value() {
  local out
  out="$(kc "$1" 2>/dev/null | tr -d '[:space:]' || true)"
  case "${out}" in None|"<no value>") out="";; esac
  printf '%s' "${out}"
}
check_path() {
  local name="$1" label="$2" selector port target endpoint dns
  if ! kc "get service ${name} -n ${NS}" >/dev/null 2>&1; then
    fail_check "Service '${name}' is missing" "service/${name}" "Trace the expected traffic path from the Service to ready Pod endpoints."
    return 1
  fi
  selector="$(value "get service ${name} -n ${NS} -o jsonpath={.spec.selector.app}")"
  port="$(value "get service ${name} -n ${NS} -o jsonpath={.spec.ports[0].port}")"
  target="$(value "get service ${name} -n ${NS} -o jsonpath={.spec.ports[0].targetPort}")"
  endpoint="$(value "get endpoints ${name} -n ${NS} -o jsonpath={.subsets[0].addresses[0].ip}")"
  if [ "${selector}" != "${label}" ] || [ "${port}" != "80" ] || [ "${target}" != "80" ] || [ -z "${endpoint}" ]; then
    fail_check "Service '${name}' has a selector, port, or endpoint fault" "service/${name}: selector=${selector:-empty}, port=${port:-empty}, targetPort=${target:-empty}, endpoint=${endpoint:-empty}" "Check Pod labels, Service selector, targetPort, readiness, and EndpointSlices as separate hops."
    return 1
  fi
  dns="$(kc "exec netprobe -n ${NS} -- nslookup ${name}" 2>/dev/null || true)"
  if ! printf '%s\n' "${dns}" | grep -Eq 'Address [0-9]+:|Address: [0-9]+\.'; then
    fail_check "Service '${name}' does not resolve from netprobe" "pod/netprobe and service/${name}" "Inspect the in-cluster resolver path separately from endpoint health."
    return 1
  fi
  if ! kc "exec netprobe -n ${NS} -- wget -q -T 5 -O /dev/null http://${name}" >/dev/null 2>&1; then
    fail_check "HTTP connectivity to '${name}' failed from netprobe" "pod/netprobe -> service/${name}" "After DNS and endpoints are healthy, inspect port mapping, policy rules, and the application's listening port."
    return 1
  fi
  ok "PASS: ${name} has correct Service wiring, DNS, endpoints, and HTTP connectivity"
}
check_path "incident-a" "app-a" || return 1
check_path "incident-b" "app-b" || return 1
check_path "incident-c" "app-c" || return 1
check_path "incident-d" "app-d" || return 1
check_path "hc-incident-e" "app-e" || return 1
check_path "hc-incident-f" "app-f" || return 1
check_path "hc-incident-g" "app-g" || return 1
check_path "hc-incident-h" "app-h" || return 1
ok "PASS: Lab 19 base + four hard challenges complete"
return 0
