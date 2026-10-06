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

The setup also deploys three additional resources for the hard challenges below:
- `trace-app` — rolled from nginx:1.24 → nginx:1.25 (two ReplicaSets).
- `tmpl-change` — nginx:1.25 with an env var patched in (two ReplicaSets).
- `broken-deploy` — nginx:1.25 but with an impossible memory request (pods
  Pending).

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

### Hard Challenges

**HC1 — Deployment Controller Forensics**

The Deployment `trace-app` was created at nginx:1.24 and then rolled forward to
nginx:1.25, leaving **two** ReplicaSets. Your task:

1. List all ReplicaSets owned by `trace-app` and determine which is the
   **active** one (holding the running pods) and which is the **old** one
   (scaled to 0).
2. Trace the full ownership chain: Deployment → active RS → Pods. Use
   `ownerReferences` and `pod-template-hash` labels to prove the link.
3. Confirm the old RS exists but has 0 replicas.

**HC2 — Template Change Investigation**

The Deployment `tmpl-change` was created at nginx:1.25 with 2 replicas, then
an environment variable was added to its pod template. This produced a second
ReplicaSet. Your task:

1. List both ReplicaSets and compare their pod templates (hint: use
   `-o yaml` or `-o jsonpath` on each RS).
2. Identify **what changed** between the two templates that caused Kubernetes to
   create a new RS.
3. Confirm all 2 replicas are available on the latest RS.

**HC3 — ReplicaSet/Deployment Mismatch**

The Deployment `broken-deploy` (nginx:1.25, 3 replicas) was deployed, but its
pods are stuck in `Pending`. Your task:

1. Investigate why the pods cannot be scheduled. Check pod events and the pod
   spec for anything unusual.
2. Fix the problem so that all 3 replicas become `Ready` and available.

## 5. Expected Outcome

- `deployment/app` reports `3/3` ready and `3` available.
- Exactly **one** ReplicaSet exists, named `app-<hash>`, owned by the
  Deployment, with `3` ready pods.
- Three pods named `app-<hash>-<suffix>` are `Running`.
- **HC1**: `trace-app` has 2 ReplicaSets — the active one (3 ready pods,
  nginx:1.25) and the old one (0 replicas, nginx:1.24). The ownership chain is
  fully traceable.
- **HC2**: `tmpl-change` has 2 ReplicaSets — the newer one includes the
  environment variable. All 2 replicas are available.
- **HC3**: `broken-deploy` has all 3 replicas available after you fix the
  resource request.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 08
```

Passes when:
- `deployment/app` exists in `lab-08` with `status.availableReplicas == 3`.
- Exactly one ReplicaSet is owned by `deployment/app`.
- That ReplicaSet has `status.readyReplicas == 3`.
- `deployment/trace-app` has image `nginx:1.25`, owns 2 ReplicaSets, and has 3
  available replicas.
- `deployment/tmpl-change` owns 2 ReplicaSets and has 2 available replicas.
- `deployment/broken-deploy` has all desired replicas available (you fixed it).

## 7. Optional Hints

- `kubectl create deployment --help` shows `--image` and `--replicas`.
- The ReplicaSet name suffix is a hash of the pod template — remember it; it
  changes when the template changes (that fact matters in Lab 09).
- `kubectl describe deploy` summarizes the managed ReplicaSet under
  `NewReplicaSet`.
- HC1: `kubectl get rs -n lab-08 -l app=trace-app -o wide` shows replica counts
  for both ReplicaSets side by side.
- HC2: Compare the pod templates of both RS objects using
  `kubectl get rs <name> -n lab-08 -o yaml` and look for env differences.
- HC3: `kubectl describe pod` on a Pending pod shows scheduling events — look
  for resource-related reasons.

## 8. Troubleshooting

- Only 1 replica appears → the default for `kubectl create deployment` is 1;
  set `--replicas=3` (or `kubectl scale` afterwards).
- Pods `Pending` → `kubectl describe pod` and check scheduling/capacity events.
- Wrong image → `kubectl describe deploy app -n lab-08` shows the container
  image; use `kubectl set image` or recreate.
- Multiple ReplicaSets appear → you likely changed the pod template; a fresh
  Deployment with no updates should own exactly one.
- HC3 pods stuck Pending → the pod spec requests more resources than any node
  can provide. Think about what you can change in the pod template.

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 08     # deletes the lab-08 namespace and starts fresh
./scripts/lab-destroy.sh 08   # removes lab state entirely
```
