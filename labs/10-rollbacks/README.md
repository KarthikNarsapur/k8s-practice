# Lab 10 — Deployment Rollbacks

Level 2: Workloads

## 1. Objective

Learn how Deployments version every change and how to recover from a bad
release. By the end you will be able to read a Deployment's revision history,
recognise a stuck rollout caused by an unpullable image, and roll back to a
previous working revision with a single command.

## 2. Prerequisites

- The cluster is deployed and all nodes are `Ready`.
- You can open an SSM session to the control-plane node (see main README).
- Completed: Lab 02 (Pods) and a basic understanding of Deployments/ReplicaSets.

## 3. Environment Setup

```bash
./scripts/lab-start.sh 10
```

This deploys a healthy Deployment named `rbk` (nginx:1.25, 3 replicas) into the
`lab-10` namespace and waits for it to become available. That state is
**revision 1** — your known-good baseline.

## 4. Challenge

Work in the `lab-10` namespace.

1. Confirm the baseline is healthy and inspect its revision history:
   ```bash
   kubectl -n lab-10 get deployment rbk
   kubectl -n lab-10 rollout history deployment/rbk
   ```
2. **Break the rollout** by updating the container image to a tag that does not
   exist, causing `ImagePullBackOff`:
   ```bash
   kubectl -n lab-10 set image deployment/rbk web=nginx:doesnotexist-9.9
   ```
3. **Observe** the failed rollout. Do not just guess — investigate:
   - `kubectl -n lab-10 rollout status deployment/rbk --timeout=30s` (it will
     not complete).
   - `kubectl -n lab-10 get pods` — find the pods stuck in `ImagePullBackOff`.
   - `kubectl -n lab-10 describe pod <bad-pod>` and read the Events.
   - `kubectl -n lab-10 get events --sort-by=.lastTimestamp`.
4. **Roll back** to the previous revision so the Deployment returns to a healthy
   nginx image and all 3 replicas become available again.

## 5. Expected Outcome

- Deployment `rbk` in `lab-10` reports all 3 replicas available.
- The container image is a valid nginx image (NOT `nginx:doesnotexist-9.9`).
- You understand that the bad rollout created a second revision, and that the
  rollback either restored revision 1 or created a new revision matching it.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 10
```

Passes when:
- Deployment `rbk` in `lab-10` has `availableReplicas == spec.replicas`.
- The Deployment's container image is a valid nginx image and is not the broken
  tag.

## 7. Optional Hints

- `kubectl rollout history deployment/rbk` lists every revision; add
  `--revision=N` to see the pod template for a specific one.
- A RollingUpdate keeps old pods serving while the new (broken) pods fail, which
  is why the rollout "hangs" rather than causing an outage.
- There is a dedicated `kubectl rollout` subcommand that reverts to the previous
  revision without you having to retype the old image.

## 8. Troubleshooting

- Rollout status never returns → that is expected while the bad image is set;
  press Ctrl-C and inspect the pods instead.
- `describe pod` shows `ErrImagePull` / `ImagePullBackOff` → the kubelet cannot
  pull `nginx:doesnotexist-9.9`; the tag simply does not exist in the registry.
- After rollback the pods are still terminating → give the ReplicaSet a few
  seconds and re-check `kubectl -n lab-10 get pods`.

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 10     # deletes the lab-10 namespace, starts fresh
./scripts/lab-destroy.sh 10   # removes lab state entirely
```
