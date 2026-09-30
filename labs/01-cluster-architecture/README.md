# Lab 01 — Cluster Architecture

Level 1: Kubernetes Fundamentals

## 1. Objective

Understand what a kubeadm cluster is actually made of. By the end you will be
able to name every control-plane component, see them running as real
processes/containers on the node, and explain how the worker nodes register
with the API server.

## 2. Prerequisites

- The cluster is deployed (`terraform apply`) and Ready.
- You can open an SSM session to the control-plane node (see main README).
- Completed: none (this is the first lab).

## 3. Environment Setup

```bash
./scripts/lab-start.sh 01
```

This lab does not deploy workloads — it asks you to inspect the cluster that is
already there. You will work mostly from an SSM shell on the control-plane.

## 4. Challenge

Answer these by investigating the live cluster (not by reading docs):

1. List all nodes and identify which one is the control-plane (look at the
   ROLES column).
2. From an SSM session on the control-plane, find the **static pod manifests**
   that kubeadm uses to run the control plane. Which directory are they in?
3. Show the four core control-plane components running as containers using
   `crictl ps`. Name them.
4. Show that `etcd` is running and identify the port it listens on using `ss`.
5. Prove that the kubelet is a systemd service and show its status.

Create a proof artifact the verifier can check: label the control-plane node
with `lab01/investigated=true` **after** you have inspected it:

```bash
kubectl label node <control-plane-node-name> lab01/investigated=true
```

## 5. Expected Outcome

- You can enumerate: kube-apiserver, kube-controller-manager, kube-scheduler,
  etcd (control-plane) and kubelet + kube-proxy (all nodes).
- The control-plane node carries the label `lab01/investigated=true`.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 01
```

Passes when:
- All nodes are `Ready`.
- The control-plane node has label `lab01/investigated=true`.

## 7. Optional Hints

- `kubectl get nodes -o wide` shows roles and internal IPs.
- Static pod manifests live under a directory named after "manifests" inside
  `/etc/kubernetes/...`.
- `crictl ps` lists running containers at the runtime level (below kubectl).
- `sudo ss -ltnp` shows listening TCP sockets with the owning process.

## 8. Troubleshooting

- `crictl` says permission denied → prefix with `sudo`.
- No nodes show `Ready` → the CNI may still be initializing; wait and re-check
  `kubectl get pods -n calico-system`.
- Can't reach the API from the node → confirm `KUBECONFIG` or use
  `sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes`.

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 01     # removes the label + lab namespace, starts fresh
./scripts/lab-destroy.sh 01   # removes lab state entirely
```
