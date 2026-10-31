#!/usr/bin/env python3
"""J-022 B1 experiment A: prefix-length grades (doc S4 named experiment).

For prefix lengths N in (8, 16, 32) of the J-022 prose prompt ids:
  1. run the Aesir streamed OLMoE session (test_olmoe_stream_v2, cap
     512 MiB, ctx 512) on the first N ids, greedy gen 16;
  2. grade Aesir's picks with tf_oracle (ggml CPU comparator, raw
     prompt, teacher-forcing rank + logit gap) on a prompt file whose
     text is the exact decode of the first N ids -- the oracle's own
     tokenization count is asserted == N before the grade is trusted.
Writes one combined log per N under ~/j022/b1/.
"""
import subprocess, sys, os

HOME = "/home/volmarr"
MODEL = HOME + "/aesir-gpu/.aesir/models/olmoe-1b-7b-0924-instruct-q4_k_m.gguf"
BIN = HOME + "/j022/test_olmoe_stream_v2"
ORACLE = HOME + "/s026l/tf_oracle"
OUT = HOME + "/j022/b1"
os.makedirs(OUT, exist_ok=True)

ids = [int(x) for x in open(HOME + "/j022/prompt_prose_ids.csv").read().strip().split(",")]

import gguf
r = gguf.GGUFReader(MODEL)
toks = r.fields["tokenizer.ggml.tokens"].contents()
bs = list(range(ord("!"), ord("~") + 1)) + list(range(0xA1, 0xAC + 1)) + list(range(0xAE, 0xFF + 1))
cs = bs[:]; n = 0
for b in range(256):
    if b not in bs:
        bs.append(b); cs.append(256 + n); n += 1
inv = {chr(c): b for b, c in zip(bs, cs)}

def dec(idlist):
    raw = bytearray()
    for i in idlist:
        for ch in toks[i]:
            if ch in inv: raw.append(inv[ch])
            else: raw.extend(ch.encode("utf-8"))
    return bytes(raw).decode("utf-8", errors="replace")

env = dict(os.environ)
env["LD_LIBRARY_PATH"] = HOME + "/j022/stage"
env["CUDA_VISIBLE_DEVICES"] = ""

for N in (8, 16, 32):
    prefix = ids[:N]
    ptxt = dec(prefix)
    pfile = f"{OUT}/prompt_{N}.txt"
    with open(pfile, "w") as f:
        f.write(ptxt)
    csv = ",".join(str(x) for x in prefix)
    run = subprocess.run(["nice", "-n", "10", BIN, MODEL, "512", "536870912", csv, "16"],
                         capture_output=True, text=True, env=env, timeout=900)
    gen = None
    for line in run.stdout.splitlines():
        if line.startswith("Generated IDs:"):
            gen = [int(x) for x in line.split("[")[1].split("]")[0].split(",") if x.strip()]
    log = [f"=== prefix N={N} ===", f"prompt text: {ptxt!r}", f"aesir rc={run.returncode}",
           run.stdout, run.stderr[-500:]]
    if gen:
        gcsv = ",".join(str(x) for x in gen)
        ora = subprocess.run([ORACLE, MODEL, pfile, gcsv], capture_output=True, text=True, timeout=900)
        ptok = [l for l in ora.stderr.splitlines() if "prompt_tokens" in l]
        log += [f"oracle stderr prompt_tokens line: {ptok}", "oracle grade:", ora.stdout]
    with open(f"{OUT}/prefix_{N}.log", "w") as f:
        f.write("\n".join(log))
    print(f"N={N} done gen={gen}", flush=True)
print("ALLDONE")
