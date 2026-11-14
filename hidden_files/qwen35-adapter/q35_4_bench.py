#!/usr/bin/env python3
"""Q35-4a HTTP bench for the qwen35 CPU serve on the side port.

Modes:
  resident  -- health + two-turn resident chat; replies compared
               against the in-process reference log (R1=/R2= lines).
  fresh     -- sends ONLY the turn-2 full-history request (with the
               same session_id) to a FRESH instance; its reply must
               DIFFER from the resident R2 (no resident state).
"""
import json, sys, urllib.request

BASE = "http://127.0.0.1:18435"
KEY = open("/tmp/q354-key.txt").read().strip()
MODEL = "aesir_engine/tests/fixtures/qwen35_forward.gguf"
SYSTEM = "You are a toy test assistant."
U1 = "alpha bravo charlie"
U2 = "delta echo foxtrot"

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
    for line in open("/home/volmarr/aesir-hipserve/hidden_files/qwen35-adapter/q35-4-session-test.log"):
        if line.startswith("R1="): r1 = line[3:].rstrip("\n").replace("<NL>", "\n")
        elif line.startswith("R2="): r2 = line[3:].rstrip("\n").replace("<NL>", "\n")
    return r1, r2

S = {"role": "system", "content": SYSTEM}
A1 = {"role": "user", "content": U1}
A2 = {"role": "user", "content": U2}
mode = sys.argv[1]
if mode == "resident":
    status, health = req("/health")
    print("HEALTH status=%d body=%s" % (status, json.dumps(health)))
    caps = health["capabilities"]
    assert health["profile"] == "qwen35" and health["backend"] == "cpu"
    assert caps["session_residency"] is True and caps["exact_prefix_reuse"] is False
    assert caps["experimental_admission"] is True
    print("HEALTH CAPS PASS: profile=qwen35 backend=cpu residency=true exact_prefix_reuse=false experimental=true")
    r1ref, r2ref = reference()
    st1, r1, u1u = chat([S, A1], "q35-4a-proof")
    print("T1 status=%d usage=%s reply=%r" % (st1, json.dumps(u1u), r1))
    assert st1 == 200 and r1 == r1ref, "turn1 != in-process reference"
    print("T1 MATCHES REFERENCE")
    st2, r2, u2u = chat([S, A1, {"role": "assistant", "content": r1}, A2], "q35-4a-proof")
    print("T2 status=%d usage=%s reply=%r" % (st2, json.dumps(u2u), r2))
    assert st2 == 200 and r2 == r2ref, "resident turn2 != in-process A+B reference"
    assert u2u["reused_prompt_tokens"] > 0, "resident turn2 reused no prompt tokens"
    print("T2 MATCHES REFERENCE; RESIDENCY usage: prompt_tokens=%d reused=%d evaluated=%d" % (
        u2u["prompt_tokens"], u2u["reused_prompt_tokens"], u2u["prompt_tokens"] - u2u["reused_prompt_tokens"]))
    print("Q35-4a HTTP resident bench: ALL PASS")
elif mode == "fresh":
    r1ref, r2ref = reference()
    st, r2f, uf = chat([S, A1, {"role": "assistant", "content": r1ref}, A2], "q35-4a-proof")
    print("FRESH T2 status=%d usage=%s reply=%r" % (st, json.dumps(uf), r2f))
    assert st == 200
    assert uf["reused_prompt_tokens"] == 0
    if r2f == r2ref:
        print("WARNING: fresh-instance continuation EQUALS resident R2 (residency not distinguishable with these prompts)")
        sys.exit(2)
    print("FRESH != RESIDENT: fresh-instance continuation differs from resident R2 as required")
    print("Q35-4a HTTP fresh-control bench: ALL PASS")
