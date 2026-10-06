# Lab t01 — Troubleshooting: CrashLoopBackOff

Level 10: Troubleshooting

## 1. Objective

A Deployment named `broken-app` has been rolled out for you, but its pods will
not stay up. Your job is to **diagnose why on your own** — nothing here tells
you the cause — and then **fix it** so the Deployment runs stably. By the end
you will have exercised the core Kubernetes debugging loop: `get`, `describe`,
`logs` (including `--previous`), events, and runtime-level inspection with
`crictl` on the node.

## 2. Prerequisites

- The cluster is deployed (`terraform apply`) and all nodes are `Ready`.
- You can open an SSM session to the control-plane node (see main README).
- Completed: Lab 01 (Cluster Architecture) recommended, so you know how to
  reach the node and use `crictl`.

## 3. Environment Setup

```bash
./scripts/lab-start.sh t01
```

This deploys the starting state (a broken `broken-app` Deployment with 2
replicas) into namespace `lab-t01`. Do **not** delete and recreate it — work
with what is there.

## 4. Challenge

The `broken-app` Deployment in namespace `lab-t01` is **not staying up**. Its
pods keep coming and going instead of settling into a healthy `Running` state.

Investigate the live cluster and figure out *why*, then repair it so all
replicas become and remain `Running` and `Ready` with stable (non-increasing)
restart counts.

Work the problem like an operator with no prior knowledge of the app:

1. Look at pod status and how many times each pod has restarted:
   ```bash
   kubectl get pods -n lab-t01 -o wide
   kubectl get pods -n lab-t01 -w
   ```
2. Inspect a pod in detail — its events and its container's last state:
   ```bash
   kubectl describe pod -n lab-t01 <pod-name>
   ```
3. Read what the container actually produced, including the *previous*
   (crashed) instance:
   ```bash
   kubectl logs -n lab-t01 <pod-name>
   kubectl logs -n lab-t01 <pod-name> --previous
   ```
4. Examine exactly what the container is configured to run:
   ```bash
   kubectl get deployment broken-app -n lab-t01 -o yaml
   ```
5. Apply a fix using the live cluster (patch / set / edit) and re-verify.

You decide what the fix is — the verifier only checks that the workload ends up
healthy and stays that way.

### Hard Challenges

`./scripts/lab-start.sh t01` also deploys three additional broken workloads.
Each has **more than one** independent problem. Work them like real incidents:
investigate first, then restore each to a healthy, stable state. The verifier
checks all of them.

**HC1 — CrashLoop + Configuration.** The `config-crash` Deployment keeps
restarting.
- Distinguish an *application/config* failure from a *Kubernetes scheduling*
  failure — are the pods `Pending`, or are they being placed and then dying?
- Use `kubectl logs`, `kubectl describe`, and events to find what the container
  is unable to read, and why.
- Restore it so both replicas are `Running` and stable.

**HC2 — CrashLoop + Scheduling.** The `sched-crash` Deployment is unavailable.
- Determine which problem occurs **first**. The pods will not even be placed
  until one issue is resolved; a second issue surfaces only after that.
- Distinguish between the four states you may see along the way: `Pending`,
  `CrashLoopBackOff`, `Running`, `Completed`.
- Restore it so both replicas are `Running` and stable.

**HC3 — Multi-Cause Incident.**

> "The application `incident-app` is unavailable. Investigate and restore the
> desired state."

That is all the information you get. The deployment and its Service have
multiple independent faults spanning scheduling, the container/runtime, and
labels/selectors. Investigate with `kubectl get`, `describe`, `logs`, `exec`,
and `get events`; fix every cause; and prove the result is healthy — including
that the Service actually selects the running pods.

## 5. Expected Outcome

- `kubectl get deployment broken-app -n lab-t01` shows `READY 2/2`,
  `AVAILABLE 2`.
- `kubectl get pods -n lab-t01` shows both pods `Running` and `1/1` ready.
- Restart counts are low and no longer climbing.
- **HC1:** `config-crash` has all replicas `Running` and stable.
- **HC2:** `sched-crash` has all replicas `Running` and stable (no `Pending`,
  no `CrashLoopBackOff`).
- **HC3:** `incident-app` has all replicas `Running` **and** `incident-svc` has
  at least one endpoint (its selector matches the pods).

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh t01
```

Passes when:
- Deployment `broken-app` has all desired replicas available **and** ready.
- Every `broken-app` pod is in the `Running` phase (no `Waiting` container
  state such as a back-off).
- The maximum container restart count across the pods is low and stable.
- **HC1:** Deployment `config-crash` has all replicas available and every pod
  `Running`.
- **HC2:** Deployment `sched-crash` has all replicas available and every pod
  `Running`.
- **HC3:** Deployment `incident-app` has all replicas available and `Running`,
  and Service `incident-svc` has at least one endpoint.

## 7. Optional Hints

- The pod STATUS column and the RESTARTS column together tell a story — watch
  them change over ~60 seconds with `-w`.
- `kubectl describe pod` shows the container's **Last State**, its exit code,
  and the sequence of events the kubelet recorded.
- `kubectl logs --previous` shows output from the instance that already died,
  which is often the only place the evidence survives.
- Compare the container's declared `command`/`args` against what a
  long-running workload needs in order to keep its main process alive.
- **HC1:** A pod that is `Pending` has not been placed; a pod that is
  `CrashLoopBackOff` was placed and keeps dying. The two call for completely
  different fixes. For a config problem, compare where the volume is *mounted*
  with the path the command actually *reads*.
- **HC2:** Read the pod's scheduling events before worrying about the container.
  A `nodeSelector` that matches no node leaves pods `Pending`. Only once a pod
  is placed can you see whether the container itself also has a problem.
- **HC3:** Treat it as a real incident with an unknown number of causes. Walk
  the layers in order — can the pod be scheduled? does the container stay up?
  does anything select it? — and do not stop at the first fault you fix.

## 8. Troubleshooting

From your workstation (kubectl talks to the API via the lab engine / SSM):

```bash
kubectl get pods -n lab-t01 -o wide
kubectl get events -n lab-t01 --sort-by=.lastTimestamp
kubectl describe pod -n lab-t01 <pod-name>
kubectl logs -n lab-t01 <pod-name>
kubectl logs -n lab-t01 <pod-name> --previous
kubectl get deployment broken-app -n lab-t01 -o yaml
```

From an SSM session on the node the pod is scheduled to, drop below kubectl to
the container runtime:

```bash
# Which node is the pod on?
kubectl get pod -n lab-t01 <pod-name> -o wide

# On that node (SSM session):
sudo crictl ps -a | grep app          # includes exited containers
sudo crictl logs <container-id>        # runtime-level logs
sudo crictl inspect <container-id> | grep -A5 -i state
sudo journalctl -u kubelet --no-pager | tail -40   # kubelet's view of the restarts
```

Common gotchas:
- `crictl` permission denied → prefix with `sudo`.
- `kubectl logs` returns nothing → the container may have already exited; use
  `--previous`, or grab runtime logs with `crictl logs`.
- The pod flips between `Error`/`CrashLoopBackOff`/`Running` — that back-and-forth
  is itself a clue about how the kubelet handles a container that keeps exiting.

## 9. Solution

The full solution is in `solution.md`. Work through section 4 and the
troubleshooting commands first — open it only if you are truly stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh t01     # deletes the lab namespace and redeploys clean broken state
./scripts/lab-destroy.sh t01   # removes lab state entirely
```
