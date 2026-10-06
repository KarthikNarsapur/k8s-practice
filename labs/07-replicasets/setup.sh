# Lab 07 setup — deploy a ReplicaSet 'rs-web' with 2 replicas into $NS.
# setup.sh is SOURCED by lab-start.sh: helpers (kc/remote_exec/info/ok/err)
# and $NS are already available. The namespace is created before this runs.

info "Deploying ReplicaSet 'rs-web' (nginx:1.25, replicas=2) into ${NS}..."

remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: rs-web
  labels:
    app: rs-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: rs-web
  template:
    metadata:
      labels:
        app: rs-web
    spec:
      containers:
      - name: web
        image: nginx:1.25
        ports:
        - containerPort: 80
YAML"

ok "ReplicaSet 'rs-web' created with 2 replicas."
info "Now scale it and observe self-healing — see README.md section 4."

###############################################################################
# HARD CHALLENGES — additional starting state (deterministic, idempotent).
# These support the harder challenges in README.md. The ORIGINAL challenge
# above is untouched; everything below uses distinct names so it never
# interferes with 'rs-web'.
###############################################################################

# --- Hard Challenge 1 & 2 support: a ReplicaSet 'rs-ownership' plus an
#     unmanaged stray pod that does NOT match its selector, and a second
#     "adoption candidate" standalone pod whose labels CAN match. The learner
#     must work out which pods the controller actually owns.
info "Deploying hard-challenge state: 'rs-ownership' + stray/candidate pods..."

remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: rs-ownership
  labels:
    tier: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: owned-web
      tier: frontend
  template:
    metadata:
      labels:
        app: owned-web
        tier: frontend
    spec:
      containers:
      - name: web
        image: nginx:1.25
        ports:
        - containerPort: 80
---
# Stray pod: label does NOT satisfy the full selector (missing tier=frontend),
# so rs-ownership must not manage it and must not delete it.
apiVersion: v1
kind: Pod
metadata:
  name: stray-pod
  labels:
    app: owned-web
spec:
  containers:
  - name: web
    image: nginx:1.25
    ports:
    - containerPort: 80
---
# Adoption candidate: a bare pod whose labels FULLY match the rs-ownership
# selector. Because it already satisfies the selector, investigate whether the
# ReplicaSet adopts it (ownerReferences) and how that affects desired/current.
apiVersion: v1
kind: Pod
metadata:
  name: adopt-me
  labels:
    app: owned-web
    tier: frontend
spec:
  containers:
  - name: web
    image: nginx:1.25
    ports:
    - containerPort: 80
YAML"

# --- Hard Challenge 3 support: a ReplicaSet 'rs-forensics' whose desired count
#     cannot currently be met because its pod template requests far more memory
#     than any node can satisfy, so replicas stay Pending. The learner diagnoses
#     the discrepancy (desired vs available) and restores the desired state.
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: rs-forensics
  labels:
    app: rs-forensics
spec:
  replicas: 3
  selector:
    matchLabels:
      app: rs-forensics
  template:
    metadata:
      labels:
        app: rs-forensics
    spec:
      containers:
      - name: web
        image: nginx:1.25
        resources:
          requests:
            memory: \"900Gi\"
YAML"

ok "Hard-challenge state deployed: rs-ownership, stray-pod, adopt-me, rs-forensics."
info "Hard challenges are described in README.md (sections 4+)."
