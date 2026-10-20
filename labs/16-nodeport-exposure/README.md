# Lab 16 — NodePort Exposure

Level: Networking intermediate

## Objective
Expose selected workloads through NodePort Services and distinguish Service port, targetPort, and nodePort.

## Start
```bash
./scripts/lab-start.sh 16
```
Work in namespace `lab-16`.

## Four basic challenges
Create `node-a`, `node-b`, `node-c`, and `node-d`. Each must select the matching `app=app-a` through `app=app-d`, use Service port 80 and targetPort 80, and set type `NodePort`. Assign nodePorts 30081, 30082, 30083, and 30084 respectively.

## Four hard challenges
Repair `hc-node-e`, `hc-node-f`, `hc-node-g`, and `hc-node-h`. Select the matching app label, set port and targetPort to 80, and use nodePorts 30085, 30086, 30087, and 30088 respectively.

## Verify and troubleshoot
```bash
./scripts/lab-verify.sh 16
kubectl -n lab-16 get svc -o wide
kubectl -n lab-16 get endpointslices
kubectl get nodes -o wide
```
Verifier requires the exact NodePort, matching selector, port mapping, and a ready endpoint. This lab verifies Kubernetes configuration and endpoint wiring; reachability from outside the VPC is not expected because nodes are private and access is through SSM.

Reset: `./scripts/lab-reset.sh 16`. Solution: `solution.md`.
