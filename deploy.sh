#!/usr/bin/env bash
set -e

TAG="${1:-latest}"
REGISTRY="docker.io/bettyyyc14"

echo "▶ Deploying tag: $TAG from registry: $REGISTRY"

# Patch image placeholders into temporary copies (don't modify originals)
TMPDIR=$(mktemp -d)
for f in k8s/auth-deployment.yaml k8s/jobapp-deployment.yaml k8s/frontend-deployment.yaml; do
  out="$TMPDIR/$(basename $f)"
  sed "s|IMAGE_REGISTRY|$REGISTRY|g; s|IMAGE_TAG|$TAG|g" "$f" > "$out"
  echo "  Patched $f → $TAG"
done

echo "▶ Applying manifests..."
kubectl apply -f k8s/jobapp-ksa.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/mongo.yaml
kubectl apply -f "$TMPDIR/auth-deployment.yaml"
kubectl apply -f "$TMPDIR/jobapp-deployment.yaml"
kubectl apply -f "$TMPDIR/frontend-deployment.yaml"
kubectl apply -f k8s/services.yaml

echo "▶ Waiting for rollouts..."
kubectl rollout status deployment/auth-service    --timeout=300s
kubectl rollout status deployment/jobapp-service  --timeout=300s
kubectl rollout status deployment/frontend        --timeout=300s

echo ""
echo "✅ Deployment complete!"
echo ""
echo "External IP (may take 1-2 min to provision):"
kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo ""
