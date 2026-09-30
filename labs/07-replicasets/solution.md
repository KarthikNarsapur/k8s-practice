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
