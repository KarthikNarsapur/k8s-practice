# Lab 03 — Pods

Level 1: Kubernetes Fundamentals

## 1. Objective

Understand the Pod as the smallest deployable unit in Kubernetes and why a Pod
can hold more than one container. By the end you will be able to build a
multi-container Pod, reason about shared network/storage, and inspect an
individual container inside a Pod.

You will practice:

- Creating a multi-container Pod
- `kubectl describe pod` to read container status
- `kubectl logs -c <container>` for a specific container
- `kubectl exec -c <container>` into a specific container
- The concept of init containers (background reading)

## 2. Prerequisites

- The cluster is deployed and all nodes are Ready.
- Completed: Lab 02 (kubectl Basics).

## 3. Environment Setup

```bash
./scripts/lab-start.sh 03
```

No workload is deployed for you — you build the Pod yourself in namespace
`lab-03`.

## 4. Challenge

All objects go in namespace `lab-03`.

Create a single Pod named `web` that contains **two containers**:

1. A container named `server` running image `nginx:1.25`.
2. A container named `sidecar` running image `busybox:1.36` with the command
   `sleep 3600`.

Then prove you understand the shared context of a Pod:

- Use `kubectl describe pod web -n lab-03` and identify both containers and
  their states.
- Fetch logs from **only** the `server` container.
- `exec` into **only** the `sidecar` container and confirm it can reach the
  nginx container over `localhost:80` (they share the Pod network namespace).

> A single-container `kubectl run` cannot express two containers, so you will
> need a YAML manifest for this one. That is the point.

## 5. Expected Outcome

- Pod `web` is `Running` in namespace `lab-03` with `2/2` containers ready.
- The two containers are named exactly `server` and `sidecar`.
- You can retrieve logs and exec into each container by name.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 03
```

Passes when:
- Pod `web` exists in `lab-03` and is `Running`.
- Both containers report `ready`.
- The container names are exactly `server` and `sidecar`.

## 7. Optional Hints

- `kubectl explain pod.spec.containers` confirms that `containers` is a list —
  you add a second list entry.
- Without `-c`, `kubectl logs`/`exec` default to the first container (or error
  if ambiguous). Name the container explicitly.
- busybox stays alive only while its command runs — that is why `sleep 3600`
  is used instead of a one-shot command.

## 8. Troubleshooting

- Pod shows `1/2` ready → `kubectl describe pod web -n lab-03` and check each
  container's State/Reason. A crashed sidecar usually means the command exited.
- `kubectl exec` says "container not found" → pass the exact name with `-c`.
- Sidecar in `CrashLoopBackOff` → confirm the command keeps the container alive
  (a bare `busybox` with no long-running command exits immediately).

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 03     # deletes the lab-03 namespace and restarts clean
./scripts/lab-destroy.sh 03   # removes lab state entirely
```
