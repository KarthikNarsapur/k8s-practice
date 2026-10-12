# Lab 23 — ConfigMap Volumes

Level: Configuration intermediate

## Objective
Mount ConfigMap data into a container filesystem and debug volume references, mount paths, and rollout availability.

## Start
```bash
./scripts/lab-start.sh 23
```
Namespace: `lab-23`.

## Four basic challenges
1. Repair `app-a` to mount `files-a` at `/etc/app-config` read-only.
2. Repair `app-b` to mount `files-b` at `/etc/app-config` read-only.
3. Repair `app-c` to mount `files-c` at `/etc/app-config` read-only.
4. Repair `app-d` to mount `files-d` at `/etc/app-config` read-only.

## Four hard challenges
1. Repair `app-e` to mount `files-e` at `/etc/app-config` read-only.
2. Repair `app-f` to mount `files-f` at `/etc/app-config` read-only.
3. Repair `app-g` so mount and declared volume names match, use ConfigMap `files-g`, and mount read-only at `/etc/app-config`.
4. Repair `app-h` so its volume references `files-h` and is mounted read-only at `/etc/app-config`.

## Verify and troubleshoot
```bash
./scripts/lab-verify.sh 23
kubectl -n lab-23 get deploy,pods
kubectl -n lab-23 describe pod <pod-name>
kubectl -n lab-23 get configmap files-a -o yaml
```


Reset: `./scripts/lab-reset.sh 23`. Full solution: `solution.md`.
