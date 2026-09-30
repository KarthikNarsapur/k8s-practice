# Lab 01 — Solution

> Spoiler. Only read this after attempting the challenge.

### 1. List nodes / identify control-plane
```bash
kubectl get nodes -o wide
# The control-plane shows ROLES = control-plane.
```

### 2. Static pod manifests
On the control-plane node (SSM session):
```bash
ls -l /etc/kubernetes/manifests/
# etcd.yaml  kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml
```
kubelet watches this directory and runs these as "static pods" — they exist
without the API server needing to schedule them (which is how the API server
itself can start).

### 3. Control-plane containers at the runtime level
```bash
sudo crictl ps | grep -E 'apiserver|controller|scheduler|etcd'
```
The four: `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `etcd`.

### 4. etcd port
```bash
sudo ss -ltnp | grep etcd
# etcd listens on 2379 (client) and 2380 (peer).
```

### 5. kubelet is a systemd service
```bash
systemctl status kubelet
journalctl -u kubelet --no-pager | tail -20
```

### Record the proof
```bash
CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')
kubectl label node "$CP" lab01/investigated=true --overwrite
```

### Why it matters
kubeadm runs the control plane as static pods managed directly by kubelet. etcd
is the single source of truth. Understanding this layering (systemd → kubelet →
static pods → API server → everything else) is the foundation for every
troubleshooting lab later.
