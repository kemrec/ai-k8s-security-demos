#!/usr/bin/env bash
# Demo 2 — PHASE B: defended. Apply default-deny egress + least-privilege allows.
# The model is STILL injected, the agent STILL tries to exfiltrate — but the
# network won't let the secret leave the pod. Defense in depth.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Applying egress NetworkPolicies (default-deny + DNS + Ollama only)"
kubectl apply -f "${SCRIPT_DIR}/netpol/00-default-deny-egress.yaml"
kubectl apply -f "${SCRIPT_DIR}/netpol/10-allow-dns.yaml"
kubectl apply -f "${SCRIPT_DIR}/netpol/20-allow-ollama.yaml"
echo "    (giving the CNI a couple of seconds to program the policy)"
sleep 4

echo
echo "############ Re-sending the SAME malicious document ############"
echo "(expect: model STILL injected, agent STILL tries — but exfil=BLOCKED)"
"${SCRIPT_DIR}/send-doc.sh" "${SCRIPT_DIR}/payloads/malicious-doc.txt"

echo
echo ">>> The model was fooled exactly as before. The difference is the blast radius:"
echo ">>> the secret never left the pod. Nothing new at the attacker terminal."
echo ">>> agent logs: kubectl -n ai-demo logs deploy/agent --tail=20   (look for 'EXFIL FAILED')"
