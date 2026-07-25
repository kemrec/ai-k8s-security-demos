#!/usr/bin/env bash
# Create the local kind cluster and install Calico (NetworkPolicy-enforcing CNI).
# Idempotent-ish: re-running recreates the cluster.
set -euo pipefail

CLUSTER_NAME="ai-sec"
CALICO_VERSION="v3.28.2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> [1/4] Preflight: docker, kind, kubectl"
for bin in docker kind kubectl; do
  command -v "$bin" >/dev/null 2>&1 || { echo "MISSING: $bin — install it first."; exit 1; }
done

echo "==> [2/4] Creating kind cluster '${CLUSTER_NAME}' (default CNI disabled)"
kind delete cluster --name "${CLUSTER_NAME}" >/dev/null 2>&1 || true
kind create cluster --config "${SCRIPT_DIR}/kind-config.yaml"

echo "==> [3/4] Installing Calico ${CALICO_VERSION} (enforces NetworkPolicy)"
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"

echo "    waiting for Calico to become ready (this can take ~1-2 min)..."
kubectl -n kube-system rollout status ds/calico-node --timeout=240s
kubectl -n kube-system rollout status deploy/calico-kube-controllers --timeout=240s
kubectl wait --for=condition=Ready nodes --all --timeout=180s

echo "==> [4/4] Cluster ready"
kubectl get nodes -o wide
echo
echo "Next:"
echo "  cd demo1-supply-chain-hardening && ./run-demo1.sh"
echo "  cd demo2-prompt-injection-exfil  && ./run-demo2-vulnerable.sh"
