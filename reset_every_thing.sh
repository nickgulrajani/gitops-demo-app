#!/usr/bin/env bash
set -e

########################################################
# reset_every_thing.sh
#
# HARD RESET for the GitOps demo:
#  - Resets deployment.yaml in Git to a known-good baseline:
#       replicas: 2
#       image:    nginxdemos/hello:plain-text  (v1)
#  - Deletes Argo CD Application (hello-gitops)
#  - Deletes all hello workloads (Deployment/Service/ReplicaSets)
#  - Leaves Argo CD itself installed
########################################################

# --- CONFIG -------------------------------------------------------------------
REPO_DIR="$HOME/nic-projects/OPPORTUNITY-UCS/Truist/ARGOCD/gitops-demo-app"
DEPLOY_FILE="deployment.yaml"
APP_NAME="hello-gitops"
K8S_NAMESPACE="default"
K8S_APP_LABEL="hello"
GIT_BRANCH="main"

BASE_REPLICAS=2
BASE_IMAGE="nginxdemos/hello:plain-text"

line() {
  echo "======================================================="
}

echo "======================================================="
echo "             🔄 FULL GITOPS RESET SCRIPT"
line

# --- STEP 1: Reset local Git repo to known-good baseline ----------------------
echo "➡️  Step 1: Reset local Git repo to known-good baseline"
echo "    - Repo dir: ${REPO_DIR}"
echo "    - Branch:   ${GIT_BRANCH}"
echo "    - File:     ${DEPLOY_FILE}"

if [[ ! -d "${REPO_DIR}" ]]; then
  echo "[ERROR] Repo directory not found: ${REPO_DIR}"
  exit 1
fi

cd "${REPO_DIR}"

git checkout "${GIT_BRANCH}" >/dev/null 2>&1 || true
git pull --ff-only || true

# Overwrite deployment.yaml with clean baseline (2 replicas, v1 image)
cat > "${DEPLOY_FILE}" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
  labels:
    app: hello
spec:
  replicas: ${BASE_REPLICAS}
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - name: hello
        image: ${BASE_IMAGE}
        ports:
        - containerPort: 80
EOF

echo "[INFO] New baseline deployment.yaml contents:"
grep -E 'replicas:|image:' "${DEPLOY_FILE}" || true

git add "${DEPLOY_FILE}"
git commit -m "Reset baseline deployment for GitOps demo (replicas=${BASE_REPLICAS}, image=${BASE_IMAGE})" || echo "[INFO] Nothing to commit (already at baseline)."
git push origin "${GIT_BRANCH}" || echo "[WARN] Could not push to origin (check network/remote)."

# --- STEP 2: Remove existing GitOps application --------------------------------
line
echo "➡️  Step 2: Removing existing GitOps application '${APP_NAME}' (if any)"

kubectl delete application "${APP_NAME}" -n argocd --ignore-not-found || true

# --- STEP 3: Remove workloads for 'hello' --------------------------------------
line
echo "➡️  Step 3: Removing workloads for app 'hello'"

echo "[ACTION] Deleting Deployment..."
kubectl delete deploy hello -n "${K8S_NAMESPACE}" --ignore-not-found || true

echo "[ACTION] Deleting Service..."
kubectl delete svc hello -n "${K8S_NAMESPACE}" --ignore-not-found || true

echo "[ACTION] Deleting ReplicaSets with label app=${K8S_APP_LABEL}..."
kubectl delete rs -l app="${K8S_APP_LABEL}" -n "${K8S_NAMESPACE}" --ignore-not-found || true

# --- STEP 4: Confirm cluster is clean -----------------------------------------
line
echo "➡️  Step 4: Confirming cluster is clean for 'hello'"

if kubectl get deploy hello -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then
  echo "[WARN] Deployment 'hello' still exists (unexpected):"
  kubectl get deploy hello -n "${K8S_NAMESPACE}"
else
  echo "✔️ No deployment 'hello' exists (clean)."
fi

echo
echo "[INFO] Any remaining hello-related resources:"
kubectl get deploy,svc,rs,pods -l app="${K8S_APP_LABEL}" -n "${K8S_NAMESPACE}" --ignore-not-found || true

line
echo "             RESET COMPLETE — READY TO BOOTSTRAP"
line
