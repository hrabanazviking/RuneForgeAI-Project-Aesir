"""S-088: raw packed known-value regressions for the ternary kinds
TQ1_0 (GGML type 34, 54 bytes per 256 values) and TQ2_0 (type 35,
66 bytes per 256 values), multi-block, walking packed bytes only.
Fixtures are built byte-level from the ggml layouts in ggml-common.h
(TQ1_0: qs[48] + qh[4] + f16 d at +52; TQ2_0: qs[64] + f16 d at +64)
and checked against values computed by hand from ggml
dequantize_row_tq1_0 / dequantize_row_tq2_0 (the hand computation was
itself cross-checked against the pre-existing in-tree TQ1_0 oracle
fixture: block 0 below reproduces its 21 spot values and its -4.0
block sum exactly). Also pins scalar-vs-production bit-identity:
dequantize_tq_block (the production GEMM's decode) must equal the
per-element scalar decoders exactly on every lane, and the
decode-once fast GEMM (via gemm_f16) must equal the scalar GEMMs on
these exactly-representable fixtures.
"""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_f16, gemm_ternary_158
from core.extreme_quantization import (
    tq1_0_value,
    tq2_0_value,
    dequantize_tq1_0_blocks,
    dequantize_tq2_0_blocks,
    dequantize_tq_block,
    tq_block_bytes,
    gemm_tq2_0_blocks,
)
from std.memory import Pointer
from std.memory.alloc import alloc


def _build_tq1(mut well: MimirWell) raises -> Pointer[UInt8, MutUntrackedOrigin]:
    # Two 54-byte blocks (108 bytes).
    # Block 0: qs+qh bytes (i*37+11)%256 (the pre-existing oracle
    # fixture pattern), d = 2.0 at bytes 52..53 (f16 0x4000 LE).
    # Block 1: qs (i*53+7)%256, qh (i*29+3)%256, d = 0.5 (0x3800 LE).
    var raw = well.allocate(108).unsafe_bitcast[UInt8]()
    for i in range(52):
        raw.unsafe_store(i, UInt8((i * 37 + 11) % 256))
    raw.unsafe_store(52, UInt8(0))
    raw.unsafe_store(53, UInt8(64))
    for i in range(48):
        raw.unsafe_store(54 + i, UInt8((i * 53 + 7) % 256))
    for i in range(4):
        raw.unsafe_store(54 + 48 + i, UInt8((i * 29 + 3) % 256))
    raw.unsafe_store(54 + 52, UInt8(0))
    raw.unsafe_store(54 + 53, UInt8(56))
    return raw


def _build_tq2(mut well: MimirWell) raises -> Pointer[UInt8, MutUntrackedOrigin]:
    # Two 66-byte blocks (132 bytes).
    # Block 0: qs (i*37+11)%256, d = 2.0 at bytes 64..65.
    # Block 1: qs (i*91+5)%256, d = 0.5 at bytes 66+64..66+65.
    var raw = well.allocate(132).unsafe_bitcast[UInt8]()
    for i in range(64):
        raw.unsafe_store(i, UInt8((i * 37 + 11) % 256))
    raw.unsafe_store(64, UInt8(0))
    raw.unsafe_store(65, UInt8(64))
    for i in range(64):
        raw.unsafe_store(66 + i, UInt8((i * 91 + 5) % 256))
    raw.unsafe_store(66 + 64, UInt8(0))
    raw.unsafe_store(66 + 65, UInt8(56))
    return raw


