# AI on Kubernetes — Security Demos

> Live demo kit for the talk "AI with Containers: How Do AI and GPU Workloads
> Run on Kubernetes?" **Cloud Native Ankara.** Told through a security lens.

Both required demos run **fully locally** (kind + Docker, **no GPU required**,
CPU is enough) and use lightweight **Ollama** models. There's also a bonus
that requires a real GPU.

## Contents

| Folder | Demo | Security theme |
|--------|------|-----------------|
| `demo1-supply-chain-hardening/` | **Trojan model + pod hardening** | Supply chain (image + model), runtime hardening — OWASP LLM03 |
| `demo2-prompt-injection-exfil/`  | **Prompt injection → data exfiltration, stopped with NetworkPolicy** | Prompt injection, data exposure, egress isolation — OWASP LLM01/LLM02 |
| `bonus-gpu-vram-residue/` | (optional, real GPU) lack of time-slicing isolation | GPU multi-tenant isolation (MIG vs time-slicing) |
| `cluster/` | kind + Calico setup, NetworkPolicy smoke test | Infrastructure |

## Prerequisites

- **Docker** (kind runs on top of this)
- **kind** (Kubernetes-in-Docker) — https://kind.sigs.k8s.io
- **kubectl**
- **python3** (for Demo 1 Act 2; also works without a cluster)
- Optional: **trivy** (image scanning), `pip install safetensors numpy` (for the safetensors demo)
- Internet: only needed during setup (pulling images + the lightweight model). The
  demo flow itself runs offline — Demo 2's whole point is cutting off egress anyway.

RAM recommendation: ~8 GB. Models: `qwen2.5:0.5b` (Demo 1), `llama3.2:1b` (Demo 2).

## Quick start

```bash
# 0) Cluster + Calico (the CNI that enforces NetworkPolicy)
cd cluster
./setup-kind.sh
./verify-netpol.sh          # you should see 'ENFORCED ✅' — a prerequisite for Demo 2
cd ..

# 1) Demo 1 — supply chain + hardening
cd demo1-supply-chain-hardening
./run-demo1.sh
cd ..

# 2) Demo 2 — prompt injection -> exfil -> NetworkPolicy
cd demo2-prompt-injection-exfil
./setup-demo2.sh
# second terminal: kubectl -n attacker logs -f deploy/listener
./run-demo2-vulnerable.sh   # exfil SUCCEEDS 💥
./run-demo2-defended.sh     # exfil BLOCKED ✅
cd ..

# Cleanup
cd cluster && ./teardown.sh
```

Or simply `make setup && make demo1 && make demo2 && make clean`.

## Disclaimer

All payloads are **harmless** (they write to a file / print a log instead of
opening a reverse shell). Run this only on your own local cluster, for
educational purposes.
