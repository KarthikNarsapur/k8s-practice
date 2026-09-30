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
