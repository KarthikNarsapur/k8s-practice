# Lab 06 — Solution

> Spoiler. Only read this after attempting the challenge.

### 1. Create the namespace
```bash
kubectl create namespace team-x
kubectl get namespaces            # team-x should appear
```

### 2. Create the ResourceQuota (pods = 2) — BEFORE creating pods
```bash
kubectl create quota pod-limit --hard=pods=2 -n team-x
kubectl describe resourcequota pod-limit -n team-x
# Used:  pods 0 / Hard: pods 2
```
Equivalent manifest form:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pod-limit
  namespace: team-x
spec:
  hard:
    pods: "2"
```

### 3. Create two pods (admitted)
```bash
kubectl run p1 --image=nginx:1.25 -n team-x
kubectl run p2 --image=nginx:1.25 -n team-x
kubectl get pods -n team-x
kubectl describe resourcequota pod-limit -n team-x   # Used: pods 2 / Hard: pods 2
```

### 4. Attempt a third pod (denied)
```bash
kubectl run p3 --image=nginx:1.25 -n team-x
# Error from server (Forbidden): pods "p3" is forbidden:
#   exceeded quota: pod-limit, requested: pods=1, used: pods=2, limited: pods=2
```
Confirm from the cluster's point of view:
```bash
kubectl get events -n team-x --sort-by=.lastTimestamp | grep -i quota
kubectl describe resourcequota pod-limit -n team-x
```

### Optional — save typing with a default namespace
```bash
kubectl config set-context --current --namespace=team-x
kubectl get pods            # now implicitly -n team-x
# reset it afterwards:
kubectl config set-context --current --namespace=default
```

### Why it matters
Namespaces isolate names and provide a boundary for policy: quotas, limit
ranges, RBAC, and network policy all attach at the namespace level. A
ResourceQuota is enforced at **admission** — the API server rejects the create
outright, which is why the 3rd pod never even reaches scheduling.

### Cleanup
`team-x` is cluster-scoped, so it is removed by this lab's `teardown.sh`:
```bash
./scripts/lab-reset.sh 06     # deletes team-x + lab-06 and restarts
./scripts/lab-destroy.sh 06   # removes lab state entirely
```
