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

### Hard Challenge 1 — Multi-Revision Forensics

> Spoiler. Only read this after attempting the hard challenge.

#### 1. List the full revision history
```bash
kubectl -n lab-10 rollout history deployment/multi-rev
# REVISION  CHANGE-CAUSE
# 1         <none>   (nginx:1.24)
# 2         <none>   (nginx:1.25)
# 3         <none>   (nginx:doesnotexist-bad)
# 4         <none>   (recovered via undo)
```
Note: after an `undo`, Kubernetes may renumber revisions — the previously-good
template reappears as the newest revision, and the duplicate older entry is
dropped. The exact numbers depend on history, so inspect each one.

#### 2. Inspect individual revisions
```bash
kubectl -n lab-10 rollout history deployment/multi-rev --revision=1
# Image: nginx:1.24
kubectl -n lab-10 rollout history deployment/multi-rev --revision=2
# Image: nginx:1.25
kubectl -n lab-10 rollout history deployment/multi-rev --revision=3
# Image: nginx:doesnotexist-bad   <-- the broken one
kubectl -n lab-10 rollout history deployment/multi-rev --revision=4
# Image: nginx:1.25               <-- recovered (matches rev 2 template)
```

#### 3. Confirm current health
```bash
kubectl -n lab-10 get deployment multi-rev \
  -o jsonpath='image={.spec.template.spec.containers[0].image} avail={.status.availableReplicas} desired={.spec.replicas}{"\n"}'
# image=nginx:1.25 avail=3 desired=3
```
If `multi-rev` is somehow still on the bad image, recover it:
```bash
kubectl -n lab-10 rollout undo deployment/multi-rev
kubectl -n lab-10 rollout status deployment/multi-rev
```

### Why it matters
Each image change creates a new revision backed by its own ReplicaSet. You can
read any revision's pod template with `rollout history --revision=N` **without**
applying it — essential for forensics when you need to know what a release
actually contained before you roll back. The `undo` operation re-applies a prior
template as a new revision, so the history grows forward even when you move
backward.

### Hard Challenge 2 — Rollback Investigation

> Spoiler. Only read this after attempting the hard challenge.

#### 1. Inspect the state
```bash
kubectl -n lab-10 get deployment rev-inspect
# READY shows fewer than 3 — the rollout is stuck.

kubectl -n lab-10 rollout history deployment/rev-inspect
# REVISION 1 = nginx:1.25 (good), REVISION 2 = nginx:doesnotexist-broken (bad)

kubectl -n lab-10 get rs -l app=rev-inspect -o wide
# Old RS (nginx:1.25): 3 ready
# New RS (nginx:doesnotexist-broken): 0-1 pods, ImagePullBackOff
```

#### 2. Identify the healthy revision
```bash
kubectl -n lab-10 rollout history deployment/rev-inspect --revision=1
# Image: nginx:1.25  <-- healthy
```

#### 3. Roll back
```bash
kubectl -n lab-10 rollout undo deployment/rev-inspect
# or: kubectl -n lab-10 rollout undo deployment/rev-inspect --to-revision=1

kubectl -n lab-10 rollout status deployment/rev-inspect
kubectl -n lab-10 get deployment rev-inspect
# READY 3/3
```

### Why it matters
Before rolling back, you must know **which** revision to target. The rollout
history plus the per-revision ReplicaSets tell you exactly which template was
healthy. In a multi-revision scenario, blindly undoing could land you on another
broken revision — always confirm the target image first. `--to-revision=N` lets
you jump to a specific known-good revision instead of just the immediately
previous one.

### Hard Challenge 3 — Post-Rollback Verification

> Spoiler. Only read this after attempting the hard challenge.

#### 1. Roll back off the broken image
```bash
kubectl -n lab-10 rollout history deployment/post-rbk
# REVISION 1 = nginx:1.24, REVISION 2 = nginx:1.25, REVISION 3 = nginx:nope (bad)

kubectl -n lab-10 rollout undo deployment/post-rbk
# This returns to revision 2 (nginx:1.25) — the last healthy template.

kubectl -n lab-10 rollout status deployment/post-rbk
```

#### 2. Verify the recovered image
```bash
kubectl -n lab-10 get deployment post-rbk \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
# nginx:1.25   (NOT nginx:nope)
```

#### 3. Verify all replicas are available
```bash
kubectl -n lab-10 get deployment post-rbk \
  -o jsonpath='avail={.status.availableReplicas} desired={.spec.replicas}{"\n"}'
# avail=3 desired=3
```

#### 4. Verify the active ReplicaSet and its pods
```bash
# Which RS is active (replicas > 0)?
kubectl -n lab-10 get rs -l app=post-rbk -o wide
# The RS running nginx:1.25 holds the 3 pods; the nginx:nope RS is scaled to 0.

# Confirm the pods' image matches the recovered template
kubectl -n lab-10 get pods -l app=post-rbk \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[0].image}{"\n"}{end}'
# Each pod runs nginx:1.25
```

### Why it matters
Rolling back is only half the job — you must **verify** the recovery landed
where you expect. A thorough post-rollback check covers three layers: the
Deployment's pod template (what *should* run), the active ReplicaSet (what the
controller scaled up), and the actual pods (what is *really* running). If all
three agree on a healthy image and the replica counts match, the rollback is
truly complete. This verification discipline prevents "it says rolled back but
is still broken" incidents.
