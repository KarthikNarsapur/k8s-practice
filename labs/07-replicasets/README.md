# Lab 07 — ReplicaSets

Level 2: Workloads

## 1. Objective

Understand the ReplicaSet controller: how it reconciles **desired** state
(`spec.replicas`) against **actual** state (running pods), how it self-heals by
recreating deleted pods, and how it claims pods through label selectors and
`ownerReferences`. By the end you will be able to scale a ReplicaSet, watch it
recover from a deleted pod, and explain the owner/child relationship in a pod's
manifest.

## 2. Prerequisites

- The cluster is deployed (`terraform apply`) and all nodes are `Ready`.
- You can open an SSM session to the control-plane node (see main README).
- Completed: Labs 01–06 (Pods, labels, and basic `kubectl` navigation).

## 3. Environment Setup

```bash
./scripts/lab-start.sh 07
```

This deploys a ReplicaSet named `rs-web` (image `nginx:1.25`, `replicas: 2`,
selector `matchLabels: app=rs-web`) into namespace `lab-07`.

The setup also deploys additional resources for the hard challenges:
- `rs-ownership` — a ReplicaSet (3 replicas, selector `app=owned-web,
  tier=frontend`) plus two standalone pods: `stray-pod` (missing a selector
  label) and `adopt-me` (all labels matching the selector).
- `rs-forensics` — a ReplicaSet (3 replicas) whose pods cannot be scheduled.

## 4. Challenge

Work entirely within namespace `lab-07`.

1. Confirm the starting state: two pods owned by `rs-web`.
   ```bash
   kubectl get rs,pods -n lab-07 -o wide
   ```
2. **Scale** the ReplicaSet to **4** replicas using the `kubectl scale` verb
   (do not edit YAML by hand).
3. In a second terminal, watch the pods live:
   ```bash
   kubectl get pods -n lab-07 -w
   ```
   Then **delete one pod** and observe the ReplicaSet immediately create a
   replacement to restore the desired count. Note the new pod's name and age.
4. Inspect the **ownerReferences** of any pod and confirm it points back to
   `rs-web`:
   ```bash
   kubectl get pod <pod-name> -n lab-07 -o yaml | grep -A6 ownerReferences
   ```
5. Read the controller's activity:
   ```bash
   kubectl describe rs rs-web -n lab-07
   kubectl get events -n lab-07 --sort-by=.lastTimestamp
   ```

### Hard Challenges

**HC1 — ReplicaSet Ownership Investigation**

The ReplicaSet `rs-ownership` manages pods whose labels match
`app=owned-web, tier=frontend`. Two standalone pods also exist: `stray-pod` and
`adopt-me`. Your task:

1. Determine which pods are actually managed by `rs-ownership` (look at
   `ownerReferences` on each pod).
2. Explain why `stray-pod` is NOT managed — compare its labels to the selector.
3. Delete **one managed pod** and observe that the controller recreates it to
   maintain the desired count.
4. Confirm that `stray-pod` is still present — the ReplicaSet does not touch it
   because it does not own it.

**HC2 — Selector and Adoption**

The bare pod `adopt-me` was created with labels that fully satisfy
`rs-ownership`'s selector.

1. Inspect `adopt-me`'s `ownerReferences` — has the ReplicaSet acquired it?
2. Check the ReplicaSet's `desired` / `current` counts — did the adoption
   change them?
3. Explain in your own words **why** a bare pod matching a ReplicaSet's selector
   is adopted, and why an extra adopted pod may cause the ReplicaSet to
   terminate one of its own pods to stay at the desired count.

**HC3 — Replica Count Forensics**

The ReplicaSet `rs-forensics` reports a gap between desired and ready replicas.
Some of its pods are stuck in `Pending`.

1. Investigate using `kubectl get`, `kubectl describe`, and events.
2. Identify the reason pods cannot be scheduled.
3. **Restore the desired state** so that `readyReplicas == spec.replicas`.

## 5. Expected Outcome

- `rs-web` reports `DESIRED=4`, `CURRENT=4`, `READY=4`.
- Deleting a pod is transparently healed: a new pod appears within seconds.
- Each pod carries an `ownerReferences` entry with `kind: ReplicaSet` and
  `name: rs-web` (and `controller: true`).
- **HC1:** `rs-ownership` is at its desired count and `stray-pod` still exists,
  proving the controller only manages pods whose labels satisfy its selector.
- **HC2:** `adopt-me` has an `ownerReferences` entry naming `rs-ownership`,
  proving the ReplicaSet adopted the bare pod.
- **HC3:** `rs-forensics` has `readyReplicas == spec.replicas` after you fix the
  scheduling problem.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 07
```

Passes when:
- `replicaset/rs-web` exists in `lab-07`.
- `spec.replicas == 4`.
- `status.readyReplicas == 4`.
- **HC1:** `rs-ownership` has `readyReplicas == spec.replicas`, and the
  unmanaged `stray-pod` still exists.
- **HC2:** Pod `adopt-me` has `ownerReferences[0].name == rs-ownership`.
- **HC3:** `rs-forensics` has `readyReplicas == spec.replicas` (you fixed it).

## 7. Optional Hints

- `kubectl scale --help` shows the flag that sets `--replicas`.
- Deleting a managed pod does not reduce the desired count — the controller
  reconciles back to it.
- `ownerReferences` is under a pod's `metadata`; `controller: true` marks the
  managing object.
- `kubectl describe rs` shows `Events` at the bottom, including
  `SuccessfulCreate` messages.
- **HC1:** Compare `stray-pod`'s labels with the ReplicaSet's
  `spec.selector.matchLabels` — a pod must satisfy **all** selector labels to be
  managed.
- **HC2:** A bare pod that satisfies a ReplicaSet's selector and has no
  controller-ownerReference is "acquired" immediately. The ReplicaSet then
  considers it toward the desired count.
- **HC3:** `kubectl describe pod` on a Pending pod shows scheduling events.
  Look for resource-related reasons and what the pod template requests.

## 8. Troubleshooting

- Scale command reports "not found" → check you targeted the right resource
  type/name and namespace (`-n lab-07`).
- Pods stuck `Pending` → `kubectl describe pod` and check node capacity /
  scheduling events.
- Pods stuck `ContainerCreating` → image pull may be in progress; check
  `kubectl describe pod` events.
- The `-w` watch never returns to prompt → that is expected; press `Ctrl+C` to
  stop watching.
- HC3: a ReplicaSet's pod template is mutable only through delete-and-recreate
  of the entire RS object. Alternatively, fix just the stuck pods themselves
  (or scale down and recreate with a corrected template).

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 07     # deletes the lab-07 namespace and starts fresh
./scripts/lab-destroy.sh 07   # removes lab state entirely
```
