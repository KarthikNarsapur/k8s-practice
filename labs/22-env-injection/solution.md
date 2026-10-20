# Lab 22 — Environment Variable Injection Solution

> Spoilers — attempt all eight challenges before reading this file.

For each Deployment, correct both `configMapKeyRef.name` fields to the matching letter's ConfigMaps and ensure the keys remain `APP_MODE` and `LOG_LEVEL`.

```bash
kubectl -n lab-22 get deployments
kubectl -n lab-22 describe deployment app-a
./scripts/lab-verify.sh 22
```
