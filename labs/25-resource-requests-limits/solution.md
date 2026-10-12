# Lab 25 — Requests and Limits Solution

> Spoilers — attempt all eight challenges before reading this file.

Set requests to CPU `100m` and memory `64Mi`, and limits to CPU `500m` and memory `128Mi`. Observe events and node allocatable capacity after rollout.

```bash
kubectl -n lab-25 get deployments
kubectl -n lab-25 describe deployment app-a
./scripts/lab-verify.sh 25
```
