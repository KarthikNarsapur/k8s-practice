# Lab 21 — Secrets Solution

> Spoilers — attempt all eight challenges before reading this file.

Create type `Opaque` Secrets with the exact required keys and fake lab-only values. `stringData` is convenient for authoring; Kubernetes stores values under `.data`.

```bash
kubectl -n lab-21 get secrets
kubectl -n lab-21 describe secret secret-a
./scripts/lab-verify.sh 21
```
