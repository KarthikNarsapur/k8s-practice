# Lab 17 — Solution

> Spoilers. Attempt all eight policy tasks before reading this file.

Use `networking.k8s.io/v1` NetworkPolicy. `spec.podSelector` selects destination/source Pods governed by that policy; ingress/egress peer selectors define allowed traffic. A policy selecting backend Pods with `policyTypes: [Ingress]` and no ingress rules denies all ingress to those Pods.

For each allow rule, match the intended peer tier and destination port. DNS egress uses UDP/53 to the `kube-system` namespace.

```bash
kubectl -n lab-17 get networkpolicy -o yaml
kubectl -n lab-17 describe networkpolicy <name>
./scripts/lab-verify.sh 17
```
Calico enforcement and live traffic tests are important in addition to API-level validation.
