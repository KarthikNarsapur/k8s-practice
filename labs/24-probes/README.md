# Lab 24 — Liveness and Readiness Probes

Level: Configuration advanced

## Objective
Diagnose incorrect HTTP probe paths and restore liveness/readiness checks without masking application failures.

## Start
```bash
./scripts/lab-start.sh 24
```
Namespace: `lab-24`.

## Four basic challenges
1. Repair `app-a` liveness and readiness HTTP paths so nginx returns success.
2. Repair `app-b` liveness and readiness HTTP paths.
3. Repair `app-c` liveness and readiness HTTP paths.
4. Repair `app-d` liveness and readiness HTTP paths.

## Four hard challenges
1. Repair `app-e` liveness and readiness HTTP paths.
2. Repair `app-f` liveness and readiness HTTP paths.
3. Repair `app-g` liveness and readiness HTTP paths.
4. Repair `app-h` liveness and readiness HTTP paths.

## Verify and troubleshoot
```bash
./scripts/lab-verify.sh 24
kubectl -n lab-24 get pods
kubectl -n lab-24 describe pod <pod-name>
kubectl -n lab-24 get events --sort-by=.lastTimestamp
```
Verifier checks readiness and Deployment availability; inspect liveness too. A syntactically valid probe can still be operationally wrong.

Reset: `./scripts/lab-reset.sh 24`. Full solution: `solution.md`.
