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
