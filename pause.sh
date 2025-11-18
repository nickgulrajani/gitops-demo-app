#!/usr/bin/env bash
set -e

CLUSTER_NAME="gitops-demo"

echo "=== Pausing GitOps demo ==="

# Kill port-forward if running
echo "[STEP] Stopping any Argo CD port-forward sessions..."
PF_PID=$(lsof -ti:9999 || true)
if [ -n "$PF_PID" ]; then
  echo "Killing port-forward process PID: $PF_PID"
  kill -9 "$PF_PID"
else
  echo "No port-forward process running on port 9999."
fi

# Delete KinD cluster
echo "[STEP] Deleting KinD cluster ($CLUSTER_NAME)..."
kind delete cluster --name "${CLUSTER_NAME}" || true

echo "=== Demo paused successfully ==="

