# Lab 19 — Solution

> Spoilers. Diagnose all eight paths independently before reading this file.

For each path, check the Service selector against Pod labels, targetPort against the listening container port, ready endpoint addresses, DNS resolution, and HTTP response. An existing Service or a DNS answer alone does not prove application connectivity.

```bash
kubectl -n lab-19 get svc,endpointslices
kubectl -n lab-19 get pods --show-labels
kubectl -n lab-19 exec netprobe -- nslookup <service-name>
kubectl -n lab-19 exec netprobe -- wget -S -T 5 -O /dev/null http://<service-name>
./scripts/lab-verify.sh 19
```
