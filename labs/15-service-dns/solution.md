# Lab 15 — Solution

> Spoilers. Attempt all eight challenges before reading this file.

For each Service, set the selector to the matching workload label `app=app-<letter>`, Service port 80, and targetPort 80. Confirm endpoint addresses rather than relying only on Service existence.

```bash
kubectl -n lab-15 get svc,endpointslices
./scripts/lab-verify.sh 15
```
