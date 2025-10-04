#!/bin/bash
set -euo pipefail

NAMESPACE="$1"
DEPLOYMENT="$2"
TIMEOUT="${3:-180}"

kubectl wait --for=condition=Available deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout="${TIMEOUT}s"
echo "✅ Deployment $DEPLOYMENT in namespace $NAMESPACE is ready"
