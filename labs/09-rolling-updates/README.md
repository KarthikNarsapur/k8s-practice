# Lab 09 — Rolling Updates

Level 2: Workloads

## 1. Objective

Understand how a Deployment performs a **rolling update**: how `maxSurge` and
`maxUnavailable` bound the transition, how the old and new ReplicaSets coexist
during the roll, and how to monitor progress with `kubectl rollout status`. By
the end you will be able to change a Deployment's image, watch the controller
migrate pods safely, and read the rollout history.

## 2. Prerequisites

- The cluster is deployed (`terraform apply`) and all nodes are `Ready`.
- You can open an SSM session to the control-plane node (see main README).
- Completed: Lab 08 (Deployments).

## 3. Environment Setup

```bash
./scripts/lab-start.sh 09
```

This deploys a Deployment named `rollme` (image `nginx:1.24`, `replicas: 4`)
with an explicit `RollingUpdate` strategy (`maxSurge: 1`, `maxUnavailable: 1`)
into namespace `lab-09`.

## 4. Challenge

Work entirely within namespace `lab-09`.

1. Confirm the starting state and note the current ReplicaSet:
   ```bash
   kubectl get deploy,rs,pods -n lab-09 -o wide
   kubectl describe deploy rollme -n lab-09 | grep -i strategy -A2
   ```
2. **Roll the Deployment forward** by changing the image from `nginx:1.24` to
   **`nginx:1.25`** (use `kubectl set image` or edit the template).
3. **Immediately** watch the rollout progress:
   ```bash
   kubectl rollout status deploy/rollme -n lab-09
   ```
4. While it rolls (or right after), observe that **two ReplicaSets** exist — the
   old one scaling down, the new one scaling up:
   ```bash
   kubectl get rs -n lab-09 -o wide
   ```
   Relate the transient counts to `maxSurge=1` / `maxUnavailable=1` (never more
   than 5 pods total, never fewer than 3 available).
5. Review the recorded history:
   ```bash
   kubectl rollout history deploy/rollme -n lab-09
   ```

## 5. Expected Outcome

- `deployment/rollme` runs `nginx:1.25` across all 4 replicas.
- `4/4` replicas are `updated` and `available`; `0 unavailable`.
- The old ReplicaSet is scaled to `0`; a new ReplicaSet (new pod-template hash)
  holds all 4 pods.
- `status.observedGeneration` equals `metadata.generation` (the controller has
  fully processed the latest spec).

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 09
```

Passes when:
- `deployment/rollme` exists in `lab-09`.
- `spec.template.spec.containers[0].image == nginx:1.25`.
- `status.availableReplicas == 4` and `status.updatedReplicas == 4`.
- `status.observedGeneration == metadata.generation`.

## 7. Optional Hints

- `kubectl set image deploy/<name> <container>=<image>` updates just the image.
- The container name in `rollme` is `web` — you need it for `set image`.
- `kubectl rollout status` blocks until the rollout finishes (or fails), then
  returns.
- Changing the pod template creates a new ReplicaSet with a new
  `pod-template-hash`; the old one is kept (scaled to 0) for rollback.

## 8. Troubleshooting

- `rollout status` hangs forever → a new pod may be unschedulable or crashing;
  `kubectl get pods -n lab-09` and `kubectl describe pod` on the pending one.
- Image typo → the new pods stay `ImagePullBackOff`; the rollout stalls but does
  not break the running pods (that is what `maxUnavailable` protects). Fix the
  image and the rollout resumes.
- Want to undo a bad roll → `kubectl rollout undo deploy/rollme -n lab-09`.
- Rollout appears "done" but verify fails on generation → give the controller a
  moment; re-run `kubectl rollout status` until it reports success.

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 09     # deletes the lab-09 namespace and starts fresh
./scripts/lab-destroy.sh 09   # removes lab state entirely
```
