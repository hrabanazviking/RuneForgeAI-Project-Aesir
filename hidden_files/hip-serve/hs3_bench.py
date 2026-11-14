#!/usr/bin/env python3
"""HS-3 two-turn KV bench against the native Aesir serve on :18434.
Turn 1: fresh prompt. Turn 2: append-only history (turn-1 prompt + reply +
new question), same system -> prefix reuse should cover turn 1.
Turn 3 (control): same history, changed system -> reuse should collapse."""
import json
import time
import urllib.request

BASE = "http://127.0.0.1:18434"
with open("/home/volmarr/.config/aesir/service.key", "r", encoding="utf-8") as f:
    KEY = f.read().strip()

SYSTEM = ("You are a helpful local assistant. Keep answers concise and "
          "remember the conversation accurately.")
P1 = ("My name is Volmarr, and my favourite colour is purple. "
      "Acknowledge this briefly.")
P2 = "What is my name, and what is my favourite colour? Answer briefly."


def call(path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(BASE + path, data=data, method="GET" if data is None else "POST")
    req.add_header("Authorization", "Bearer " + KEY)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    started = time.time()
    with urllib.request.urlopen(req, timeout=180) as resp:
        body = resp.read().decode()
    return json.loads(body), (time.time() - started) * 1000.0


def turn(label, prompt, system):
    payload = {"prompt": prompt, "system": system, "max_tokens": 64,
               "temperature": 0, "seed": 42, "stream": False}
    body, wall_ms = call("/v1/generate", payload)
    pt = body.get("prompt_tokens")
    rt = body.get("reused_prompt_tokens")
    ev = None if pt is None or rt is None else pt - rt
    print(f"{label}: prompt_tokens={pt} reused={rt} evaluated={ev} "
          f"generated={body.get('generated_tokens')} "
          f"prefill_ms={body.get('timings_ms', {}).get('prefill')} "
          f"decode_ms={body.get('timings_ms', {}).get('decode')} "
          f"wall_ms={wall_ms:.0f} finish={body.get('finish_reason')}")
    print(f"{label} text: {body.get('text', '')!r}")
    return body


health, _ = call("/health")
print("health:", json.dumps(health))

t1 = turn("turn1", P1, SYSTEM)
reply = t1.get("text", "")
history = P1 + "\n" + reply + "\n" + P2
t2 = turn("turn2", history, SYSTEM)
t3 = turn("turn3-control-changed-system", history, "Answer accurately and briefly.")
print("BENCH DONE")
