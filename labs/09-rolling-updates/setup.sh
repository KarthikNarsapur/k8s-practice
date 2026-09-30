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
