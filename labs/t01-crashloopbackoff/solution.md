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
