# Lab t01 setup — deploys a deliberately BROKEN workload for you to diagnose.
# Sourced by lab-start.sh; has kc/remote_exec/info/ok/warn/err and $NS.
# The namespace ($NS) already exists.
#
# We deploy a Deployment 'broken-app' whose container will not stay up.
# The root cause is intentionally NOT documented here or in README.md — that
# is the whole point of the lab. Diagnose it with kubectl/crictl.

info "Deploying 'broken-app' into namespace ${NS}..."

remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
  labels:
    app: broken-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: broken-app
  template:
    metadata:
      labels:
        app: broken-app
    spec:
      restartPolicy: Always
      containers:
        - name: app
          image: busybox:1.36
          command: ['sh', '-c', 'echo starting; exit 1']
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
            limits:
              cpu: 50m
              memory: 32Mi
YAML"

ok "Deployed broken-app (2 replicas) into ${NS}."
info "It is NOT staying up. Diagnose and fix it — see README.md section 4."
info "Verify with: ./scripts/lab-verify.sh t01"
