# Lab 18 — Ingress Routing

Level: Networking advanced

## Objective
Route HTTP requests by host and path through an Ingress controller. Setup installs a lab-specific ingress-nginx controller exposed internally through NodePort 30090; no public AWS endpoint is created.

## Start
```bash
./scripts/lab-start.sh 18
```
Wait for the controller and backend Pods to become Ready.

## Four basic challenges
Create Ingress resources `ing-a` through `ing-d`. Each uses IngressClass `lab18`, host `app-a.lab.test` through `app-d.lab.test`, path `/` with pathType `Prefix`, and backend Service `ing-a` through `ing-d` on port 80.

## Four hard challenges
Repair `hc-ing-e` through `hc-ing-h`:
1. Correct the host for app-e.
2. Correct the path to `/` for app-f.
3. Correct the backend Service for app-g.
4. Correct the IngressClass for app-h.

## Verify and troubleshoot
```bash
./scripts/lab-verify.sh 18
kubectl -n lab-18 get ingress,svc,endpointslices
kubectl -n lab-18 logs deploy/ingress-controller
kubectl -n lab-18 describe ingress <name>
```
The verifier checks the Ingress fields, ready backend endpoint, controller readiness, and an HTTP request through the controller from an in-cluster client.

Reset: `./scripts/lab-reset.sh 18`. The reset/destroy scripts also remove the lab-specific IngressClass and RBAC objects. Solution: `solution.md`.
