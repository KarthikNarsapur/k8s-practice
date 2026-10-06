# Lab 11 — DaemonSets

Level 2: Workloads

## 1. Objective

Understand that a DaemonSet runs exactly one pod copy per matching node, and
that the node set — not a replica count — determines how many pods run. By the
end you will be able to create a DaemonSet, read its status columns, and explain
why a tolerationless DaemonSet skips tainted nodes such as the control-plane.

## 2. Prerequisites

- The cluster is deployed and all nodes are `Ready`.
- You can open an SSM session to the control-plane node (see main README).
- Completed: Lab 10 (Rollbacks) and a basic understanding of pods/labels.

## 3. Environment Setup

```bash
./scripts/lab-start.sh 11
```

This lab deploys **nothing**. You create the DaemonSet yourself in the `lab-11`
namespace.

## 4. Challenge

Work in the `lab-11` namespace.

1. First, see how many nodes exist and which are schedulable for an ordinary
   pod:
   ```bash
   kubectl get nodes -o wide
   kubectl describe node <control-plane-node> | grep -i taint
   ```
2. Create a DaemonSet named `node-agent` in `lab-11` that:
   - uses image `busybox:1.36`,
   - runs the command `sleep infinity` so the pod stays up,
   - has a pod label selector that matches its pod template.
3. Confirm it landed one pod per schedulable node:
   ```bash
   kubectl -n lab-11 get ds node-agent -o wide
   kubectl -n lab-11 get pods -o wide
   kubectl -n lab-11 describe ds node-agent
   ```

Note: there is no `kubectl create daemonset` generator — you must apply a
manifest.

### Hard Challenges

These build on the base lab. `./scripts/lab-start.sh 11` pre-deploys the
resources below (plus a couple of node-label changes). Investigate them in the
`lab-11` namespace with `kubectl -n lab-11 get ds -o wide`.

**HC1 — DaemonSet Scheduling Investigation.** Setup labels exactly one worker
node with `disk=ssd` and deploys a DaemonSet `ssd-agent` whose pod template has
`nodeSelector: {disk: ssd}`.
- Explain why `ssd-agent` runs on some nodes but not others.
- Read its `DESIRED / CURRENT / READY / AVAILABLE` columns and relate the
  desired count to how many nodes carry `disk=ssd`.

**HC2 — Taints and Tolerations.** Setup deploys a DaemonSet `taint-agent` that
*includes* a toleration for the control-plane `NoSchedule` taint, so it runs on
**every** node — workers *and* the control-plane.
- Compare `taint-agent`'s desired count to the total node count.
- Explain how its toleration lets it land on the tainted control-plane node,
  unlike your original tolerationless `node-agent`.

**HC3 — Node Label Change.** Setup labels **all** workers with `zone=east`,
deploys a DaemonSet `zone-agent` with `nodeSelector: {zone: east}`, then
**removes** `zone=east` from one worker.
- Observe that the daemon pod on that node was removed and `DESIRED` dropped by
  one.
- Explain why: a DaemonSet continuously reconciles its pod set against the nodes
  that currently match its selector.

## 5. Expected Outcome

- DaemonSet `node-agent` exists in `lab-11`.
- `DESIRED == READY` and both equal the number of schedulable nodes.
- You can explain why the control-plane node is (or is not) included, based on
  its taint and whether your DaemonSet tolerates it.
- **HC1:** `ssd-agent` has `DESIRED == READY`, and that count equals the number
  of nodes labeled `disk=ssd`.
- **HC2:** `taint-agent` has `DESIRED == READY`, and that count equals the
  **total** node count (control-plane included).
- **HC3:** `zone-agent` has `DESIRED == READY`; after one worker lost
  `zone=east`, its desired count reflects the remaining matching nodes.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 11
```

Passes when:
- DaemonSet `node-agent` in `lab-11` has
  `status.desiredNumberScheduled == status.numberReady`.
- `desiredNumberScheduled` equals the number of schedulable nodes (nodes without
  a `NoSchedule`/`NoExecute` taint), computed from `kubectl get nodes`.
- **HC1:** DaemonSet `ssd-agent` has `desiredNumberScheduled == numberReady`,
  and desired equals the count of nodes labeled `disk=ssd`.
- **HC2:** DaemonSet `taint-agent` has `desiredNumberScheduled == numberReady`,
  and desired equals the total node count (it tolerates control-plane taints).
- **HC3:** DaemonSet `zone-agent` has `desiredNumberScheduled == numberReady`.

## 7. Optional Hints

- `kubectl get ds -o wide` shows DESIRED / CURRENT / READY / UP-TO-DATE columns
  and the container image.
- A DaemonSet pod is placed on a node like any pod: it is repelled by a
  `NoSchedule` taint unless the pod tolerates it.
- The control-plane node normally carries
  `node-role.kubernetes.io/control-plane:NoSchedule`, so a DaemonSet with no
  matching toleration will not run there — and the verifier expects the same.
- **HC1:** A `nodeSelector` constrains the DaemonSet to the intersection of
  "all schedulable nodes" and "nodes carrying that label". If only one node
  carries `disk=ssd`, only one pod is desired.
- **HC2:** A toleration is what lets a pod ignore a matching taint. Without it,
  the scheduler rejects the node; with it, the node becomes eligible.
- **HC3:** Node labels are not immutable — removing a label that a DaemonSet's
  `nodeSelector` depends on causes the controller to delete the pod from that
  node. It is a runtime change; the DaemonSet is not re-created.

## 8. Troubleshooting

- DESIRED is smaller than your total node count → that is normal if some nodes
  are tainted; the verifier counts only schedulable nodes.
- Pods are `CrashLoopBackOff` → busybox exits immediately unless it has a
  long-running command; make sure the command keeps the container alive.
- Pod stuck `Pending` → `kubectl -n lab-11 describe pod <name>` and read the
  Events for scheduling/taint messages.

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 11     # deletes the lab-11 namespace, starts fresh
./scripts/lab-destroy.sh 11   # removes lab state entirely
```
