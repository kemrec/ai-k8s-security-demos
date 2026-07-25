#!/usr/bin/env bash
# Demo 1, Act 3 — Prove the difference at runtime.
#
# Shows that the NAIVE pod hands an attacker root + a writable filesystem,
# while the HARDENED pod denies both — yet still serves the model.
set -uo pipefail
NS=demo1

echo "############################################################"
echo "# NAIVE pod — what an attacker gets after popping the model #"
echo "############################################################"
NAIVE=$(kubectl -n $NS get pod -l app=ollama-naive -o jsonpath='{.items[0].metadata.name}')
echo "== whoami inside naive pod =="
kubectl -n $NS exec "$NAIVE" -- id || true
echo "== can I write to the root filesystem? (persistence / tool-drop) =="
kubectl -n $NS exec "$NAIVE" -- sh -c 'echo pwned > /malware && echo "WROTE /malware — root FS is writable"' || true
echo "== am I privileged? (host device / escape surface) =="
kubectl -n $NS exec "$NAIVE" -- sh -c 'capsh --print 2>/dev/null | grep -i current || cat /proc/1/status | grep -i cap' || true

echo
echo "################################################################"
echo "# HARDENED pod — same attacker, same image, almost nothing gained #"
echo "################################################################"
HARD=$(kubectl -n $NS get pod -l app=ollama-hardened -o jsonpath='{.items[0].metadata.name}')
echo "== whoami inside hardened pod =="
kubectl -n $NS exec "$HARD" -- id || true
echo "== try to write to the root filesystem (should FAIL: read-only) =="
kubectl -n $NS exec "$HARD" -- sh -c 'echo pwned > /malware 2>&1 || echo "DENIED — root FS is read-only"' || true
echo "== try to escalate to root (should FAIL: allowPrivilegeEscalation=false, non-root) =="
kubectl -n $NS exec "$HARD" -- sh -c 'id -u' || true

echo
echo "########################################################"
echo "# ...and the HARDENED pod still answers inference calls #"
echo "########################################################"
kubectl -n $NS exec "$HARD" -- sh -c \
  'ollama list >/dev/null 2>&1 && echo "ollama up" ; \
   curl -s http://localhost:11434/api/generate -d "{\"model\":\"'"${MODEL:-qwen2.5:0.5b}"'\",\"prompt\":\"Reply with exactly one word: SECURE\",\"stream\":false}" \
   | (grep -o "\"response\":\"[^\"]*\"" || echo "(model not pulled yet — run run-demo1.sh)")'

echo
echo "Takeaway: hardening did not cost us functionality. It cost the attacker their foothold."
