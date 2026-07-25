#!/usr/bin/env bash
# Demo 1 driver — runs the whole supply-chain + hardening story end to end.
#   Act 1: scan the image (supply chain, image layer)
#   Act 2: poisoned pickle vs safetensors (supply chain, model layer)
#   Act 3: deploy naive + hardened, prove the runtime difference
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL="${MODEL:-qwen2.5:0.5b}"     # tiny, fast; good enough to prove "it still serves"
NS=demo1

pause() { echo; read -rp "  [enter] to continue..."; echo; }

echo "=================== ACT 1 — SUPPLY CHAIN: IMAGE ==================="
"${SCRIPT_DIR}/trivy-scan.sh" || echo "(trivy not installed — skipping live scan)"
pause

echo "=================== ACT 2 — SUPPLY CHAIN: MODEL =================="
python3 "${SCRIPT_DIR}/malicious_pickle_poc.py"
echo
python3 "${SCRIPT_DIR}/safetensors_safe_demo.py" || true
pause

echo "=================== ACT 3 — RUNTIME HARDENING ===================="
echo "==> deploying naive + hardened Ollama"
kubectl apply -f "${SCRIPT_DIR}/01-ollama-naive.yaml"
kubectl apply -f "${SCRIPT_DIR}/02-ollama-hardened.yaml"
kubectl -n $NS rollout status deploy/ollama-naive --timeout=180s
kubectl -n $NS rollout status deploy/ollama-hardened --timeout=180s

echo "==> pulling the light model '${MODEL}' into the HARDENED pod"
HARD=$(kubectl -n $NS get pod -l app=ollama-hardened -o jsonpath='{.items[0].metadata.name}')
kubectl -n $NS exec "$HARD" -- ollama pull "${MODEL}"
pause

MODEL="${MODEL}" "${SCRIPT_DIR}/verify-hardening.sh"

echo
echo "Cleanup with:  kubectl delete ns ${NS}"
