# Lab 05 verification — sourced by lab-verify.sh (has kc/remote_exec/info/ok/err).
# Contract: on failure print FAILED: + object + ONE hint, return non-zero.

# 1. app-b must have selected=true
b_sel="$(kc "get pod app-b -n ${NS} -o jsonpath={.metadata.labels.selected}" 2>/dev/null | tr -d '[:space:]')"
if [ "${b_sel}" != "true" ]; then
  err "FAILED: app-b is not labelled selected=true"
  err "Object: pod/app-b label 'selected' in namespace ${NS}"
  err "Hint: The only pod matching BOTH tier=backend and env=prod should receive the label — target it via a selector."
  return 1
fi
ok "PASS: app-b has selected=true"

# 2. app-a must NOT have selected=true
a_sel="$(kc "get pod app-a -n ${NS} -o jsonpath={.metadata.labels.selected}" 2>/dev/null | tr -d '[:space:]')"
if [ "${a_sel}" = "true" ]; then
  err "FAILED: app-a was labelled selected=true but should not be"
  err "Object: pod/app-a label 'selected' in namespace ${NS}"
  err "Hint: app-a is tier=frontend — your selector matched too broadly. Combine both conditions (tier AND env) and verify the match count before labelling."
  return 1
fi
ok "PASS: app-a is not selected"

# 3. app-c must NOT have selected=true
c_sel="$(kc "get pod app-c -n ${NS} -o jsonpath={.metadata.labels.selected}" 2>/dev/null | tr -d '[:space:]')"
if [ "${c_sel}" = "true" ]; then
  err "FAILED: app-c was labelled selected=true but should not be"
  err "Object: pod/app-c label 'selected' in namespace ${NS}"
  err "Hint: app-c is env=dev — your selector matched too broadly. Combine both conditions (tier AND env) and verify the match count before labelling."
  return 1
fi
ok "PASS: app-c is not selected"

return 0
