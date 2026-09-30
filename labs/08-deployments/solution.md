# Lab 08 — Solution

> Spoiler. Only read this after attempting the challenge.

### 1. Create the Deployment
Imperative (simplest):
```bash
kubectl create deployment app --image=nginx:1.25 --replicas=3 -n lab-08
```
Or declaratively:
```bash
cat <<'YAML' | kubectl apply -n lab-08 -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
YAML
```

### 2. Observe the object chain
```bash
kubectl get deploy,rs,pods -n lab-08 -o wide
# deployment.apps/app        3/3     3            3
# replicaset.apps/app-6d8f...   3     3     3
# pod/app-6d8f...-aaaaa   1/1   Running
# pod/app-6d8f...-bbbbb   1/1   Running
# pod/app-6d8f...-ccccc   1/1   Running
```
The Deployment created one ReplicaSet named `app-<hash>`. The `<hash>` is the
`pod-template-hash` label value — a hash of the pod template. The ReplicaSet
created the three pods.

### 3. Inspect the Deployment
```bash
kubectl describe deploy app -n lab-08
# Replicas:  3 desired | 3 updated | 3 total | 3 available | 0 unavailable
# ...
# NewReplicaSet:  app-6d8f... (3/3 replicas created)
```

### 4. Confirm the ownership chain
```bash
kubectl get rs -n lab-08 -o yaml | grep -A6 ownerReferences
#   ownerReferences:
#   - apiVersion: apps/v1
#     kind: Deployment
#     name: app
#     controller: true

POD=$(kubectl get pods -n lab-08 -o jsonpath='{.items[0].metadata.name}')
kubectl get pod "$POD" -n lab-08 -o yaml | grep -A6 ownerReferences
#   ownerReferences:
#   - apiVersion: apps/v1
#     kind: ReplicaSet
#     name: app-6d8f...
#     controller: true
```

### Why it matters
A Deployment does not manage pods directly — it manages **one ReplicaSet per
pod-template revision**. When you change the pod template (image, env, etc.),
the Deployment creates a *new* ReplicaSet and scales it up while scaling the old
one down. That indirection (Deployment → ReplicaSet → Pod) is precisely what
makes rolling updates and rollbacks possible, which is the focus of Lab 09.
