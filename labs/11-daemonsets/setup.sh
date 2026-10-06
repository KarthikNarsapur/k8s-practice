# Lab 11 setup — nothing is deployed. You will create the DaemonSet yourself.
# The namespace ($NS) is already created by lab-start.sh.
info "Lab 11 deploys no starting workload."
info "Your task: create a DaemonSet 'node-agent' in namespace ${NS}."
info "First, look at how many nodes are schedulable:"
info "  kubectl get nodes -o wide"
info "See README.md section 4 for the full challenge."

###############################################################################
# Hard Challenges — extra pre-deployed state for the advanced scenarios.
# These are OPTIONAL: the base challenge above still works on its own.
###############################################################################
info "Setting up hard-challenge resources..."

# HC1 — label exactly one worker node with disk=ssd, then deploy an 'ssd-agent'
#        DaemonSet that only targets that node via nodeSelector.
info "[HC1] Labeling one worker node with disk=ssd..."
remote_exec "FIRST=\$(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' -o custom-columns=NAME:.metadata.name | head -1); [ -n \"\$FIRST\" ] && kubectl label node \$FIRST disk=ssd --overwrite" || warn "[HC1] could not label a worker node"

info "[HC1] Deploying DaemonSet 'ssd-agent' (nodeSelector disk=ssd)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ssd-agent
  labels:
    app: ssd-agent
spec:
  selector:
    matchLabels:
      app: ssd-agent
  template:
    metadata:
      labels:
        app: ssd-agent
    spec:
      nodeSelector:
        disk: ssd
      containers:
        - name: agent
          image: busybox:1.36
          command: [\"sh\", \"-c\", \"sleep infinity\"]
YAML"

# HC2 — deploy a 'taint-agent' DaemonSet WITH a toleration for the control-plane
#        NoSchedule taint, so it runs on EVERY node (workers + control-plane).
info "[HC2] Deploying DaemonSet 'taint-agent' (tolerates control-plane taint)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: taint-agent
  labels:
    app: taint-agent
spec:
  selector:
    matchLabels:
      app: taint-agent
  template:
    metadata:
      labels:
        app: taint-agent
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
        - key: node-role.kubernetes.io/master
          operator: Exists
          effect: NoSchedule
      containers:
        - name: agent
          image: busybox:1.36
          command: [\"sh\", \"-c\", \"sleep infinity\"]
YAML"

# HC3 — label ALL workers with zone=east, deploy a 'zone-agent' DaemonSet that
#        selects zone=east, then REMOVE the label from one worker so the learner
#        can observe a daemon pod being removed and 'desired' dropping by one.
info "[HC3] Labeling all worker nodes with zone=east..."
remote_exec "for n in \$(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' -o custom-columns=NAME:.metadata.name); do kubectl label node \$n zone=east --overwrite; done" || warn "[HC3] could not label worker nodes"

info "[HC3] Deploying DaemonSet 'zone-agent' (nodeSelector zone=east)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: zone-agent
  labels:
    app: zone-agent
spec:
  selector:
    matchLabels:
      app: zone-agent
  template:
    metadata:
      labels:
        app: zone-agent
    spec:
      nodeSelector:
        zone: east
      containers:
        - name: agent
          image: busybox:1.36
          command: [\"sh\", \"-c\", \"sleep infinity\"]
YAML"

info "[HC3] Removing zone=east from one worker node (watch a pod disappear)..."
remote_exec "FIRST=\$(kubectl get nodes --no-headers -l 'zone=east,!node-role.kubernetes.io/control-plane' -o custom-columns=NAME:.metadata.name | head -1); [ -n \"\$FIRST\" ] && kubectl label node \$FIRST zone- --overwrite" || warn "[HC3] could not remove zone label"

ok "Hard-challenge resources deployed (ssd-agent, taint-agent, zone-agent)."
info "Investigate them: kubectl -n ${NS} get ds -o wide"
