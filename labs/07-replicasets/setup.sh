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
