#!/usr/bin/env bash
set -e

CLUSTER_NAME="gitops-demo"
ARGO_NAMESPACE="argocd"
GITHUB_REPO="https://github.com/nickgulrajani/gitops-demo-app.git"
APP_NAME="hello-gitops"
ARGO_PORT=9999

echo "=== Starting GitOps demo ==="

# --- 0. Sanity checks --------------------------------------------------------
if ! command -v kind >/dev/null 2>&1; then
  echo "[ERROR] kind is not installed. Install it from https://kind.sigs.k8s.io/."
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[ERROR] kubectl is not installed."
  exit 1
fi

# --- 1. Create KinD cluster --------------------------------------------------
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "[INFO] KinD cluster '${CLUSTER_NAME}' already exists. Skipping creation."
else
  echo "[STEP] Creating KinD cluster '${CLUSTER_NAME}'..."
  kind create cluster --name "${CLUSTER_NAME}" --image kindest/node:v1.29.2
fi

# --- 2. Install / Update Argo CD --------------------------------------------
echo "[STEP] Creating namespace '${ARGO_NAMESPACE}' (if not present)..."
kubectl create namespace "${ARGO_NAMESPACE}" 2>/dev/null || echo "[INFO] Namespace '${ARGO_NAMESPACE}' already exists."

echo "[STEP] Installing / updating Argo CD..."
kubectl apply -n "${ARGO_NAMESPACE}" \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "[STEP] Waiting for Argo CD pods to appear..."
until kubectl get pods -n "${ARGO_NAMESPACE}" 2>/dev/null | grep -q "argocd-"; do
  echo "  - Argo CD pods not visible yet, retrying in 5s..."
  sleep 5
done

echo "[STEP] Waiting for Argo CD pods to become Ready (this can take a bit)..."
kubectl wait pods -n "${ARGO_NAMESPACE}" --all --for=condition=Ready --timeout=300s || {
  echo "WARNING: Some Argo CD pods did not become Ready within timeout. Current status:"
  kubectl get pods -n "${ARGO_NAMESPACE}"
}

# --- 3. Port-forward Argo CD UI ---------------------------------------------
echo "[STEP] Starting Argo CD UI port-forward on https://localhost:${ARGO_PORT} ..."

# Kill any existing port-forward on that port
PF_PID=$(lsof -ti:"${ARGO_PORT}" || true)
if [ -n "${PF_PID}" ]; then
  echo "  - Found existing process on port ${ARGO_PORT} (PID ${PF_PID}), killing it..."
  kill -9 "${PF_PID}" || true
fi

kubectl port-forward svc/argocd-server -n "${ARGO_NAMESPACE}" "${ARGO_PORT}":443 >/dev/null 2>&1 &
PF_NEW_PID=$!
sleep 3
echo "  - Port-forward running with PID ${PF_NEW_PID}"
echo "  - Argo CD UI: https://localhost:${ARGO_PORT}"

# --- 4. Print Argo CD admin password ----------------------------------------
echo "[STEP] Fetching Argo CD admin password..."
ADMIN_PW=$(kubectl -n "${ARGO_NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || true)

if [ -n "${ADMIN_PW}" ]; then
  echo "  - Username: admin"
  echo "  - Password: ${ADMIN_PW}"
else
  echo "  - Could not retrieve initial admin password (it may have been changed already)."
fi

# --- 5. Create / update the GitOps Application ------------------------------
echo "[STEP] Creating / updating Argo CD Application '${APP_NAME}'..."

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}
  namespace: ${ARGO_NAMESPACE}
spec:
  project: default
  source:
    repoURL: ${GITHUB_REPO}
    targetRevision: HEAD
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  # Use manual sync by default so you can show the Sync button in the demo.
  # To enable auto-sync + self-heal, uncomment the syncPolicy below.
  # syncPolicy:
  #   automated:
  #     prune: true
  #     selfHeal: true
EOF

echo "[STEP] Waiting a few seconds for Application to reconcile..."
sleep 10

echo "=== GitOps demo started successfully ==="
echo "✔ KinD cluster: ${CLUSTER_NAME}"
echo "✔ Argo CD namespace: ${ARGO_NAMESPACE}"
echo "✔ Argo CD UI: https://localhost:${ARGO_PORT}"
echo "✔ Application: ${APP_NAME} (connected to ${GITHUB_REPO})"
echo
echo "Next steps:"
echo "  1) Open https://localhost:${ARGO_PORT} in your browser."
echo "  2) Log in with admin / password above."
echo "  3) Open app '${APP_NAME}', click SYNC, and watch it deploy."

