# Lab 09 — Solution

> Spoiler. Only read this after attempting the challenge.

### 1. Confirm the starting state
```bash
kubectl get deploy,rs,pods -n lab-09 -o wide
# deployment.apps/rollme   4/4   4   4   ...   nginx:1.24
# replicaset.apps/rollme-<hashA>   4   4   4   ...
kubectl describe deploy rollme -n lab-09 | grep -i strategy -A2
# StrategyType:  RollingUpdate
# RollingUpdateStrategy:  1 max unavailable, 1 max surge
```

### 2. Roll forward to nginx:1.25
The container is named `web`:
```bash
kubectl set image deploy/rollme web=nginx:1.25 -n lab-09
# deployment.apps/rollme image updated
```
(Equivalent: `kubectl edit deploy rollme -n lab-09` and change the image.)

### 3. Watch the rollout
```bash
kubectl rollout status deploy/rollme -n lab-09
# Waiting for deployment "rollme" rollout to finish: 1 out of 4 new replicas...
# ...
# deployment "rollme" successfully rolled out
```

### 4. Two ReplicaSets during the transition
```bash
kubectl get rs -n lab-09 -o wide
# rollme-<hashA>   0   0   0   ...   nginx:1.24   (old, scaling to 0)
# rollme-<hashB>   4   4   4   ...   nginx:1.25   (new, scaled up)
```
With `maxSurge=1` and `maxUnavailable=1`, at any instant the total pods stay
≤ 5 (4 desired + 1 surge) and available pods stay ≥ 3 (4 desired − 1
unavailable). The controller adds a new-version pod, waits for it Ready, removes
an old-version pod, and repeats.

### 5. Rollout history
```bash
kubectl rollout history deploy/rollme -n lab-09
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>
kubectl rollout history deploy/rollme -n lab-09 --revision=2
```

### Confirm final state
```bash
kubectl get deploy rollme -n lab-09 -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
# nginx:1.25
kubectl get deploy rollme -n lab-09 \
  -o jsonpath='gen={.metadata.generation} observed={.status.observedGeneration} avail={.status.availableReplicas} updated={.status.updatedReplicas}{"\n"}'
```

### Rolling back (bonus)
```bash
kubectl rollout undo deploy/rollme -n lab-09            # back to previous revision
kubectl rollout undo deploy/rollme -n lab-09 --to-revision=1
```

### Why it matters
A Deployment rolls out by shifting replicas from the old ReplicaSet to a new one
created for the new pod template. `maxSurge`/`maxUnavailable` are the safety
rails that keep the service available throughout. `kubectl rollout status`
returns success only when `updatedReplicas == replicas` and all are available,
and the Deployment's `status.observedGeneration` catches up to
`metadata.generation` once the controller has fully reconciled the change.
Because the old ReplicaSet is retained (scaled to 0), `kubectl rollout undo`
gives you an instant, template-accurate rollback.

### Hard Challenge 1 — Failed Rolling Update

> Spoiler. Only read this after attempting the hard challenge.

#### 1. Investigate the stuck rollout
```bash
kubectl -n lab-09 rollout status deployment/rollme-fail --timeout=30s
# The rollout will not complete — it is stuck waiting for new pods.

kubectl -n lab-09 get pods -l app=rollme-fail
# Some pods are Running (old RS), some are ImagePullBackOff (new RS).

kubectl -n lab-09 describe pod -l app=rollme-fail | sed -n '/Events/,$p'
# Events show: Failed to pull image "nginx:doesnotexist-99.99"

kubectl -n lab-09 get rs -l app=rollme-fail -o wide
# Old RS: 2-3 pods running nginx:1.25
# New RS: 1-2 pods failing at nginx:doesnotexist-99.99
```

#### 2. Recover via rollback
```bash
kubectl -n lab-09 rollout undo deployment/rollme-fail
# deployment.apps/rollme-fail rolled back
```
Or explicitly set the image back:
```bash
kubectl -n lab-09 set image deployment/rollme-fail web=nginx:1.25
```

#### 3. Confirm recovery
```bash
kubectl -n lab-09 rollout status deployment/rollme-fail
kubectl -n lab-09 get deploy rollme-fail
# READY 3/3
```

### Why it matters
A RollingUpdate with default parameters protects the running service: the old
pods keep serving while the new (broken) ones fail. The rollout "hangs" instead
of causing an outage. `rollout undo` is the fast escape hatch — it restores the
previous RS template and scales it back up. This is the same pattern you will
use in production incident response: observe the stuck rollout, identify the bad
image in events, and undo.

### Hard Challenge 2 — maxSurge/maxUnavailable

> Spoiler. Only read this after attempting the hard challenge.

#### 1. Roll forward
```bash
kubectl -n lab-09 set image deployment/surge-test web=nginx:1.25
```

#### 2. Watch the rollout with zero unavailability
```bash
kubectl -n lab-09 rollout status deployment/surge-test
```
During the rollout, observe that available pods never drops below 6:
```bash
kubectl -n lab-09 get rs -l app=surge-test -o wide --watch
# The new RS scales up 2 at a time (maxSurge=2), reaching up to 8 total pods.
# The old RS only scales down once new pods are Ready, so available stays ≥ 6.
```

#### 3. Confirm final state
```bash
kubectl -n lab-09 get deploy surge-test
# READY 6/6

kubectl -n lab-09 get deploy surge-test \
  -o jsonpath='image={.spec.template.spec.containers[0].image} avail={.status.availableReplicas} updated={.status.updatedReplicas}{"\n"}'
# image=nginx:1.25 avail=6 updated=6
```

### Why it matters
`maxUnavailable=0` guarantees **zero downtime** during a rolling update — the
controller will not remove a single old pod until a new one is Ready. The cost
is extra capacity: `maxSurge=2` means 2 extra pods running temporarily. This is
the recommended strategy for production services where availability matters more
than resource cost during deploys. Understanding these two knobs lets you tune
the speed vs. safety tradeoff.

### Hard Challenge 3 — Rollout Availability Investigation

> Spoiler. Only read this after attempting the hard challenge.

#### 1. Diagnose the problem
```bash
kubectl -n lab-09 get deploy avail-check
# READY 0/3 — no pods are available.

kubectl -n lab-09 get pods -l app=avail-check
# All pods show ImagePullBackOff or ErrImagePull.

kubectl -n lab-09 describe pod -l app=avail-check | sed -n '/Events/,$p'
# Failed to pull image "nginx:1.25-nonexistent": ... not found
```
This is an **image pull failure** — the tag `1.25-nonexistent` does not exist on
Docker Hub. It is not a scheduling issue (no `FailedScheduling` event) and not a
readiness probe failure (the container never starts).

#### 2. Fix the image
```bash
kubectl -n lab-09 set image deployment/avail-check web=nginx:1.25
```

#### 3. Confirm recovery
```bash
kubectl -n lab-09 rollout status deployment/avail-check
kubectl -n lab-09 get deploy avail-check
# READY 3/3
```

### Why it matters
Diagnosing **why** pods are not available is a core operational skill. The three
most common causes are: image pull failure (tag does not exist or registry is
unreachable), scheduling failure (insufficient resources), and readiness probe
failure (container starts but the probe endpoint is wrong). Each has a distinct
signature in pod events. Knowing which one you are looking at determines the
fix: change the image, adjust resources, or fix the probe.
