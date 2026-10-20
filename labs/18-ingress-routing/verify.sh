#!/usr/bin/env bash
fail_check() { err "FAILED: $1"; err "Object: $2"; err "Hint: $3"; return 1; }
value() {
  local out
  out="$(kc "$1" 2>/dev/null | tr -d '[:space:]' || true)"
  case "${out}" in None|"<no value>") out="";; esac
  printf '%s' "${out}"
}

check_ingress() {
  local name="$1" host="$2" backend="$3" fields class actualhost path pathtype actualbackend port endpoint response
  if ! kc "get ingress ${name} -n ${NS}" >/dev/null 2>&1; then
    fail_check "Ingress '${name}' not found" "ingress/${name}" "Create or repair the named Ingress in the lab namespace."
    return 1
  fi
  fields="$(kc "get ingress ${name} -n ${NS} -o jsonpath='{.spec.ingressClassName}|{.spec.rules[0].host}|{.spec.rules[0].http.paths[0].path}|{.spec.rules[0].http.paths[0].pathType}|{.spec.rules[0].http.paths[0].backend.service.name}|{.spec.rules[0].http.paths[0].backend.service.port.number}'" 2>/dev/null || true)"
  IFS='|' read -r class actualhost path pathtype actualbackend port <<< "${fields}"
  if [ "${class}" != "lab18" ] || [ "${actualhost}" != "${host}" ] || [ "${path}" != "/" ] || [ "${pathtype}" != "Prefix" ] || [ "${actualbackend}" != "${backend}" ] || [ "${port}" != "80" ]; then
    fail_check "Ingress '${name}' host/path/class/backend configuration is incorrect" "ingress/${name}: class=${class:-empty}, host=${actualhost:-empty}, path=${path:-empty}, backend=${actualbackend:-empty}:${port:-empty}" "Trace the requested HTTP host and path to the intended Service backend and check the IngressClass."
    return 1
  fi
  endpoint="$(value "get endpoints ${backend} -n ${NS} -o jsonpath={.subsets[0].addresses[0].ip}")"
  if [ -z "${endpoint}" ]; then
    fail_check "Ingress backend '${backend}' has no ready endpoint" "service/${backend}" "Ingress forwards to a Service; ensure that Service selects ready backend Pods."
    return 1
  fi
  response="$(kc "exec ingress-client -n ${NS} -- wget -q -T 5 -O - --header='Host: ${host}' http://ingress-controller/" 2>/dev/null || true)"
  if ! printf '%s\n' "${response}" | grep -q "Welcome to nginx"; then
    fail_check "HTTP request for '${host}' did not reach the expected web backend" "ingress/${name} via service/ingress-controller" "Check controller readiness, Ingress events/logs, host routing, and the backend Service path."
    return 1
  fi
  ok "PASS: ${name} routes ${host} to ${backend} and HTTP succeeds"
}
ready="$(value "get deployment ingress-controller -n ${NS} -o jsonpath={.status.availableReplicas}")"
if [ "${ready}" != "1" ]; then
  fail_check "Ingress controller is not available" "deployment/ingress-controller namespace=${NS}" "Inspect controller Pod status, events, image pulls, RBAC, and readiness."
  return 1
fi
check_ingress "ing-a" "app-a.lab.test" "ing-a" || return 1
check_ingress "ing-b" "app-b.lab.test" "ing-b" || return 1
check_ingress "ing-c" "app-c.lab.test" "ing-c" || return 1
check_ingress "ing-d" "app-d.lab.test" "ing-d" || return 1
check_ingress "hc-ing-e" "app-e.lab.test" "ing-e" || return 1
check_ingress "hc-ing-f" "app-f.lab.test" "ing-f" || return 1
check_ingress "hc-ing-g" "app-g.lab.test" "ing-g" || return 1
check_ingress "hc-ing-h" "app-h.lab.test" "ing-h" || return 1
ok "PASS: Lab 18 base + four hard challenges complete"
return 0
