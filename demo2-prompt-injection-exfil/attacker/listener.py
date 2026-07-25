#!/usr/bin/env python3
"""
Demo 2 — The attacker's collection server.

Runs in a SEPARATE namespace ('attacker') to make the trust boundary obvious.
Anything POSTed here is "off the cluster" as far as the victim is concerned.
It just logs whatever it receives, loudly, so the audience sees the stolen
secret land. Pure stdlib.
"""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

captured = []


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8", "replace")
        try:
            data = json.loads(raw)
        except Exception:
            data = {"raw": raw}
        captured.append(data)
        print("\n" + "!" * 70, flush=True)
        print("!!!  ATTACKER RECEIVED EXFILTRATED DATA  !!!", flush=True)
        print("!" * 70, flush=True)
        print(json.dumps(data, indent=2), flush=True)
        print(f"(total captures so far: {len(captured)})\n", flush=True)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"captured": captured}).encode())

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print("[attacker] listener up on :8080 — waiting for stolen secrets...", flush=True)
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
