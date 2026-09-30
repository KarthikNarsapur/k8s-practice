# Lab 01 teardown — remove the investigation label.
kc "label node -l node-role.kubernetes.io/control-plane lab01/investigated-" >/dev/null 2>&1 || true
