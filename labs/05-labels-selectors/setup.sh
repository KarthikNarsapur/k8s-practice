# Lab 05 setup — deploy three labelled pods into ${NS}.
# The namespace ${NS} is already created by lab-start.sh.
info "Deploying app-a, app-b, app-c (nginx:1.25) with different labels..."

remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: v1
kind: Pod
metadata:
  name: app-a
  labels:
    tier: frontend
    env: prod
spec:
  containers:
    - name: nginx
      image: nginx:1.25
---
apiVersion: v1
kind: Pod
metadata:
  name: app-b
  labels:
    tier: backend
    env: prod
spec:
  containers:
    - name: nginx
      image: nginx:1.25
---
apiVersion: v1
kind: Pod
metadata:
  name: app-c
  labels:
    tier: backend
    env: dev
spec:
  containers:
    - name: nginx
      image: nginx:1.25
YAML" >/dev/null

ok "Deployed app-a, app-b, app-c in ${NS}."
info "Inspect labels:  kubectl get pods -n ${NS} --show-labels"
info "Then complete the labelling task in README.md section 4."
