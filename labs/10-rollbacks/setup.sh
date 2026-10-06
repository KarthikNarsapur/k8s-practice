# Lab 10 setup — deploy a healthy Deployment 'rbk' as the known-good baseline.
# The namespace ($NS) is already created by lab-start.sh.
# We use the remote_exec heredoc approach so the manifest is applied verbatim
# on the control-plane (stdin over SSM is not reliable through kc directly).

info "Deploying Deployment 'rbk' (nginx:1.25, 3 replicas) into ${NS}..."

remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rbk
  labels:
    app: rbk
spec:
  replicas: 3
  selector:
    matchLabels:
      app: rbk
  template:
    metadata:
      labels:
        app: rbk
    spec:
      containers:
        - name: web
          image: nginx:1.25
          ports:
            - containerPort: 80
YAML"

# Wait for the baseline rollout to finish so 'revision 1' is the known-good state.
info "Waiting for the baseline rollout to become available..."
kc "rollout status deployment/rbk -n ${NS} --timeout=120s" || \
  warn "Baseline rollout did not complete in time; check 'kubectl get pods -n ${NS}'."

ok "Baseline is deployed. Revision 1 (nginx:1.25) is your known-good state."
info "Now break it and roll back — see README.md section 4."

# -----------------------------------------------------------------------------
# Hard Challenges
# -----------------------------------------------------------------------------
info "Deploying hard-challenge resources into ${NS}..."

# HC1 — Multi-Revision Forensics: multi-rev goes through 4 image changes to
# build a revision history. The 3rd revision uses a bad tag causing a stuck
# rollout, then revision 4 rolls back to a healthy image.
info "HC1: deploying 'multi-rev' with 4 revisions..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-rev
  labels:
    app: multi-rev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: multi-rev
  template:
    metadata:
      labels:
        app: multi-rev
    spec:
      containers:
        - name: web
          image: nginx:1.24
          ports:
            - containerPort: 80
YAML"
kc "rollout status deployment/multi-rev -n ${NS} --timeout=120s" || \
  warn "multi-rev rev 1 rollout did not complete in time."
# Revision 2: roll to nginx:1.25
kc "set image deployment/multi-rev web=nginx:1.25 -n ${NS}" || \
  warn "Could not roll multi-rev to nginx:1.25."
kc "rollout status deployment/multi-rev -n ${NS} --timeout=120s" || \
  warn "multi-rev rev 2 rollout did not complete in time."
# Revision 3: roll to a bad image (will get stuck)
kc "set image deployment/multi-rev web=nginx:doesnotexist-bad -n ${NS}" || \
  warn "Could not roll multi-rev to the bad image."
# Give the controller a moment to start creating bad pods, then undo.
sleep 5
# Revision 4: undo back to previous healthy revision
kc "rollout undo deployment/multi-rev -n ${NS}" || \
  warn "Could not undo multi-rev."
kc "rollout status deployment/multi-rev -n ${NS} --timeout=120s" || \
  warn "multi-rev rev 4 rollout did not complete in time."

# HC2 — Rollback Investigation: rev-inspect starts healthy, gets broken.
info "HC2: deploying 'rev-inspect' (nginx:1.25, 3 replicas), then breaking it..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rev-inspect
  labels:
    app: rev-inspect
spec:
  replicas: 3
  selector:
    matchLabels:
      app: rev-inspect
  template:
    metadata:
      labels:
        app: rev-inspect
    spec:
      containers:
        - name: web
          image: nginx:1.25
          ports:
            - containerPort: 80
YAML"
kc "rollout status deployment/rev-inspect -n ${NS} --timeout=120s" || \
  warn "rev-inspect baseline rollout did not complete in time."
kc "set image deployment/rev-inspect web=nginx:doesnotexist-broken -n ${NS}" || \
  warn "Could not set broken image on rev-inspect."

# HC3 — Post-Rollback Verification: post-rbk goes nginx:1.24 → nginx:1.25 →
# broken. Learner rolls back and verifies.
info "HC3: deploying 'post-rbk' (nginx:1.24, 3 replicas), rolling forward, then breaking..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: post-rbk
  labels:
    app: post-rbk
spec:
  replicas: 3
  selector:
    matchLabels:
      app: post-rbk
  template:
    metadata:
      labels:
        app: post-rbk
    spec:
      containers:
        - name: web
          image: nginx:1.24
          ports:
            - containerPort: 80
YAML"
kc "rollout status deployment/post-rbk -n ${NS} --timeout=120s" || \
  warn "post-rbk rev 1 rollout did not complete in time."
kc "set image deployment/post-rbk web=nginx:1.25 -n ${NS}" || \
  warn "Could not roll post-rbk to nginx:1.25."
kc "rollout status deployment/post-rbk -n ${NS} --timeout=120s" || \
  warn "post-rbk rev 2 rollout did not complete in time."
kc "set image deployment/post-rbk web=nginx:nope -n ${NS}" || \
  warn "Could not set broken image on post-rbk."

ok "Hard-challenge resources deployed. See README.md section 4 'Hard Challenges'."
