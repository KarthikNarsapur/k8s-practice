# Lab 04 setup — deploy the cycling 'lifecycle' pod into ${NS}.
# The namespace ${NS} is already created by lab-start.sh.
info "Deploying the 'lifecycle' pod (sleeps 30s, exits 0, restartPolicy=Always)..."

remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: v1
kind: Pod
metadata:
  name: lifecycle
  labels:
    lab: '04'
spec:
  restartPolicy: Always
  containers:
    - name: worker
      image: busybox:1.36
      command: [\"sh\", \"-c\", \"echo starting; sleep 30; echo done; exit 0\"]
YAML" >/dev/null

ok "Deployed pod 'lifecycle' in ${NS}."
info "Watch it cycle:  kubectl get pod lifecycle -n ${NS} -w"
info "Then create the 'stable' pod as described in README.md section 4."
