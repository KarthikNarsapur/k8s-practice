# Lab 06 setup — the learner creates the cluster-scoped 'team-x' namespace,
# its ResourceQuota, and the pods. Nothing is deployed for them.
# The lab bookkeeping namespace ${NS} is already created by lab-start.sh.

# Ensure no stale team-x lingers from a previous attempt (idempotent start).
remote_exec "KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete namespace team-x --ignore-not-found --wait=true" >/dev/null 2>&1 || true

info "Lab 06: you will create the 'team-x' namespace, a ResourceQuota (pods=2),"
info "and pods inside it — see README.md section 4."
info "Note: 'team-x' is cluster-scoped and will be cleaned up by teardown on reset/destroy."
