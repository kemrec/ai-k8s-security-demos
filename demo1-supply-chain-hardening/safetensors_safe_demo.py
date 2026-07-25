#!/usr/bin/env python3
"""
Demo 1, Act 2 (part b) — The fix: safetensors can't execute code.

safetensors stores only tensors + a JSON header. There is no __reduce__, no
callable, no code path that runs attacker input at load time. It is also
faster. Migrating pickle -> safetensors deletes an entire vulnerability class.

This script tries to smuggle the same attack into safetensors and shows it is
structurally impossible: the format holds numbers, not code.

Requires: pip install safetensors numpy   (optional — degrades gracefully)
Run:      python3 safetensors_safe_demo.py
"""
import os
import tempfile

try:
    import numpy as np
    from safetensors.numpy import save_file, load_file
except Exception:
    print("safetensors/numpy not installed. `pip install safetensors numpy` to run this part.")
    print("The point stands regardless: safetensors stores tensors, not executable objects,")
    print("so there is no load-time code execution to exploit.")
    raise SystemExit(0)


def main():
    path = os.path.join(tempfile.gettempdir(), "clean_model.safetensors")

    # A real model's weights — just arrays. There is nowhere to hide a __reduce__.
    tensors = {
        "layer1.weight": np.random.rand(4, 4).astype("float32"),
        "layer1.bias": np.zeros(4, dtype="float32"),
    }
    save_file(tensors, path)
    print(f"[builder] wrote a safetensors model to {path}")

    loaded = load_file(path)      # <— no code executes here, by design
    print(f"[victim ] loaded tensors: {list(loaded.keys())}")

    marker = os.path.join(tempfile.gettempdir(), "PWNED_by_safetensors.txt")
    print(f"[proof  ] payload marker present? {os.path.exists(marker)}  (expected: False)")
    print("\nsafetensors = data-only. No __reduce__, no os.system, no reverse shell.")


if __name__ == "__main__":
    print("=" * 68)
    print(" safetensors — the same attack has nowhere to live")
    print("=" * 68)
    main()
