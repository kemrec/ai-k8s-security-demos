# Demo 1 — Trojan Model + Pod Hardening (Supply Chain & Runtime)

**Security question:** What should we verify before trusting an AI serving pod,
and if that pod gets compromised, how do we narrow the blast radius?

This demo touches **two** layers of the AI supply chain, then shows **runtime**
hardening on top:

| Act | Layer | What we show |
|-----|--------|-----------------|
| 1 | Image (container) | CVE/secret scanning with Trivy + SBOM generation |
| 2 | Model artifact | **Code execution** via `pickle.load()` (OWASP LLM03) vs `safetensors` |
| 3 | Runtime (pod) | `naive` vs `hardened` pod — what does the attacker actually gain? |

> GPU connection: GPU serving pods are frequently run `privileged` to get
> `/dev/nvidia*` access. So the naive pod here is a direct mirror of a real
> GPU pod. The hardening recipe is the same too; on GPU you just add
> `resources.limits: nvidia.com/gpu` (or `nvidia.com/mig-1g.10gb`) and,
> preferably, `runtimeClassName: kata`.

## Prerequisites
- A running kind cluster (`../cluster/setup-kind.sh`)
- `kubectl`, `python3`
- Optional: `trivy` (for image scanning), `pip install safetensors numpy`

## Running it (single command)
```bash
./run-demo1.sh
```
If you'd rather go step by step:
```bash
# Act 1 — image supply chain
./trivy-scan.sh ollama/ollama:0.6.5

# Act 2 — model supply chain (these are fully local, no cluster needed)
python3 malicious_pickle_poc.py      # poisoned pickle -> code executes (harmless payload)
python3 safetensors_safe_demo.py     # safetensors -> the same attack is impossible

# Act 3 — runtime
kubectl apply -f 01-ollama-naive.yaml
kubectl apply -f 02-ollama-hardened.yaml
MODEL=qwen2.5:0.5b ./verify-hardening.sh
```

## Hardening checklist (line by line in the manifest)
- `runAsNonRoot: true`, a fixed `runAsUser` (not root)
- `allowPrivilegeEscalation: false`, `privileged: false`
- `readOnlyRootFilesystem: true` (+ a writable `emptyDir` only where actually needed)
- `capabilities.drop: ["ALL"]`
- `seccompProfile.type: RuntimeDefault`
- `resources.limits` (bound the DoS radius)
- Put authentication in front of the model (Ollama has **no** auth by default —
  CVE-2025-63389)

## Cleanup
```bash
kubectl delete ns demo1
```
