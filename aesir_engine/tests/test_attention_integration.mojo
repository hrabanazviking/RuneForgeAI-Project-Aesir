"""KV-cache slice to causal attention integration evidence."""

from core.mimir_well import MimirWell, RuneTensor, Scalar, f16, KVCache
from core.compute import flash_attention_2


def test_attention_integration() raises:
    var well = MimirWell(8192)
    var Q = RuneTensor[f16](2, 4, well.allocate(8))
    var K = RuneTensor[f16](2, 4, well.allocate(8))
    var V = RuneTensor[f16](2, 4, well.allocate(8))
    var Out = RuneTensor[f16](2, 4, well.allocate(8))
    for index in range(8):
        Q.data.unsafe_store(index, Scalar[f16](Float32(index + 1) / 5.0))
        K.data.unsafe_store(index, Scalar[f16](Float32(index - 2) / 4.0))
        V.data.unsafe_store(index, Scalar[f16](Float32(10 + index)))

    var cache = KVCache(4, 4, well, 1)
    for position in range(2):
        var key_row = RuneTensor[f16](1, 4, K.data.unsafe_offset(position * 4), False)
        var value_row = RuneTensor[f16](1, 4, V.data.unsafe_offset(position * 4), False)
        cache.append(0, position, key_row, value_row)
    var active_k = cache.get_k_slice(0, 2)
    var active_v = cache.get_v_slice(0, 2)
    flash_attention_2(Q, active_k, active_v, Out, 2, 4)
    for col in range(4):
        if Out.data.unsafe_load(col) != V.data.unsafe_load(col):
            raise Error("Cache-backed causal row 0 consumed a future value")
    var changed = False
    for col in range(4):
        if Out.data.unsafe_load(4 + col) != Out.data.unsafe_load(col):
            changed = True
    if not changed:
        raise Error("Second query row did not attend across its causal prefix")
    print("PASS: KV cache active slices feed causal attention prefixes")


def main() raises:
    test_attention_integration()
