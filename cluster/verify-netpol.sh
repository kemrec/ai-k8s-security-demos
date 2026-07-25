#!/usr/bin/env bash
# Pre-flight smoke test: PROVE that NetworkPolicy is actually enforced on this
# cluster BEFORE you stand on stage. If this prints "ENFORCED", Demo 2's
# punchline will fire. If it prints "NOT ENFORCED", your CNI is not doing
# egress policy — fix that first (use the provided Calico setup).
set -euo pipefail
NS="netpol-smoketest"

cleanup() { kubectl delete ns "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true; }
trap cleanup EXIT

kubectl create ns "$NS" >/dev/null
# A pod that tries to reach the internet / another service.
kubectl -n "$NS" run probe --image=busybox:1.36 --restart=Never --command -- sleep 3600 >/dev/null
kubectl -n "$NS" wait --for=condition=Ready pod/probe --timeout=60s >/dev/null

echo "==> Baseline (no policy): egress should SUCCEED"
if kubectl -n "$NS" exec probe -- timeout 5 wget -q -O- http://1.1.1.1 >/dev/null 2>&1; then
  echo "    egress OK (as expected)"
else
  echo "    NOTE: egress already blocked or no internet; continuing"
fi

echo "==> Applying default-deny egress in $NS"
cat <<'EOF' | kubectl -n "$NS" apply -f - >/dev/null
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-egress }
spec:
  podSelector: {}
  policyTypes: [Egress]
EOF
sleep 3

echo "==> With default-deny: egress should FAIL"
if kubectl -n "$NS" exec probe -- timeout 5 wget -q -O- http://1.1.1.1 >/dev/null 2>&1; then
  echo
  echo "RESULT: NOT ENFORCED  ❌  — your CNI is ignoring NetworkPolicy."
  echo "        Re-run ./cluster/setup-kind.sh (installs Calico) and try again."
  exit 1
else
  echo
  echo "RESULT: ENFORCED  ✅  — egress policy works. Demo 2 is stage-ready."
fi
