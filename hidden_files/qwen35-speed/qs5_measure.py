#!/usr/bin/env python3
"""QS-5.1 load mix for the fence measurement, against the scratch
serve on port 18438. Legs: short completion, resident two-turn,
sampling leg (QS-4 params), medium prefill, near-full-context
(4096) prefill + generation. Prints one line per leg with usage;
the caller reads the unit MemoryPeak afterwards.
Key read in-process, never printed."""
import json, time, urllib.request

BASE = "http://127.0.0.1:18438"
KEY = open("/home/volmarr/.config/aesir/service.key").read().strip()
MODEL = "/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf"
SYSTEM = "You are a helpful assistant."
PASSAGE = ("The old harbour town kept its records in a stone archive above the tide line. "
  "Every spring the clerks carried the ledgers down to the counting house, checked each "
  "cargo against the harbour master's roll, and noted the ships that had wintered in the "
  "northern ports. Grain, salt, timber and dried fish filled the manifests, and the town "
  "council argued each year about the cost of repairing the eastern pier. ")

def chat(messages, max_tokens=48, tag="leg", **kw):
    body = {"model": MODEL, "max_tokens": max_tokens, "messages": messages}
    body.update(kw)
    r = urllib.request.Request(BASE + "/v1/chat/completions", data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(r, timeout=1500) as resp:
        data = json.load(resp)
    wall = time.time() - t0
    text = ""
    try:
        text = data["choices"][0]["message"]["content"] or ""
    except Exception:
        pass
    print("LEG %s wall=%.1fs usage=%s text_head=%r" % (tag, wall, json.dumps(data.get("usage")), text[:60]), flush=True)
    return text, data.get("usage")

def words_prompt(nwords, suffix):
    reps = max(1, nwords // len(PASSAGE.split()))
    return PASSAGE * reps + suffix

def main():
    r = urllib.request.Request(BASE + "/health", headers={"Authorization": "Bearer " + KEY})
    with urllib.request.urlopen(r, timeout=60) as resp:
        print("HEALTH", resp.status, resp.read().decode()[:200], flush=True)
    # 1 short stateless
    chat([{"role": "system", "content": SYSTEM},
          {"role": "user", "content": "In one short sentence, what is a lighthouse?"}], 32, "short")
    # 2 resident two-turn
    m1 = [{"role": "system", "content": SYSTEM},
          {"role": "user", "content": "Name three colours of the sea at dawn, briefly."}]
    t1, _ = chat(m1, 40, "resident-t1")
    m2 = m1 + [{"role": "assistant", "content": t1},
               {"role": "user", "content": "Which of those is rarest? One sentence."}]
    chat(m2, 40, "resident-t2")
    # 3a sampling leg, chat route (temperature/top_p are the
    # sampling fields the OpenAI parser accepts; min_p on the
    # chat route is refused 400 by design at this base)
    chat([{"role": "system", "content": SYSTEM},
          {"role": "user", "content": "Write two vivid sentences about a storm reaching a harbour."}],
         48, "sampling-chat", temperature=0.8, top_p=0.95)
    # 3b sampling leg, native /v1/generate route: min_p +
    # repeat_penalty (the QS-4 wiring) exercised end to end
    body = {"prompt": "The old lighthouse keeper", "system": SYSTEM,
            "max_tokens": 48, "temperature": 1.0, "top_p": 1.0,
            "min_p": 0.05, "repeat_penalty": 1.1}
    r = urllib.request.Request(BASE + "/v1/generate", data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(r, timeout=1500) as resp:
        raw = resp.read().decode("utf-8", "replace")
        print("LEG generate-minp http=%d wall=%.1fs body_head=%r" % (resp.status, time.time() - t0, raw[:160]), flush=True)
    # 4 medium prefill (~700 words)
    chat([{"role": "system", "content": SYSTEM},
          {"role": "user", "content": words_prompt(700, "Question: in one sentence, what did the clerks check each spring?")}],
         48, "prefill-med")
    # 5 near-full-context prefill (~2600 words, target ~3400-3800 tokens) + generation
    chat([{"role": "system", "content": SYSTEM},
          {"role": "user", "content": words_prompt(2600, "Question: in one sentence, what filled the manifests?")}],
         64, "prefill-full")
    print("QS5 MEASURE MIX DONE", flush=True)

if __name__ == "__main__":
    main()
