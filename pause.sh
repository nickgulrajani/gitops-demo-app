#!/usr/bin/env bash
set -e

echo "=== Pausing GitOps Demo ==="

# Delete the Argo CD application (but leave Argo itself installed)
echo "[STEP] Deleting Argo CD application 'hello-gitops'..."
kubectl delete application hello-gitops -n argocd --ignore-not-found=true

# Delete the hello workload from the default namespace
echo "[STEP] Deleting deployed hello app resources..."
kubectl delete deploy hello -n default --ignore-not-found=true
kubectl delete svc hello -n default --ignore-not-found=true

echo "=== GitOps demo paused ==="
echo "Cluster is clean. You can re-run start_demo.sh anytime."

