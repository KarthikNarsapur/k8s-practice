# Lab 03 — Solution

> Spoiler. Only read this after attempting the challenge.

All objects target the lab namespace `lab-03`.

### 1. Manifest for the multi-container Pod
Save as `web.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: lab-03
spec:
  containers:
    - name: server
      image: nginx:1.25
      ports:
        - containerPort: 80
    - name: sidecar
      image: busybox:1.36
      command: ["sleep", "3600"]
```

### 2. Apply it
```bash
kubectl apply -f web.yaml
kubectl get pod web -n lab-03 -w        # wait for 2/2 Running
```

### 3. Read one container's logs
```bash
kubectl logs web -n lab-03 -c server
```
Without `-c`, kubectl must guess the container and will error when there is
more than one.

### 4. Exec into the sidecar and prove the shared network
```bash
kubectl exec -it web -n lab-03 -c sidecar -- sh
# inside the sidecar:
wget -qO- localhost:80 | head -n1     # reaches nginx in the 'server' container
exit
```
Both containers share the Pod's network namespace, so the sidecar reaches
nginx on `localhost:80` — no Service needed.

### Init containers (background concept)
An init container runs to completion *before* the app containers start. It is
declared under `spec.initContainers`. Example use: wait for a dependency or
seed a shared volume. Not required for this lab, but worth knowing:
```yaml
spec:
  initContainers:
    - name: wait
      image: busybox:1.36
      command: ["sh", "-c", "echo init done"]
```

### Why it matters
A Pod is the atomic unit Kubernetes schedules. Containers in the same Pod share
the network namespace (localhost) and can share volumes, which is the basis for
the sidecar pattern. `-c` is how you address one container within a Pod.
