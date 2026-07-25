#!/usr/bin/env python3
"""
BONUS demo (requires a REAL NVIDIA GPU + PyTorch/CUDA — NOT part of the two
mandatory local demos).

Point: GPU *time-slicing* on Kubernetes gives you sharing but NO memory
isolation. Two pods time-slicing the same physical GPU take turns on the same
VRAM. If a "tenant A" workload leaves secrets in VRAM and the allocator hands
that memory to "tenant B" without zeroing, tenant B can read the residue.
MIG (hardware partitioning) does not have this problem; time-slicing and MPS do.

This script illustrates the *residue* idea within a single process (safe,
portable): write a recognizable pattern to GPU memory, free it, then allocate
fresh GPU tensors and look for the pattern in the raw bytes. On real
multi-tenant time-slicing the two halves run in different pods.

Run (on a GPU box):  pip install torch ; python3 vram_residue_check.py

DISCLAIMER: illustrative. Driver/allocator behavior varies; a clean run does not
prove your platform is safe, and a hit here is a within-process artifact. The
security lesson — "time-slicing != isolation" — is the takeaway, not this exact
output.
"""
import sys

try:
    import torch
except Exception:
    print("PyTorch not installed / no GPU. This bonus needs a real CUDA GPU.")
    print("Lesson stands: time-slicing shares VRAM with no isolation; prefer MIG")
    print("for multi-tenant, and treat time-sliced GPUs as a shared trust domain.")
    sys.exit(0)

if not torch.cuda.is_available():
    print("No CUDA GPU visible. Nothing to demonstrate here.")
    sys.exit(0)

SENTINEL = 0x7E571337  # recognizable 'TEST' marker


def writer():
    print("[tenant A] writing a secret pattern into VRAM, then 'freeing' it")
    t = torch.full((1024, 1024), float(SENTINEL), device="cuda", dtype=torch.float32)
    _ = t.sum().item()          # force allocation/use
    del t                        # 'free' — but VRAM is not necessarily zeroed
    torch.cuda.empty_cache()


def reader():
    print("[tenant B] allocating fresh VRAM and scanning it for tenant A's residue")
    probe = torch.empty((1024, 1024), device="cuda", dtype=torch.float32)
    vals = probe.flatten()
    hits = int((vals == float(SENTINEL)).sum().item())
    print(f"[tenant B] sentinel matches found in freshly-allocated VRAM: {hits}")
    if hits:
        print("[result ] ⚠  residue observed — this is why time-slicing is NOT isolation")
    else:
        print("[result ] no residue this run (allocator/driver dependent) — lesson unchanged")


if __name__ == "__main__":
    print("=" * 68)
    print(" GPU time-slicing has NO memory isolation (illustrative)")
    print("=" * 68)
    writer()
    reader()
    print("\nOn Kubernetes: use MIG (nvidia.com/mig-*) for hardware-isolated tenants;")
    print("treat time-sliced / MPS GPUs as a single shared trust domain.")
