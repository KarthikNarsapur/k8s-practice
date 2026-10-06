# Lab 09 setup — deploy Deployment 'rollme' (nginx:1.24, 4 replicas,
# RollingUpdate strategy) into $NS. setup.sh is SOURCED by lab-start.sh:
# helpers (kc/remote_exec/info/ok/err) and $NS are already available.

info "Deploying Deployment 'rollme' (nginx:1.24, replicas=4) into ${NS}..."

remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rollme
  labels:
    app: rollme
spec:
  replicas: 4
  selector:
    matchLabels:
      app: rollme
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: rollme
    spec:
      containers:
      - name: web
        image: nginx:1.24
        ports:
        - containerPort: 80
YAML"

ok "Deployment 'rollme' created at nginx:1.24 with 4 replicas."
info "Now roll it forward to nginx:1.25 — see README.md section 4."

# -----------------------------------------------------------------------------
# Hard Challenges
# -----------------------------------------------------------------------------
info "Deploying hard-challenge resources into ${NS}..."

# HC1 — Failed Rolling Update: rollme-fail starts healthy at nginx:1.25, then is
# rolled to a nonexistent tag so the rollout gets stuck in ImagePullBackOff.
info "HC1: deploying 'rollme-fail' (nginx:1.25, 3 replicas), then rolling to a bad image..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rollme-fail
  labels:
    app: rollme-fail
spec:
  replicas: 3
  selector:
    matchLabels:
      app: rollme-fail
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: rollme-fail
    spec:
      containers:
      - name: web
        image: nginx:1.25
        ports:
        - containerPort: 80
YAML"
kc "rollout status deployment/rollme-fail -n ${NS} --timeout=120s" || \
  warn "rollme-fail baseline rollout did not complete in time."
kc "set image deployment/rollme-fail web=nginx:doesnotexist-99.99 -n ${NS}" || \
  warn "Could not set the broken image on rollme-fail."

# HC2 — maxSurge/maxUnavailable: surge-test (nginx:1.24, 6 replicas,
# maxSurge=2, maxUnavailable=0). Learner rolls it to nginx:1.25.
info "HC2: deploying 'surge-test' (nginx:1.24, 6 replicas, maxSurge=2, maxUnavailable=0)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: surge-test
  labels:
    app: surge-test
spec:
  replicas: 6
  selector:
    matchLabels:
      app: surge-test
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: surge-test
    spec:
      containers:
      - name: web
        image: nginx:1.24
        ports:
        - containerPort: 80
YAML"
kc "rollout status deployment/surge-test -n ${NS} --timeout=120s" || \
  warn "surge-test baseline rollout did not complete in time."

# HC3 — Rollout Availability Investigation: avail-check deployed directly with a
# nonexistent tag so all pods are ImagePullBackOff. Learner diagnoses and fixes.
info "HC3: deploying 'avail-check' (nginx:1.25-nonexistent, 3 replicas, broken on purpose)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: avail-check
  labels:
    app: avail-check
spec:
  replicas: 3
  selector:
    matchLabels:
      app: avail-check
  template:
    metadata:
      labels:
        app: avail-check
    spec:
      containers:
      - name: web
        image: nginx:1.25-nonexistent
        ports:
        - containerPort: 80
YAML"

ok "Hard-challenge resources deployed. See README.md section 4 'Hard Challenges'."
