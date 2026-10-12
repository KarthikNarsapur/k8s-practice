#!/usr/bin/env bash
# Read structured Kubernetes API fields, normalize SSM empty output, and never parse display tables.
fail_check() { err "FAILED: $1"; err "Object: $2"; err "Hint: $3"; return 1; }
fields() {
  local out
  out="$(kc "$1" 2>/dev/null | tr -d '[:space:]' || true)"
  case "${out}" in None|"<no value>") out="";; esac
  printf '%s' "${out}"
}
check_secret_a() {
  local actual available
  if ! kc "get secret secret-a -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required secret 'secret-a' is missing" "secret/secret-a" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get secret secret-a -n ${NS} -o jsonpath='{.type}|{.data.username}'")"
  if [ "${actual}" != "Opaque|ZGVtby11c2Vy" ]; then
    fail_check "secret 'secret-a' has incorrect configuration" "secret/secret-a" "Check the Secret type and required key/value without printing credential values into logs."
    return 1
  fi
  ok "PASS: secret-a meets the required condition"
}
check_secret_b() {
  local actual available
  if ! kc "get secret secret-b -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required secret 'secret-b' is missing" "secret/secret-b" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get secret secret-b -n ${NS} -o jsonpath='{.type}|{.data.password}'")"
  if [ "${actual}" != "Opaque|cm90YXRlLW1lLTEyMw==" ]; then
    fail_check "secret 'secret-b' has incorrect configuration" "secret/secret-b" "Check the Secret type and required key/value without printing credential values into logs."
    return 1
  fi
  ok "PASS: secret-b meets the required condition"
}
check_secret_c() {
  local actual available
  if ! kc "get secret secret-c -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required secret 'secret-c' is missing" "secret/secret-c" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get secret secret-c -n ${NS} -o jsonpath='{.type}|{.data.api-token}'")"
  if [ "${actual}" != "Opaque|ZmFrZS10b2tlbi03ODk=" ]; then
    fail_check "secret 'secret-c' has incorrect configuration" "secret/secret-c" "Check the Secret type and required key/value without printing credential values into logs."
    return 1
  fi
  ok "PASS: secret-c meets the required condition"
}
check_secret_d() {
  local actual available
  if ! kc "get secret secret-d -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required secret 'secret-d' is missing" "secret/secret-d" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get secret secret-d -n ${NS} -o jsonpath='{.type}|{.data.database}'")"
  if [ "${actual}" != "Opaque|b3JkZXJz" ]; then
    fail_check "secret 'secret-d' has incorrect configuration" "secret/secret-d" "Check the Secret type and required key/value without printing credential values into logs."
    return 1
  fi
  ok "PASS: secret-d meets the required condition"
}
check_hc_secret_e() {
  local actual available
  if ! kc "get secret hc-secret-e -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required secret 'hc-secret-e' is missing" "secret/hc-secret-e" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get secret hc-secret-e -n ${NS} -o jsonpath='{.type}|{.data.username}'")"
  if [ "${actual}" != "Opaque|ZGVtby11c2Vy" ]; then
    fail_check "secret 'hc-secret-e' has incorrect configuration" "secret/hc-secret-e" "Check the Secret type and required key/value without printing credential values into logs."
    return 1
  fi
  ok "PASS: hc-secret-e meets the required condition"
}
check_hc_secret_f() {
  local actual available
  if ! kc "get secret hc-secret-f -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required secret 'hc-secret-f' is missing" "secret/hc-secret-f" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get secret hc-secret-f -n ${NS} -o jsonpath='{.type}|{.data.password}'")"
  if [ "${actual}" != "Opaque|cm90YXRlLW1lLTEyMw==" ]; then
    fail_check "secret 'hc-secret-f' has incorrect configuration" "secret/hc-secret-f" "Check the Secret type and required key/value without printing credential values into logs."
    return 1
  fi
  ok "PASS: hc-secret-f meets the required condition"
}
check_hc_secret_g() {
  local actual available
  if ! kc "get secret hc-secret-g -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required secret 'hc-secret-g' is missing" "secret/hc-secret-g" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get secret hc-secret-g -n ${NS} -o jsonpath='{.type}|{.data.api-token}'")"
  if [ "${actual}" != "Opaque|ZmFrZS10b2tlbi03ODk=" ]; then
    fail_check "secret 'hc-secret-g' has incorrect configuration" "secret/hc-secret-g" "Check the Secret type and required key/value without printing credential values into logs."
    return 1
  fi
  ok "PASS: hc-secret-g meets the required condition"
}
check_hc_secret_h() {
  local actual available
  if ! kc "get secret hc-secret-h -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required secret 'hc-secret-h' is missing" "secret/hc-secret-h" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get secret hc-secret-h -n ${NS} -o jsonpath='{.type}|{.data.database}'")"
  if [ "${actual}" != "Opaque|b3JkZXJz" ]; then
    fail_check "secret 'hc-secret-h' has incorrect configuration" "secret/hc-secret-h" "Check the Secret type and required key/value without printing credential values into logs."
    return 1
  fi
  ok "PASS: hc-secret-h meets the required condition"
}
check_secret_a || return 1
check_secret_b || return 1
check_secret_c || return 1
check_secret_d || return 1
check_hc_secret_e || return 1
check_hc_secret_f || return 1
check_hc_secret_g || return 1
check_hc_secret_h || return 1
ok "PASS: Lab 21 four basic and four hard challenges complete"
return 0
