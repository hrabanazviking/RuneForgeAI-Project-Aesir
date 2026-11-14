# Q35-6b T1-pattern bisect: real file, the bench T1 prompt
# stream (23 tokens). A: 23 singles. B: chunk(22 @0, cap 32)
# + single(22). Compare state + KV images bit-exactly.

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
    print("  maxdiff at index", at, "of", len(a))
    return m


def main() raises:
    var path = String("/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf")
    var stream = List[Int]([2523, 513, 264, 10631, 17313, 13, 198, 1421, 25, 3437, 369, 279, 6511, 314, 9338, 30, 3855, 799, 10919, 23223, 1017, 13, 198])
    var a = Qwen35HipExecutor(path, 4096)
    for pos in range(23):
        _ = a.forward_chunk(List[Int]([stream[pos]]), pos, pos == 22, 1)
    print("A singles done")
    var b = Qwen35HipExecutor(path, 4096)
    var chunk = List[Int]()
    for i in range(0, 22):
        chunk.append(stream[i])
    _ = b.forward_chunk(chunk, 0, False, 32)
    _ = b.forward_chunk(List[Int]([stream[22]]), 22, True, 1)
    print("B chunk done")
    print("state maxdiff =", maxdiff(b.readback_state(), a.readback_state()))
    print("kv maxdiff =", maxdiff(b.readback_kv_prefix(23), a.readback_kv_prefix(23)))
    print("T1 CHUNK BISECT DONE")
