# Lab 16 — Solution

> Spoilers. Attempt all eight challenges first.

For each Service, use `type: NodePort`, selector `app=app-<letter>`, port 80, targetPort 80, and the exact nodePort assigned in README.md.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <service-name>
spec:
  type: NodePort
  selector:
    app: <matching-app-label>
  ports:
  - port: 80
    targetPort: 80
    nodePort: <assigned-port>
```

Verify configuration and ready endpoints:
```bash
kubectl -n lab-16 get svc,endpointslices
./scripts/lab-verify.sh 16
```
