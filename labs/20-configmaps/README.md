# Lab 20 — ConfigMaps

Level: Configuration foundations

## Objective
Create and repair non-sensitive application configuration using ConfigMaps. Values must match exactly.

## Start
```bash
./scripts/lab-start.sh 20
```
Namespace: `lab-20`.

## Four basic challenges
1. Create `config-a` with `APP_MODE=production`.
2. Create `config-b` with `LOG_LEVEL=info`.
3. Create `config-c` with `FEATURE_FLAG=enabled`.
4. Create `config-d` with `REGION=eu-west-1`.

## Four hard challenges
1. Repair `hc-config-e` to provide `APP_MODE=production`.
2. Repair `hc-config-f` to provide `LOG_LEVEL=info`.
3. Repair `hc-config-g` to provide `FEATURE_FLAG=enabled`.
4. Repair `hc-config-h` to provide `REGION=eu-west-1`.

## Verify and troubleshoot
```bash
./scripts/lab-verify.sh 20
kubectl -n lab-20 get configmaps -o yaml
kubectl -n lab-20 describe configmap hc-config-e
```
ConfigMaps are for non-confidential settings. Do not put passwords, tokens, or private keys in ConfigMaps.

Reset: `./scripts/lab-reset.sh 20`. Full solution: `solution.md`.
