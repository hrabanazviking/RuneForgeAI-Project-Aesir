#!/usr/bin/env python3
"""QS-4.4 serve smoke client: POST /v1/generate on 127.0.0.1:18437.
Key read in-process from ~/.config/aesir/service.key, never printed.
Usage: qs4_smoke.py <tag> <min_p> <repeat_penalty>"""
import json, sys, urllib.request
BASE = "http://127.0.0.1:18437"
KEY = open("/home/volmarr/.config/aesir/service.key").read().strip()
def gen(tag, min_p, rep):
    body = {"prompt": "The old lighthouse keeper", "max_tokens": 24,
            "temperature": 1.0, "top_k": 256, "top_p": 1.0,
            "seed": 42, "min_p": min_p, "repeat_penalty": rep}
    r = urllib.request.Request(BASE + "/v1/generate", data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=300) as resp:
        raw = resp.read().decode("utf-8", "replace")
    print("SMOKE %s http-ok min_p=%s rep=%s body=%s" % (tag, min_p, rep, raw[:400]), flush=True)
    return raw
if __name__ == "__main__":
    gen(sys.argv[1], float(sys.argv[2]), float(sys.argv[3]))
