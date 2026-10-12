# Lab 24 — Probes Solution

> Spoilers — attempt all eight challenges before reading this file.

Set both HTTP liveness and readiness probes to the valid nginx path on port 80, then wait for the Deployment to recover and confirm Pod restart counts stabilize.

```bash
kubectl -n lab-24 get deployments
kubectl -n lab-24 describe deployment app-a
./scripts/lab-verify.sh 24
```
