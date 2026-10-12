# Lab 18 — Solution

> Spoilers. Attempt all eight challenges before reading this file.

Each Ingress should reference class `lab18`, the requested host, a Prefix path of `/`, and the matching backend Service on port 80. Check both the Ingress resource and actual HTTP behavior.

```bash
kubectl -n lab-18 get ingress -o yaml
kubectl -n lab-18 get svc,endpointslices
kubectl -n lab-18 logs deploy/ingress-controller
./scripts/lab-verify.sh 18
```
