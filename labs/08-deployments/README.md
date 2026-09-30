# Lab 08 — Deployments

Level 2: Workloads

## 1. Objective

Understand how a **Deployment** manages **ReplicaSets**, which in turn manage
pods. By the end you will be able to create a Deployment, identify the
ReplicaSet it generates, and explain the three-layer ownership chain
(Deployment → ReplicaSet → Pod). This layering is what enables controlled
rollouts (next lab).

## 2. Prerequisites

- The cluster is deployed (`terraform apply`) and all nodes are `Ready`.
- You can open an SSM session to the control-plane node (see main README).
- Completed: Lab 07 (ReplicaSets).

## 3. Environment Setup

```bash
./scripts/lab-start.sh 08
```

This lab deploys **no** starting workload. The namespace `lab-08` is created for
you and you will build the Deployment yourself.

## 4. Challenge

Work entirely within namespace `lab-08`.

1. Create a Deployment named **`app`** using image **`nginx:1.25`** with
   **3 replicas**. You may do this imperatively (`kubectl create deployment`)
   or by applying a manifest — your choice.
2. Observe the object chain the Deployment produced:
   ```bash
   kubectl get deploy,rs,pods -n lab-08 -o wide
   ```
   Note the ReplicaSet's name — it is `app-<template-hash>`. That hash comes
   from the pod template.
3. Inspect the Deployment and confirm its status:
   ```bash
   kubectl describe deploy app -n lab-08
   ```
   Look at `Replicas:` (desired/updated/available) and the `NewReplicaSet`
   field.
4. Confirm the ownership chain: the ReplicaSet's `ownerReferences` point to the
   Deployment, and each pod's `ownerReferences` point to the ReplicaSet.
   ```bash
   kubectl get rs -n lab-08 -o yaml | grep -A6 ownerReferences
   ```

## 5. Expected Outcome

- `deployment/app` reports `3/3` ready and `3` available.
- Exactly **one** ReplicaSet exists, named `app-<hash>`, owned by the
  Deployment, with `3` ready pods.
- Three pods named `app-<hash>-<suffix>` are `Running`.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 08
```

Passes when:
- `deployment/app` exists in `lab-08` with `status.availableReplicas == 3`.
- Exactly one ReplicaSet is owned by `deployment/app`.
- That ReplicaSet has `status.readyReplicas == 3`.

## 7. Optional Hints

- `kubectl create deployment --help` shows `--image` and `--replicas`.
- The ReplicaSet name suffix is a hash of the pod template — remember it; it
  changes when the template changes (that fact matters in Lab 09).
- `kubectl describe deploy` summarizes the managed ReplicaSet under
  `NewReplicaSet`.

## 8. Troubleshooting

- Only 1 replica appears → the default for `kubectl create deployment` is 1;
  set `--replicas=3` (or `kubectl scale` afterwards).
- Pods `Pending` → `kubectl describe pod` and check scheduling/capacity events.
- Wrong image → `kubectl describe deploy app -n lab-08` shows the container
  image; use `kubectl set image` or recreate.
- Multiple ReplicaSets appear → you likely changed the pod template; a fresh
  Deployment with no updates should own exactly one.

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 08     # deletes the lab-08 namespace and starts fresh
./scripts/lab-destroy.sh 08   # removes lab state entirely
```
