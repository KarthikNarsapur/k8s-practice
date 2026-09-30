# Lab 10 — Solution

> Spoiler. Only read this after attempting the challenge.

### 1. Confirm the healthy baseline (revision 1)
```bash
kubectl -n lab-10 get deployment rbk
kubectl -n lab-10 rollout history deployment/rbk
kubectl -n lab-10 get pods -o wide
```

### 2. Break it — roll out a bad image
```bash
kubectl -n lab-10 set image deployment/rbk web=nginx:doesnotexist-9.9
```

### 3. Observe the failed rollout
```bash
# The rollout status will hang; the new pods can't pull the image.
kubectl -n lab-10 rollout status deployment/rbk --timeout=30s

# See the ImagePullBackOff / ErrImagePull on the new ReplicaSet's pods.
kubectl -n lab-10 get pods
kubectl -n lab-10 describe pod -l app=rbk | sed -n '/Events/,$p'
kubectl -n lab-10 get events --sort-by=.lastTimestamp | tail -20
```
Because the Deployment uses a RollingUpdate strategy with default
`maxUnavailable`/`maxSurge`, the old healthy pods stay up while the new bad
pods fail — the Deployment is stuck partway through the rollout.

### 4. Inspect the revision history
```bash
kubectl -n lab-10 rollout history deployment/rbk
# REVISION 1 = nginx:1.25 (good), REVISION 2 = nginx:doesnotexist-9.9 (bad)

kubectl -n lab-10 rollout history deployment/rbk --revision=1
```

### 5. Roll back to the previous (working) revision
```bash
kubectl -n lab-10 rollout undo deployment/rbk
# or explicitly: kubectl -n lab-10 rollout undo deployment/rbk --to-revision=1

kubectl -n lab-10 rollout status deployment/rbk
kubectl -n lab-10 get deployment rbk
kubectl -n lab-10 get pods
```

### Verify
```bash
./scripts/lab-verify.sh 10
```

### Why it matters
Every Deployment update creates a new ReplicaSet and a new revision. Kubernetes
keeps a bounded history (`spec.revisionHistoryLimit`, default 10) so you can
`rollout undo` to any prior revision instantly. A bad image only takes down the
new pods during a RollingUpdate — the old ones keep serving until the new ones
are healthy, which is exactly why the rollout "hangs" instead of causing an
outage. `rollout undo` is your fast, declarative escape hatch.
