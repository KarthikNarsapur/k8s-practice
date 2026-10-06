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

###############################################################################
# Hard Challenges — additional broken workloads for advanced troubleshooting.
# These are deployed alongside broken-app. Each has multiple, independent
# problems. The learner must investigate and restore each to a healthy state.
###############################################################################
info "Deploying hard-challenge resources..."

# HC1 — CrashLoop + Configuration: a Deployment whose container crashes because
# it tries to read a required config file that does not exist (the mount path is
# wrong). The command succeeds only if /etc/app/config.txt exists; the pod
# crashes on missing config.
info "[HC1] Deploying 'config-crash' (crashes on missing config)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  config.txt: \"mode=production\"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-crash
  labels:
    app: config-crash
spec:
  replicas: 2
  selector:
    matchLabels:
      app: config-crash
  template:
    metadata:
      labels:
        app: config-crash
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ['sh', '-c', 'cat /etc/wrong-path/config.txt && sleep 3600']
          volumeMounts:
            - name: cfg
              mountPath: /etc/app
              readOnly: true
      volumes:
        - name: cfg
          configMap:
            name: app-config
YAML"

# HC2 — CrashLoop + Scheduling: a Deployment with a nodeSelector that matches
# no nodes (missing label) AND a container command that would crash even if
# scheduled. Two layered problems: Pending first, then CrashLoop if the label
# is added without fixing the command.
info "[HC2] Deploying 'sched-crash' (unschedulable + crashing command)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sched-crash
  labels:
    app: sched-crash
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sched-crash
  template:
    metadata:
      labels:
        app: sched-crash
    spec:
      nodeSelector:
        special-hw: gpu
      containers:
        - name: app
          image: busybox:1.36
          command: ['sh', '-c', 'echo starting; exit 1']
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
YAML"

# HC3 — Multi-Cause Incident: a Deployment with THREE independent issues:
#   1. Scheduling: an impossibly large memory request (900Gi) → Pending.
#   2. Container: command exits 1 even if memory is fixed → CrashLoopBackOff.
#   3. Selector: a standalone service targets the wrong label, so even if the
#      pods are fixed they are not selected by anything. (We create a Service
#      with a wrong selector to make the incident more realistic.)
# The learner gets only an incident statement: "incident-app is unavailable."
info "[HC3] Deploying 'incident-app' (3 independent problems)..."
remote_exec "cat <<'YAML' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: incident-app
  labels:
    app: incident-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: incident-app
  template:
    metadata:
      labels:
        app: incident-app
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ['sh', '-c', 'echo booting; exit 1']
          resources:
            requests:
              memory: \"900Gi\"
---
apiVersion: v1
kind: Service
metadata:
  name: incident-svc
spec:
  selector:
    app: incident-app-TYPO
  ports:
    - port: 80
      targetPort: 8080
YAML"

ok "Hard-challenge resources deployed (config-crash, sched-crash, incident-app)."
info "Investigate them: kubectl -n ${NS} get deploy,pods,svc"
