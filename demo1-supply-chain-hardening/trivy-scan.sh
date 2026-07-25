#!/usr/bin/env bash
# Demo 1, Act 1 — SCAN the serving image before you trust it.
#
# The container image IS part of your AI supply chain. The base OS, the CUDA
# libs, the Python deps of vLLM/Triton — all of it can carry known CVEs.
# Trivy also detects secrets accidentally baked into layers.
#
# Requires: trivy (https://trivy.dev). Fully local; pulls the image once.
set -euo pipefail
IMAGE="${1:-ollama/ollama:0.6.5}"

command -v trivy >/dev/null 2>&1 || { echo "Install trivy first: https://trivy.dev/latest/getting-started/installation/"; exit 1; }

echo "==> Scanning ${IMAGE} for HIGH/CRITICAL CVEs + secrets"
trivy image \
  --scanners vuln,secret \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  "${IMAGE}"

echo
echo "==> Generating an SBOM (CycloneDX) — this is your image's ingredient list"
trivy image --format cyclonedx --output sbom-$(echo "${IMAGE}" | tr '/:' '__').json "${IMAGE}"
echo "    SBOM written. In production this feeds an AIBOM alongside your model card."
echo
echo "Talking point: a clean scan does NOT vouch for the *model weights* pulled at"
echo "runtime. Image scanning and model provenance are two different problems."
