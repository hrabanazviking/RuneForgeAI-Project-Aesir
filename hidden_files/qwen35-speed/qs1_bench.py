#!/usr/bin/env python3
"""QS-0 baseline bench v2: LIVE aesir-gate end-to-end (27B Q8_0
resident, CPU, ctx 4096, port 18436). Read-only client.
Key read from ~/.config/aesir/service.key in-process, never printed.
Stream format (native_serve.mojo): OpenAI route streams SSE lines
'data: {json}' terminated by 'data: [DONE]'. v1 of this harness
parsed raw NDJSON and counted 0 chunks -- fixed here (bug logged
in LEDGER). Method per prompt size:
  (1) streaming gen=128: TTFT = time to first content chunk;
      decode_a = (chunks-1)/(wall-TTFT) [chunk ~= token, labelled]
  (2) non-streaming gen=128, same prompt: exact usage counts;
      decode_b = (completion-1)/(wall_ns - TTFT) [cross-check]
      prompt_tok_s = prompt_tokens/TTFT (TTFT includes first
      decode step => LOWER bound on pure prefill rate, labelled)
Unique suffix per prompt so snapshot reuse cannot skip prefill;
reused_prompt_tokens printed wherever the serve reports it."""
import json, time, urllib.request

BASE = "http://127.0.0.1:18436"
KEY = open("/home/volmarr/aesir-qs-cpu/hidden_files/qwen35-speed/qs1.key").read().strip()
MODEL = "/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf"
SYSTEM = "You are a helpful assistant."
PASSAGE = ("The old harbour town kept its records in a stone archive above the tide line. "
  "Every spring the clerks carried the ledgers down to the counting house, checked each "
  "cargo against the harbour master's roll, and noted the ships that had wintered in the "
  "northern ports. Grain, salt, timber and dried fish filled the manifests, and the town "
  "council argued each year about the cost of repairing the eastern pier. ")

def prompt_for(target_words, suffix):
    reps = max(1, target_words // len(PASSAGE.split()))
    return PASSAGE * reps + suffix

def stream_chat(user_text, max_tokens, tag):
    body = {"model": MODEL, "stream": True, "max_tokens": max_tokens,
            "messages": [{"role": "system", "content": SYSTEM},
                         {"role": "user", "content": user_text}]}
    r = urllib.request.Request(BASE + "/v1/chat/completions", data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    t0 = time.time(); ttft = None; chunks = 0; usage = None; text = ""
    with urllib.request.urlopen(r, timeout=1500) as resp:
        print("STREAM %s http=%d" % (tag, resp.status), flush=True)
        for raw in resp:
            line = raw.decode("utf-8", "replace").strip()
            if line.startswith("data:"):
                line = line[5:].strip()
            if not line or line == "[DONE]":
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue
            if isinstance(obj, dict) and obj.get("usage"):
                usage = obj["usage"]
            ch = ""
            try:
                ch = obj["choices"][0]["delta"].get("content") or ""
            except Exception:
                ch = ""
            if ch:
                if ttft is None:
                    ttft = time.time() - t0
                chunks += 1; text += ch
    wall = time.time() - t0
    print("RESULT %s wall=%.2fs ttft=%s chunks=%d usage=%s head=%r" % (
        tag, wall, ("%.2fs" % ttft) if ttft is not None else "NONE", chunks,
        json.dumps(usage), text[:60]), flush=True)
    return wall, ttft, chunks, usage

def plain_chat(user_text, max_tokens, tag):
    body = {"model": MODEL, "max_tokens": max_tokens,
            "messages": [{"role": "system", "content": SYSTEM},
                         {"role": "user", "content": user_text}]}
    r = urllib.request.Request(BASE + "/v1/chat/completions", data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(r, timeout=1500) as resp:
        data = json.load(resp)
    wall = time.time() - t0
    u = data.get("usage")
    print("PLAIN %s wall=%.2fs usage=%s" % (tag, wall, json.dumps(u)), flush=True)
    return wall, u

def measure(tag, user_text):
    w_s, ttft, chunks, _u = stream_chat(user_text, 128, tag + "-stream128")
    w_n, u = plain_chat(user_text, 128, tag + "-plain128")
    if u and ttft:
        pt, ct = u.get("prompt_tokens"), u.get("completion_tokens")
        da = (chunks - 1) / (w_s - ttft) if chunks > 1 and w_s > ttft else 0
        db = (ct - 1) / (w_n - ttft) if ct and w_n > ttft else 0
        print("SUM %s prompt_tokens=%s completion=%s reused=%s prompt_tok_s>=%.2f decode_stream=%.2f decode_plain=%.2f ttft=%.2fs" % (
            tag, pt, ct, u.get("reused_prompt_tokens"), pt / ttft, da, db, ttft), flush=True)

def main():
    r = urllib.request.Request(BASE + "/health", headers={"Authorization": "Bearer " + KEY})
    with urllib.request.urlopen(r, timeout=60) as resp:
        print("HEALTH", resp.status, resp.read().decode(), flush=True)
    measure("p500", prompt_for(360, "Question: in one sentence, what did the clerks check each spring?"))
    measure("p2000", prompt_for(1500, "Question: in one sentence, what filled the manifests?"))
    print("QS0 BENCH DONE", flush=True)

if __name__ == "__main__":
    main()