def test_tq1_0_known_value() raises:
    var well = MimirWell(1024 * 1024)
    var raw = _build_tq1(well)
    if tq_block_bytes(34) != 54:
        raise Error("TQ1_0 tq_block_bytes must be 54")
    var out32 = alloc[Float32](256)
    # Production block decode vs scalar per-element decoder, all lanes.
    for sb in range(2):
        dequantize_tq_block(raw, sb * 54, 34, out32)
        for i in range(256):
            if out32.unsafe_load(i) != tq1_0_value(raw, 0, sb * 256 + i):
                raise Error("TQ1_0 production decode vs scalar mismatch")
    # Hand-computed spots, block 0 (d = 2.0).
    dequantize_tq_block(raw, 0, 34, out32)
    var idx0 = [0, 1, 2, 3, 4, 5, 6, 7, 31, 32, 64, 128, 159, 160, 175, 176, 239, 240, 243, 244, 255]
    var exp0 = [Float32(-2.0), Float32(-2.0), Float32(-2.0), Float32(0.0), Float32(0.0), Float32(2.0), Float32(2.0), Float32(-2.0), Float32(0.0), Float32(-2.0), Float32(0.0), Float32(0.0), Float32(0.0), Float32(2.0), Float32(2.0), Float32(-2.0), Float32(2.0), Float32(2.0), Float32(0.0), Float32(2.0), Float32(-2.0)]
    for k in range(len(idx0)):
        if out32.unsafe_load(idx0[k]) != exp0[k]:
            raise Error("TQ1_0 block 0 spot mismatch")
    var sum0 = Float32(0.0)
    for i in range(256):
        sum0 += out32.unsafe_load(i)
    if sum0 != Float32(-4.0):
        raise Error("TQ1_0 block 0 sum mismatch")
    # Hand-computed spots, block 1 (d = 0.5).
    dequantize_tq_block(raw, 54, 34, out32)
    var idx1 = [0, 1, 2, 5, 31, 32, 100, 159, 160, 200, 239, 240, 244, 255]
    var exp1 = [Float32(-0.5), Float32(-0.5), Float32(0.0), Float32(-0.5), Float32(0.0), Float32(-0.5), Float32(-0.5), Float32(-0.5), Float32(0.0), Float32(0.5), Float32(0.0), Float32(-0.5), Float32(-0.5), Float32(0.0)]
    for k in range(len(idx1)):
        if out32.unsafe_load(idx1[k]) != exp1[k]:
            raise Error("TQ1_0 block 1 spot mismatch")
    var sum1 = Float32(0.0)
    for i in range(256):
        sum1 += out32.unsafe_load(i)
    if sum1 != Float32(-4.0):
        raise Error("TQ1_0 block 1 sum mismatch")
    # Whole-tensor decoder vs scalar, all 512 lanes.
    var expanded = well.allocate(512 * 2).unsafe_bitcast[Float16]()
    dequantize_tq1_0_blocks(raw, 108, expanded, 512)
    for i in range(512):
        if expanded.unsafe_load(i).cast[DType.float32]() != tq1_0_value(raw, 0, i):
            raise Error("TQ1_0 whole-tensor decode mismatch")
    # GEMM: A rows = [all-ones, first-block-only ones] over 512 lanes.
    var input_ptr = well.allocate(1024 * 2)
    for i in range(512):
        input_ptr.unsafe_store(i, Scalar[f16](1.0))
    for i in range(512, 768):
        input_ptr.unsafe_store(i, Scalar[f16](1.0))
    for i in range(768, 1024):
        input_ptr.unsafe_store(i, Scalar[f16](0.0))
    var input = RuneTensor[f16](2, 512, input_ptr, False)
    var weights = RuneTensor[f16](1, 512, raw.unsafe_bitcast[Scalar[f16]](), True, CompressedFormatType(CompressedFormatType.TQ1_0))
    var out_fast_ptr = well.allocate(2 * 2)
    var out_fast = RuneTensor[f16](2, 1, out_fast_ptr, False)
    gemm_f16(input, weights, out_fast)
    var out_scalar_ptr = well.allocate(2 * 2)
    var out_scalar = RuneTensor[f16](2, 1, out_scalar_ptr, False)
    gemm_ternary_158(input, weights, out_scalar)
    if out_fast.data.unsafe_load(0) != Scalar[f16](-8.0) or out_fast.data.unsafe_load(1) != Scalar[f16](-4.0):
        raise Error("TQ1_0 fast GEMM disagrees with hand-computed sums")
    if out_scalar.data.unsafe_load(0) != out_fast.data.unsafe_load(0) or out_scalar.data.unsafe_load(1) != out_fast.data.unsafe_load(1):
        raise Error("TQ1_0 fast GEMM vs scalar GEMM mismatch")
    # Short-input rejection mutates nothing.
    for i in range(512):
        expanded.unsafe_store(i, Float16(99.0))
    var rejected = False
    try:
        dequantize_tq1_0_blocks(raw, 107, expanded, 512)
    except:
        rejected = True
    if not rejected:
        raise Error("TQ1_0 accepted short packed storage")
    for i in range(512):
        if expanded.unsafe_load(i) != Float16(99.0):
            raise Error("TQ1_0 short-input rejection mutated output")
    out32.unsafe_free()
    print("TQ1_0 canonical 54-byte block, production==scalar, GEMM: PASS")


