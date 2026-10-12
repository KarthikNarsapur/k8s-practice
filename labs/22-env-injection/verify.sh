#!/usr/bin/env bash
# Read structured Kubernetes API fields, normalize SSM empty output, and never parse display tables.
fail_check() { err "FAILED: $1"; err "Object: $2"; err "Hint: $3"; return 1; }
fields() {
  local out
  out="$(kc "$1" 2>/dev/null | tr -d '[:space:]' || true)"
  case "${out}" in None|"<no value>") out="";; esac
  printf '%s' "${out}"
}
check_app_a() {
  local actual available
  if ! kc "get deployment app-a -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required deployment 'app-a' is missing" "deployment/app-a" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get deployment app-a -n ${NS} -o jsonpath='{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.key}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.key}}'")"
  if [ "${actual}" != "settings-a|APP_MODE|settings-a-logs|LOG_LEVEL" ]; then
    fail_check "deployment 'app-a' has incorrect configuration" "deployment/app-a" "Trace both environment variables to their ConfigMap names and keys, then confirm the rollout becomes available."
    return 1
  fi
  available="$(fields "get deployment app-a -n ${NS} -o jsonpath={.status.availableReplicas}")"
  if [ "${available}" != "1" ]; then
    fail_check "Deployment 'app-a' is not available" "deployment/app-a" "Inspect Pod events and readiness separately from the configuration field."
    return 1
  fi
  ok "PASS: app-a meets the required condition"
}
check_app_b() {
  local actual available
  if ! kc "get deployment app-b -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required deployment 'app-b' is missing" "deployment/app-b" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get deployment app-b -n ${NS} -o jsonpath='{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.key}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.key}}'")"
  if [ "${actual}" != "settings-b|APP_MODE|settings-b-logs|LOG_LEVEL" ]; then
    fail_check "deployment 'app-b' has incorrect configuration" "deployment/app-b" "Trace both environment variables to their ConfigMap names and keys, then confirm the rollout becomes available."
    return 1
  fi
  available="$(fields "get deployment app-b -n ${NS} -o jsonpath={.status.availableReplicas}")"
  if [ "${available}" != "1" ]; then
    fail_check "Deployment 'app-b' is not available" "deployment/app-b" "Inspect Pod events and readiness separately from the configuration field."
    return 1
  fi
  ok "PASS: app-b meets the required condition"
}
check_app_c() {
  local actual available
  if ! kc "get deployment app-c -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required deployment 'app-c' is missing" "deployment/app-c" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get deployment app-c -n ${NS} -o jsonpath='{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.key}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.key}}'")"
  if [ "${actual}" != "settings-c|APP_MODE|settings-c-logs|LOG_LEVEL" ]; then
    fail_check "deployment 'app-c' has incorrect configuration" "deployment/app-c" "Trace both environment variables to their ConfigMap names and keys, then confirm the rollout becomes available."
    return 1
  fi
  available="$(fields "get deployment app-c -n ${NS} -o jsonpath={.status.availableReplicas}")"
  if [ "${available}" != "1" ]; then
    fail_check "Deployment 'app-c' is not available" "deployment/app-c" "Inspect Pod events and readiness separately from the configuration field."
    return 1
  fi
  ok "PASS: app-c meets the required condition"
}
check_app_d() {
  local actual available
  if ! kc "get deployment app-d -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required deployment 'app-d' is missing" "deployment/app-d" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get deployment app-d -n ${NS} -o jsonpath='{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.key}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.key}}'")"
  if [ "${actual}" != "settings-d|APP_MODE|settings-d-logs|LOG_LEVEL" ]; then
    fail_check "deployment 'app-d' has incorrect configuration" "deployment/app-d" "Trace both environment variables to their ConfigMap names and keys, then confirm the rollout becomes available."
    return 1
  fi
  available="$(fields "get deployment app-d -n ${NS} -o jsonpath={.status.availableReplicas}")"
  if [ "${available}" != "1" ]; then
    fail_check "Deployment 'app-d' is not available" "deployment/app-d" "Inspect Pod events and readiness separately from the configuration field."
    return 1
  fi
  ok "PASS: app-d meets the required condition"
}
check_app_e() {
  local actual available
  if ! kc "get deployment app-e -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required deployment 'app-e' is missing" "deployment/app-e" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get deployment app-e -n ${NS} -o jsonpath='{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.key}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.key}}'")"
  if [ "${actual}" != "settings-e|APP_MODE|settings-e-logs|LOG_LEVEL" ]; then
    fail_check "deployment 'app-e' has incorrect configuration" "deployment/app-e" "Trace both environment variables to their ConfigMap names and keys, then confirm the rollout becomes available."
    return 1
  fi
  available="$(fields "get deployment app-e -n ${NS} -o jsonpath={.status.availableReplicas}")"
  if [ "${available}" != "1" ]; then
    fail_check "Deployment 'app-e' is not available" "deployment/app-e" "Inspect Pod events and readiness separately from the configuration field."
    return 1
  fi
  ok "PASS: app-e meets the required condition"
}
check_app_f() {
  local actual available
  if ! kc "get deployment app-f -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required deployment 'app-f' is missing" "deployment/app-f" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get deployment app-f -n ${NS} -o jsonpath='{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.key}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.key}}'")"
  if [ "${actual}" != "settings-f|APP_MODE|settings-f-logs|LOG_LEVEL" ]; then
    fail_check "deployment 'app-f' has incorrect configuration" "deployment/app-f" "Trace both environment variables to their ConfigMap names and keys, then confirm the rollout becomes available."
    return 1
  fi
  available="$(fields "get deployment app-f -n ${NS} -o jsonpath={.status.availableReplicas}")"
  if [ "${available}" != "1" ]; then
    fail_check "Deployment 'app-f' is not available" "deployment/app-f" "Inspect Pod events and readiness separately from the configuration field."
    return 1
  fi
  ok "PASS: app-f meets the required condition"
}
check_app_g() {
  local actual available
  if ! kc "get deployment app-g -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required deployment 'app-g' is missing" "deployment/app-g" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get deployment app-g -n ${NS} -o jsonpath='{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.key}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.key}}'")"
  if [ "${actual}" != "settings-g|APP_MODE|settings-g-logs|LOG_LEVEL" ]; then
    fail_check "deployment 'app-g' has incorrect configuration" "deployment/app-g" "Trace both environment variables to their ConfigMap names and keys, then confirm the rollout becomes available."
    return 1
  fi
  available="$(fields "get deployment app-g -n ${NS} -o jsonpath={.status.availableReplicas}")"
  if [ "${available}" != "1" ]; then
    fail_check "Deployment 'app-g' is not available" "deployment/app-g" "Inspect Pod events and readiness separately from the configuration field."
    return 1
  fi
  ok "PASS: app-g meets the required condition"
}
check_app_h() {
  local actual available
  if ! kc "get deployment app-h -n ${NS}" >/dev/null 2>&1; then
    fail_check "Required deployment 'app-h' is missing" "deployment/app-h" "Create or repair the named object in the lab namespace."
    return 1
  fi
  actual="$(fields "get deployment app-h -n ${NS} -o jsonpath='{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.key}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.name}|{.spec.template.spec.containers[0].env[1].valueFrom.configMapKeyRef.key}}'")"
  if [ "${actual}" != "settings-h|APP_MODE|settings-h-logs|LOG_LEVEL" ]; then
    fail_check "deployment 'app-h' has incorrect configuration" "deployment/app-h" "Trace both environment variables to their ConfigMap names and keys, then confirm the rollout becomes available."
    return 1
  fi
  available="$(fields "get deployment app-h -n ${NS} -o jsonpath={.status.availableReplicas}")"
  if [ "${available}" != "1" ]; then
    fail_check "Deployment 'app-h' is not available" "deployment/app-h" "Inspect Pod events and readiness separately from the configuration field."
    return 1
  fi
  ok "PASS: app-h meets the required condition"
}
check_app_a || return 1
check_app_b || return 1
check_app_c || return 1
check_app_d || return 1
check_app_e || return 1
check_app_f || return 1
check_app_g || return 1
check_app_h || return 1
ok "PASS: Lab 22 four basic and four hard challenges complete"
return 0
