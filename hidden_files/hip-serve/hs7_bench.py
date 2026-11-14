#!/usr/bin/env python3
"""HS-7 bench: stable-order memory injection, live.

T1 seeds a resident session with two memory blocks.
T2 continues with the SAME blocks: must stay resident (delta-only).
T3 appends a third block: the effective system changes, so the session
reseeds through the stateless path -- but the injected prefix shared
with T1/T2 must still be reused by the exact-prefix cache.
"""
import json
import time
import urllib.request

BASE = "http://127.0.0.1:18434"
KEY = open("/home/volmarr/.config/aesir/service.key").read().strip()
SYSTEM = "Answer briefly."
MEM_A = [
    {"key": "user-name", "text": "The user is named Volmarr.", "order": 1},
    {"key": "home", "text": "The user lives in Indiana.", "order": 2},
]
MEM_B = MEM_A + [
    {"key": "project", "text": "The current project is Aesir, a local AI engine.", "order": 3},
]


def chat(messages, blocks):
    body = {"model": "llama3-3b:latest", "messages": messages,
            "max_tokens": 48, "temperature": 0.0,
            "session_id": "hs7-bench", "memory_blocks": blocks}
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


def turn(label, messages, blocks):
    reply, prompt, reused, evaluated, wall = chat(messages, blocks)
    print("%s prompt=%d reused=%d evaluated=%d wall_ms=%d reply=%r"
          % (label, prompt, reused, evaluated, wall, reply))
    return reply, prompt, reused, evaluated


S = {"role": "system", "content": SYSTEM}
U1 = {"role": "user", "content": "What is my name and where do I live?"}
U2 = {"role": "user", "content": "And what is the weather like there in winter?"}
U3 = {"role": "user", "content": "What project am I working on?"}

r1, p1, _, _ = turn("T1 seed, blocks A", [S, U1], MEM_A)
r2, p2, ru2, ev2 = turn("T2 same blocks, continuation",
                        [S, U1, {"role": "assistant", "content": r1}, U2], MEM_A)
r3, p3, ru3, ev3 = turn("T3 appended block, continuation shape",
                        [S, U1, {"role": "assistant", "content": r1},
                         U2, {"role": "assistant", "content": r2}, U3], MEM_B)

print("VERDICT T2_evaluated=%d T3_evaluated=%d T3_reused=%d" % (ev2, ev3, ru3))
assert ev2 <= 20, "same blocks must keep the resident delta-only path"
assert ev3 > ev2, "an appended block must reseed (larger evaluated count)"
assert ru3 >= 20, "the shared injected prefix must still be reused after reseed"
print("HS7 BENCH PASS")
