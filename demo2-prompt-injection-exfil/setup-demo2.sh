#!/usr/bin/env bash
# Demo 2 setup — deploy Ollama + agent + attacker listener, pull the light model.
# Run this ONCE before the talk. Model pull needs internet (done now, before we
# apply the egress lock-down).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL="${MODEL:-llama3.2:1b}"

echo "==> namespaces + secret"
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"
kubectl apply -f "${SCRIPT_DIR}/attacker/deployment.yaml"   # creates attacker ns too

echo "==> code as ConfigMaps (no image build, no registry)"
kubectl -n ai-demo   create configmap agent-code    --from-file=agent.py="${SCRIPT_DIR}/agent/agent.py"        --dry-run=client -o yaml | kubectl apply -f -
kubectl -n attacker  create configmap listener-code --from-file=listener.py="${SCRIPT_DIR}/attacker/listener.py" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Ollama + agent + listener"
kubectl apply -f "${SCRIPT_DIR}/ollama.yaml"
kubectl apply -f "${SCRIPT_DIR}/agent/deployment.yaml"

echo "==> waiting for Ollama"
kubectl -n ai-demo rollout status deploy/ollama --timeout=240s

echo "==> pulling light model '${MODEL}' (needs internet; do this before lock-down)"
kubectl -n ai-demo exec deploy/ollama -- ollama pull "${MODEL}"

echo "==> waiting for agent + listener"
kubectl -n ai-demo  rollout status deploy/agent    --timeout=180s
kubectl -n attacker rollout status deploy/listener --timeout=180s

echo
echo "Ready. Watch the attacker's inbox in a second terminal:"
echo "    kubectl -n attacker logs -f deploy/listener"
echo "Then:  ./run-demo2-vulnerable.sh   and later   ./run-demo2-defended.sh"