def test_tq2_0_known_value() raises:
    var well = MimirWell(1024 * 1024)
    var raw = _build_tq2(well)
    if tq_block_bytes(35) != 66:
        raise Error("TQ2_0 tq_block_bytes must be 66")
    var out32 = alloc[Float32](256)
    for sb in range(2):
        dequantize_tq_block(raw, sb * 66, 35, out32)
        for i in range(256):
            if out32.unsafe_load(i) != tq2_0_value(raw, 0, sb * 256 + i):
                raise Error("TQ2_0 production decode vs scalar mismatch")
    # Hand-computed spots, block 0 (d = 2.0; digit field 3 yields 2*d,
    # ggml's defined behaviour for arbitrary bytes, pinned as-is).
    dequantize_tq_block(raw, 0, 35, out32)
    var idx0 = [0, 1, 2, 3, 31, 32, 33, 63, 64, 95, 96, 127, 128, 160, 192, 224, 255]
    var exp0 = [Float32(4.0), Float32(-2.0), Float32(0.0), Float32(2.0), Float32(2.0), Float32(2.0), Float32(-2.0), Float32(0.0), Float32(-2.0), Float32(-2.0), Float32(-2.0), Float32(2.0), Float32(4.0), Float32(2.0), Float32(2.0), Float32(2.0), Float32(-2.0)]
    for k in range(len(idx0)):
        if out32.unsafe_load(idx0[k]) != exp0[k]:
            raise Error("TQ2_0 block 0 spot mismatch")
    var sum0 = Float32(0.0)
    for i in range(256):
        sum0 += out32.unsafe_load(i)
    if sum0 != Float32(258.0):
        raise Error("TQ2_0 block 0 sum mismatch")
    # Hand-computed spots, block 1 (d = 0.5).
    dequantize_tq_block(raw, 66, 35, out32)
    var idx1 = [0, 1, 2, 31, 32, 64, 100, 128, 200, 255]
    var exp1 = [Float32(0.0), Float32(-0.5), Float32(1.0), Float32(0.5), Float32(0.0), Float32(-0.5), Float32(0.0), Float32(0.0), Float32(1.0), Float32(0.0)]
    for k in range(len(idx1)):
        if out32.unsafe_load(idx1[k]) != exp1[k]:
            raise Error("TQ2_0 block 1 spot mismatch")
    var sum1 = Float32(0.0)
    for i in range(256):
        sum1 += out32.unsafe_load(i)
    if sum1 != Float32(64.0):
        raise Error("TQ2_0 block 1 sum mismatch")
    # Whole-tensor decoder vs scalar, all 512 lanes.
    var expanded = well.allocate(512 * 2).unsafe_bitcast[Float16]()
    dequantize_tq2_0_blocks(raw, 132, expanded, 512)
    for i in range(512):
        if expanded.unsafe_load(i).cast[DType.float32]() != tq2_0_value(raw, 0, i):
            raise Error("TQ2_0 whole-tensor decode mismatch")
    # GEMM: same A shape as the TQ1_0 case; fast (gemm_f16) vs scalar
    # (gemm_tq2_0_blocks) vs hand-computed sums 322.0 / 258.0.
    var input_ptr = well.allocate(1024 * 2)
    for i in range(512):
        input_ptr.unsafe_store(i, Scalar[f16](1.0))
    for i in range(512, 768):
        input_ptr.unsafe_store(i, Scalar[f16](1.0))
    for i in range(768, 1024):
        input_ptr.unsafe_store(i, Scalar[f16](0.0))
    var input = RuneTensor[f16](2, 512, input_ptr, False)
    var weights = RuneTensor[f16](1, 512, raw.unsafe_bitcast[Scalar[f16]](), True, CompressedFormatType(CompressedFormatType.TQ2_0))
    var out_fast_ptr = well.allocate(2 * 2)
    var out_fast = RuneTensor[f16](2, 1, out_fast_ptr, False)
    gemm_f16(input, weights, out_fast)
    var out_scalar = well.allocate(2 * 2).unsafe_bitcast[Float16]()
    gemm_tq2_0_blocks(input_ptr.unsafe_bitcast[Float16](), 1024, 2, raw, 132, 512, 1, out_scalar, 2)
    if out_fast.data.unsafe_load(0) != Scalar[f16](322.0) or out_fast.data.unsafe_load(1) != Scalar[f16](258.0):
        raise Error("TQ2_0 fast GEMM disagrees with hand-computed sums")
    if out_scalar.unsafe_load(0).cast[DType.float32]() != Float32(322.0) or out_scalar.unsafe_load(1).cast[DType.float32]() != Float32(258.0):
        raise Error("TQ2_0 scalar GEMM disagrees with hand-computed sums")
    # Short-input rejection mutates nothing.
    for i in range(512):
        expanded.unsafe_store(i, Float16(99.0))
    var rejected = False
    try:
        dequantize_tq2_0_blocks(raw, 131, expanded, 512)
    except:
        rejected = True
    if not rejected:
        raise Error("TQ2_0 accepted short packed storage")
    for i in range(512):
        if expanded.unsafe_load(i) != Float16(99.0):
            raise Error("TQ2_0 short-input rejection mutated output")
    out32.unsafe_free()
    print("TQ2_0 canonical 66-byte block, production==scalar, GEMM: PASS")


def main() raises:
    test_tq1_0_known_value()
    test_tq2_0_known_value()
    print("TQ tests: ALL PASS")
