# Q35-6b sequence replication: the session's exact executor call
# pattern for the two-turn bench conversation, argmax sampling.
#   T1: chunk(stream[0:22], 0, cap 32) + single(22) + 6 gen singles
#       + snapshot readbacks (state + kv prefix 29)
#   T2: chunk(stream[29:38], 29, cap 32) + single(38) + 6 gen singles
# Stream ids are the debug run's printed STREAM2 prefix.
# Expected T2 gen: 198 69267 25 271 760 <primary> where <primary>
# is the CPU R2 token for " primary".

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


def main() raises:
    var path = String("/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf")
    var stream = List[Int]([2523, 513, 264, 10631, 17313, 13, 198, 1421, 25, 3437, 369, 279, 6511, 314, 9338, 30, 3855, 799, 10919, 23223, 1017, 13, 198])
    var ex = Qwen35HipExecutor(path, 4096)
    var chunk = List[Int]()
    for i in range(0, 22):
        chunk.append(stream[i])
    _ = ex.forward_chunk(chunk, 0, False, 32)
    var logits = ex.forward_chunk(List[Int]([stream[22]]), 22, True, 1)
    var pending = argmax(logits)
    print("T1 pending:", pending)
    var pos = 23
    for _ in range(6):
        stream.append(pending)
        logits = ex.forward_chunk(List[Int]([pending]), pos, True, 1)
        pending = argmax(logits)
        pos += 1
    print("T1 stream tail:", stream[23], stream[24], stream[25], stream[26], stream[27], stream[28], "pos", pos)
    var img = ex.readback_state()
    var kv = ex.readback_kv_prefix(29)
    print("snapshotted:", len(img), len(kv))
    var delta = List[Int]([3710, 3992, 635, 1379, 1208, 6266, 303, 421, 3177, 30])
    for t in delta:
        stream.append(t)
    for i in range(29, 38):
        _ = ex.forward_chunk(List[Int]([stream[i]]), i, False, 1)
    logits = ex.forward_chunk(List[Int]([stream[38]]), 38, True, 1)
    pending = argmax(logits)
    print("T2 pending:", pending)
    pos = 39
    var gen = List[Int]()
    for _ in range(6):
        gen.append(pending)
        logits = ex.forward_chunk(List[Int]([pending]), pos, True, 1)
        pending = argmax(logits)
        pos += 1
    print("T2 gen:", gen[0], gen[1], gen[2], gen[3], gen[4], gen[5])
    print("SEQ V2 (T2 delta as singles) DONE")
