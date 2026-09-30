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

## 5. Expected Outcome

- `rs-web` reports `DESIRED=4`, `CURRENT=4`, `READY=4`.
- Deleting a pod is transparently healed: a new pod appears within seconds.
- Each pod carries an `ownerReferences` entry with `kind: ReplicaSet` and
  `name: rs-web` (and `controller: true`).

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 07
```

Passes when:
- `replicaset/rs-web` exists in `lab-07`.
- `spec.replicas == 4`.
- `status.readyReplicas == 4`.

## 7. Optional Hints

- `kubectl scale --help` shows the flag that sets `--replicas`.
- Deleting a managed pod does not reduce the desired count — the controller
  reconciles back to it.
- `ownerReferences` is under a pod's `metadata`; `controller: true` marks the
  managing object.
- `kubectl describe rs` shows `Events` at the bottom, including
  `SuccessfulCreate` messages.

## 8. Troubleshooting

- Scale command reports "not found" → check you targeted the right resource
  type/name and namespace (`-n lab-07`).
- Pods stuck `Pending` → `kubectl describe pod` and check node capacity /
  scheduling events.
- Pods stuck `ContainerCreating` → image pull may be in progress; check
  `kubectl describe pod` events.
- The `-w` watch never returns to prompt → that is expected; press `Ctrl+C` to
  stop watching.

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 07     # deletes the lab-07 namespace and starts fresh
./scripts/lab-destroy.sh 07   # removes lab state entirely
```
