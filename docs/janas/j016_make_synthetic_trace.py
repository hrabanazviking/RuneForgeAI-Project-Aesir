#!/usr/bin/env python3
"""J-016 synthetic validation trace generator.

Produces a DETERMINISTIC, clearly-labelled synthetic router trace
("trace_kind": "synthetic-validation") in the J-016 trace format, used ONLY
to prove the analysis tool (j016_analyze_trace.py) computes correctly.
Its routing pattern is an invented Zipf-like process with planted locality;
no number derived from it is a measurement of any model. Real traces come
from j016_router_forward.py on purplelongship and are labelled "measured".
"""
import json
import random
import sys

random.seed(16016)

L, E, K = 16, 64, 8
# Zipf-like popularity per layer (invented), plus a per-prompt hot subset to
# plant reuse locality the analyser must detect.
popularity = []
for l in range(L):
    w = [1.0 / (i + 1) ** 0.9 for i in range(E)]
    random.shuffle(w)
    popularity.append(w)

prompts = {"syn-prose": 90, "syn-code": 70, "syn-numbers": 50}
out = [{
    "type": "header", "trace_kind": "synthetic-validation",
    "model": "SYNTHETIC (no model)", "arch": "synthetic", "n_layer": L,
    "n_expert": E, "top_k": K,
    "instrument": "j016_make_synthetic_trace.py (invented Zipf process, seed 16016)",
    "hardware": "n/a - generated, not measured",
    "expert_bytes_per_layer": [3538944] * L,
}]
for pid, ntok in prompts.items():
    hot = [random.randrange(E) for _ in range(10)]
    for pos in range(ntok):
        layers = []
        for l in range(L):
            w = list(popularity[l])
            for h in hot:
                w[h] *= 6.0
            sel = []
            pool = list(range(E))
            for _ in range(K):
                tot = sum(w[i] for i in pool)
                r = random.random() * tot
                acc = 0.0
                for i in pool:
                    acc += w[i]
                    if acc >= r:
                        sel.append(i)
                        pool.remove(i)
                        break
            layers.append(sel)
        out.append({"type": "token", "prompt_id": pid, "pos": pos,
                    "token_id": -1, "layers": layers})
out.append({"type": "end"})
path = sys.argv[1] if len(sys.argv) > 1 else "j016_synthetic_trace.jsonl"
with open(path, "w") as f:
    for o in out:
        f.write(json.dumps(o) + "\n")
print(f"wrote {path}: {sum(prompts.values())} tokens, {L} layers, top-{K} of {E}")
