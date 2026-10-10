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
    # OPTIMIZED (2026-10-10): kb-outer loop order. For each k-block, A's
    # 32 int8 values (+ scale) are loaded ONCE and reused across all N
    # columns; B streams once (optimal). The previous j-outer order
    # re-loaded A's row N times (17.8 MB of redundant L1 traffic for
    # the decode case). B's scales are precomputed once (N*nb fp32) so
    # the hot loop does no fp16_from_bits decoding; the block dot is
    # inlined (16-wide NEON, widened to int32).
    var nb = K // 32
    var sb_all = unsafe_alloc[Float32](N * nb)
    for j in range(N):
        var brow = (j * nb) * 34
        for kb in range(nb):
            sb_all[unsafe_offset=j * nb + kb] = q80_block_scale(
                bq, brow + kb * 34
            )
    var sa_row = unsafe_alloc[Float32](nb)
    var s_acc = unsafe_alloc[Float32](N)
    for i in range(M):
        var arow = (i * nb) * 34
        for kb in range(nb):
            sa_row[unsafe_offset=kb] = q80_block_scale(aq, arow + kb * 34)
        for j in range(N):
            s_acc[unsafe_offset=j] = Float32(0)
        for kb in range(nb):
            var abo = arow + kb * 34 + 2
            var a0 = aq.unsafe_offset(abo).unsafe_load[16]()
            var a1 = aq.unsafe_offset(abo + 16).unsafe_load[16]()
            var a0w = a0.cast[DType.int32]()
            var a1w = a1.cast[DType.int32]()
            var sa = sa_row[unsafe_offset=kb]
            for j in range(N):
                var bbo = (j * nb + kb) * 34 + 2
                var b0 = bq.unsafe_offset(bbo).unsafe_load[16]()
                var b1 = bq.unsafe_offset(bbo + 16).unsafe_load[16]()
                var d = (
                    a0w * b0.cast[DType.int32]()
                    + a1w * b1.cast[DType.int32]()
                ).reduce_add()
                s_acc[unsafe_offset=j] += (
                    sa * sb_all[unsafe_offset=j * nb + kb] * Float32(d)
                )
        for j in range(N):
            c[unsafe_offset=i * N + j] = s_acc[unsafe_offset=j]


def q80_gemm_bytes(M: Int, K: Int) -> Int64:
    # Bytes streamed by the M=1 decode case: one activation row + the
    # whole B matrix in Q8_0 (scales included).
    var nb = K // 32
    return Int64((M * nb + 1 * nb) * 34)
