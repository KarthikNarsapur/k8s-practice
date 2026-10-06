# Lab t01 — Solution

> Spoiler. Only read this after attempting the challenge.

## Root cause

The `broken-app` container is defined with:

```yaml
command: ['sh', '-c', 'echo starting; exit 1']
```

That command prints `starting` and then **exits immediately with code 1**. A
container's lifetime is the lifetime of its PID 1 process, so the container
dies the instant that shell exits.

Because the Pod's `restartPolicy` is `Always` (the default for Deployments),
the kubelet restarts the container every time it dies. After repeated rapid
failures the kubelet applies an **exponential back-off** (10s, 20s, 40s … up to
5 minutes) and reports the container state as **`CrashLoopBackOff`**. Nothing
is wrong with the image, the node, or the network — the workload is simply
telling the container to quit as soon as it starts.

## How to see it

```bash
# Pods keep restarting; RESTARTS climbs, STATUS shows CrashLoopBackOff.
kubectl get pods -n lab-t01 -o wide

# Last State: Terminated, Reason: Error, Exit Code: 1, plus BackOff events.
kubectl describe pod -n lab-t01 <pod-name>

# The evidence: the container's own output before it exited.
kubectl logs -n lab-t01 <pod-name> --previous
# -> starting

# The exact command that causes it:
kubectl get deployment broken-app -n lab-t01 \
  -o jsonpath='{.spec.template.spec.containers[0].command}'
# -> ["sh","-c","echo starting; exit 1"]
```

At the runtime level on the node:

```bash
sudo crictl ps -a | grep app        # exited containers with non-zero exit
sudo crictl logs <container-id>      # starting
sudo journalctl -u kubelet | grep -i backoff
```

## Fix

Replace the self-terminating command with one that keeps the main process
alive. Any of the following work.

### Option A — `kubectl patch` (surgical, scriptable)

```bash
kubectl patch deployment broken-app -n lab-t01 --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/command",
   "value":["sh","-c","echo ok; sleep 3600"]}
]'
```

### Option B — `kubectl set` is not available for `command`, so use `edit`

```bash
kubectl edit deployment broken-app -n lab-t01
# change the container command to:
#   command: ['sh', '-c', 'echo ok; sleep 3600']
```

### Option C — apply a corrected manifest

```bash
kubectl apply -n lab-t01 -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
  labels:
    app: broken-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: broken-app
  template:
    metadata:
      labels:
        app: broken-app
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ['sh', '-c', 'echo ok; sleep 3600']
YAML
```

Any of these triggers a new ReplicaSet rollout with a container that stays up.

## Verify

```bash
kubectl rollout status deployment/broken-app -n lab-t01
kubectl get pods -n lab-t01 -o wide
# both pods Running, 1/1 ready, RESTARTS stops climbing.

./scripts/lab-verify.sh t01
```

## Why it matters

`CrashLoopBackOff` is the single most common Pod failure you will meet. The
reflex to build is: **STATUS + RESTARTS → describe (Last State / exit code /
events) → logs --previous → inspect the spec**. Exit code `0` vs non-zero, and
whether the process is *supposed* to be long-lived, tells you whether the app
crashed or was simply never designed to keep running. The same loop applies
whether the cause is a bad command, a missing config/secret, a failing
migration, or an OOM kill.

---

## Hard Challenge Solutions

> Spoiler. Only read these after attempting the hard challenges. `lab-start.sh`
> pre-deploys `config-crash`, `sched-crash`, and `incident-app` (plus
> `incident-svc`). Each has multiple independent faults; the verifier re-checks
> all of them.

### Hard Challenge 1 — CrashLoop + Configuration

> `config-crash` mounts a ConfigMap at `/etc/app` but its command reads
> `/etc/wrong-path/config.txt`. The file is not there, so `cat` fails and the
> container exits — a *configuration* bug, not a scheduling one.

```bash
# The pods are placed, then crash — this is NOT a Pending/scheduling problem.
kubectl -n lab-t01 get pods -l app=config-crash -o wide
# STATUS flaps between Error / CrashLoopBackOff; the pods DID get a node.

kubectl -n lab-t01 logs -l app=config-crash --previous
# cat: can't open '/etc/wrong-path/config.txt': No such file or directory

kubectl -n lab-t01 get deployment config-crash -o yaml | grep -A4 -i volumeMounts
# mountPath: /etc/app   <-- the ConfigMap is mounted here, not /etc/wrong-path
```

