# Lab 02 — Solution

> Spoiler. Only read this after attempting the challenge.

All commands target the lab namespace `lab-02`.

### 1. Discover the API surface
```bash
kubectl api-resources          # NAME, SHORTNAMES, APIVERSION, NAMESPACED, KIND
kubectl api-resources --namespaced=true
kubectl api-versions           # served group/versions, e.g. apps/v1
```

### 2. Explore the Pod schema with explain
```bash
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers            # image lives here
kubectl explain pod.spec.containers.image
kubectl explain pod.metadata.annotations       # pod-level annotations
kubectl explain pod.spec --recursive           # full nested tree
```
- The container image field: `pod.spec.containers[].image`.
- Annotations field: `pod.metadata.annotations`.

### 3. Create kb-pod imperatively
```bash
kubectl run kb-pod --image=nginx:1.25 -n lab-02
```
`kubectl run` creates a single Pod imperatively — no YAML file required.

### 4. Inspect it three ways
```bash
kubectl get pod kb-pod -n lab-02 -o wide     # shows NODE and IP
kubectl get pod kb-pod -n lab-02 -o yaml     # full object as stored in etcd
kubectl describe pod kb-pod -n lab-02        # human-readable + Events
```
- `-o wide`: extra columns (node, pod IP) in a table.
- `-o yaml`: the complete API object, including status.
- `describe`: formatted summary plus the Events timeline (great for debugging).

### 5. Add the required annotation
```bash
kubectl annotate pod kb-pod -n lab-02 lab02/done=yes
# add --overwrite if it already exists
kubectl get pod kb-pod -n lab-02 -o jsonpath='{.metadata.annotations.lab02/done}'
```

### Bonus — generate a manifest without applying it
```bash
kubectl create deployment demo --image=nginx:1.25 --dry-run=client -o yaml
```
`--dry-run=client` builds the object locally and prints it; nothing is sent to
the API server. This is the standard way to scaffold YAML.

### Why it matters
`get`, `describe`, and `explain` are the three commands you will reach for
constantly. `explain` means you rarely need to leave the terminal to look up a
field, and `--dry-run=client -o yaml` turns imperative commands into a manifest
starting point.
