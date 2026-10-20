# Lab 21 — Secrets

Level: Configuration and security foundations

## Objective
Create and repair Opaque Secrets. Values are fake lab-only values; never reuse real credentials. The verifier never prints secret values.

## Start
```bash
./scripts/lab-start.sh 21
```
Namespace: `lab-21`.

## Four basic challenges
1. Create `secret-a` with key `username` and value `demo-user`.
2. Create `secret-b` with key `password` and value `rotate-me-123`.
3. Create `secret-c` with key `api-token` and value `fake-token-789`.
4. Create `secret-d` with key `database` and value `orders`.

## Four hard challenges
1. Repair `hc-secret-e` to use `username=demo-user`.
2. Repair `hc-secret-f` to use `password=rotate-me-123`.
3. Repair `hc-secret-g` to use `api-token=fake-token-789`.
4. Repair `hc-secret-h` to use `database=orders`.

## Verify and troubleshoot
```bash
./scripts/lab-verify.sh 21
kubectl -n lab-21 get secrets
kubectl -n lab-21 describe secret hc-secret-e
```
Base64 is encoding, not encryption. Do not inspect full Secret YAML while screen-sharing or recording.

Reset: `./scripts/lab-reset.sh 21`. Full solution: `solution.md`.
