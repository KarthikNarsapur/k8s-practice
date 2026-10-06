# Lab 11 teardown — remove node labels added by hard challenges.
# These labels are cluster-scoped, so they must be cleaned up before the
# namespace is deleted (the namespace delete does not touch node labels).
kc "label nodes --all disk- zone-" >/dev/null 2>&1 || true
