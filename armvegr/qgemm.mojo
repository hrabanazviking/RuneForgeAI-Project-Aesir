# H033 — Quantized GEMM: Q8_0 x Q8_0 -> FP32 accumulate.
#
# C[M,N] (fp32) = Aq[M,K] (Q8_0) x Bq[K,N] (Q8_0), K a multiple of 32.
# Bq is stored K-major: row j holds nb = K/32 blocks covering K, so the
# dot product over K streams both operands' blocks in order. Each
# block-pair contributes sa*sb*dot(int8a, int8b) in fp32; the int8 dot
# is NEON-accelerated (16-wide, widened to int32: 16 x 128 x 127 fits).
# Layout cross-check (H033 acceptance): this kernel reads blocks with
# q80_block_scale from armvegr.quant — the same layout the H031
# quantizer writes — so the shared-layout test exercises both sides.
#
# ERROR CONTRACT (documented interpretation, see DEVLOG 2026-10-10):
# "max absolute error <= 0.05 relative to the FP16 result" is read as
#   max_i |q_i - r_i| <= 0.05 * rms(r)
# i.e. the worst absolute deviation is bounded relative to the RMS scale
# of the FP16 reference. A per-element relative bound would be infeasible
# (quantization noise does not scale with output magnitude near zero),
# and an absolute 0.05 bound is infeasible for K >= 128 (quantization
# noise random-walks as sqrt(K)). The RMS-relative form is the standard
# quantization-error statement and is what the tests assert.

from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from std.memory.alloc import unsafe_alloc
from armvegr.quant import q80_block_scale


def q80_gemm(
    aq: Pointer[Int8, MutUntrackedOrigin],
    bq: Pointer[Int8, MutUntrackedOrigin],
    c: Pointer[Float32, MutUntrackedOrigin],
    M: Int,
    N: Int,
    K: Int,
):
    # aq: M x K Q8_0, row-major blocks: block (i, kb) at byte
    #     (i * nb + kb) * 34, nb = K // 32.
    # bq: N x K Q8_0, row j = blocks over K: block (j, kb) at byte
    #     (j * nb + kb) * 34.
    # c:  M x N fp32.
    #
    # OPTIMIZED (2026-10-10): the block dot is inlined (a per-block-pair
    # function call cost ~15 cycles at 524k pairs for the decode case)
    # and A's row scales are hoisted: they were re-decoded N times per
    # row (once per j), now decoded once per (i, kb).
    var nb = K // 32
    var sa_row = unsafe_alloc[Float32](nb)
    for i in range(M):
        var arow = (i * nb) * 34
        for kb in range(nb):
            sa_row[unsafe_offset=kb] = q80_block_scale(aq, arow + kb * 34)
        for j in range(N):
            var s = Float32(0)
            var brow = (j * nb) * 34
            for kb in range(nb):
                var abo = arow + kb * 34 + 2
                var bbo = brow + kb * 34 + 2
                var sb = q80_block_scale(bq, brow + kb * 34)
                var acc = SIMD[DType.int32, 16](0)
                var a0 = aq.unsafe_offset(abo).unsafe_load[16]()
                var b0 = bq.unsafe_offset(bbo).unsafe_load[16]()
                var a1 = aq.unsafe_offset(abo + 16).unsafe_load[16]()
                var b1 = bq.unsafe_offset(bbo + 16).unsafe_load[16]()
                acc += a0.cast[DType.int32]() * b0.cast[DType.int32]()
                acc += a1.cast[DType.int32]() * b1.cast[DType.int32]()
                s += (
                    sa_row[unsafe_offset=kb] * sb * Float32(acc.reduce_add())
                )
            c[unsafe_offset=i * N + j] = s


def q80_gemm_bytes(M: Int, K: Int) -> Int64:
    # Bytes streamed by the M=1 decode case: one activation row + the
    # whole B matrix in Q8_0 (scales included).
    var nb = K // 32
    return Int64((M * nb + 1 * nb) * 34)
