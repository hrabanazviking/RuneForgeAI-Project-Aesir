#!/usr/bin/env python3
"""J-022 B1 experiment B (compare): Aesir layer dump vs numpy reference.

Usage: j022_b1_compare.py <ref.npz> <aesir_dump.txt> <pos>
<pos> = index of the dumped token within the reference sequence (its
last-position row is used from the .npz arrays).
Prints per-checkpoint relative L2, cosine, max-abs-diff, and the
per-layer router top-8 set overlap for the dumped token.
"""
import sys
import numpy as np

ref = np.load(sys.argv[1])
pos = int(sys.argv[3])
aes = {}
routes_a = {}
for line in open(sys.argv[2]):
    parts = line.strip().split(" ", 1)
    if parts[0] == "DUMP":
        fields = [x for x in parts[1].split(",") if x != ""]
        vals = np.array([int(x) for x in fields[1:]], dtype=np.float64) / 1e6
        aes[int(fields[0])] = vals
    elif parts[0] == "ROUTE":
        fields = [x for x in parts[1].split(",") if x != ""]
        nums = fields[1:]
        exps = [int(nums[i]) for i in range(0, len(nums), 2)]
        ws = [int(nums[i]) / 1e6 for i in range(1, len(nums), 2)]
        routes_a[int(fields[0])] = (exps, ws)
    elif parts[0] == "NEXT":
        print("aesir NEXT pick:", parts[1])

def stats(a, b):
    a = a.astype(np.float64); b = b.astype(np.float64)
    rel = np.linalg.norm(a - b) / max(np.linalg.norm(b), 1e-12)
    cos = float(a @ b / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-12))
    return rel, cos, float(np.max(np.abs(a - b)))

names = [(0, "emb", "emb")]
for l in range(16):
    names.append((2 * l + 1, f"attn{l}", f"attn{l}"))
    names.append((2 * l + 2, f"ffn{l}", f"ffn{l}"))
names.append((33, "final", "final"))
print(f"{'chk':>4} {'name':>7} {'relL2':>10} {'cos':>9} {'maxabs':>9}")
for ci, nm, rk in names:
    if ci not in aes:
        print(ci, nm, "MISSING in aesir dump"); continue
    rel, cos, mx = stats(aes[ci], ref[rk][pos])
    print(f"{ci:>4} {nm:>7} {rel:10.5f} {cos:9.5f} {mx:9.4f}")
print("router agreement (dumped token):")
for l in range(16):
    rexp = [int(x) for x in ref[f"route{l}_experts"][pos]]
    rw = ref[f"route{l}_weights"][pos]
    aexp, aw = routes_a.get(l, ([], []))
    inter = len(set(rexp) & set(aexp))
    print(f" layer {l:>2}: ref {rexp} aesir {aexp} overlap {inter}/8")
top5 = np.argsort(-ref["logits"][pos])[:5]
print("ref last-position top5:", [(int(i), float(ref['logits'][pos][i])) for i in top5])
