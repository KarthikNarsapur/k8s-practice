# Lab 22 — Environment Variable Injection

Level: Configuration intermediate

## Objective
Inject ConfigMap values into container environment variables and troubleshoot workloads blocked by invalid references.

## Start
```bash
./scripts/lab-start.sh 22
```
Namespace: `lab-22`.

## Four basic challenges
1. Repair `app-a` so `APP_MODE` references `settings-a` and `LOG_LEVEL` references `settings-a-logs`.
2. Repair `app-b` to use `settings-b` and `settings-b-logs`.
3. Repair `app-c` to use `settings-c` and `settings-c-logs`.
4. Repair `app-d` to use `settings-d` and `settings-d-logs`.

## Four hard challenges
1. Repair `app-e` to use `settings-e` and `settings-e-logs`.
2. Repair `app-f` to use `settings-f` and `settings-f-logs`.
3. Repair `app-g` to use `settings-g` and `settings-g-logs`.
4. Repair `app-h` to use `settings-h` and `settings-h-logs`.

## Verify and troubleshoot
```bash
./scripts/lab-verify.sh 22
kubectl -n lab-22 get deploy,pods
kubectl -n lab-22 describe pod <pod-name>
kubectl -n lab-22 get configmaps
```


Reset: `./scripts/lab-reset.sh 22`. Full solution: `solution.md`.
