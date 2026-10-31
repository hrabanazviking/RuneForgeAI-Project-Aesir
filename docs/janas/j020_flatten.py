#!/usr/bin/env python3
"""J-020 trace flattening (Project Aesir, Janas clean-room road).

Reads the J-016 measured OLMoE trace and emits access streams for the
J-020 Mojo replay through the REAL J-018 ExpertCache module:
  session_accesses.csv  token_idx,layer,expert,scaled_size  (all 577 tokens)
  prose_accesses.csv    same, prose prompt only (71 tokens, renumbered)
  tokens.csv            token_idx,prompt_id,pos,phase,token_id (session)
  prose_tokens.csv      same for the prose subset
scaled_size = header expert_bytes_per_layer[layer] // 1024 (exact, the
J-018 construction: 4079616->3984, 3538944->3456).
"""
import csv
import json
import os
import sys

TRACE = os.path.expanduser("~/workspace/model-tests/janas/j016_trace_olmoe.jsonl")
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/j020"
os.makedirs(OUT, exist_ok=True)

header = None
tokens = []
with open(TRACE) as f:
    for line in f:
        d = json.loads(line)
        if d.get("type") == "header":
            header = d
        elif d.get("type") == "token":
            tokens.append(d)

sizes = [b // 1024 for b in header["expert_bytes_per_layer"]]
assert all(b % 1024 == 0 for b in header["expert_bytes_per_layer"])

def emit(tok_list, acc_name, tok_name):
    with open(os.path.join(OUT, acc_name), "w", newline="") as fa, \
         open(os.path.join(OUT, tok_name), "w", newline="") as ft:
        aw = csv.writer(fa)
        tw = csv.writer(ft)
        n_acc = 0
        for ti, t in enumerate(tok_list):
            tw.writerow([ti, t["prompt_id"], t["pos"], t["phase"], t["token_id"]])
            for L, layer in enumerate(t["layers"]):
                for e in layer:
                    aw.writerow([ti, L, e, sizes[L]])
                    n_acc += 1
    return n_acc

n1 = emit(tokens, "session_accesses.csv", "tokens.csv")
prose = [t for t in tokens if t["prompt_id"] == "prose"]
n2 = emit(prose, "prose_accesses.csv", "prose_tokens.csv")
print(f"session: {len(tokens)} tokens, {n1} accesses")
print(f"prose:   {len(prose)} tokens, {n2} accesses")
print(f"sizes per layer (scaled): {sizes}")
