# Lab 06 teardown — remove the cluster-scoped 'team-x' namespace.
# (The lab bookkeeping namespace ${NS} is deleted automatically by the engine.)
info "Deleting cluster-scoped namespace team-x..."
kc "delete namespace team-x --ignore-not-found --wait=true" >/dev/null 2>&1 || true
