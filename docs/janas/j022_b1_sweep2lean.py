import sys
sys.path.insert(0, "/home/volmarr/j016")
sys.path.insert(0, "/home/volmarr/aesir-j022-tree/docs/janas")
import numpy as np
from j016_router_forward import OlmoeForward
from j022_b1_convention_sweep2 import run, IDS67
M = "/home/volmarr/aesir-gpu/.aesir/models/olmoe-1b-7b-0924-instruct-q4_k_m.gguf"
model = OlmoeForward(M, "full")
for variant in ("attn_scale_x2", "attn_scale_half", "router_no_renorm", "rope_partial64", "pos_plus1", "gate_up_swap", "tied_head"):
    for nm, ids, probe in [("seq2", IDS67[:2], [5967, 273]), ("seq8", IDS67[:8], [281, 13])]:
        logits = run(model, ids, variant)
        top5 = np.argsort(-logits)[:5]
        print(variant, nm, [(int(i), round(float(logits[i]), 3)) for i in top5], "| probes", {p: round(float(logits[p]), 3) for p in probe}, flush=True)
