# J-021 replay: the dense demand stream through the demand form of the
# residency machinery (core/dense_residency.mojo DenseLayerCache).
#
# The demand stream is the dense truth: every token touches every
# layer exactly once, in order -- a cyclic scan. Layer sizes are the
# measured directory-true sizes of the spill proof's own file
# (L3-8B-Stheno-v3.2-Q4_K_M.gguf, sha256 8e98c1953f9c04e06...,
# cross-checked by j021_layer_sizes.py against the J-015-verified
# type table). 28 tokens = the S-011 spill run's shape (22 prompt +
# 6 generated). Budgets: the full layer body, the front-31 sum (the
# proven split's device layer bytes), half and one eighth of the body.
#
# Run: mojo run -I aesir_engine docs/janas/j021_layer_replay.mojo
from core.dense_residency import DenseLayerCache


def layer_sizes() -> List[Int]:
    var sizes = List[Int]()
    sizes.append(138936320)
    sizes.append(138936320)
    sizes.append(138936320)
    sizes.append(122716160)
    sizes.append(122716160)
    sizes.append(138936320)
    sizes.append(138936320)
    sizes.append(138936320)
    sizes.append(138936320)
    sizes.append(138936320)
    sizes.append(138936320)
    sizes.append(138936320)
    sizes.append(122716160)
    sizes.append(122716160)
    sizes.append(138936320)
    sizes.append(122716160)
    sizes.append(122716160)
    sizes.append(138936320)
    sizes.append(122716160)
    sizes.append(122716160)
    sizes.append(122716160)
    sizes.append(122716160)
    sizes.append(138936320)
    sizes.append(122716160)
    sizes.append(122716160)
    sizes.append(138936320)
    sizes.append(122716160)
    sizes.append(122716160)
    sizes.append(138936320)
    sizes.append(122716160)
    sizes.append(138936320)
    sizes.append(122716160)
    return sizes^


def run_scan(budget: Int, policy: String, sizes: List[Int], tokens: Int) raises:
    var cache = DenseLayerCache(budget, policy)
    for _ in range(tokens):
        for layer in range(len(sizes)):
            _ = cache.access(layer, sizes[layer])
    var stats = cache.snapshot()
    print(
        "SCAN policy="
        + policy
        + " budget="
        + String(budget)
        + " "
        + stats.describe()
    )


def main() raises:
    var sizes = layer_sizes()
    var total = 0
    for i in range(len(sizes)):
        total += sizes[i]
    print("layer_body_bytes=" + String(total) + " layers=" + String(len(sizes)))
    var budgets = List[Int]()
    budgets.append(total)
    budgets.append(4063723520)
    budgets.append(total // 2)
    budgets.append(total // 8)
    for b in range(len(budgets)):
        run_scan(budgets[b], String("lru"), sizes, 28)
        run_scan(budgets[b], String("segmented"), sizes, 28)
