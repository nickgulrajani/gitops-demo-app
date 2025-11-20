#!/usr/bin/env bash
set -e

echo "======================================================="
echo "             🔄 FULL GITOPS RESET SCRIPT"
echo "======================================================="

REPO_DIR="$HOME/nic-projects/OPPORTUNITY-UCS/Truist/ARGOCD/gitops-demo-app"
DEPLOY_FILE="deployment.yaml"
APP_NAME="hello-gitops"

echo "➡️  Step 1: Reset local Git repo to known-good state"
cd "$REPO_DIR"

git restore $DEPLOY_FILE || true
cat > $DEPLOY_FILE << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
  labels:
    app: hello
spec:
  replicas: 3
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
        image: nginxdemos/hello:plain-text
        ports:
        - containerPort: 80
EOF

git add deployment.yaml
git commit -m "Reset baseline deployment for GitOps demo" || echo "Nothing to commit"
git push origin main

echo "➡️  Step 2: Removing existing GitOps application"
kubectl delete application $APP_NAME -n argocd --ignore-not-found

echo "➡️  Step 3: Removing workloads"
kubectl delete deploy hello -n default --ignore-not-found
kubectl delete svc hello -n default --ignore-not-found
kubectl delete rs -l app=hello -n default --ignore-not-found

echo "➡️  Step 4: Confirming cluster is clean"
kubectl get deploy hello -n default || echo "✔️ No deployment exists (clean)."

echo "======================================================="
echo "             RESET COMPLETE — READY TO BOOTSTRAP"
echo "======================================================="