Fix: point the command at the real mount path (and keep the process alive).
```bash
kubectl -n lab-t01 patch deployment config-crash --type=json -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/command",
   "value":["sh","-c","cat /etc/app/config.txt && sleep 3600"]}
]'
kubectl -n lab-t01 rollout status deployment/config-crash
```

**Why it matters:** The single most important triage split is *scheduling* vs
*runtime*. `Pending` = not placed (scheduling/resources/affinity). `CrashLoop`
= placed but the container keeps dying (command, config, missing dependency).
Here the pods were scheduled fine; the fault was a config path mismatch that
only `logs --previous` reveals.

### Hard Challenge 2 — CrashLoop + Scheduling

> `sched-crash` has a `nodeSelector: {special-hw: gpu}` that matches no node, so
> pods stay `Pending`. Even if you make them schedulable, the command
> `exit 1` would then crash them — so there are two problems, surfacing in order.

```bash
# First problem: nothing is placed.
kubectl -n lab-t01 get pods -l app=sched-crash
# STATUS: Pending

kubectl -n lab-t01 describe pod -l app=sched-crash | grep -A3 Events
# Warning  FailedScheduling ... node(s) didn't match node selector.
```

Fix step 1 — remove the impossible nodeSelector so pods can be placed:
```bash
kubectl -n lab-t01 patch deployment sched-crash --type=json -p='[
  {"op":"remove","path":"/spec/template/spec/template/spec/nodeSelector"}
]' 2>/dev/null \
 || kubectl -n lab-t01 patch deployment sched-crash --type=json -p='[
  {"op":"remove","path":"/spec/template/spec/nodeSelector"}
]'
```
Now the **second** problem appears — the pods are placed but crash:
```bash
kubectl -n lab-t01 get pods -l app=sched-crash   # now CrashLoopBackOff
kubectl -n lab-t01 logs -l app=sched-crash --previous   # starting
```
Fix step 2 — give it a command that stays up:
```bash
kubectl -n lab-t01 patch deployment sched-crash --type=json -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/command",
   "value":["sh","-c","echo ok; sleep 3600"]}
]'
kubectl -n lab-t01 rollout status deployment/sched-crash
```

**Why it matters:** Problems often stack. A pod can only reach `CrashLoopBackOff`
*after* it is scheduled, so a scheduling fault masks a runtime fault until you
clear it. Recognizing the state progression — `Pending` → (scheduled) →
`CrashLoopBackOff` → (fixed) → `Running` — tells you which problem to attack
first and warns you not to declare victory after the first fix.

### Hard Challenge 3 — Multi-Cause Incident

> `incident-app` has THREE independent faults:
> 1. **Scheduling:** `requests.memory: 900Gi` → pods `Pending`.
> 2. **Container:** command `exit 1` → `CrashLoopBackOff` once schedulable.
> 3. **Selector:** `incident-svc` selects `app=incident-app-TYPO`, which matches
>    no pod → the Service has no endpoints.

```bash
# Investigate the whole incident surface.
kubectl -n lab-t01 get deploy,pods,svc,endpoints -l app=incident-app
kubectl -n lab-t01 describe pod -l app=incident-app | grep -A3 Events
#   Insufficient memory  (FailedScheduling)
kubectl -n lab-t01 get svc incident-svc -o jsonpath='{.spec.selector}{"\n"}'
#   {"app":"incident-app-TYPO"}   <-- does not match the pods
```

Fix all three:
```bash
# (1) schedulable memory + (2) a command that stays up
kubectl -n lab-t01 patch deployment incident-app --type=json -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"32Mi"},
  {"op":"replace","path":"/spec/template/spec/containers/0/command","value":["sh","-c","echo up; sleep 3600"]}
]'
kubectl -n lab-t01 rollout status deployment/incident-app

# (3) correct the Service selector so it matches the pods
kubectl -n lab-t01 patch service incident-svc --type=merge \
  -p '{"spec":{"selector":{"app":"incident-app"}}}'

# Prove it:
kubectl -n lab-t01 get deploy incident-app          # READY 2/2
kubectl -n lab-t01 get endpoints incident-svc       # now lists pod IPs
```

**Why it matters:** Real outages rarely have a single cause. The discipline is
to map the whole failure surface before touching anything — deployment, pods,
events, service, endpoints — then fix each independent fault and *verify end to
end*. A pod that is `Running` but not selected by its Service is still
"unavailable" from a user's point of view. Checking `endpoints` is how you prove
traffic can actually reach the workload, not just that pods happen to be up.
