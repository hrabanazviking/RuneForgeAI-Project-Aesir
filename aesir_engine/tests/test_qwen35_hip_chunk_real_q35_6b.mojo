# Q35-6b real-scale chunk bisect: singles vs singles+chunk on
# the REAL 27B file. Stream: P0 prompt (5 tokens) + the banked
# greedy continuation (first 10 ids from Q35-3b v2 GEN IDS).
#   A: 15 singles
#   B: 5 singles + chunk(10 tokens, start 5, cap 32)
# Compare full state image + KV prefix image.

from loader.packed_gguf import PackedGGUF  # anchor (Q35-1 lesson)
from core.qwen35_hip import Qwen35HipExecutor


def maxdiff(a: List[Float32], b: List[Float32]) -> Float32:
    var m: Float32 = 0.0
    var at = -1
    for i in range(len(a)):
        var d = a[i] - b[i]
        if d < 0:
            d = -d
        if d > m:
            m = d
            at = i
    print("  maxdiff at index", at)
    return m


def main() raises:
    var path = String("/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf")
    var toks = List[Int]([9707, 25, 264, 5894, 766, 11751, 13, 271, 4639, 369, 4252, 13, 2972, 57590, 332])
    var a = Qwen35HipExecutor(path, 4096)
    for pos in range(15):
        _ = a.forward_chunk(List[Int]([toks[pos]]), pos, pos == 14, 1)
    print("A singles done")
    var b = Qwen35HipExecutor(path, 4096)
    for pos in range(5):
        _ = b.forward_chunk(List[Int]([toks[pos]]), pos, False, 1)
    var chunk = List[Int]()
    for i in range(5, 15):
        chunk.append(toks[i])
    _ = b.forward_chunk(chunk, 5, True, 32)
    print("B chunk done")
    print("state maxdiff =", maxdiff(b.readback_state(), a.readback_state()))
    print("kv maxdiff =", maxdiff(b.readback_kv_prefix(15), a.readback_kv_prefix(15)))
    print("REAL CHUNK BISECT DONE")
