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

The setup also deploys three additional resources for the hard challenges:
- `multi-rev` — rolled through 4 revisions (nginx:1.24 → 1.25 → bad →
  recovered). Learner investigates the revision history.
- `rev-inspect` — starts healthy (nginx:1.25), then broken with a bad image.
  Learner rolls back.
- `post-rbk` — goes nginx:1.24 → nginx:1.25 → broken. Learner rolls back and
  verifies the full recovery.

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

### Hard Challenges

**HC1 — Multi-Revision Forensics**

The Deployment `multi-rev` has been through 4 revisions:
- Revision 1: nginx:1.24
- Revision 2: nginx:1.25
- Revision 3: a bad image (stuck rollout, then undone)
- Revision 4: recovered (the undo created this)

Your task:

1. Use `kubectl rollout history` to list all revisions of `multi-rev`.
2. Inspect individual revisions (`--revision=N`) to determine which image each
   used.
3. Confirm the Deployment is currently healthy and identify which image it is
   running.
4. Understand that the undo from revision 3 created revision 4, and that
   revision 4 matches a previous healthy template.

**HC2 — Rollback Investigation**

The Deployment `rev-inspect` started at nginx:1.25 (healthy, 3 replicas), then
was broken by setting a nonexistent image. The rollout is stuck. Your task:

1. Inspect the rollout history and ReplicaSets to understand the state.
2. Identify the healthy revision from the history.
3. Roll back to the healthy revision so all 3 replicas are available again.

**HC3 — Post-Rollback Verification**

The Deployment `post-rbk` went through three stages:
- Revision 1: nginx:1.24 (healthy)
- Revision 2: nginx:1.25 (healthy)
- Revision 3: nginx:nope (broken — stuck rollout)

Your task:

1. Roll back to recover the Deployment.
2. After rolling back, verify the full state:
   - Check the current image in the pod template.
   - Confirm all replicas are available.
   - Identify which ReplicaSet is active and that its pods match the expected
     template.

## 5. Expected Outcome

- Deployment `rbk` in `lab-10` reports all 3 replicas available.
- The container image is a valid nginx image (NOT `nginx:doesnotexist-9.9`).
- You understand that the bad rollout created a second revision, and that the
  rollback either restored revision 1 or created a new revision matching it.
- **HC1**: `multi-rev` is healthy on a valid nginx image with all 3 replicas
  available. You can explain the 4-revision history.
- **HC2**: `rev-inspect` is healthy on a valid nginx image (not the broken tag)
  with all 3 replicas available.
- **HC3**: `post-rbk` is healthy on a valid nginx image (not `nginx:nope`) with
  all 3 replicas available. You have verified the active RS and pod template.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 10
```

Passes when:
- Deployment `rbk` in `lab-10` has `availableReplicas == spec.replicas`.
- The Deployment's container image is a valid nginx image and is not the broken
  tag.
- `deployment/multi-rev` has all desired replicas available and is running a
  valid nginx image (not `nginx:doesnotexist-bad`).
- `deployment/rev-inspect` has all desired replicas available and is running a
  valid nginx image (not `nginx:doesnotexist-broken`).
- `deployment/post-rbk` has all desired replicas available and is running a
  valid nginx image (not `nginx:nope`).

## 7. Optional Hints

- `kubectl rollout history deployment/rbk` lists every revision; add
  `--revision=N` to see the pod template for a specific one.
- A RollingUpdate keeps old pods serving while the new (broken) pods fail, which
  is why the rollout "hangs" rather than causing an outage.
- There is a dedicated `kubectl rollout` subcommand that reverts to the previous
  revision without you having to retype the old image.
- HC1: `rollout history --revision=N` shows the pod template for each revision,
  including the image. Compare them to understand the lifecycle.
- HC2: `kubectl get rs -l app=rev-inspect -o wide` shows replica counts and
  images for both ReplicaSets — the healthy one has pods, the broken one is
  stuck.
- HC3: After rolling back, use `kubectl get deploy post-rbk -o yaml` to confirm
  the active template matches what you expect.

## 8. Troubleshooting

- Rollout status never returns → that is expected while the bad image is set;
  press Ctrl-C and inspect the pods instead.
- `describe pod` shows `ErrImagePull` / `ImagePullBackOff` → the kubelet cannot
  pull `nginx:doesnotexist-9.9`; the tag simply does not exist in the registry.
- After rollback the pods are still terminating → give the ReplicaSet a few
  seconds and re-check `kubectl -n lab-10 get pods`.
- HC2/HC3: if pods are still in ImagePullBackOff after the undo, the undo may
  not have completed yet. Run `kubectl rollout status` to wait.

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 10     # deletes the lab-10 namespace, starts fresh
./scripts/lab-destroy.sh 10   # removes lab state entirely
```
