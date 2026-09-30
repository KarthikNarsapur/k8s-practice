# Lab 04 — Solution

> Spoiler. Only read this after attempting the challenge.

Namespace: `lab-04`.

### Part A — observe the cycling pod
```bash
kubectl get pod lifecycle -n lab-04 -w
# You'll see it go Running -> (container exits 0) -> RESTARTS increments -> Running again.
kubectl describe pod lifecycle -n lab-04
```
In `describe`, look at the container block:
```
State:          Running        # (or Waiting, during backoff)
Last State:     Terminated
  Reason:       Completed
  Exit Code:    0
Restart Count:  3
```

Why does a container that exits `0` keep restarting? Because the Pod's
`restartPolicy` is `Always` — it restarts the container **regardless of exit
code**. Compare:

| restartPolicy | exit 0 (success) | exit non-zero (failure) |
|---------------|------------------|--------------------------|
| `Always`      | restart          | restart                  |
| `OnFailure`   | do NOT restart   | restart                  |
| `Never`       | do NOT restart   | do NOT restart           |

- With `OnFailure`, this pod would run once, exit 0, and land in `Succeeded`.
- With `Never`, same — it would not restart.

### Terminology you should now be able to explain
- **Completed**: the container's process exited `0`. Under a non-`Always`
  policy the Pod phase becomes `Succeeded`.
- **CrashLoopBackOff**: the container repeatedly starts and fails; kubelet adds
  an increasing backoff delay between restarts. It is a *symptom*, not a root
  cause — always read logs/events to find why it exits.
- **Running (steady)**: a long-lived foreground process (like nginx) that never
  exits, so there is nothing to restart.

### Part B — create the stable pod
```bash
kubectl run stable --image=nginx:1.25 -n lab-04
kubectl get pod stable -n lab-04 -o wide
```
nginx runs in the foreground and never exits, so the Pod stays `Running` with
`0` restarts.

### Why it matters
Reading phase + container State + Last State + Restart Count is exactly how you
triage a misbehaving Pod. The `restartPolicy` decides what happens when a
container ends, and `CrashLoopBackOff` is the signal to go read logs.
