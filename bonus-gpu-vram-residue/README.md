# Bonus — Why GPU Time-Slicing Doesn't Give You Isolation (requires a real GPU)

This is **not part of the two required local demos**; it's extra for anyone
who wants to show it on a machine with a GPU.

**The message:** Kubernetes has three ways to share a GPU, and they are not
equal from a security standpoint:

| Method | Memory isolation | Fault isolation | When to use |
|--------|-------------------|------------------|----------|
| **Time-slicing** | ❌ none | ❌ none | Trusted/single-tenant, for throughput |
| **MPS** | ❌ weak | ❌ (one client crashing affects others) | Trusted CUDA workloads |
| **MIG** | ✅ hardware | ✅ hardware | Multi-tenant, SLA, isolation |

Time-slicing shares the same physical GPU in turns; if VRAM isn't zeroed, one
tenant's residue can leak to another. `vram_residue_check.py` brings this idea
to life inside a single process (safe, portable).

```bash
pip install torch
python3 vram_residue_check.py
```

**Kubernetes takeaway:** if you need multi-tenant isolation, use MIG
(resources like `nvidia.com/mig-1g.10gb`). Treat time-sliced/MPS GPUs as **a
single shared trust zone**. Also consider `runtimeClassName: kata`/gVisor for
kernel-level isolation.

> Note: the ecosystem is moving toward **DRA** (Dynamic Resource Allocation);
> the NVIDIA DRA driver was donated to CNCF at KubeCon EU 2026. Worth knowing
> about DRA when setting up new GPU clusters.
