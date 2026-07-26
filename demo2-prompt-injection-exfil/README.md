# Demo 2 — Prompt Injection → Data Exfiltration, Stopped with NetworkPolicy

**Security question:** Fooling the LLM may be *unavoidable*. So how do we
guarantee that even when the model is fooled, data still can't get **out** of
the pod?

This is an end-to-end scenario showing how an AI-specific attack (prompt
injection) gets brought under control by a classic Kubernetes primitive
(egress NetworkPolicy). **Defense in depth:** model-layer defenses working
together with infrastructure-layer defenses.

## Architecture

```
document ──► agent ──► Ollama (LLM) ──► model output
│ │
│ looks for an ACTION: │
│ EXFIL line ◄───────┘
│
└─► if found: reads the MOUNTED SECRET and POSTs it to <url>
```

- The **agent** is a "confused deputy": it holds a mounted Secret (ambient
  authority), and the LLM's output decides what it does with it.
- The **attacker** sits in a separate namespace; a simple listener that
  captures the exfiltrated data.
- The flaw is architectural — not the model's "fault." OWASP **LLM01** (Prompt
  Injection) → **LLM02/LLM06** (sensitive data disclosure).

## Prerequisites
- A kind cluster + **Calico** (the CNI that actually *enforces* NetworkPolicy).
  `../cluster/setup-kind.sh` sets this up.
- Before going on stage, always check: `../cluster/verify-netpol.sh` → you
  should see `ENFORCED ✅`.
- Model: `llama3.2:1b` (small, but complies with the injection reliably).
  Alternative: `qwen2.5:1.5b`.

## Setup (once, before the talk)
```bash
./setup-demo2.sh                       # sets everything up + pulls the model
kubectl -n attacker logs -f deploy/listener   # the attacker's inbox, in a second terminal
```

## Stage flow
```bash
# PHASE A — vulnerable
./run-demo2-vulnerable.sh
#   1) benign document -> normal summary, nothing gets sent
#   2) malicious document -> the model produces 'ACTION: EXFIL ...' -> the agent leaks the SECRET
#   => the prod DB password shows up in the attacker's terminal 💥

# PHASE B — defended
./run-demo2-defended.sh
#   the same malicious document is sent again
#   the model is fooled again, the agent tries again, BUT egress is blocked => exfil=BLOCKED ✅
```

## Why this punchline works
- **The model is fooled again.** Nothing changed — the injection still works.
- The only thing that changed is the **blast radius**: thanks to
  `default-deny egress`, the secret couldn't leave the pod. The agent can only
  reach DNS and Ollama; the path to the attacker's listener is closed.
- The lesson: you may not be able to block prompt injection 100% of the time,
  but with **least-privilege egress + tightly scoped secret mounts** you can
  render it harmless.

## Defense points in the manifests
- `netpol/00-default-deny-egress.yaml` — the keystone; all egress closed for every pod.
- `netpol/10-allow-dns.yaml` — DNS only. (Resolving a name ≠ being able to connect to it.)
- `netpol/20-allow-ollama.yaml` — the agent can only reach Ollama, and only on port 11434.
- Further hardening: don't mount the Secret this broadly in the first place;
  allow egress destination by destination; wire unexpected outbound
  connections up to runtime alerting (Falco/Tetragon).

## A note on determinism (for a smooth stage run)
Small models are probabilistic. `llama3.2:1b` reliably complies with the
injection in this simple `ACTION:` format; even so, if it doesn't comply, the
agent honestly reports "no tool call — nothing sent" (it never makes things
up). If it doesn't comply, resend it once or twice, or use
`MODEL=qwen2.5:1.5b`. The raw model output is printed to the logs, so the
audience can see the model actually produce the malicious line.

## Cleanup
```bash
kubectl delete ns ai-demo attacker
```
