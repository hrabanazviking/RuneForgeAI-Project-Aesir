# Q35-6b chunk bisect: does forward_chunk with batch_cap > 1 at
# start_pos > 0 reproduce the all-singles trajectory exactly?
# (Singles were proven CPU-equal in Q35-6 (c).) Compares the
# full device state image + KV prefix image after:
#   A12: 12 singles          A20: 20 singles
#   B4 : 8 singles + chunk(4 tokens, start 8, cap 32)
#   B12: 8 singles + chunk(12 tokens, start 8, cap 32)

from loader.packed_gguf import PackedGGUF  # anchor (Q35-1 lesson)
from core.qwen35_hip import Qwen35HipExecutor


def maxdiff(a: List[Float32], b: List[Float32]) -> Float32:
    var m: Float32 = 0.0
    for i in range(len(a)):
        var d = a[i] - b[i]
        if d < 0:
            d = -d
        if d > m:
            m = d
    return m


def singles(path: String, toks: List[Int], n: Int) raises -> Qwen35HipExecutor:
    var ex = Qwen35HipExecutor(path, 512)
    for pos in range(n):
        _ = ex.forward_chunk(List[Int]([toks[pos]]), pos, pos == n - 1, 1)
    return ex^


def main() raises:
    var path = String("aesir_engine/tests/fixtures/qwen35_forward.gguf")
    var toks = List[Int]([1, 3, 17, 42, 5, 9, 2, 8, 33, 21, 4, 6, 11, 19, 7, 12, 30, 15, 23, 10])
    var a12 = singles(path, toks, 12)
    var a20 = singles(path, toks, 20)
    var b4 = Qwen35HipExecutor(path, 512)
    for pos in range(8):
        _ = b4.forward_chunk(List[Int]([toks[pos]]), pos, False, 1)
    var chunk4 = List[Int]()
    for i in range(8, 12):
        chunk4.append(toks[i])
    _ = b4.forward_chunk(chunk4, 8, True, 32)
    var b12 = Qwen35HipExecutor(path, 512)
    for pos in range(8):
        _ = b12.forward_chunk(List[Int]([toks[pos]]), pos, False, 1)
    var chunk12 = List[Int]()
    for i in range(8, 20):
        chunk12.append(toks[i])
    _ = b12.forward_chunk(chunk12, 8, True, 32)
    var s12 = a12.readback_state()
    var s20 = a20.readback_state()
    print("B4  vs A12 state maxdiff =", maxdiff(b4.readback_state(), s12))
    print("B12 vs A20 state maxdiff =", maxdiff(b12.readback_state(), s20))
    print("B4  vs A12 kv maxdiff =", maxdiff(b4.readback_kv_prefix(12), a12.readback_kv_prefix(12)))
    print("B12 vs A20 kv maxdiff =", maxdiff(b12.readback_kv_prefix(20), a20.readback_kv_prefix(20)))
    print("CHUNK BISECT DONE")
