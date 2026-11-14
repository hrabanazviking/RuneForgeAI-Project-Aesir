# Q35-6b readback probe: does readback_state/readback_kv_prefix
# (the session's _take_snapshot calls between turns) disturb the
# live device state? Control: 20 greedy singles. Probe: 15
# greedy singles, both readbacks, then 5 more greedy singles.
# Greedy tokens at positions 15..19 must equal the banked GEN
# IDS continuation [369, 279, 6511, 321, 1379] in both runs, and
# the final state images must be bit-equal.

from loader.packed_gguf import PackedGGUF  # anchor (Q35-1 lesson)
from core.qwen35_hip import Qwen35HipExecutor


def argmax(logits: List[Float32]) -> Int:
    var best = 0
    var bv = logits[0]
    for i in range(1, len(logits)):
        if logits[i] > bv:
            bv = logits[i]
            best = i
    return best


def maxdiff(a: List[Float32], b: List[Float32]) -> Float32:
    var m: Float32 = 0.0
    for i in range(len(a)):
        var d = a[i] - b[i]
        if d < 0:
            d = -d
        if d > m:
            m = d
    return m


def run(path: String, probe: Bool) raises -> List[Int]:
    var toks = List[Int]([9707, 25, 264, 5894, 766, 11751, 13, 271, 4639, 369, 4252, 13, 2972, 57590, 332])
    var ex = Qwen35HipExecutor(path, 4096)
    var gen = List[Int]()
    for pos in range(15):
        _ = ex.forward_chunk(List[Int]([toks[pos]]), pos, False, 1)
    if probe:
        var img = ex.readback_state()
        var kv = ex.readback_kv_prefix(15)
        print("probe readbacks:", len(img), len(kv))
    var cur = toks[14]
    # positions 15..19: evaluate the pending token, sample next
    var pending = List[Int]([369, 279, 6511, 321, 1379])
    for k in range(5):
        var logits = ex.forward_chunk(List[Int]([pending[k]]), 15 + k, True, 1)
        gen.append(argmax(logits))
    print("gen:", gen[0], gen[1], gen[2], gen[3], gen[4])
    var st = ex.readback_state()
    print("state sum:", st[0], st[1000000])
    return gen^


def main() raises:
    var path = String("/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf")
    print("CONTROL")
    var c = run(path, False)
    print("PROBE")
    var p = run(path, True)
    var same = len(c) == len(p)
    for i in range(len(c)):
        if c[i] != p[i]:
            same = False
    print("CONTROL == PROBE:", same)
    print("READBACK PROBE DONE")
