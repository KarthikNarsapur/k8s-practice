#!/usr/bin/env bash
# Verifiers use structured jsonpath fields, never human-readable kubectl table parsing.
fail_check() { err "FAILED: $1"; err "Object: $2"; err "Hint: $3"; return 1; }
value() {
  local out
  out="$(kc "$1" 2>/dev/null | tr -d '[:space:]' || true)"
  case "${out}" in None|"<no value>") out="";; esac
  printf '%s' "${out}"
}

check_rule() {
  local name="$1" destination="$2" direction="$3" peer="$4" port="$5" selector ptype actualpeer actualport nspeer
  if ! kc "get networkpolicy ${name} -n ${NS}" >/dev/null 2>&1; then
    fail_check "NetworkPolicy '${name}' not found" "networkpolicy/${name}" "Create or repair the policy while preserving the intended traffic boundary."
    return 1
  fi
  selector="$(value "get networkpolicy ${name} -n ${NS} -o jsonpath={.spec.podSelector.matchLabels.tier}")"
  ptype="$(value "get networkpolicy ${name} -n ${NS} -o jsonpath={.spec.policyTypes[0]}")"
  if [ "${selector}" != "${destination}" ] || [ "${ptype}" != "${direction}" ]; then
    fail_check "NetworkPolicy '${name}' selects the wrong tier or direction" "networkpolicy/${name}: tier=${selector:-empty}, policyType=${ptype:-empty}" "Separate the destination Pods selected by podSelector from the direction and peers in its rules."
    return 1
  fi
  if [ -n "${peer}" ]; then
    if [ "${direction}" = "Ingress" ]; then
      actualpeer="$(value "get networkpolicy ${name} -n ${NS} -o jsonpath={.spec.ingress[0].from[0].podSelector.matchLabels.tier}")"
      actualport="$(value "get networkpolicy ${name} -n ${NS} -o jsonpath={.spec.ingress[0].ports[0].port}")"
    else
      actualpeer="$(value "get networkpolicy ${name} -n ${NS} -o jsonpath='{.spec.egress[0].to[0].namespaceSelector.matchLabels.kubernetes\.io/metadata\.name}'")"
      actualport="$(value "get networkpolicy ${name} -n ${NS} -o jsonpath={.spec.egress[0].ports[0].port}")"
    fi
    if [ "${actualpeer}" != "${peer}" ] || [ "${actualport}" != "${port}" ]; then
      fail_check "NetworkPolicy '${name}' has an incorrect peer or port" "networkpolicy/${name}: peer=${actualpeer:-empty}, port=${actualport:-empty}" "Inspect the allowed peer selector, protocol, and destination port for the intended traffic."
      return 1
    fi
  fi
  ok "PASS: ${name} selector, direction, and required rule fields are correct"
}
check_deny() {
  local name="$1" tier="$2" selector ptype ingress
  if ! kc "get networkpolicy ${name} -n ${NS}" >/dev/null 2>&1; then
    fail_check "NetworkPolicy '${name}' not found" "networkpolicy/${name}" "A deny-ingress policy needs a destination selector and no allowed ingress rules."
    return 1
  fi
  selector="$(value "get networkpolicy ${name} -n ${NS} -o jsonpath={.spec.podSelector.matchLabels.tier}")"
  ptype="$(value "get networkpolicy ${name} -n ${NS} -o jsonpath={.spec.policyTypes[0]}")"
  ingress="$(value "get networkpolicy ${name} -n ${NS} -o jsonpath={.spec.ingress[0].from[0].podSelector.matchLabels.tier}")"
  if [ "${selector}" != "${tier}" ] || [ "${ptype}" != "Ingress" ] || [ -n "${ingress}" ]; then
    fail_check "NetworkPolicy '${name}' does not express the expected ingress isolation" "networkpolicy/${name}" "Check the selected destination tier, policyTypes, and whether any ingress allow rules remain."
    return 1
  fi
  ok "PASS: ${name} isolates the expected tier"
}
check_dns() {
  local name="$1" selector ptype peer port
  if ! kc "get networkpolicy ${name} -n ${NS}" >/dev/null 2>&1; then
    fail_check "NetworkPolicy '${name}' not found" "networkpolicy/${name}" "DNS egress needs an explicit policy rule for DNS traffic."
    return 1
  fi
  selector="$(value "get networkpolicy ${name} -n ${NS} -o jsonpath={.spec.podSelector.matchLabels.tier}")"
  ptype="$(value "get networkpolicy ${name} -n ${NS} -o jsonpath={.spec.policyTypes[0]}")"
  peer="$(value "get networkpolicy ${name} -n ${NS} -o jsonpath='{.spec.egress[0].to[0].namespaceSelector.matchLabels.kubernetes\.io/metadata\.name}'")"
  port="$(value "get networkpolicy ${name} -n ${NS} -o jsonpath={.spec.egress[0].ports[0].port}")"
  if [ "${selector}" != "frontend" ] || [ "${ptype}" != "Egress" ] || [ "${peer}" != "kube-system" ] || [ "${port}" != "53" ]; then
    fail_check "NetworkPolicy '${name}' does not allow the expected DNS egress" "networkpolicy/${name}: tier=${selector:-empty}, direction=${ptype:-empty}, namespace=${peer:-empty}, port=${port:-empty}" "Check the source Pod selector, namespace peer, egress direction, and DNS port."
    return 1
  fi
  ok "PASS: ${name} allows DNS egress to kube-system on port 53"
}
check_deny "deny-backend-ingress" "backend" || return 1
check_rule "allow-frontend-backend" "backend" "Ingress" "frontend" "80" || return 1
check_rule "allow-backend-db" "database" "Ingress" "backend" "80" || return 1
check_dns "allow-frontend-dns" || return 1
check_deny "hc-isolate-db" "database" || return 1
check_rule "hc-allow-ui" "backend" "Ingress" "frontend" "80" || return 1
check_rule "hc-db-port" "database" "Ingress" "backend" "80" || return 1
check_dns "hc-dns" || return 1
ok "PASS: Lab 17 base + four hard challenges complete"
return 0
