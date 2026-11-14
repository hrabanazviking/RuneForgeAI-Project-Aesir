#!/usr/bin/env python3
"""Q35-3r HTTP bench for the qwen35 CPU serve on the side port.

Modes:
  resident  -- serve started WITH --qwen35-resident: /health must
               report capabilities.weight_load_mode ==
               "q8_0_resident"; two-turn resident chat replies must
               equal the in-process reference (q35-3r-session-test.log
               R1=/R2= lines, produced by the Q35-4a session test).
  default   -- serve started WITHOUT the flag: /health must NOT
               carry a weight_load_mode key at all (payload
               unchanged from Q35-5), replies still equal reference.
"""
import json, sys, urllib.request

BASE = "http://127.0.0.1:18435"
KEY = open("/tmp/q353r-key.txt").read().strip()
MODEL = "aesir_engine/tests/fixtures/qwen35_forward.gguf"
SYSTEM = "You are a toy test assistant."
U1 = "alpha bravo charlie"
U2 = "delta echo foxtrot"
REFLOG = "/home/volmarr/aesir-q35-3r/hidden_files/qwen35-adapter/q35-3r-session-test.log"

def req(path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, headers={
        "Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=180) as resp:
        return resp.status, json.load(resp)

def chat(messages, session_id=None):
    body = {"model": MODEL, "messages": messages, "max_tokens": 16, "temperature": 0.0}
    if session_id:
        body["session_id"] = session_id
    status, data = req("/v1/chat/completions", body)
    return status, data["choices"][0]["message"]["content"], data["usage"]

def reference():
    r1 = r2 = None
    for line in open(REFLOG):
        if line.startswith("R1="): r1 = line[3:].rstrip("\n").replace("<NL>", "\n")
        elif line.startswith("R2="): r2 = line[3:].rstrip("\n").replace("<NL>", "\n")
    return r1, r2

S = {"role": "system", "content": SYSTEM}
A1 = {"role": "user", "content": U1}
A2 = {"role": "user", "content": U2}
mode = sys.argv[1]
status, health = req("/health")
print("HEALTH status=%d body=%s" % (status, json.dumps(health)))
caps = health["capabilities"]
assert health["profile"] == "qwen35" and health["backend"] == "cpu"
assert caps["session_residency"] is True and caps["experimental_admission"] is True
r1ref, r2ref = reference()
st1, r1, u1u = chat([S, A1], "q35-3r-proof")
print("T1 status=%d usage=%s reply=%r" % (st1, json.dumps(u1u), r1))
assert st1 == 200 and r1 == r1ref, "turn1 != in-process reference"
st2, r2, u2u = chat([S, A1, {"role": "assistant", "content": r1}, A2], "q35-3r-proof")
print("T2 status=%d usage=%s reply=%r" % (st2, json.dumps(u2u), r2))
assert st2 == 200 and r2 == r2ref, "resident turn2 != in-process reference"
assert u2u["reused_prompt_tokens"] > 0
if mode == "resident":
    assert caps.get("weight_load_mode") == "q8_0_resident", caps
    print("HEALTH MODE PASS: weight_load_mode=q8_0_resident reported under the resident opt-in")
    print("Q35-3r HTTP resident bench: ALL PASS")
elif mode == "default":
    assert "weight_load_mode" not in caps, caps
    print("HEALTH MODE PASS: no weight_load_mode key on the default load (payload unchanged)")
    print("Q35-3r HTTP default bench: ALL PASS")
else:
    raise SystemExit("unknown mode " + mode)
