#!/usr/bin/env bash
set -euo pipefail
kind delete cluster --name ai-sec
echo "Cluster 'ai-sec' deleted."
