#!/usr/bin/env python3
"""Q35-7 bench: REAL 27B Q8_0-resident serve (stage-1 fixes + stage-2
swap configuration). Port + key file from argv. Order: health
(now incl. model_variant) -> resident T1 -> resident T2 ->
intervening short-answer STOP case (the Q35-4b F-4b-2 shape) ->
stateless resend -> R1 long exchange. Replies are compared with
the NEW in-process reference (session stop rule + trim apply
there too) AND with the banked Q35-4b replies minus exactly the
leading "Assistant:" marker (F-4b-1 byte-otherwise-identical)."""
import json, sys, time, urllib.request
PORT = sys.argv[1] if len(sys.argv) > 1 else "18434"
KEYF = sys.argv[2] if len(sys.argv) > 2 else "/tmp/q357-key.txt"
BASE = "http://127.0.0.1:" + PORT
KEY = open(KEYF).read().strip()
MODEL = "/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf"
AD = "/home/volmarr/aesir-q35-7/hidden_files/qwen35-adapter"
OLD = "/home/volmarr/aesir-hipserve/hidden_files/qwen35-adapter"
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

R1 = ref_line(AD + "/q35-7-ref-turns.log", "R1=")
R2 = ref_line(AD + "/q35-7-ref-turns.log", "R2=")
POS1 = int(ref_line(AD + "/q35-7-ref-turns.log", "POS1="))
STOPCASE = ref_line(AD + "/q35-7-ref-turns.log", "STOPCASE=")
LONG_R = ref_line(AD + "/q35-7-ref-long.log", "LONG_R=")
OLD_R1 = ref_line(OLD + "/q35-4b-ref-turns.log", "R1=")
OLD_R2 = ref_line(OLD + "/q35-4b-ref-turns.log", "R2=")
OLD_LONG = ref_line(OLD + "/q35-4b-ref-long.log", "LONG_R=")
def strip_marker(text):
    for shape in ("\n\nAssistant:", "\nAssistant:", "Assistant:"):
        if text.startswith(shape):
            return text[len(shape):]
    return text
for new, old, name in ((R1, OLD_R1, "R1"), (R2, OLD_R2, "R2"), (LONG_R, OLD_LONG, "LONG")):
    assert strip_marker(old) != old, (name, old[:30])
    assert new == strip_marker(old), (name, new[:40], old[:40])
    print("TRIM PROOF %s: new reference == banked Q35-4b reply minus its leading role-marker block, byte-otherwise-identical" % name)

def S(): return {"role": "system", "content": SYSTEM}
def U(c): return {"role": "user", "content": c}
def A(c): return {"role": "assistant", "content": c}

status, health, wall = req("/health")
print("HEALTH status=%d wall=%.2fs body=%s" % (status, wall, json.dumps(health)))
caps = health["capabilities"]
assert health["profile"] == "qwen35", health
assert health["backend"] == "cpu", health
assert caps["session_residency"] is True, caps
assert caps["exact_prefix_reuse"] is True, caps
assert caps.get("exact_prefix_reuse_detail") == "snapshot-based at committed turn boundaries only", caps
assert caps.get("weight_load_mode") == "q8_0_resident", caps
assert caps.get("model_variant") == "qwen35-27B", caps
assert caps.get("experimental_admission") is False, caps
print("HEALTH TRUTH PASS: profile=qwen35 variant=qwen35-27B backend=cpu residency=true exact_prefix_reuse=true(snapshot detail) weight_load_mode=q8_0_resident experimental=false")

st1, d1, w1 = chat([S(), U(U1)], "q35-7-proof", 32)
r1 = d1["choices"][0]["message"]["content"]; u1u = d1["usage"]
print("T1 status=%d wall=%.2fs usage=%s reply=%r" % (st1, w1, json.dumps(u1u), r1))
assert st1 == 200 and r1 == R1, "turn1 != in-process reference"
assert not r1.startswith("Assistant:"), "turn1 still carries the marker"
print("T1 MATCHES REFERENCE (trimmed); eval_tok/s=%.2f" % (u1u["completion_tokens"] / w1))

st2, d2, w2 = chat([S(), U(U1), A(r1), U(U2)], "q35-7-proof", 32)
r2 = d2["choices"][0]["message"]["content"]; u2u = d2["usage"]
print("T2 status=%d wall=%.2fs usage=%s reply=%r" % (st2, w2, json.dumps(u2u), r2))
assert st2 == 200 and r2 == R2, "resident turn2 != in-process reference"
assert u2u["reused_prompt_tokens"] == POS1, "resident reuse != committed turn-1 position"
print("T2 MATCHES REFERENCE; RESIDENT reuse: prompt=%d reused=%d evaluated=%d" % (
    u2u["prompt_tokens"], u2u["reused_prompt_tokens"], u2u["prompt_tokens"] - u2u["reused_prompt_tokens"]))

stx, dx, wx = chat([U("Say the word hello.")], "q35-7-other", 8)
rx = dx["choices"][0]["message"]["content"]; ux = dx["usage"]
finx = dx["choices"][0].get("finish_reason")
print("STOPCASE status=%d wall=%.2fs usage=%s finish=%s reply=%r" % (stx, wx, json.dumps(ux), finx, rx))
assert stx == 200
assert rx == STOPCASE, "served stop case != in-process reference stop case"
assert "<|" not in rx, "stop case leaked control-token spelling"
assert ux["completion_tokens"] < 8, "stop case ran to the cap"
print("STOPCASE PASS: reply halted on the model's stop tokens; clean text %r; completion_tokens=%d < cap 8" % (rx, ux["completion_tokens"]))

st3, d3, w3 = chat([S(), U(U1), A(r1), U(U2)], "q35-7-proof", 32)
r3 = d3["choices"][0]["message"]["content"]; u3u = d3["usage"]
print("STATELESS status=%d wall=%.2fs usage=%s reply=%r" % (st3, w3, json.dumps(u3u), r3))
assert st3 == 200 and r3 == R2, "stateless resend reply != resident reference"
assert u3u["reused_prompt_tokens"] == POS1, "stateless reuse != turn-1 boundary"
print("STATELESS MATCHES REFERENCE via SNAPSHOT: prompt=%d reused=%d evaluated=%d" % (
    u3u["prompt_tokens"], u3u["reused_prompt_tokens"], u3u["prompt_tokens"] - u3u["reused_prompt_tokens"]))

st4, d4, w4 = chat([U(LONG)], None, 48)
r4 = d4["choices"][0]["message"]["content"]; u4u = d4["usage"]
print("LONG status=%d wall=%.2fs usage=%s" % (st4, w4, json.dumps(u4u)))
print("LONG REPLY=%r" % r4)
assert st4 == 200 and r4 == LONG_R, "long reply != in-process reference"
print("LONG MATCHES IN-PROCESS REFERENCE at prompt_tokens=%d" % u4u["prompt_tokens"])
print("Q35-7 HTTP bench: ALL PASS")
