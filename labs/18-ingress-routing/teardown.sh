#!/usr/bin/env bash
set -euo pipefail
info "Removing Lab 18 cluster-scoped ingress resources..."
remote_exec "kubectl delete ingressclass lab18 --ignore-not-found; kubectl delete clusterrolebinding lab18-ingress-controller --ignore-not-found; kubectl delete clusterrole lab18-ingress-controller --ignore-not-found" || true
