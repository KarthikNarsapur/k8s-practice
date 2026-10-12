#!/usr/bin/env bash
# Use structured API fields, not human-readable kubectl table columns.
fail_check() { err "FAILED: $1"; err "Object: $2"; err "Hint: $3"; return 1; }
value() {
  local out
  out="$(kc "$1" 2>/dev/null | tr -d '[:space:]' || true)"
  case "${out}" in None|"<no value>") out="";; esac
  printf '%s' "${out}"
}

check_one() {
  local name="$1" expected="$2" selector port target endpoint
  if ! kc "get service ${name} -n ${NS}" >/dev/null 2>&1; then
    fail_check "Service '${name}' not found" "service/${name} namespace=${NS}" "Confirm the Service exists in the requested namespace."
    return 1
  fi
  selector="$(value "get service ${name} -n ${NS} -o jsonpath={.spec.selector.app}")"
  port="$(value "get service ${name} -n ${NS} -o jsonpath={.spec.ports[0].port}")"
  target="$(value "get service ${name} -n ${NS} -o jsonpath={.spec.ports[0].targetPort}")"
  endpoint="$(value "get endpoints ${name} -n ${NS} -o jsonpath={.subsets[0].addresses[0].ip}")"
  if [ "${selector}" != "${expected}" ] || [ "${port}" != "80" ] || [ "${target}" != "80" ]; then
    fail_check "Service '${name}' selector or port mapping is incorrect" "service/${name}: selector=${selector:-empty}, port=${port:-empty}, targetPort=${target:-empty}" "Compare the selector to Pod labels and the Service port mapping to the application port."
    return 1
  fi
  if [ -z "${endpoint}" ] || [ "${endpoint}" = "None" ] || [ "${endpoint}" = "<no value>" ]; then
    fail_check "Service '${name}' has no ready endpoint address" "endpoints/${name}" "A Service object can exist without selecting ready Pods; inspect labels, readiness, and EndpointSlices."
    return 1
  fi
  ok "PASS: ${name} selector, port mapping, and ready endpoint are correct"
}

check_dns() {
  local name="$1" output
  output="$(kc "exec dns-client -n ${NS} -- nslookup ${name}" 2>/dev/null || true)"
  if ! printf '%s\n' "${output}" | grep -Eq 'Address [0-9]+:|Address: [0-9]+\.'; then
    fail_check "DNS lookup for '${name}' returned no address" "pod/dns-client and service/${name}" "Inspect the client's resolver configuration and cluster DNS path, then separately check Service endpoints."
    return 1
  fi
}
  check_one "dns-a" "app-a" || return 1
  check_dns "dns-a" || return 1
  check_one "dns-b" "app-b" || return 1
  check_dns "dns-b" || return 1
  check_one "dns-c" "app-c" || return 1
  check_dns "dns-c" || return 1
  check_one "dns-d" "app-d" || return 1
  check_dns "dns-d" || return 1
  check_one "hc-dns-e" "app-e" || return 1
  check_dns "hc-dns-e" || return 1
  check_one "hc-dns-f" "app-f" || return 1
  check_dns "hc-dns-f" || return 1
  check_one "hc-dns-g" "app-g" || return 1
  check_dns "hc-dns-g" || return 1
  check_one "hc-dns-h" "app-h" || return 1
  check_dns "hc-dns-h" || return 1
ok "PASS: Lab 15 base + four hard challenges complete"
return 0
