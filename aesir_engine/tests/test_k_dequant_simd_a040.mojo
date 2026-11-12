"""A-040: SIMD K-quant dequantizer bit-parity vs scalar packed_value.

dequantize_ggml_k kinds 12/13/14 (Q4_K/Q5_K/Q6_K) decode through the
width-16 SIMD block path (_dequantize_ggml_k_simd); the scalar
packed_value() oracle is preserved as comparator. Fixtures are
deterministic synthetic super-blocks (LCG seed 0xA040 + kind),
d/dmin pinned to sane f16 values, quant bytes LCG-filled.
"""
from std.memory import Pointer
from std.memory.alloc import alloc
from core.compute import dequantize_ggml_k
from core.packed_quantization import packed_value
from core.mimir_well import f16

def _lcg(state: Int64) -> Int64:
    return state * Int64(6364136223846793005) + Int64(1442695040888963407)

def _check(kind: Int) raises:
    comptime NB = 64
    comptime NE = NB * 256
    var bb = 144 if kind == 12 else 176 if kind == 13 else 210
    var w = alloc[UInt8](NB * bb)
    var s = Int64(0xA040) + Int64(kind)
    for b in range(NB):
        s = _lcg(s + Int64(b))
        var st = s
        for i in range(bb):
            st = _lcg(st)
            w.unsafe_store(b * bb + i, UInt8((st >> 33) & 0xFF))
        var p = b * bb
        if kind == 14:
            w.unsafe_store(p + 208, UInt8(0x00)); w.unsafe_store(p + 209, UInt8(0x2E))
        else:
            w.unsafe_store(p + 0, UInt8(0x00)); w.unsafe_store(p + 1, UInt8(0x2E))
            w.unsafe_store(p + 2, UInt8(0x00)); w.unsafe_store(p + 3, UInt8(0x1E))
    var out = alloc[Scalar[f16]](NE)
    dequantize_ggml_k(w, out, NE, kind)
    for i in range(NE):
        var refv = packed_value(w, 0, kind, i).cast[f16]()
        if out.unsafe_load(i) != refv:
            raise Error("A-040 SIMD dequant bit-parity mismatch")
    w.unsafe_free(); out.unsafe_free()

def test_k_dequant_simd_q4_k_parity() raises:
    _check(12)
    print("A-040 Q4_K SIMD dequant bit-parity: PASS")

def test_k_dequant_simd_q5_k_parity() raises:
    _check(13)
    print("A-040 Q5_K SIMD dequant bit-parity: PASS")

def test_k_dequant_simd_q6_k_parity() raises:
    _check(14)
    print("A-040 Q6_K SIMD dequant bit-parity: PASS")
