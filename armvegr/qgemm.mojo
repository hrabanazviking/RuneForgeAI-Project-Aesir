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
from armvegr.quant import q80_block_scale


def q80_block_dot(
    a: Pointer[Int8, MutUntrackedOrigin],
    b: Pointer[Int8, MutUntrackedOrigin],
) -> Int32:
    # Dot product of the 32 int8 values of two Q8_0 blocks (skipping the
    # 2 scale bytes): 16-wide NEON, widened to int32 before multiply.
    var acc = SIMD[DType.int32, 16](0)
    for t in range(0, 32, 16):
        var av = a.unsafe_offset(2 + t).unsafe_load[16]()
        var bv = b.unsafe_offset(2 + t).unsafe_load[16]()
        var av32 = av.cast[DType.int32]()
        var bv32 = bv.cast[DType.int32]()
        acc = acc + av32 * bv32
    return acc.reduce_add()


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
    var nb = K // 32
    for i in range(M):
        for j in range(N):
            var s = Float32(0)
            for kb in range(nb):
                var ab = aq.unsafe_offset((i * nb + kb) * 34)
                var bb = bq.unsafe_offset((j * nb + kb) * 34)
                var sa = q80_block_scale(aq, (i * nb + kb) * 34)
                var sb = q80_block_scale(bq, (j * nb + kb) * 34)
                var d = q80_block_dot(ab, bb)
                s += sa * sb * Float32(d)
            c[unsafe_offset=i * N + j] = s


def q80_gemm_bytes(M: Int, K: Int) -> Int64:
    # Bytes streamed by the M=1 decode case: one activation row + the
    # whole B matrix in Q8_0 (scales included).
    var nb = K // 32
    return Int64((M * nb + 1 * nb) * 34)
