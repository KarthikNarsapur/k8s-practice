# Lab 25 — Resource Requests and Limits

Level: Configuration advanced

## Objective
Set realistic CPU and memory requests/limits and observe how resource declarations affect scheduling and container enforcement.

## Start
```bash
./scripts/lab-start.sh 25
```
Namespace: `lab-25`.

## Four basic challenges
1. Repair `app-a`: requests CPU `100m`, memory `64Mi`; limits CPU `500m`, memory `128Mi`.
2. Repair `app-b` with the same request/limit profile.
3. Repair `app-c` with the same request/limit profile.
4. Repair `app-d` with the same request/limit profile.

## Four hard challenges
1. Repair `app-e` with the same request/limit profile.
2. Repair `app-f` with the same request/limit profile.
3. Repair `app-g` with the same request/limit profile.
4. Repair `app-h` with the same request/limit profile.

## Verify and troubleshoot
```bash
./scripts/lab-verify.sh 25
kubectl -n lab-25 get deploy,pods
kubectl -n lab-25 describe pod <pod-name>
kubectl describe node
```
The verifier checks CPU request and availability. Also verify memory requests and both limits; readiness alone does not establish appropriate sizing.

Reset: `./scripts/lab-reset.sh 25`. Full solution: `solution.md`.
