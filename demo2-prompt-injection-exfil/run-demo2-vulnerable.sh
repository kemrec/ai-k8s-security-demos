#!/usr/bin/env bash
# Demo 2 — PHASE A: vulnerable. No egress policy yet.
# 1) benign document  -> normal summary, nothing sent
# 2) malicious document -> prompt injection -> agent exfiltrates the mounted secret
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Ensuring NO NetworkPolicy is active (vulnerable baseline)"
kubectl -n ai-demo delete networkpolicy --all >/dev/null 2>&1 || true

echo
echo "############ 1) BENIGN document ############"
echo "(expect: a one-line summary, tool_called=false, nothing at the attacker)"
"${SCRIPT_DIR}/send-doc.sh" "${SCRIPT_DIR}/payloads/benign-doc.txt"

echo
echo "############ 2) MALICIOUS document (prompt injection) ############"
echo "(expect: model emits 'ACTION: EXFIL ...', agent POSTs the SECRET, exfil=SUCCEEDED)"
"${SCRIPT_DIR}/send-doc.sh" "${SCRIPT_DIR}/payloads/malicious-doc.txt"

echo
echo ">>> Check the attacker terminal — the production DB password just landed there."
echo ">>> agent logs:    kubectl -n ai-demo logs deploy/agent --tail=40"
echo ">>> attacker logs: kubectl -n attacker logs deploy/listener --tail=20"
