#!/usr/bin/env python3
"""Q35-6 HTTP bench for the qwen35 HIP serve on the side port.

One serve instance (--accel hip --profile qwen35
--experimental-qwen35), modes run in order by the driver:
  resident  -- health (backend hip, caps incl. weight_load_mode
               q8_0_resident) + two-turn resident chat; replies
               compared against the in-process HIP session
               reference (q35-6-hipsession.log R1=/R2=).
  stateless -- an intervening different-session request destroys
               residency; a full-history resend under the original
               session_id then restores the turn-1 snapshot:
               reused == POS1 (from the reference log), reply ==
               resident R2.
"""
import json, sys, urllib.request

BASE = "http://127.0.0.1:18435"
KEY = open("/tmp/q356-key.txt").read().strip()
MODEL = "aesir_engine/tests/fixtures/qwen35_forward.gguf"
SYSTEM = "You are a toy test assistant."
U1 = "alpha bravo charlie"
U2 = "delta echo foxtrot"
REF = "/home/volmarr/aesir-q35-6/hidden_files/qwen35-adapter/q35-6-hipsession.log"

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

def ref_line(prefix):
    for line in open(REF):
        if line.startswith(prefix):
            return line[len(prefix):].rstrip("\n").replace("<NL>", "\n")
    raise SystemExit("missing " + prefix + " in " + REF)

R1 = ref_line("R1=")
R2 = ref_line("R2=")
POS1 = int(ref_line("POS1="))
S = {"role": "system", "content": SYSTEM}
def U(c): return {"role": "user", "content": c}
def A(c): return {"role": "assistant", "content": c}

status, health = req("/health")
print("HEALTH status=%d body=%s" % (status, json.dumps(health)))
caps = health["capabilities"]
assert health["profile"] == "qwen35" and health["backend"] == "hip", health
assert caps["session_residency"] is True and caps["experimental_admission"] is True
assert caps["exact_prefix_reuse"] is True
assert caps.get("exact_prefix_reuse_detail") == "snapshot-based at committed turn boundaries only", caps
assert caps.get("weight_load_mode") == "q8_0_resident", caps
print("HEALTH CAPS PASS: profile=qwen35 backend=hip residency=true exact_prefix_reuse=true(snapshot-based) experimental=true weight_load_mode=q8_0_resident")

st1, r1, uu1 = chat([S, U(U1)], "q35-6")
print("RESIDENT T1 status=%d usage=%s reply=%r" % (st1, json.dumps(uu1), r1))
assert st1 == 200 and r1 == R1, "turn1 != in-process HIP reference"
print("T1 MATCHES HIP REFERENCE")
st2, r2, uu2 = chat([S, U(U1), A(r1), U(U2)], "q35-6")
print("RESIDENT T2 status=%d usage=%s reply=%r" % (st2, json.dumps(uu2), r2))
assert st2 == 200 and r2 == R2, "resident turn2 != in-process HIP reference"
assert uu2["reused_prompt_tokens"] > 0, uu2
print("T2 MATCHES HIP REFERENCE; RESIDENCY usage: prompt_tokens=%d reused=%d evaluated=%d" % (
    uu2["prompt_tokens"], uu2["reused_prompt_tokens"], uu2["prompt_tokens"] - uu2["reused_prompt_tokens"]))

sti, ri, uui = chat([S, U("mike november oscar")], "q35-6-other")
print("INTERVENING status=%d usage=%s reply=%r" % (sti, json.dumps(uui), ri))
assert sti == 200
sts, rs, uus = chat([S, U(U1), A(r1), U(U2)], "q35-6")
print("STATELESS T2 status=%d usage=%s reply=%r" % (sts, json.dumps(uus), rs))
assert sts == 200 and rs == R2, "stateless snapshot reply != resident R2"
assert uus["reused_prompt_tokens"] == POS1, (uus, POS1)
print("STATELESS PASS: reused=%d (turn-1 snapshot boundary) reply==resident R2 (snapshot restore on the HIP session)" % uus["reused_prompt_tokens"])
print("Q35-6 HTTP HIP bench: ALL PASS")
