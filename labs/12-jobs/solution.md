# Lab 12 — Solution

> Spoiler. Only read this after attempting the challenge.

### Option A — apply a manifest (explicit completions/parallelism)
From an SSM session on the control-plane (or any kubectl-capable host):

```bash
cat <<'YAML' | kubectl apply -n lab-12 -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  completions: 3
  parallelism: 1
  backoffLimit: 4
  template:
    metadata:
      labels:
        app: pi
    spec:
      restartPolicy: Never
      containers:
        - name: pi
          image: busybox:1.36
          command: ["sh", "-c", "echo done"]
YAML
```

### Option B — imperative create, then patch
```bash
kubectl -n lab-12 create job pi \
  --image=busybox:1.36 -- sh -c "echo done"
# The generator makes completions=1; set it to 3:
kubectl -n lab-12 patch job pi --type=merge \
  -p '{"spec":{"completions":3,"parallelism":1}}'
```
(Note: some clusters reject patching `completions` on an existing Job because it
is immutable. If so, delete and re-create with Option A.)

### Watch it run and finish
```bash
kubectl -n lab-12 get jobs -w
# COMPLETIONS should progress 0/3 -> 1/3 -> 2/3 -> 3/3

kubectl -n lab-12 get pods            # three Completed pods, one at a time
kubectl -n lab-12 logs job/pi         # prints 'done'
kubectl -n lab-12 describe job pi     # events, completion mode, backoffLimit
```

### Verify
```bash
./scripts/lab-verify.sh 12
```

### Why it matters
A Job creates pods until a fixed number of successful completions is reached.
`completions` is how many successes you need; `parallelism` is how many pods run
at once; `backoffLimit` bounds retries before the Job is marked Failed. Pods use
`restartPolicy: Never` (or `OnFailure`) — not `Always`, which is only for
long-running controllers. Because `parallelism: 1`, the three completions run
sequentially. `status.succeeded` reaching 3 is what the verifier checks.

---

## Hard Challenge Solutions

> Spoiler. Only read these after attempting the hard challenges. `lab-start.sh`
> pre-deploys `fail-job`, `backoff-job`, and `parallel-job`; for HC1 and HC2 you
> must repair the broken Jobs, and the verifier re-checks all three.

### Hard Challenge 1 — Job Failure Investigation

> `fail-job` runs `sh -c "echo failing; exit 1"`, so every pod exits non-zero
> and no completion is ever recorded.

```bash
# Diagnose first.
kubectl -n lab-12 get job fail-job -o wide
kubectl -n lab-12 get pods -l job-name=fail-job
kubectl -n lab-12 logs job/fail-job                 # prints 'failing'
kubectl -n lab-12 describe job fail-job             # Events + "Pods Statuses"
# Pod container terminates with exit code 1 -> counted as a failure, never a
# success, so status.succeeded stays 0.
```

A Job's pod template is immutable, so patch won't help — delete and recreate:
```bash
kubectl -n lab-12 delete job fail-job
cat <<'YAML' | kubectl apply -n lab-12 -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: fail-job
spec:
  completions: 1
  parallelism: 1
  backoffLimit: 4
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: fail
          image: busybox:1.36
          command: ["sh", "-c", "echo fixed; exit 0"]
YAML

kubectl -n lab-12 get job fail-job   # COMPLETIONS 1/1
```

**Why it matters:** A Job only records a *success* when a pod's container exits
0. A non-zero exit is a failure, no matter how many times it runs. The fix is
not more retries — it is making the command succeed. The investigation path
(logs → pod status → Job events) is the standard batch-debugging loop.

### Hard Challenge 2 — backoffLimit

> `backoff-job` runs `sh -c "exit 1"` with `backoffLimit: 3`. It retries with
> exponential back-off, and once 3 failures accumulate the Job is marked
> `Failed` and stops creating pods.

```bash
# Observe the behavior.
kubectl -n lab-12 get pods -l job-name=backoff-job -w
# Pods appear with growing delays (10s, 20s, 40s...) up to backoffLimit, then
# stop. The Job condition flips to Failed.
kubectl -n lab-12 get job backoff-job -o jsonpath='{.status.conditions}{"\n"}'
kubectl -n lab-12 describe job backoff-job
```

A Failed Job will not resume on its own — recreate it with a working command:
```bash
kubectl -n lab-12 delete job backoff-job
cat <<'YAML' | kubectl apply -n lab-12 -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: backoff-job
spec:
  completions: 1
  parallelism: 1
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: backoff
          image: busybox:1.36
          command: ["sh", "-c", "echo ok; exit 0"]
YAML

kubectl -n lab-12 get job backoff-job   # COMPLETIONS 1/1
```

**Why it matters:** `backoffLimit` is a safety valve: it bounds how many pod
failures Kubernetes tolerates before giving up, so a hopelessly broken Job does
not spin forever. Retries use exponential back-off. Once the limit is hit the
Job is terminal — the only recovery is to recreate it. Tuning `backoffLimit`
trades fast failure against resilience to transient errors.

### Hard Challenge 3 — Parallelism and Completions

> `parallel-job` has `completions: 5`, `parallelism: 3`, and a succeeding
> command — it is already correct; the goal is to observe the counters.

```bash
kubectl -n lab-12 get job parallel-job -o wide          # COMPLETIONS climbs to 5/5
kubectl -n lab-12 get pods -l job-name=parallel-job     # up to 3 at a time
kubectl -n lab-12 describe job parallel-job

# Read the live counters:
kubectl -n lab-12 get job parallel-job \
  -o jsonpath='active={.status.active} succeeded={.status.succeeded} failed={.status.failed}{"\n"}'
# active  = pods running right now (<= parallelism = 3)
# succeeded = completed pods so far (climbs to completions = 5)
# failed  = pods that exited non-zero (0 here)
```

**Why it matters:** `parallelism` and `completions` are independent knobs.
`completions` is *how many successes you need* (5); `parallelism` is *how many
pods may run at once* (3). The controller keeps up to `parallelism` pods active
until `completions` successes accumulate, then stops. `active`, `succeeded`, and
`failed` are the three live counters that tell you exactly where a batch job is
— the basis for monitoring fan-out workloads.
