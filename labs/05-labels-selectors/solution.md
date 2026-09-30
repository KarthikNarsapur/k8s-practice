# Lab 05 — Solution

> Spoiler. Only read this after attempting the challenge.

Namespace: `lab-05`.

### 1. See the labels
```bash
kubectl get pods -n lab-05 --show-labels
```

### 2. Practice selecting subsets
```bash
kubectl get pods -n lab-05 -l env=prod                 # app-a, app-b
kubectl get pods -n lab-05 -l tier=backend             # app-b, app-c
kubectl get pods -n lab-05 -l 'tier=backend,env=prod'  # app-b only (comma = AND)
```
Set-based form works too:
```bash
kubectl get pods -n lab-05 -l 'tier in (backend),env in (prod)'
```

### 3. Confirm the selector matches exactly one, then label the selection
Always check the match count before mutating:
```bash
kubectl get pods -n lab-05 -l 'tier=backend,env=prod'   # expect only app-b
```
Then apply the label to the **selection** (note `-l`, not a pod name):
```bash
kubectl label pods -n lab-05 -l 'tier=backend,env=prod' selected=true
```

### Verify
```bash
kubectl get pods -n lab-05 --show-labels
# app-b should now show selected=true; app-a and app-c should not.
```

### Fixing a mistake
If you labelled the wrong pod, remove the label with the trailing minus:
```bash
kubectl label pod app-a -n lab-05 selected-
```

### Why it matters
Selectors are the glue of Kubernetes: a Service routes to Pods by selector, a
Deployment owns Pods by selector, NetworkPolicies target Pods by selector.
Being able to define a set of objects purely by their labels — and to verify
the set before acting on it — is a core operational skill.
