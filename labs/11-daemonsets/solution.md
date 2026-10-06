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

---

## Hard Challenge Solutions

> Spoiler. Only read these after attempting the hard challenges. The resources
> below (`ssd-agent`, `taint-agent`, `zone-agent`) are pre-deployed by
> `lab-start.sh`; your job is to investigate and explain them, and the verifier
> re-checks their health.

### Hard Challenge 1 — DaemonSet Scheduling Investigation

> Setup labeled exactly one worker node `disk=ssd` and deployed `ssd-agent`
> with `nodeSelector: {disk: ssd}`.

```bash
# Which nodes carry the label the DaemonSet selects?
kubectl get nodes -L disk
kubectl get nodes -l disk=ssd

# The DaemonSet only wants pods on those nodes.
kubectl -n lab-11 get ds ssd-agent -o wide
# DESIRED / CURRENT / READY / UP-TO-DATE / AVAILABLE all equal the number of
# nodes labeled disk=ssd (here: 1).

kubectl -n lab-11 get pods -o wide -l app=ssd-agent   # lands only on the ssd node
kubectl -n lab-11 describe ds ssd-agent               # shows the Node-Selector
```

If `ssd-agent` is unhealthy you can re-apply its manifest (same selector):
```bash
cat <<'YAML' | kubectl apply -n lab-11 -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ssd-agent
  labels:
    app: ssd-agent
spec:
  selector:
    matchLabels:
      app: ssd-agent
  template:
    metadata:
      labels:
        app: ssd-agent
    spec:
      nodeSelector:
        disk: ssd
      containers:
        - name: agent
          image: busybox:1.36
          command: ["sh", "-c", "sleep infinity"]
YAML
```

**Why it matters:** A DaemonSet does not run "one pod per node" unconditionally
— it runs one pod per node *that matches its placement rules*. A `nodeSelector`
narrows the eligible set to nodes carrying the label, so `desiredNumberScheduled`
tracks the labeled-node count, not the cluster size. This is how you target node
pools (SSD-backed nodes, GPU nodes, a specific zone) with a daemon.

### Hard Challenge 2 — Taints and Tolerations

> Setup deployed `taint-agent` *with* a toleration for the control-plane taint,
> so it runs on every node including the control-plane.

```bash
# Inspect the control-plane taint.
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# taint-agent runs everywhere because it tolerates that taint.
kubectl -n lab-11 get ds taint-agent -o wide
# DESIRED == READY == total node count (control-plane included).

kubectl -n lab-11 get pods -o wide -l app=taint-agent   # one pod per node, incl. CP
kubectl -n lab-11 describe ds taint-agent               # shows Tolerations
```

The toleration that makes it land on the control-plane:
```yaml
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
```

**Why it matters:** A taint on a node *repels* pods that do not explicitly
tolerate it. Your original `node-agent` had no toleration, so it skipped the
tainted control-plane and `desired` equalled only the schedulable (worker)
count. `taint-agent` adds a matching toleration, so the control-plane node
becomes eligible and `desired` grows to the full node count. Taints/tolerations
are the mechanism behind "system daemons run everywhere, user workloads stay off
control-plane nodes".

### Hard Challenge 3 — Node Label Change

> Setup labeled all workers `zone=east`, deployed `zone-agent` with
> `nodeSelector: {zone: east}`, then removed `zone=east` from one worker.

```bash
# One worker no longer has zone=east, so its daemon pod was removed.
kubectl get nodes -L zone
kubectl -n lab-11 get ds zone-agent -o wide
# DESIRED dropped by one versus "all workers"; DESIRED == READY.

kubectl -n lab-11 get pods -o wide -l app=zone-agent    # no pod on the unlabeled node
kubectl -n lab-11 describe ds zone-agent                # events show the pod removal
```

To put the pod back (re-add the label — the DaemonSet reconciles automatically):
```bash
# Pick the worker that lost the label and re-add it.
kubectl label node <that-worker> zone=east --overwrite
kubectl -n lab-11 get ds zone-agent -o wide   # DESIRED goes back up
```

**Why it matters:** A DaemonSet is a continuous controller, not a one-shot
placement. It watches nodes and their labels and reconciles its pod set in real
time: label a node into the selector and a pod is added; remove the label and
the pod is deleted. You did not touch the DaemonSet at all — changing a *node*
label was enough to change `desiredNumberScheduled`. This is why node labels are
a live operational lever for daemon placement.
