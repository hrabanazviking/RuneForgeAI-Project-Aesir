# Minimal reproducer: forces codegen of core.compute's K-quant GEMM graph,
# including _gemm_k_fast_worker -> _gemm_k_vnni_range (vpdpbusd.512 site).
from core.mimir_well import MimirWell, RuneTensor, f16, f32
from core.compute import gemm_q4_k_m

def main() raises:
    var well = MimirWell(8192)
    var raw = well.allocate(144).unsafe_bitcast[UInt8]()
    for i in range(144):
        raw.unsafe_store(i, UInt8(0))
    raw.unsafe_bitcast[Float16]().unsafe_store(0, Float16(1))
    for i in range(12):
        raw.unsafe_store(4 + i, UInt8(1))
    for i in range(128):
        raw.unsafe_store(16 + i, UInt8(17))
    var input = well.allocate(256)
    for i in range(256):
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 256, input, False)
    var B = RuneTensor[f16](1, 256, raw.unsafe_bitcast[Float16](), True)
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_q4_k_m(A, B, C)
    var got = C.data.unsafe_load().cast[f32]()
    print("C[0] =", got)
    if got != Float32(256):
        raise Error("known-value mismatch: expected 256")
    print("min_vnni: PASS")
