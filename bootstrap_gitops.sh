#!/usr/bin/env bash
set -e

############################################################
# bootstrap_gitops.sh
#
# Bootstraps a working Argo CD + GitOps demo environment:
#  - Ensures Argo CD is installed
#  - Creates/updates "hello-gitops" Application
#  - Waits for app to sync and hello Deployment to be ready
#  - Starts Argo CD UI port-forward on https://localhost:9999
############################################################

APP_NAME="hello-gitops"
ARGO_NAMESPACE="argocd"
DEST_NAMESPACE="default"
REPO_URL="https://github.com/nickgulrajani/gitops-demo-app.git"
GIT_REVISION="main"
APP_PATH="."
ARGO_PORT=9999

line() {
  echo "------------------------------------------------------------"
}

echo "============================================================"
echo "             🚀 BOOTSTRAP GITOPS ENVIRONMENT"
echo "============================================================"

# --- 0. Basic checks ---------------------------------------------------------
command -v kubectl >/dev/null 2>&1 || { echo "[ERROR] kubectl not found"; exit 1; }

# --- 1. Ensure Argo CD namespace exists --------------------------------------
line
echo "➡️  Step 1: Ensure Argo CD namespace '${ARGO_NAMESPACE}' exists"
kubectl get ns "${ARGO_NAMESPACE}" >/dev/null 2>&1 || kubectl create ns "${ARGO_NAMESPACE}"

# --- 2. Install Argo CD if not present ---------------------------------------
line
echo "➡️  Step 2: Ensure Argo CD is installed"

if ! kubectl get deploy argocd-server -n "${ARGO_NAMESPACE}" >/dev/null 2>&1; then
  echo "[INFO] Argo CD not detected, installing..."
  kubectl apply -n "${ARGO_NAMESPACE}" \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  echo "[INFO] Waiting for Argo CD core components to be ready..."
  kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n "${ARGO_NAMESPACE}"
  kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n "${ARGO_NAMESPACE}"
  kubectl wait --for=condition=available --timeout=300s deployment/argocd-application-controller -n "${ARGO_NAMESPACE}"
else
  echo "[INFO] Argo CD already installed."
fi

# --- 3. Create / update Argo CD Application ----------------------------------
line
echo "➡️  Step 3: Apply Argo CD Application '${APP_NAME}'"

cat <<EOF | kubectl apply -n "${ARGO_NAMESPACE}" -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    targetRevision: ${GIT_REVISION}
    path: ${APP_PATH}
  destination:
    server: https://kubernetes.default.svc
    namespace: ${DEST_NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

echo "[INFO] Waiting a few seconds for Argo CD to process the Application..."
sleep 10

echo "[INFO] Current Argo CD Applications:"
kubectl get applications.argoproj.io -n "${ARGO_NAMESPACE}" || true

# --- 4. Wait for "hello" Deployment to be created & ready --------------------
line
echo "➡️  Step 4: Wait for 'hello' Deployment to be created and ready"

ATTEMPTS=24
SLEEP_SECONDS=5
FOUND_DEPLOYMENT=0

for i in $(seq 1 ${ATTEMPTS}); do
  if kubectl get deploy hello -n "${DEST_NAMESPACE}" >/dev/null 2>&1; then
    FOUND_DEPLOYMENT=1
    echo "[INFO] 'hello' Deployment found (attempt ${i}/${ATTEMPTS})."
    break
  fi
  echo "[INFO] 'hello' Deployment not found yet (attempt ${i}/${ATTEMPTS})... waiting ${SLEEP_SECONDS}s"
  sleep "${SLEEP_SECONDS}"
done

if [ "${FOUND_DEPLOYMENT}" -eq 0 ]; then
  echo "[WARN] 'hello' Deployment still not found after waiting. Argo CD may still be syncing."
else
  echo "[INFO] Waiting up to 180s for 'hello' Deployment to be Ready..."
  if ! kubectl wait --for=condition=available --timeout=180s deploy/hello -n "${DEST_NAMESPACE}"; then
    echo "[WARN] 'hello' Deployment did not reach Ready state within timeout."
  fi
fi

echo "[INFO] Current state of deployment and pods:"
kubectl get deploy hello -n "${DEST_NAMESPACE}" || true
kubectl get pods -l app=hello -n "${DEST_NAMESPACE}" || true

# --- 5. Start Argo CD UI port-forward ----------------------------------------
line
echo "➡️  Step 5: Start Argo CD UI port-forward on https://localhost:${ARGO_PORT}"

# Kill any existing process using that port
if lsof -ti tcp:${ARGO_PORT} >/dev/null 2>&1; then
  echo "[INFO] Port ${ARGO_PORT} already in use, killing existing process..."
  lsof -ti tcp:${ARGO_PORT} | xargs kill -9 2>/dev/null || true
fi

# Start port-forward in background
kubectl port-forward svc/argocd-server -n "${ARGO_NAMESPACE}" ${ARGO_PORT}:443 >/tmp/argocd-ui.log 2>&1 &

sleep 3

echo "============================================================"
echo "✅ BOOTSTRAP COMPLETE"
echo "   - Argo CD namespace: ${ARGO_NAMESPACE}"
echo "   - Application:       ${APP_NAME}"
echo "   - Destination ns:    ${DEST_NAMESPACE}"
echo "   - UI URL:            https://localhost:${ARGO_PORT}"
echo "   - UI log:            /tmp/argocd-ui.log"
echo "============================================================"

