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
