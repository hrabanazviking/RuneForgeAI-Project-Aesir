#!/usr/bin/env python3
"""Q35-5 HTTP bench for the qwen35 CPU serve on the side port.

One serve instance, ordered modes:
  health    -- capabilities: exact_prefix_reuse true ONLY with the
               snapshot-based detail qualifier.
  resident  -- Q35-4a two-turn resident proof (unchanged numbers).
  stateless -- an intervening different-session request destroys
               residency; a full-history resend under the original
               session_id then restores the turn-1 snapshot:
               reused == 72, prompt == 90, reply == resident R2.
  diverged  -- resent history edited inside turn 1 (no session):
               reused == 0, reply == in-process diverged reference.
  bound     -- two more resident turns evict the turn-1 snapshot
               (limit 4); resending the oldest history is cold:
               reused == 0.
"""
import json, sys, urllib.request

BASE = "http://127.0.0.1:18435"
KEY = open("/tmp/q355-key.txt").read().strip()
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

def ref_line(path, prefix):
    for line in open(path):
        if line.startswith(prefix):
            return line[len(prefix):].rstrip("\n").replace("<NL>", "\n")
    raise SystemExit("missing " + prefix + " in " + path)

R1 = ref_line("/home/volmarr/aesir-hipserve/hidden_files/qwen35-adapter/q35-4-session-test.log", "R1=")
R2 = ref_line("/home/volmarr/aesir-hipserve/hidden_files/qwen35-adapter/q35-4-session-test.log", "R2=")
RDIV = ref_line("/home/volmarr/aesir-hipserve/hidden_files/qwen35-adapter/q35-5-session-test.log", "R_DIV=")
S = {"role": "system", "content": SYSTEM}
def U(c): return {"role": "user", "content": c}
def A(c): return {"role": "assistant", "content": c}

# health
status, health = req("/health")
print("HEALTH status=%d body=%s" % (status, json.dumps(health)))
caps = health["capabilities"]
assert health["profile"] == "qwen35" and health["backend"] == "cpu"
assert caps["session_residency"] is True and caps["experimental_admission"] is True
assert caps["exact_prefix_reuse"] is True, "qwen35 must now report snapshot reuse"
assert caps.get("exact_prefix_reuse_detail") == "snapshot-based at committed turn boundaries only", caps
print("HEALTH CAPS PASS: exact_prefix_reuse=true WITH detail 'snapshot-based at committed turn boundaries only'")

# resident (Q35-4a numbers, unchanged)
st1, r1, uu1 = chat([S, U(U1)], "q35-5")
print("RESIDENT T1 status=%d usage=%s reply=%r" % (st1, json.dumps(uu1), r1))
assert st1 == 200 and r1 == R1 and uu1["reused_prompt_tokens"] == 0
st2, r2, uu2 = chat([S, U(U1), A(r1), U(U2)], "q35-5")
print("RESIDENT T2 status=%d usage=%s reply=%r" % (st2, json.dumps(uu2), r2))
assert st2 == 200 and r2 == R2 and uu2["reused_prompt_tokens"] == 72 and uu2["prompt_tokens"] == 90
print("RESIDENT PASS: reused=72 evaluated=18 reply==R2 (Q35-4a path unchanged)")

# stateless: intervening conversation destroys residency, then resend
sti, ri, uui = chat([S, U("mike november oscar")], "q35-5-other")
print("INTERVENING status=%d usage=%s reply=%r" % (sti, json.dumps(uui), ri))
assert sti == 200
sts, rs, uus = chat([S, U(U1), A(r1), U(U2)], "q35-5")
print("STATELESS T2 status=%d usage=%s reply=%r" % (sts, json.dumps(uus), rs))
assert sts == 200 and rs == R2, "stateless snapshot reply != resident R2"
assert uus["reused_prompt_tokens"] == 72, uus
assert uus["prompt_tokens"] == 90, uus
print("STATELESS PASS: reused=72 evaluated=%d reply==resident R2 (snapshot restore, not residency)" % (uus["prompt_tokens"] - uus["reused_prompt_tokens"]))

# diverged: edited turn-1 user text, no session
std, rd, uud = chat([S, U("alpha bravo DELTA"), A(r1), U(U2)])
print("DIVERGED status=%d usage=%s reply=%r" % (std, json.dumps(uud), rd))
assert std == 200 and uud["reused_prompt_tokens"] == 0, uud
assert uud["prompt_tokens"] == 191, uud
assert rd == RDIV, "diverged reply != in-process diverged reference"
print("DIVERGED PASS: reused=0 prompt=191 reply==in-process diverged reference")

# bound: two more resident turns on the q35-5 chain evict boundary 72
msgs = [S, U(U1), A(r1), U(U2), A(r2)]
st3, r3, uu3 = chat(msgs + [U("golf hotel india")], "q35-5")
print("BOUND T3 status=%d usage=%s reply=%r" % (st3, json.dumps(uu3), r3))
assert st3 == 200 and uu3["reused_prompt_tokens"] > 0
msgs = msgs + [U("golf hotel india"), A(r3)]
st4, r4, uu4 = chat(msgs + [U("juliet kilo lima")], "q35-5")
print("BOUND T4 status=%d usage=%s reply=%r" % (st4, json.dumps(uu4), r4))
assert st4 == 200 and uu4["reused_prompt_tokens"] > 0
stb, rb, uub = chat([S, U(U1), A(r1), U(U2)])
print("BOUND RESEND-OLDEST status=%d usage=%s reply=%r" % (stb, json.dumps(uub), rb))
assert stb == 200 and uub["reused_prompt_tokens"] == 0, uub
print("BOUND PASS: after >4 snapshots the turn-1 snapshot is evicted; oldest history resend is cold (reused=0)")
print("Q35-5 HTTP snapshot bench: ALL PASS")
