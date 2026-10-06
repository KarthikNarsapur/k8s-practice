# Lab 08 — Solution

> Spoiler. Only read this after attempting the challenge.

### 1. Create the Deployment
Imperative (simplest):
```bash
kubectl create deployment app --image=nginx:1.25 --replicas=3 -n lab-08
```
Or declaratively:
```bash
cat <<'YAML' | kubectl apply -n lab-08 -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
YAML
```

### 2. Observe the object chain
```bash
kubectl get deploy,rs,pods -n lab-08 -o wide
# deployment.apps/app        3/3     3            3
# replicaset.apps/app-6d8f...   3     3     3
# pod/app-6d8f...-aaaaa   1/1   Running
# pod/app-6d8f...-bbbbb   1/1   Running
# pod/app-6d8f...-ccccc   1/1   Running
```
The Deployment created one ReplicaSet named `app-<hash>`. The `<hash>` is the
`pod-template-hash` label value — a hash of the pod template. The ReplicaSet
created the three pods.

### 3. Inspect the Deployment
```bash
kubectl describe deploy app -n lab-08
# Replicas:  3 desired | 3 updated | 3 total | 3 available | 0 unavailable
# ...
# NewReplicaSet:  app-6d8f... (3/3 replicas created)
```

### 4. Confirm the ownership chain
```bash
kubectl get rs -n lab-08 -o yaml | grep -A6 ownerReferences
#   ownerReferences:
#   - apiVersion: apps/v1
#     kind: Deployment
#     name: app
#     controller: true

POD=$(kubectl get pods -n lab-08 -o jsonpath='{.items[0].metadata.name}')
kubectl get pod "$POD" -n lab-08 -o yaml | grep -A6 ownerReferences
#   ownerReferences:
#   - apiVersion: apps/v1
#     kind: ReplicaSet
#     name: app-6d8f...
#     controller: true
```

### Why it matters
A Deployment does not manage pods directly — it manages **one ReplicaSet per
pod-template revision**. When you change the pod template (image, env, etc.),
the Deployment creates a *new* ReplicaSet and scales it up while scaling the old
one down. That indirection (Deployment → ReplicaSet → Pod) is precisely what
makes rolling updates and rollbacks possible, which is the focus of Lab 09.

### Hard Challenge 1 — Deployment Controller Forensics

> Spoiler. Only read this after attempting the hard challenge.

#### 1. List both ReplicaSets
```bash
kubectl get rs -n lab-08 -l app=trace-app -o wide
# NAME                    DESIRED   CURRENT   READY   ...   IMAGES
# trace-app-<hashA>       0         0         0       ...   nginx:1.24
# trace-app-<hashB>       3         3         3       ...   nginx:1.25
```
The **active** RS is the one with 3 ready replicas (nginx:1.25). The **old** RS
(nginx:1.24) is scaled to 0 but retained for rollback.

#### 2. Trace the ownership chain
```bash
# Deployment → RS
kubectl get rs -n lab-08 -l app=trace-app \
  -o jsonpath='{range .items[*]}{.metadata.name}{" owner="}{.metadata.ownerReferences[0].name}{" kind="}{.metadata.ownerReferences[0].kind}{"\n"}{end}'
# trace-app-<hashB> owner=trace-app kind=Deployment

# RS → Pods
ACTIVE_RS=$(kubectl get rs -n lab-08 -l app=trace-app \
  -o jsonpath='{range .items[?(@.status.replicas>0)]}{.metadata.name}{end}')
kubectl get pods -n lab-08 -l app=trace-app \
  -o jsonpath='{range .items[*]}{.metadata.name}{" owner="}{.metadata.ownerReferences[0].name}{"\n"}{end}'
# Each pod's owner is the active RS name.
```

#### 3. Confirm the old RS has 0 replicas
```bash
kubectl get rs -n lab-08 -l app=trace-app \
  -o jsonpath='{range .items[?(@.status.replicas==0)]}{.metadata.name}{" replicas="}{.status.replicas}{"\n"}{end}'
```

### Why it matters
Understanding the two-RS state is essential for troubleshooting rollouts.
After a rolling update, the old RS stays at 0 replicas so `kubectl rollout undo`
can restore it instantly. The `pod-template-hash` label ties each RS to a
specific template version, making the ownership chain deterministic and
auditable.

### Hard Challenge 2 — Template Change Investigation

> Spoiler. Only read this after attempting the hard challenge.

#### 1. List both ReplicaSets
```bash
kubectl get rs -n lab-08 -l app=tmpl-change -o wide
# Two RS objects — one at 0 replicas (original), one at 2 (after env change).
```

#### 2. Compare pod templates
```bash
RS_OLD=$(kubectl get rs -n lab-08 -l app=tmpl-change \
  -o jsonpath='{range .items[?(@.status.replicas==0)]}{.metadata.name}{end}')
RS_NEW=$(kubectl get rs -n lab-08 -l app=tmpl-change \
  -o jsonpath='{range .items[?(@.status.replicas>0)]}{.metadata.name}{end}')

# Dump both templates and diff
kubectl get rs "${RS_OLD}" -n lab-08 -o yaml > /tmp/old.yaml
kubectl get rs "${RS_NEW}" -n lab-08 -o yaml > /tmp/new.yaml
diff /tmp/old.yaml /tmp/new.yaml
```
The diff reveals the new RS template includes:
```yaml
env:
  - name: LAB_FEATURE
    value: enabled
```

#### 3. Confirm replicas
```bash
kubectl get deploy tmpl-change -n lab-08 \
  -o jsonpath='available={.status.availableReplicas} updated={.status.updatedReplicas}{"\n"}'
# available=2 updated=2
```

### Why it matters
Any change to the pod template — not just the image, but also env vars, volume
mounts, resource requests, labels, or annotations — triggers a new ReplicaSet.
The `pod-template-hash` changes because the template itself changed. This is
fundamental to understanding why "small" edits cause full rolling updates.

### Hard Challenge 3 — ReplicaSet/Deployment Mismatch

> Spoiler. Only read this after attempting the hard challenge.

#### 1. Diagnose the problem
```bash
kubectl get deploy broken-deploy -n lab-08
# READY 0/3 — no pods are available.

kubectl get pods -n lab-08 -l app=broken-deploy
# All pods show Pending.

kubectl describe pod -n lab-08 -l app=broken-deploy | sed -n '/Events/,$p'
# Warning  FailedScheduling ... Insufficient memory.
# The pod requests 900Gi of memory — far more than any node has.
```

#### 2. Fix the resource request
```bash
kubectl set resources deployment/broken-deploy -n lab-08 \
  --requests=memory=64Mi
```
Or patch the Deployment:
```bash
kubectl patch deployment broken-deploy -n lab-08 --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/containers/0/resources/requests/memory"}]'
```
Or edit and change the memory request to something reasonable (e.g. `64Mi`):
```bash
kubectl edit deploy broken-deploy -n lab-08
```

#### 3. Confirm recovery
```bash
kubectl rollout status deploy/broken-deploy -n lab-08
kubectl get deploy broken-deploy -n lab-08
# READY 3/3
```

### Why it matters
When pods request more resources than any node can provide, the scheduler cannot
place them and they remain `Pending` indefinitely. The Deployment controller
reports `0 available`, but it does not crash or error — it simply waits. Reading
pod events is the key diagnostic skill: `FailedScheduling` with
`Insufficient memory` tells you exactly what is wrong. Fixing the resource
request triggers a new rollout with a schedulable pod template.
