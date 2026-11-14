#!/usr/bin/env python3
"""Q35-6b HTTP bench: REAL 27B file through the Qwen35 HIP
session in resident mode on side port 18435 (experimental gate).

Same prompts as the Q35-4b CPU serve bench. Turn 1 carries max_tokens=32 (the Q35-4b CPU bench shape, so
the resident turn-2 stream is the proven one); turn 2 and the
stateless resend carry max_tokens=12 and must equal the CPU
reference R2 PREFIX (per-token decode concatenations prefix
exactly on a token-identical stream). NOTE: a length-truncated
turn 1 (6/12 tokens) makes the model re-answer Q1 on turn 2 --
proven model behavior on the truncated stream (Q35-6b notes),
not a device defect; the bench therefore uses the full 32.
Order: health -> resident T1 -> resident T2 (reuse) ->
intervening different-session request -> stateless full-history
resend (snapshot reuse == turn-1 boundary, reply == T2).
Walls and tok/s printed for every turn.
"""
import json, time, urllib.request

BASE = "http://127.0.0.1:18435"
KEY = open("/tmp/q356b-key.txt").read().strip()
MODEL = "/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf"
AD = "/home/volmarr/aesir-q35-6/hidden_files/qwen35-adapter"
SYSTEM = "You are a helpful assistant."
U1 = "What is the capital of France? Name one famous museum there."
U2 = "What language do most people speak in that city?"

def req(path, body=None, timeout=1200):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, headers={
        "Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(r, timeout=timeout) as resp:
        out = resp.status, json.load(resp)
    return out[0], out[1], time.time() - t0

def chat(messages, session_id=None, max_tokens=12):
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
def S(): return {"role": "system", "content": SYSTEM}
def U(c): return {"role": "user", "content": c}
def A(c): return {"role": "assistant", "content": c}

status, health, wall = req("/health")
print("HEALTH status=%d wall=%.2fs body=%s" % (status, wall, json.dumps(health)))
caps = health["capabilities"]
assert health["profile"] == "qwen35" and health["backend"] == "hip", health
assert caps["session_residency"] is True and caps["experimental_admission"] is True, caps
assert caps["exact_prefix_reuse"] is True, caps
assert caps.get("exact_prefix_reuse_detail") == "snapshot-based at committed turn boundaries only", caps
assert caps.get("weight_load_mode") == "q8_0_resident", caps
print("HEALTH CAPS PASS: backend=hip residency=true exact_prefix_reuse=true(snapshot-based) experimental=true weight_load_mode=q8_0_resident")

st1, d1, w1 = chat([S(), U(U1)], "q35-6b", max_tokens=32)
r1 = d1["choices"][0]["message"]["content"]; u1u = d1["usage"]
print("T1 status=%d wall=%.2fs usage=%s reply=%r" % (st1, w1, json.dumps(u1u), r1))
assert st1 == 200 and R1.startswith(r1) and r1 != "", "T1 not a prefix of the CPU reference R1"
print("T1 MATCHES CPU REFERENCE PREFIX; completion tok/s=%.3f" % (u1u["completion_tokens"] / w1))

BOUND1 = u1u["total_tokens"]  # turn-1 committed boundary (prompt + own generated)
st2, d2, w2 = chat([S(), U(U1), A(r1), U(U2)], "q35-6b")
r2 = d2["choices"][0]["message"]["content"]; u2u = d2["usage"]
print("T2 status=%d wall=%.2fs usage=%s reply=%r" % (st2, w2, json.dumps(u2u), r2))
assert st2 == 200 and R2.startswith(r2) and r2 != "", "T2 not a prefix of the CPU reference R2"
assert u2u["reused_prompt_tokens"] == BOUND1, (u2u, BOUND1)
print("T2 MATCHES CPU REFERENCE PREFIX; RESIDENT reuse: prompt=%d reused=%d evaluated=%d; completion tok/s=%.3f" % (
    u2u["prompt_tokens"], u2u["reused_prompt_tokens"], u2u["prompt_tokens"] - u2u["reused_prompt_tokens"], u2u["completion_tokens"] / w2))

sti, di, wi = chat([S(), U("hello")], "q35-6b-other", max_tokens=4)
ri = di["choices"][0]["message"]["content"]
print("INTERVENE status=%d wall=%.2fs usage=%s reply=%r" % (sti, wi, json.dumps(di["usage"]), ri))
assert sti == 200

sts, ds, ws = chat([S(), U(U1), A(r1), U(U2)], "q35-6b")
rs = ds["choices"][0]["message"]["content"]; usu = ds["usage"]
print("STATELESS status=%d wall=%.2fs usage=%s reply=%r" % (sts, ws, json.dumps(usu), rs))
assert sts == 200 and rs == r2, "stateless snapshot reply != resident T2 reply"
assert usu["reused_prompt_tokens"] == BOUND1, (usu, BOUND1)
print("STATELESS PASS: reused=%d (snapshot restore) reply==resident T2; completion tok/s=%.3f" % (usu["reused_prompt_tokens"], usu["completion_tokens"] / ws))
print("Q35-6b HTTP HIP real-file bench: ALL PASS")
