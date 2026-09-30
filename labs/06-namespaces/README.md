# Lab 06 — Namespaces

Level 1: Kubernetes Fundamentals

## 1. Objective

Understand namespaces as the primary mechanism for scoping and isolating
resources within a single cluster, and how a ResourceQuota caps consumption in
a namespace. By the end you will be able to create namespaces, target them
explicitly, set your context's default namespace, and observe a quota
rejecting an over-limit request.

You will practice:

- `kubectl get namespaces` / `kubectl create namespace`
- `--namespace` / `-n` targeting
- Setting the context's default namespace
- `ResourceQuota` and reading it with `kubectl describe`
- Diagnosing a rejected create via `kubectl get events`

## 2. Prerequisites

- The cluster is deployed and all nodes are Ready.
- Completed: Lab 05 (Labels & Selectors).

## 3. Environment Setup

```bash
./scripts/lab-start.sh 06
```

The lab creates its own bookkeeping namespace `lab-06`, but the work happens in
a **new, cluster-scoped namespace you create called `team-x`**. Because
`team-x` lives outside the lab namespace, the lab's `teardown.sh` removes it on
reset/destroy.

## 4. Challenge

1. Create a namespace called `team-x`.
2. In `team-x`, create a `ResourceQuota` that limits the number of pods to
   **2** (the quota's `pods` hard limit = `2`).
3. Create **2** pods (`nginx:1.25`) in `team-x`. They should be admitted.
4. Attempt to create a **3rd** pod in `team-x`. It must be **denied** by the
   quota. Read the rejection message and confirm the reason with
   `kubectl get events -n team-x` and `kubectl describe resourcequota -n team-x`.

> Note: a `pods` quota only counts pods that are not in a terminal state. If a
> pod completes or is deleted, its slot frees up.

## 5. Expected Outcome

- Namespace `team-x` exists.
- `team-x` contains a `ResourceQuota` limiting pods to 2.
- `team-x` has exactly **2** running pods (the 3rd was rejected).
- You have seen the quota rejection message and can explain it.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 06
```

Passes when:
- Namespace `team-x` exists.
- A `ResourceQuota` exists in `team-x`.
- Exactly 2 pods are `Running` in `team-x`.

## 7. Optional Hints

- `kubectl create quota <name> --hard=pods=2 -n team-x` is the fast path.
- The quota must exist **before** you create the pods for the count to be
  enforced from the start.
- When the 3rd create is rejected, the error comes back immediately from the
  API server (admission), and is also visible in namespace events.
- `kubectl config set-context --current --namespace=team-x` saves typing `-n`.

## 8. Troubleshooting

- 3rd pod was admitted → the quota was created after the pods, or its `pods`
  limit isn't 2. `kubectl describe resourcequota -n team-x` shows Used vs Hard.
- Created pods in the wrong namespace → they don't count against `team-x`'s
  quota. Recreate with `-n team-x`.
- `team-x` already exists from a previous attempt → `./scripts/lab-reset.sh 06`
  clears it (teardown deletes `team-x`) and starts fresh.

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 06     # deletes lab-06 AND the team-x namespace, then restarts
./scripts/lab-destroy.sh 06   # removes lab state entirely (incl. team-x)
```
