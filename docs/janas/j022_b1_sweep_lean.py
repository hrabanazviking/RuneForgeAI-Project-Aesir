#!/usr/bin/env python3
"""J-022 B1: lean convention sweep -- seq8 only, discriminating order.
Reuses j022_b1_convention_sweep.run. Comparator fingerprint (seq8):
281:16.634 13:14.750 273:14.680 4283:14.433 598:14.013; argmax 281.
Usage: j022_b1_sweep_lean.py <gguf>
"""
import sys
import numpy as np

sys.path.insert(0, "/home/volmarr/j016")
sys.path.insert(0, "/home/volmarr/aesir-j022-tree/docs/janas")
from j016_router_forward import OlmoeForward  # noqa: E402
from j022_b1_convention_sweep import run, SEQS  # noqa: E402

VARIANTS = [
    ("full", "norm->rope", "interleaved"),
    ("full", "rope->norm", "neox"),
    ("perhead", "norm->rope", "interleaved"),
    ("none", "norm->rope", "neox"),
    ("perhead", "rope->norm", "neox"),
    ("full", "rope->norm", "interleaved"),
    ("perhead", "rope->norm", "interleaved"),
    ("none", "norm->rope", "interleaved"),
]

def main():
    model = OlmoeForward(sys.argv[1], "full")
    ids = SEQS["seq8"]
    for qknorm, order, style in VARIANTS:
        logits = run(model, ids, qknorm, order, style)
        top5 = np.argsort(-logits)[:5]
        print(f"{qknorm:>7} {order:>10} {style:>11} seq8:",
              [(int(i), round(float(logits[i]), 3)) for i in top5],
              "| 281:", round(float(logits[281]), 3), flush=True)

if __name__ == "__main__":
    main()
