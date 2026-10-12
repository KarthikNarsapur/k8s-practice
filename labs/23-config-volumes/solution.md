# Lab 23 — ConfigMap Volumes Solution

> Spoilers — attempt all eight challenges before reading this file.

Align each `volumeMounts[].name` with `volumes[].name`, point the volume at the matching ConfigMap, and mount read-only at `/etc/app-config`.

```bash
kubectl -n lab-23 get deployments
kubectl -n lab-23 describe deployment app-a
./scripts/lab-verify.sh 23
```
