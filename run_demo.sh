#!/usr/bin/env bash
set -e

echo "======================================================="
echo "                🤖 GITOPS DEMO FLOW"
echo "======================================================="

REPO_DIR="$HOME/nic-projects/OPPORTUNITY-UCS/Truist/ARGOCD/gitops-demo-app"
DEPLOY_FILE="deployment.yaml"
APP_NAME="hello"

pause() {
  echo
  read -r -p "👉 Press Enter to continue..." _
  echo
}

cd "$REPO_DIR"

echo "➡️ STEP 0 — Current state"
kubectl get deploy hello -n default
kubectl get pods -l app=hello -n default
pause

echo "➡️ STEP 1 — Git-based scaling to 3 replicas"
sed -i '' 's/replicas:.*/replicas: 3/' $DEPLOY_FILE
git add $DEPLOY_FILE
git commit -m "GitOps: scale to 3 replicas" || true
git push origin main

echo "Waiting for Argo to sync..."
sleep 15
kubectl get deploy hello -n default
kubectl get pods -l app=hello -n default
pause

echo "➡️ STEP 2 — Simulate drift (manual scale to 1)"
kubectl scale deploy hello --replicas=1 -n default
sleep 5
kubectl get deploy hello -n default

echo "Waiting for Argo CD to self-heal..."
sleep 25
kubectl get deploy hello -n default
kubectl get pods -l app=hello -n default
pause

echo "➡️ STEP 3 — Rollout a new version"
sed -i '' 's|nginxdemos/hello:plain-text|nginxdemos/hello:plain-text?version=v2|' $DEPLOY_FILE
git add $DEPLOY_FILE
git commit -m "GitOps: rollout v2" || true
git push origin main

echo "Waiting for rollout..."
sleep 20
kubectl get deploy hello -n default
kubectl get pods -l app=hello -n default

echo "======================================================="
echo "   🎉 DEMO COMPLETE — Scaling, Self-Heal, Version Rollout"
echo "======================================================="

