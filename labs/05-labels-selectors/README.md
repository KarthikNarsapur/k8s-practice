# Lab 05 — Labels & Selectors

Level 1: Kubernetes Fundamentals

## 1. Objective

Master labels and label selectors — the mechanism Kubernetes uses to group and
target objects (Services, Deployments, and almost everything else rely on it).
By the end you will be able to query objects by label and mutate objects
selected purely by a label query.

You will practice:

- `kubectl get pods --show-labels`
- Equality and set-based selectors: `-l key=value`, `-l 'key in (a,b)'`
- Combining selectors with a comma (logical AND)
- `kubectl label` applied to a selection rather than a named object

## 2. Prerequisites

- The cluster is deployed and all nodes are Ready.
- Completed: Lab 03 (Pods).

## 3. Environment Setup

```bash
./scripts/lab-start.sh 05
```

This lab deploys three pods (all `nginx:1.25`) into namespace `lab-05` with
different labels:

| Pod     | Labels                          |
|---------|---------------------------------|
| `app-a` | `tier=frontend`, `env=prod`     |
| `app-b` | `tier=backend`,  `env=prod`     |
| `app-c` | `tier=backend`,  `env=dev`      |

## 4. Challenge

Namespace: `lab-05`.

1. List all three pods **with their labels** and confirm the table above.
2. Practice selecting subsets:
   - all `prod` pods
   - all `backend` pods
   - `backend` **and** `prod` pods
3. The task: add the label `selected=true` to **exactly** the pods matching
   `tier=backend` **AND** `env=prod`. Based on the table that is only `app-b`.

   You must do this by **selecting with a label query**, not by naming `app-b`
   directly. This proves you can operate on a set defined by its labels.

## 5. Expected Outcome

- `app-b` carries `selected=true`.
- `app-a` and `app-c` do **not** carry `selected=true`.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 05
```

Passes when:
- `app-b` has label `selected=true`.
- Neither `app-a` nor `app-c` has label `selected=true`.

## 7. Optional Hints

- `--show-labels` appends a LABELS column to `kubectl get`.
- Multiple selectors separated by a comma are ANDed:
  `-l 'tier=backend,env=prod'`.
- `kubectl label` can target a selection using `-l <selector>` instead of a
  resource name.
- Verify your selector returns exactly one pod *before* you label, so you don't
  accidentally label too many.

## 8. Troubleshooting

- Labeled the wrong pods → remove a label with the minus syntax, e.g.
  `kubectl label pod app-a env-` removes the `env` label (use
  `selected-` to remove `selected`).
- Selector matched more than one pod → tighten it by ANDing both conditions.
- `kubectl label` says "already has a value" → add `--overwrite`.

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 05     # deletes the lab-05 namespace and restarts clean
./scripts/lab-destroy.sh 05   # removes lab state entirely
```
