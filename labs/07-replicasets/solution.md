# Lab 07 — Solution

> Spoiler. Only read this after attempting the challenge.

### 1. Confirm the starting state
```bash
kubectl get rs,pods -n lab-07 -o wide
# replicaset.apps/rs-web   2   2   2   ...
# pod/rs-web-xxxxx   1/1   Running ...
# pod/rs-web-yyyyy   1/1   Running ...
```

### 2. Scale to 4 replicas
```bash
kubectl scale rs rs-web -n lab-07 --replicas=4
# replicaset.apps/rs-web scaled
kubectl get rs rs-web -n lab-07
# NAME     DESIRED   CURRENT   READY   AGE
# rs-web   4         4         4       ...
```

### 3. Observe self-healing
In terminal A:
```bash
kubectl get pods -n lab-07 -w
```
In terminal B:
```bash
POD=$(kubectl get pods -n lab-07 -l app=rs-web -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$POD" -n lab-07
```
Terminal A shows the pod going `Terminating`, and almost immediately a brand-new
pod appears (`Pending` → `ContainerCreating` → `Running`). The desired count is
4, so the controller creates a replacement to reconcile actual back to desired.

### 4. Inspect ownerReferences
```bash
POD=$(kubectl get pods -n lab-07 -l app=rs-web -o jsonpath='{.items[0].metadata.name}')
kubectl get pod "$POD" -n lab-07 -o yaml | grep -A6 ownerReferences
#   ownerReferences:
#   - apiVersion: apps/v1
#     kind: ReplicaSet
#     name: rs-web
#     controller: true
#     blockOwnerDeletion: true
```
The `controller: true` flag identifies `rs-web` as the managing controller. This
is how the ReplicaSet "owns" the pods it created, and how garbage collection
knows to delete the pods if the ReplicaSet is deleted.

### 5. Read controller activity
```bash
kubectl describe rs rs-web -n lab-07
# ...
# Events:
#   Type    Reason            ... Message
#   Normal  SuccessfulCreate  ... Created pod: rs-web-...
kubectl get events -n lab-07 --sort-by=.lastTimestamp
```

### Why it matters
A ReplicaSet is a pure reconciliation loop: `desired == spec.replicas`,
`actual == pods matching the selector`. It never "remembers" pods — it only
counts pods that match its selector and creates/deletes to close the gap. This
is the exact mechanism a Deployment builds on top of (next lab). Understanding
that pods are claimed by **label selector** — not by name — is essential:
delete a pod, change a label, and the controller reacts accordingly.

---

## Hard Challenge Solutions

> Spoiler. Only read these after attempting the hard challenges. The resources
> below (`rs-ownership`, `stray-pod`, `adopt-me`, `rs-forensics`) are
> pre-deployed by `lab-start.sh`; investigate and fix them, then the verifier
> checks the resulting state.

### Hard Challenge 1 — ReplicaSet Ownership Investigation

> `rs-ownership` selects pods with BOTH `app=owned-web` AND `tier=frontend`.
> `stray-pod` has only `app=owned-web` (missing `tier=frontend`), so it is
> **not** managed. The ReplicaSet's managed pods each carry both labels.

```bash
# 1. Inspect the selector.
kubectl get rs rs-ownership -n lab-07 \
  -o jsonpath='{.spec.selector.matchLabels}'
# {"app":"owned-web","tier":"frontend"}

# 2. List ALL pods with any of those labels and check owners.
kubectl get pods -n lab-07 \
  -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels,OWNER:.metadata.ownerReferences[0].name

# stray-pod has labels {"app":"owned-web"} and OWNER=<none>.
# rs-ownership-xxxxx pods have {"app":"owned-web","tier":"frontend"} and
#   OWNER=rs-ownership.

# 3. Delete a managed pod and watch it heal.
MANAGED=$(kubectl get pods -n lab-07 -l app=owned-web,tier=frontend \
  -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$MANAGED" -n lab-07
kubectl get rs rs-ownership -n lab-07   # still 3/3 after reconciliation

# 4. stray-pod is still there.
kubectl get pod stray-pod -n lab-07
```

**Why it matters:** A ReplicaSet's selector is an AND of all `matchLabels`.
Missing even one label excludes a pod. The "stray" pod sits in the same
namespace with a similar label but is invisible to the controller — it is never
counted, never healed, and never deleted by it. This selective ownership is how
multiple controllers coexist in the same namespace without fighting.

### Hard Challenge 2 — Selector and Adoption

> `adopt-me` carries labels `{app: owned-web, tier: frontend}` — the FULL
> selector of `rs-ownership`. Since it was a bare pod with no controller-
> ownerReference, the ReplicaSet adopts it immediately.

```bash
# Check adopt-me's owner.
kubectl get pod adopt-me -n lab-07 \
  -o jsonpath='{.metadata.ownerReferences[0].kind} {.metadata.ownerReferences[0].name}'
# ReplicaSet rs-ownership

# The ReplicaSet's desired count is 3. After adopting adopt-me, the controller
# has 4 pods that match its selector — it terminates one to return to 3.
kubectl get rs rs-ownership -n lab-07
# DESIRED=3, CURRENT=3, READY=3

kubectl get pods -n lab-07 -l app=owned-web,tier=frontend \
  -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].name
# adopt-me is listed and its OWNER is rs-ownership.
```

**Why it matters:** Kubernetes documentation states that a bare pod (no
ownerReference or non-controller one) matching a ReplicaSet's selector is
"immediately acquired." This is by design: it prevents unmanaged pods from
accumulating alongside a controller. However, acquiring a pod counts toward the
desired total, so if the controller already has enough replicas, it may terminate
one of its own to stay at the declared count. This behavior can surprise you in
production if a standalone pod accidentally matches a controller's selector.

### Hard Challenge 3 — Replica Count Forensics

> `rs-forensics` has a pod template requesting `900Gi` of memory — no node can
> satisfy that. Pods stay `Pending` indefinitely, so `readyReplicas` is 0 while
> `spec.replicas` is 3.

```bash
# 1. Diagnose the gap.
kubectl get rs rs-forensics -n lab-07
# DESIRED=3, CURRENT=3, READY=0

kubectl get pods -n lab-07 -l app=rs-forensics
# All Pending

kubectl describe pod -l app=rs-forensics -n lab-07 | grep -A5 Events
# Warning  FailedScheduling ... Insufficient memory.
```

A ReplicaSet's pod template is immutable in practice (you cannot patch
`spec.template` on an existing RS). The fix is to delete the RS and recreate it
with a reasonable memory request:

```bash
kubectl delete rs rs-forensics -n lab-07

cat <<'YAML' | kubectl apply -n lab-07 -f -
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: rs-forensics
  labels:
    app: rs-forensics
spec:
  replicas: 3
  selector:
    matchLabels:
      app: rs-forensics
  template:
    metadata:
      labels:
        app: rs-forensics
    spec:
      containers:
      - name: web
        image: nginx:1.25
        resources:
          requests:
            memory: "64Mi"
YAML

kubectl get rs rs-forensics -n lab-07   # DESIRED=3, READY=3
```

**Why it matters:** When pods request more resources than any node provides, they
remain `Pending` forever. The controller keeps trying (creating new pods after
evictions/deletions) but can never reconcile. The diagnostic path is: check
`readyReplicas` vs `spec.replicas`, find `Pending` pods, read their scheduling
events. Unlike a Deployment (where you can change the template and trigger a
rollout), a ReplicaSet's template is effectively fixed once created — the only
remedy is delete-and-recreate. This limitation is the main reason real-world
workloads use Deployments, not bare ReplicaSets.
