# Lab 06 verification — sourced by lab-verify.sh (has kc/remote_exec/info/ok/err).
# Contract: on failure print FAILED: + object + ONE hint, return non-zero.
# NOTE: the target namespace here is the cluster-scoped 'team-x', not ${NS}.

# 1. Does the team-x namespace exist?
ns_name="$(kc "get namespace team-x -o jsonpath={.metadata.name}" 2>/dev/null | tr -d '[:space:]')"
if [ "${ns_name}" != "team-x" ]; then
  err "FAILED: Namespace team-x not found"
  err "Object: namespace/team-x"
  err "Hint: Namespaces are cluster-scoped objects you create explicitly before placing resources in them."
  return 1
fi
ok "PASS: namespace team-x exists"

# 2. Is there a ResourceQuota in team-x?
rq_count="$(kc "get resourcequota -n team-x --no-headers" 2>/dev/null | grep -c . | tr -d '[:space:]')"
if [ -z "${rq_count}" ] || [ "${rq_count}" = "0" ]; then
  err "FAILED: No ResourceQuota in team-x"
  err "Object: resourcequota in namespace team-x"
  err "Hint: A quota must exist in the namespace to cap consumption; create it before the pods so it is enforced."
  return 1
fi
ok "PASS: a ResourceQuota exists in team-x"

# 3. Exactly 2 pods Running in team-x?
running="$(kc "get pods -n team-x --field-selector=status.phase=Running --no-headers" 2>/dev/null | grep -c . | tr -d '[:space:]')"
if [ "${running}" != "2" ]; then
  err "FAILED: Expected exactly 2 Running pods in team-x (found ${running})"
  err "Object: pods in namespace team-x vs its ResourceQuota"
  err "Hint: The quota should admit 2 pods and reject the 3rd — check 'Used' vs 'Hard' in the quota."
  return 1
fi
ok "PASS: exactly 2 pods are Running in team-x"

return 0
