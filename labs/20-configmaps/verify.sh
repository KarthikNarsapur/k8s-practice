#!/usr/bin/env bash
# Read structured Kubernetes API fields, normalize SSM empty output, and never parse display tables.
fail_check() { err "FAILED: $1"; err "Object: $2"; err "Hint: $3"; return 1; }
fields() {
  local out
  out="$(kc "$1" 2>/dev/null | tr -d '[:space:]' || true)"
  case "${out}" in None|"<no value>") out="";; esac
  printf '%s' "${out}"
}
check_config_a() {
  local actual available
  if ! kc "get configmap config-a -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required configmap 'config-a' is missing" "configmap/config-a" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get configmap config-a -n ${NS} -o jsonpath='{.data.APP_MODE}'")"
  if [ "${actual}" != "production" ]; then
    fail_check "configmap 'config-a' has incorrect configuration" "configmap/config-a" "Check the exact configuration key and expected non-sensitive value."
    return 1
  fi
  ok "PASS: config-a meets the required condition"
}
check_config_b() {
  local actual available
  if ! kc "get configmap config-b -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required configmap 'config-b' is missing" "configmap/config-b" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get configmap config-b -n ${NS} -o jsonpath='{.data.LOG_LEVEL}'")"
  if [ "${actual}" != "info" ]; then
    fail_check "configmap 'config-b' has incorrect configuration" "configmap/config-b" "Check the exact configuration key and expected non-sensitive value."
    return 1
  fi
  ok "PASS: config-b meets the required condition"
}
check_config_c() {
  local actual available
  if ! kc "get configmap config-c -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required configmap 'config-c' is missing" "configmap/config-c" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get configmap config-c -n ${NS} -o jsonpath='{.data.FEATURE_FLAG}'")"
  if [ "${actual}" != "enabled" ]; then
    fail_check "configmap 'config-c' has incorrect configuration" "configmap/config-c" "Check the exact configuration key and expected non-sensitive value."
    return 1
  fi
  ok "PASS: config-c meets the required condition"
}
check_config_d() {
  local actual available
  if ! kc "get configmap config-d -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required configmap 'config-d' is missing" "configmap/config-d" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get configmap config-d -n ${NS} -o jsonpath='{.data.REGION}'")"
  if [ "${actual}" != "eu-west-1" ]; then
    fail_check "configmap 'config-d' has incorrect configuration" "configmap/config-d" "Check the exact configuration key and expected non-sensitive value."
    return 1
  fi
  ok "PASS: config-d meets the required condition"
}
check_hc_config_e() {
  local actual available
  if ! kc "get configmap hc-config-e -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required configmap 'hc-config-e' is missing" "configmap/hc-config-e" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get configmap hc-config-e -n ${NS} -o jsonpath='{.data.APP_MODE}'")"
  if [ "${actual}" != "production" ]; then
    fail_check "configmap 'hc-config-e' has incorrect configuration" "configmap/hc-config-e" "Check the exact configuration key and expected non-sensitive value."
    return 1
  fi
  ok "PASS: hc-config-e meets the required condition"
}
check_hc_config_f() {
  local actual available
  if ! kc "get configmap hc-config-f -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required configmap 'hc-config-f' is missing" "configmap/hc-config-f" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get configmap hc-config-f -n ${NS} -o jsonpath='{.data.LOG_LEVEL}'")"
  if [ "${actual}" != "info" ]; then
    fail_check "configmap 'hc-config-f' has incorrect configuration" "configmap/hc-config-f" "Check the exact configuration key and expected non-sensitive value."
    return 1
  fi
  ok "PASS: hc-config-f meets the required condition"
}
check_hc_config_g() {
  local actual available
  if ! kc "get configmap hc-config-g -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required configmap 'hc-config-g' is missing" "configmap/hc-config-g" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get configmap hc-config-g -n ${NS} -o jsonpath='{.data.FEATURE_FLAG}'")"
  if [ "${actual}" != "enabled" ]; then
    fail_check "configmap 'hc-config-g' has incorrect configuration" "configmap/hc-config-g" "Check the exact configuration key and expected non-sensitive value."
    return 1
  fi
  ok "PASS: hc-config-g meets the required condition"
}
check_hc_config_h() {
  local actual available
  if ! kc "get configmap hc-config-h -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required configmap 'hc-config-h' is missing" "configmap/hc-config-h" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get configmap hc-config-h -n ${NS} -o jsonpath='{.data.REGION}'")"
  if [ "${actual}" != "eu-west-1" ]; then
    fail_check "configmap 'hc-config-h' has incorrect configuration" "configmap/hc-config-h" "Check the exact configuration key and expected non-sensitive value."
    return 1
  fi
  ok "PASS: hc-config-h meets the required condition"
}
check_config_a || return 1
check_config_b || return 1
check_config_c || return 1
check_config_d || return 1
check_hc_config_e || return 1
check_hc_config_f || return 1
check_hc_config_g || return 1
check_hc_config_h || return 1
ok "PASS: Lab 20 four basic and four hard challenges complete"
return 0
