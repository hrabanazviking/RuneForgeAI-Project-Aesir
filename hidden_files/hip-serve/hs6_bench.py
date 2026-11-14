#!/usr/bin/env python3
"""HS-6 bench: session residency vs the stateless resend path.

Phase A (stateless): two turns, full history resent, no session id.
Phase B (resident): same conversation with session_id; turn 2 must
evaluate only the new user message (delta) and report the whole prior
conversation as reused.
Phase C (control): same session_id but an edited history must fall back
to the stateless resend path (large evaluated count).
"""
import json
import time
import urllib.request

BASE = "http://127.0.0.1:18434"
KEY = open("/home/volmarr/.config/aesir/service.key").read().strip()
SYSTEM = "You are a careful assistant. Answer briefly."
Q1 = "What is 17 plus 25?"
Q2 = "And what is that number times two?"
Q1_EDITED = "What is 17 plus 26?"


def chat(messages, session_id=None):
    body = {"model": "llama3-3b:latest", "messages": messages,
            "max_tokens": 48, "temperature": 0.0}
    if session_id:
        body["session_id"] = session_id
    req = urllib.request.Request(
        BASE + "/v1/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + KEY,
                 "Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=180) as r:
        data = json.load(r)
    wall = round((time.time() - t0) * 1000)
    usage = data["usage"]
    return (data["choices"][0]["message"]["content"], usage["prompt_tokens"],
            usage["reused_prompt_tokens"],
            usage["prompt_tokens"] - usage["reused_prompt_tokens"], wall)


def turn(label, messages, session_id=None):
    reply, prompt, reused, evaluated, wall = chat(messages, session_id)
    print("%s prompt=%d reused=%d evaluated=%d wall_ms=%d reply=%r"
          % (label, prompt, reused, evaluated, wall, reply))
    return reply, evaluated


S = {"role": "system", "content": SYSTEM}
U1 = {"role": "user", "content": Q1}
U2 = {"role": "user", "content": Q2}

print("== phase A: stateless resend ==")
a1, _ = turn("A1", [S, U1])
a2_eval = turn("A2", [S, U1, {"role": "assistant", "content": a1}, U2])[1]

print("== phase B: resident session ==")
b1, _ = turn("B1", [S, U1], "hs6-bench")
b2_eval = turn("B2", [S, U1, {"role": "assistant", "content": b1}, U2],
               "hs6-bench")[1]

print("== phase C: edited history, same session id (fallback control) ==")
c3_eval = turn("C3", [S, {"role": "user", "content": Q1_EDITED},
                      {"role": "assistant", "content": b1}, U2],
               "hs6-bench")[1]

print("VERDICT A2_evaluated=%d B2_evaluated=%d C3_evaluated=%d"
      % (a2_eval, b2_eval, c3_eval))
assert b2_eval < a2_eval, "resident turn must evaluate fewer tokens than resend"
assert b2_eval <= 20, "resident turn should evaluate only the delta + framing"
assert c3_eval > b2_eval, "edited history must fall back to the resend path"
print("HS6 BENCH PASS")
