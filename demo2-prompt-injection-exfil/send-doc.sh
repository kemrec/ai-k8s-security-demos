#!/usr/bin/env bash
# Helper: POST a document file to the agent and pretty-print the result.
# Uses the NodePort mapped to your laptop (http://localhost:30080). If that is
# not reachable, falls back to an in-cluster curl pod.
set -euo pipefail
DOC="${1:?usage: send-doc.sh <path-to-document>}"
URL="http://localhost:30080/summarize"

if curl -s -o /dev/null -m 2 "http://localhost:30080/healthz" 2>/dev/null; then
  curl -s -X POST "$URL" --data-binary "@${DOC}" | sed 's/^/    /'
else
  echo "    (NodePort not reachable from host; using in-cluster curl pod)"
  kubectl -n ai-demo run tmp-curl-$RANDOM --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- \
    -s -X POST "http://agent.ai-demo.svc.cluster.local:8000/summarize" \
    --data-binary "$(cat "${DOC}")" | sed 's/^/    /'
fi
echo
