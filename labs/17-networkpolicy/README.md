# Lab 17 — NetworkPolicy Segmentation

Level: Networking advanced

## Objective
Control Pod ingress and egress with NetworkPolicy. This cluster uses Calico; a Kubernetes API accepting policies does not itself prove the CNI enforces them.

## Start
```bash
./scripts/lab-start.sh 17
```
Namespace `lab-17` contains workloads labeled `tier=frontend`, `tier=backend`, `tier=database`, and `tier=metrics`.

## Four basic challenges
1. Create `deny-backend-ingress`: select backend Pods, set policyTypes to Ingress, and allow no ingress sources.
2. Create `allow-frontend-backend`: select backend Pods; allow TCP/80 from Pods labeled `tier=frontend`.
3. Create `allow-backend-db`: select database Pods; allow TCP/80 from Pods labeled `tier=backend`.
4. Create `allow-frontend-dns`: select frontend Pods; set policyTypes to Egress and allow UDP/53 to the `kube-system` namespace.

## Four hard challenges
Repair the pre-created policies without deleting them:
1. `hc-isolate-db`: isolate database Pods for ingress.
2. `hc-allow-ui`: allow TCP/80 from frontend Pods to backend Pods.
3. `hc-db-port`: allow TCP/80 from backend Pods to database Pods.
4. `hc-dns`: allow UDP/53 egress from frontend Pods to kube-system.

## Verify and troubleshoot
```bash
./scripts/lab-verify.sh 17
kubectl -n lab-17 get networkpolicy -o yaml
kubectl -n lab-17 get pods --show-labels
kubectl -n lab-17 describe networkpolicy <name>
kubectl -n kube-system get pods -o wide
```
The verifier checks selectors, policy direction, peer selectors, ports, and the DNS namespace peer using structured fields. After it passes, test actual allowed and denied traffic from temporary Pods; configuration checks alone do not prove data-plane enforcement.

Reset: `./scripts/lab-reset.sh 17`. Solution: `solution.md`.
