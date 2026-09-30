# Lab 11 — Solution

> Spoiler. Only read this after attempting the challenge.

### 1. Understand the target node count
```bash
kubectl get nodes -o wide
# Count the nodes a normal pod can land on. By default the control-plane node
# carries a NoSchedule taint (node-role.kubernetes.io/control-plane), so a
# DaemonSet WITHOUT a matching toleration runs only on the worker nodes.
```

### 2. Create the DaemonSet
There is no `kubectl create daemonset` generator, so apply a manifest. From an
SSM session on the control-plane (or any machine with kubectl access):

```bash
cat <<'YAML' | kubectl apply -n lab-11 -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-agent
  labels:
    app: node-agent
spec:
  selector:
    matchLabels:
      app: node-agent
  template:
    metadata:
      labels:
        app: node-agent
    spec:
      containers:
        - name: agent
          image: busybox:1.36
          command: ["sh", "-c", "sleep infinity"]
YAML
```

### 3. Verify one pod per (schedulable) node
```bash
kubectl -n lab-11 get ds node-agent -o wide
# DESIRED and READY should match and equal the number of schedulable nodes.

kubectl -n lab-11 get pods -o wide          # one pod per node, spread out
kubectl -n lab-11 describe ds node-agent    # events, node selector, tolerations
```

### If you WANT it on every node including the control-plane
Add a toleration for the control-plane taint (this changes DESIRED to include
the control-plane node):
```yaml
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
```

### Verify
```bash
./scripts/lab-verify.sh 11
```

### Why it matters
A DaemonSet guarantees exactly one pod copy per matching node — the scheduler
does not choose replica counts, the node set does. As nodes join or leave, the
DaemonSet controller adds/removes pods automatically. Node selectors, node
affinity, and tolerations decide *which* nodes are "matching". This is the
pattern behind log collectors, CNI agents, and node exporters. The verifier
accepts your DaemonSet as long as `desiredNumberScheduled == numberReady` and
that number equals the count of schedulable nodes it computes the same way you
did.
