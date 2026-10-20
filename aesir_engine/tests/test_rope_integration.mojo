"""Integration of rotary key output with the KV cache append/read path."""

from core.mimir_well import MimirWell, RuneTensor, Scalar, f16, KVCache
from core.compute import apply_rope


def test_rope_integration() raises:
    var well = MimirWell(4096)
    var Q = RuneTensor[f16](1, 8, well.allocate(8))
    var K = RuneTensor[f16](1, 4, well.allocate(4))
    var V = RuneTensor[f16](1, 4, well.allocate(4))
    for index in range(Q.size):
        Q.data.unsafe_store(index, Scalar[f16](Float32(index + 1) / 2.0))
    for index in range(K.size):
        K.data.unsafe_store(index, Scalar[f16](Float32(index + 2)))
        V.data.unsafe_store(index, Scalar[f16](Float32(10 + index)))

    apply_rope(Q, K, 4, 4, 10000.0, False)
    var rotated = List[Scalar[f16]]()
    for index in range(K.size):
        rotated.append(K.data.unsafe_load(index))

    var cache = KVCache(8, 4, well, 1)
    cache.append(0, 4, K, V)
    var key_slice = cache.get_k_slice(0, 5)
    var value_slice = cache.get_v_slice(0, 5)
    for index in range(K.size):
        if key_slice.data.unsafe_load(4 * 4 + index) != rotated[index]:
            raise Error("KV cache did not preserve the rotated key values")
        if value_slice.data.unsafe_load(4 * 4 + index) != V.data.unsafe_load(index):
            raise Error("RoPE integration changed the unrotated value tensor")
    if Q.data.unsafe_load(0) == Scalar[f16](0.5):
        raise Error("RoPE integration did not transform query input")
    print("PASS: RoPE output flows into KV cache without changing values")


def main() raises:
    test_rope_integration()
