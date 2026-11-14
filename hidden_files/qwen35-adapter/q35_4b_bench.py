#!/usr/bin/env python3
"""Q35-4b HTTP bench: REAL 27B file through the Qwen35 CPU session in
Q8_0-resident mode on side port 18435.

Order: health -> resident turn 1 -> resident turn 2 -> intervening
different-session request -> stateless full-history resend (Q35-5
snapshot reuse) -> R1 long-prompt exchange. No sampling fields are
sent in any request: the serve's own defaults apply (R2). Replies are
compared against the in-process reference logs produced by
ref_qwen35_realfile_q35_4b (turns + long modes).
"""
import json, sys, time, urllib.request

BASE = "http://127.0.0.1:18435"
KEY = open("/tmp/q354b-key.txt").read().strip()
MODEL = "/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf"
AD = "/home/volmarr/aesir-q35-4b/hidden_files/qwen35-adapter"
SYSTEM = "You are a helpful assistant."
U1 = "What is the capital of France? Name one famous museum there."
U2 = "What language do most people speak in that city?"
LONG = open(AD + "/q35-4b-long-prompt.txt").read()

def req(path, body=None, timeout=900):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, headers={
        "Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(r, timeout=timeout) as resp:
        out = resp.status, json.load(resp)
    return out[0], out[1], time.time() - t0

def chat(messages, session_id=None, max_tokens=32):
    body = {"model": MODEL, "messages": messages, "max_tokens": max_tokens}
    if session_id:
        body["session_id"] = session_id
    return req("/v1/chat/completions", body)

def ref_line(path, prefix):
    for line in open(path):
        if line.startswith(prefix):
            return line[len(prefix):].rstrip("\n").replace("<NL>", "\n")
    raise SystemExit("missing " + prefix + " in " + path)

R1 = ref_line(AD + "/q35-4b-ref-turns.log", "R1=")
R2 = ref_line(AD + "/q35-4b-ref-turns.log", "R2=")
POS1 = int(ref_line(AD + "/q35-4b-ref-turns.log", "POS1="))
LONG_R = ref_line(AD + "/q35-4b-ref-long.log", "LONG_R=")

def S(): return {"role": "system", "content": SYSTEM}
def U(c): return {"role": "user", "content": c}
def A(c): return {"role": "assistant", "content": c}

# --- health ---
status, health, wall = req("/health")
print("HEALTH status=%d wall=%.2fs body=%s" % (status, wall, json.dumps(health)))
caps = health["capabilities"]
assert health["profile"] == "qwen35", health
assert health["backend"] == "cpu", health
assert caps["session_residency"] is True, caps
assert caps["exact_prefix_reuse"] is True, caps
assert caps.get("exact_prefix_reuse_detail") == "snapshot-based at committed turn boundaries only", caps
assert caps.get("weight_load_mode") == "q8_0_resident", caps
assert caps.get("experimental_admission") is False, caps
print("HEALTH TRUTH PASS: profile=qwen35 backend=cpu residency=true exact_prefix_reuse=true(snapshot detail) weight_load_mode=q8_0_resident experimental=false")

# --- resident turn 1 ---
st1, d1, w1 = chat([S(), U(U1)], "q35-4b-proof", 32)
r1 = d1["choices"][0]["message"]["content"]; u1u = d1["usage"]
print("T1 status=%d wall=%.2fs usage=%s reply=%r" % (st1, w1, json.dumps(u1u), r1))
assert st1 == 200 and r1 == R1, "turn1 != in-process reference"
print("T1 MATCHES REFERENCE; eval_tok/s=%.2f" % (u1u["completion_tokens"] / w1))

# --- resident turn 2 ---
st2, d2, w2 = chat([S(), U(U1), A(r1), U(U2)], "q35-4b-proof", 32)
r2 = d2["choices"][0]["message"]["content"]; u2u = d2["usage"]
print("T2 status=%d wall=%.2fs usage=%s reply=%r" % (st2, w2, json.dumps(u2u), r2))
assert st2 == 200 and r2 == R2, "resident turn2 != in-process reference"
assert u2u["reused_prompt_tokens"] == POS1, "resident reuse != committed turn-1 position"
print("T2 MATCHES REFERENCE; RESIDENT reuse: prompt=%d reused=%d evaluated=%d" % (
    u2u["prompt_tokens"], u2u["reused_prompt_tokens"], u2u["prompt_tokens"] - u2u["reused_prompt_tokens"]))

# --- intervening different-session request (destroys residency) ---
stx, dx, wx = chat([U("Say the word hello.")], "q35-4b-other", 8)
print("INTERVENE status=%d wall=%.2fs usage=%s reply=%r" % (stx, wx, json.dumps(dx["usage"]), dx["choices"][0]["message"]["content"]))
assert stx == 200

# --- stateless resend: snapshot reuse ---
st3, d3, w3 = chat([S(), U(U1), A(r1), U(U2)], "q35-4b-proof", 32)
r3 = d3["choices"][0]["message"]["content"]; u3u = d3["usage"]
print("STATELESS status=%d wall=%.2fs usage=%s reply=%r" % (st3, w3, json.dumps(u3u), r3))
assert st3 == 200 and r3 == R2, "stateless resend reply != resident reference"
assert u3u["reused_prompt_tokens"] == POS1, "stateless reuse != turn-1 boundary"
print("STATELESS MATCHES REFERENCE via SNAPSHOT: prompt=%d reused=%d evaluated=%d" % (
    u3u["prompt_tokens"], u3u["reused_prompt_tokens"], u3u["prompt_tokens"] - u3u["reused_prompt_tokens"]))

# --- R1 long-prompt exchange ---
st4, d4, w4 = chat([U(LONG)], None, 48)
r4 = d4["choices"][0]["message"]["content"]; u4u = d4["usage"]
print("LONG status=%d wall=%.2fs usage=%s" % (st4, w4, json.dumps(u4u)))
print("LONG REPLY=%r" % r4)
assert st4 == 200 and r4 == LONG_R, "long reply != in-process reference"
print("LONG MATCHES IN-PROCESS REFERENCE at prompt_tokens=%d" % u4u["prompt_tokens"])
print("Q35-4b HTTP real-file resident bench: ALL PASS")
