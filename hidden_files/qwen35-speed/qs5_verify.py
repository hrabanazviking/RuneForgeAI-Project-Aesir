#!/usr/bin/env python3
"""QS-5 verify: health + real completion + two-turn prefix reuse.
Usage: qs5_verify.py <port> <label>
Key read from ~/.config/aesir/service.key in-process, never printed.
Model field = full GGUF path (strict routing)."""
import json, sys, time, urllib.request

PORT = sys.argv[1] if len(sys.argv) > 1 else "18434"
LABEL = sys.argv[2] if len(sys.argv) > 2 else "verify"
BASE = "http://127.0.0.1:%s" % PORT
KEY = open("/home/volmarr/.config/aesir/service.key").read().strip()
MODEL = "/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf"

def req(path, body=None, timeout=1500):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data,
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=timeout) as resp:
        return resp.status, json.load(resp)

def chat(messages, max_tokens=48, **kw):
    body = {"model": MODEL, "max_tokens": max_tokens, "messages": messages}
    body.update(kw)
    t0 = time.time()
    st, data = req("/v1/chat/completions", body)
    wall = time.time() - t0
    text = ""
    try:
        text = data["choices"][0]["message"]["content"] or ""
    except Exception:
        pass
    return st, wall, data.get("usage"), text

fails = 0
st, health = req("/health")
print("HEALTH %s status=%d %s" % (LABEL, st, json.dumps(health)), flush=True)
ok = (st == 200 and health.get("status") == "ready"
      and health.get("profile") == "qwen35"
      and (health.get("capabilities") or {}).get("model_variant") == "qwen35-27B"
      and (health.get("capabilities") or {}).get("weight_load_mode") == "q8_0_resident")
print("HEALTH_CHECK %s %s" % (LABEL, "PASS" if ok else "FAIL"), flush=True)
if not ok:
    fails += 1

msgs = [{"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "In one short sentence, what is a lighthouse?"}]
st, wall, usage, text = chat(msgs, 48)
print("TURN1 %s http=%d wall=%.1fs usage=%s text=%r" % (LABEL, st, wall, json.dumps(usage), text[:120]), flush=True)
ok = st == 200 and len(text.strip()) > 0
print("TURN1_CHECK %s %s" % (LABEL, "PASS" if ok else "FAIL"), flush=True)
if not ok:
    fails += 1

msgs2 = msgs + [{"role": "assistant", "content": text},
                {"role": "user", "content": "And in one short sentence, who tended it?"}]
st, wall, usage, text2 = chat(msgs2, 48)
print("TURN2 %s http=%d wall=%.1fs usage=%s text=%r" % (LABEL, st, wall, json.dumps(usage), text2[:120]), flush=True)
reused = (usage or {}).get("reused_prompt_tokens") or 0
ok = st == 200 and len(text2.strip()) > 0 and reused > 0
print("TURN2_CHECK %s %s reused=%s" % (LABEL, "PASS" if ok else "FAIL", reused), flush=True)
if not ok:
    fails += 1

print("VERIFY %s %s fails=%d" % (LABEL, "ALL_PASS" if fails == 0 else "FAILED", fails), flush=True)
sys.exit(1 if fails else 0)
