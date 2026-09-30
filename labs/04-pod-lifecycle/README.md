# Lab 04 — Pod Lifecycle

Level 1: Kubernetes Fundamentals

## 1. Objective

Understand how a Pod moves through its lifecycle: the pod **phases**
(`Pending`, `Running`, `Succeeded`, `Failed`), the `restartPolicy`, container
**states** (`Waiting`, `Running`, `Terminated`), and how restarts and
`CrashLoopBackOff` arise. By the end you will be able to read a Pod's status
like a story of what happened to it.

You will practice:

- Watching phase transitions with `kubectl get pod -w`
- Reading container State/Reason and restart counts via `kubectl describe`
- Distinguishing `Completed` vs `CrashLoopBackOff` vs steady `Running`
- Reasoning about `restartPolicy`

## 2. Prerequisites

- The cluster is deployed and all nodes are Ready.
- Completed: Lab 03 (Pods).

## 3. Environment Setup

```bash
./scripts/lab-start.sh 04
```

This lab **does** deploy a starting workload: a Pod named `lifecycle` in
namespace `lab-04`. It runs `sleep 30` and then exits `0`, with
`restartPolicy: Always`. Because it keeps completing successfully and the
policy always restarts it, you will watch it cycle: `Running` → `Completed` →
restart → `Running` again, with an increasing restart count.

## 4. Challenge

Namespace: `lab-04`.

Part A — observe (nothing to submit, but do it):

1. Watch the pre-deployed `lifecycle` pod with `kubectl get pod lifecycle -n lab-04 -w`.
   Record the phase transitions and how the RESTARTS column climbs.
2. `kubectl describe pod lifecycle -n lab-04` — read the container's
   `Last State: Terminated (Reason: Completed, Exit Code: 0)` and the current
   `State`.
3. Explain to yourself why a container that exits `0` still restarts. What
   would change if `restartPolicy` were `OnFailure` or `Never`?

Part B — submit:

4. Create a **new** Pod named `stable` running `nginx:1.25` in `lab-04` that
   stays `Running` (does not exit, does not restart-loop).

## 5. Expected Outcome

- You can explain: `Completed` (a container that exited 0), `CrashLoopBackOff`
  (a container that keeps failing/exiting and is being backed off), and a
  steady `Running` (a long-lived process).
- A Pod `stable` (image `nginx:1.25`) is `Running` in `lab-04` and is **not**
  restart-looping.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 04
```

Passes when:
- Pod `stable` exists in `lab-04` and is in phase `Running`.

## 7. Optional Hints

- `kubectl get pod -w` streams updates until you Ctrl-C.
- The RESTARTS column and `describe`'s `Last State` tell you the container's
  recent history.
- nginx is a long-running foreground server, so it stays `Running` without a
  custom command.
- A container's restart behaviour is governed by the Pod's `restartPolicy`,
  not by the container itself.

## 8. Troubleshooting

- Don't confuse the `lifecycle` pod (meant to cycle) with `stable` (meant to
  stay up) — they are different Pods.
- If `stable` is `CrashLoopBackOff`, you probably gave it a command that
  exits; plain `nginx:1.25` needs no command.
- `stable` stuck in `Pending` → `kubectl describe` and check Events for
  scheduling or image-pull issues.

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 04     # deletes the lab-04 namespace and restarts clean
./scripts/lab-destroy.sh 04   # removes lab state entirely
```
