#!/usr/bin/env python3
"""J-022 B1: QK-norm convention A/B against the ggml comparator's numbers.

Runs the J-016 instrument's own forward (which supports both readings)
with --mode perhead|full over three sequences and prints the
last-position top-10 logits plus the logits of the comparator's
published top ids, for direct comparison with tf_oracle's tables:
  seq8  (pos7):  cmp 281:16.634 13:14.750 273:14.680 4283:14.433 598:14.013
  seq67 (pos66): cmp 187:15.824 754:15.168 2635:14.913 380:14.314 1292:14.057
  seq72 (pos71): cmp 6225:13.578 369:13.422 43775:13.170 574:12.280 3139:11.566
Usage: j022_b1_qknorm_ab.py <gguf> <mode>
"""
import sys
import numpy as np

sys.path.insert(0, "/home/volmarr/j016")
from j016_router_forward import OlmoeForward, rms_norm  # noqa: E402

IDS67 = [int(x) for x in open("/home/volmarr/j022/prompt_prose_ids.csv").read().strip().split(",")]
SEQS = {
    "seq8": (IDS67[:8], [281, 13, 273, 4283, 598]),
    "seq67": (IDS67, [187, 754, 2635, 380, 1292]),
    "seq72": (IDS67 + [187, 187, 510, 1708, 5967], [6225, 369, 43775, 574, 3139, 13]),
}

def main():
    gguf_path, mode = sys.argv[1], sys.argv[2]
    model = OlmoeForward(gguf_path, mode)
    out_w = model.deq("output.weight")
    out_n = model.deq("output_norm.weight")
    for name, (ids, probe) in SEQS.items():
        emb = model.deq("token_embd.weight")
        states = [emb[np.array(ids, dtype=np.int64)].astype(np.float32).copy()]
        del emb
        sink = [[[] for _ in ids]]
        for l in range(model.n_layer):
            states = model.layer(l, states, sink)
        h = rms_norm(states[0], out_n, model.eps)
        logits = h[-1] @ out_w.T
        top10 = np.argsort(-logits)[:10]
        print(f"== {name} mode={mode} top10:", [(int(i), round(float(logits[i]), 3)) for i in top10])
        print(f"   probe logits:", {int(i): round(float(logits[i]), 3) for i in probe})

if __name__ == "__main__":
    main()
