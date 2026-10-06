# Lab 08 setup — nothing to deploy. You will create the Deployment yourself.
# The namespace ($NS) is already created by lab-start.sh.
info "Lab 08 deploys no starting workload."
info "Your task is to create a Deployment 'app' in namespace ${NS}."
info "See README.md section 4, then verify with ./scripts/lab-verify.sh 08."

# -----------------------------------------------------------------------------
# Hard Challenges — deploy the broken/forensic scenarios the learner must solve.
# -----------------------------------------------------------------------------
info "Deploying hard-challenge resources into ${NS}..."

# HC1 — Deployment Controller Forensics.
# Deploy 'trace-app' at nginx:1.24, then roll it to nginx:1.25 so the Deployment
# ends up owning TWO ReplicaSets (old scaled to 0, new holding the pods).
info "HC1: deploying 'trace-app' (nginx:1.24, 3 replicas), then rolling to nginx:1.25..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trace-app
  labels:
    app: trace-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: trace-app
  template:
    metadata:
      labels:
        app: trace-app
    spec:
      containers:
        - name: web
          image: nginx:1.24
          ports:
            - containerPort: 80
YAML"
kc "rollout status deployment/trace-app -n ${NS} --timeout=120s" || \
  warn "trace-app baseline rollout did not complete in time."
kc "set image deployment/trace-app web=nginx:1.25 -n ${NS}" || \
  warn "Could not roll trace-app forward to nginx:1.25."
kc "rollout status deployment/trace-app -n ${NS} --timeout=120s" || \
  warn "trace-app roll-forward did not complete in time."

# HC2 — Template Change Investigation.
# Deploy 'tmpl-change' at nginx:1.25, then patch in an env var. The template
# change produces a second ReplicaSet (new pod-template-hash).
info "HC2: deploying 'tmpl-change' (nginx:1.25, 2 replicas), then patching env..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tmpl-change
  labels:
    app: tmpl-change
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tmpl-change
  template:
    metadata:
      labels:
        app: tmpl-change
    spec:
      containers:
        - name: web
          image: nginx:1.25
          ports:
            - containerPort: 80
YAML"
kc "rollout status deployment/tmpl-change -n ${NS} --timeout=120s" || \
  warn "tmpl-change baseline rollout did not complete in time."
remote_exec "KUBECONFIG=/etc/kubernetes/admin.conf kubectl set env deployment/tmpl-change -n ${NS} LAB_FEATURE=enabled" || \
  warn "Could not add env var to tmpl-change."
kc "rollout status deployment/tmpl-change -n ${NS} --timeout=120s" || \
  warn "tmpl-change env rollout did not complete in time."

# HC3 — ReplicaSet/Deployment Mismatch.
# Deploy 'broken-deploy' with an absurd memory request so pods stay Pending.
# The learner must diagnose the unschedulable pods and fix the resource request.
info "HC3: deploying 'broken-deploy' (nginx:1.25, 3 replicas, impossible memory request)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-deploy
  labels:
    app: broken-deploy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: broken-deploy
  template:
    metadata:
      labels:
        app: broken-deploy
    spec:
      containers:
        - name: web
          image: nginx:1.25
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: \"900Gi\"
YAML"

ok "Hard-challenge resources deployed. See README.md section 4 'Hard Challenges'."
