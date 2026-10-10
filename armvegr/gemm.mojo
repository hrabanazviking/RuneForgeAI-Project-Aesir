# H022/H023 — NEON FP16 GEMM: register-tiled micro-kernel + blocked driver.
#
# Data flow: C[M,N] (fp16) = A[M,K] (fp16) x B[K,N] (fp16).
# Accumulation is in FP32 (widened NEON FMA), output rounded to fp16.
# Rationale (see DEVLOG 2026-10-10): fp32 accumulation keeps the kernel
# within 1e-3 of an fp64 reference even for K=4096; pure-fp16 accumulation
# would diverge by ~0.3 on large K. The H007 spike used fp16 accumulation;
# this shipped kernel widens, which is also what production inference
# GEMMs do.
#
# H022 MICRO-KERNEL: Mr x Nr = 8 x 8, fp32 accumulators.
# Loop order: row i outer, k-chunks inner, columns j unrolled.
# Per output row i, 8 accumulators (one SIMD[DType.float32, 8] per column
# j) hold 8 k-lanes each and are reduced at the row's end.
# Register-budget justification (32 NEON 128-bit q-registers available):
#   - 8 fp32x8 accumulators = 16 q-regs
#   - A row vector fp16 (1 q-reg) + widened fp32 (2 q-regs) = 3 q-regs
#   - B column vector fp16 (1 q-reg) + widened fp32 (2 q-regs) = 3 q-regs
#     (one column at a time; reloaded per row from the L1-resident panel)
#   Total live: 16 + 3 + 3 = 22 of 32 q-regs. No spills expected.
#   8-wide matches the 128-bit NEON register exactly for fp16.
# Trade-off documented: B is reloaded per output row (8 kc B-loads per
# tile) instead of hoisted across rows, because hoisting would need 64
# accumulators (128 q-regs). The B panel (8 x kc fp16 <= 4 KiB) is
# L1-resident, so the reloads are L1 hits, not DRAM traffic.

from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from std.memory.alloc import unsafe_alloc


def gemm_micro_8x8(
    ap: Pointer[Float16, MutUntrackedOrigin],
    bp: Pointer[Float16, MutUntrackedOrigin],
    acc: Pointer[Float32, MutUntrackedOrigin],
    kc: Int,
    ldc: Int,
):
    # ap: 8 x kc packed A, row-major (ap[i*kc + k]).
    # bp: 8 x kc packed B, column-panels (bp[j*kc + k], j = output column).
    # acc: 8 x 8 fp32 tile, row stride ldc; the product is ADDED in.
    for i in range(8):
        var c0 = SIMD[DType.float32, 8](0)
        var c1 = SIMD[DType.float32, 8](0)
        var c2 = SIMD[DType.float32, 8](0)
        var c3 = SIMD[DType.float32, 8](0)
        var c4 = SIMD[DType.float32, 8](0)
        var c5 = SIMD[DType.float32, 8](0)
        var c6 = SIMD[DType.float32, 8](0)
        var c7 = SIMD[DType.float32, 8](0)
        var k = 0
        while k + 8 <= kc:
            var av = ap.unsafe_offset(i * kc + k).unsafe_load[8]().cast[DType.float32]()
            var b0 = bp.unsafe_offset(0 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c0 = av.fma(b0, c0)
            var b1 = bp.unsafe_offset(1 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c1 = av.fma(b1, c1)
            var b2 = bp.unsafe_offset(2 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c2 = av.fma(b2, c2)
            var b3 = bp.unsafe_offset(3 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c3 = av.fma(b3, c3)
            var b4 = bp.unsafe_offset(4 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c4 = av.fma(b4, c4)
            var b5 = bp.unsafe_offset(5 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c5 = av.fma(b5, c5)
            var b6 = bp.unsafe_offset(6 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c6 = av.fma(b6, c6)
            var b7 = bp.unsafe_offset(7 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c7 = av.fma(b7, c7)
            k += 8
        var s0 = c0.reduce_add()
        var s1 = c1.reduce_add()
        var s2 = c2.reduce_add()
        var s3 = c3.reduce_add()
        var s4 = c4.reduce_add()
        var s5 = c5.reduce_add()
        var s6 = c6.reduce_add()
        var s7 = c7.reduce_add()
        # k-tail (kc not a multiple of 8): scalar fp32 accumulation into
        # the same lane sums, preserving summation order class.
        for kk in range(k, kc):
            var aik = Float32(ap[unsafe_offset=i * kc + kk])
            s0 += aik * Float32(bp[unsafe_offset=0 * kc + kk])
            s1 += aik * Float32(bp[unsafe_offset=1 * kc + kk])
            s2 += aik * Float32(bp[unsafe_offset=2 * kc + kk])
            s3 += aik * Float32(bp[unsafe_offset=3 * kc + kk])
            s4 += aik * Float32(bp[unsafe_offset=4 * kc + kk])
            s5 += aik * Float32(bp[unsafe_offset=5 * kc + kk])
            s6 += aik * Float32(bp[unsafe_offset=6 * kc + kk])
            s7 += aik * Float32(bp[unsafe_offset=7 * kc + kk])
        acc[unsafe_offset=i * ldc + 0] += s0
        acc[unsafe_offset=i * ldc + 1] += s1
        acc[unsafe_offset=i * ldc + 2] += s2
        acc[unsafe_offset=i * ldc + 3] += s3
        acc[unsafe_offset=i * ldc + 4] += s4
        acc[unsafe_offset=i * ldc + 5] += s5
        acc[unsafe_offset=i * ldc + 6] += s6
        acc[unsafe_offset=i * ldc + 7] += s7


def gemm_scalar_tile(
    ap: Pointer[Float16, MutUntrackedOrigin],
    bp: Pointer[Float16, MutUntrackedOrigin],
    acc: Pointer[Float32, MutUntrackedOrigin],
    mr: Int,
    nr: Int,
    kc: Int,
    ldc: Int,
):
    # Edge-tile fallback for mr < 8 or nr < 8: scalar fp32 accumulation,
    # same packed layouts as the micro-kernel. Keeps every shape correct.
    for i in range(mr):
        for j in range(nr):
            var s = Float32(0)
            for k in range(kc):
                s += Float32(ap[unsafe_offset=i * kc + k]) * Float32(
                    bp[unsafe_offset=j * kc + k]
                )
            acc[unsafe_offset=i * ldc + j] += s


def gemm_pack_a(
    a: Pointer[Float16, MutUntrackedOrigin],
    ap: Pointer[Float16, MutUntrackedOrigin],
    K: Int,
    i0: Int,
    mc: Int,
    p0: Int,
    kc: Int,
):
    # ap[i*kc + k] = a[(i0+i)*K + (p0+k)]: row-panel, k contiguous.
    for i in range(mc):
        for k in range(kc):
            ap[unsafe_offset=i * kc + k] = a[unsafe_offset=(i0 + i) * K + p0 + k]


def gemm_pack_b(
    b: Pointer[Float16, MutUntrackedOrigin],
    bp: Pointer[Float16, MutUntrackedOrigin],
    N: Int,
    j0: Int,
    nc: Int,
    p0: Int,
    kc: Int,
):
    # bp[j*kc + k] = b[(p0+k)*N + (j0+j)]: column-panels, k contiguous
    # per output column so the micro-kernel streams B.
    for j in range(nc):
        for k in range(kc):
            bp[unsafe_offset=j * kc + k] = b[unsafe_offset=(p0 + k) * N + j0 + j]


def gemm_fp16(
    a: Pointer[Float16, MutUntrackedOrigin],
    b: Pointer[Float16, MutUntrackedOrigin],
    c: Pointer[Float16, MutUntrackedOrigin],
    M: Int,
    N: Int,
    K: Int,
):
    # H023 driver: full M x N x K fp16 GEMM, C = A @ B (beta = 0).
    # Cache blocking: MC=64 rows of A (32 KiB panel, L1-resident),
    # KC=256 depth, NC=64 columns of B (32 KiB panel, L1/L2-resident).
    # The fp32 accumulator tile (MC x NC) lets K block without rounding
    # C back to fp16 between blocks.
    var mc_block = 64
    var nc_block = 64
    var kc_block = 256
    var acc = unsafe_alloc[Float32](mc_block * nc_block)
    var ap = unsafe_alloc[Float16](mc_block * kc_block)
    var bp = unsafe_alloc[Float16](nc_block * kc_block)
    for i0 in range(0, M, mc_block):
        var cur_mc = mc_block
        if i0 + cur_mc > M:
            cur_mc = M - i0
        for j0 in range(0, N, nc_block):
            var cur_nc = nc_block
            if j0 + cur_nc > N:
                cur_nc = N - j0
            for t in range(cur_mc * cur_nc):
                acc[unsafe_offset=t] = Float32(0)
            for p0 in range(0, K, kc_block):
                var cur_kc = kc_block
                if p0 + cur_kc > K:
                    cur_kc = K - p0
                gemm_pack_a(a, ap, K, i0, cur_mc, p0, cur_kc)
                gemm_pack_b(b, bp, N, j0, cur_nc, p0, cur_kc)
                var ii = 0
                while ii < cur_mc:
                    var mr = 8
                    if ii + mr > cur_mc:
                        mr = cur_mc - ii
                    var jj = 0
                    while jj < cur_nc:
                        var nr = 8
                        if jj + nr > cur_nc:
                            nr = cur_nc - jj
                        if mr == 8 and nr == 8:
                            gemm_micro_8x8(
                                ap.unsafe_offset(ii * cur_kc),
                                bp.unsafe_offset(jj * cur_kc),
                                acc.unsafe_offset(ii * cur_nc + jj),
                                cur_kc,
                                cur_nc,
                            )
                        else:
                            gemm_scalar_tile(
                                ap.unsafe_offset(ii * cur_kc),
                                bp.unsafe_offset(jj * cur_kc),
                                acc.unsafe_offset(ii * cur_nc + jj),
                                mr,
                                nr,
                                cur_kc,
                                cur_nc,
                            )
                        jj += 8
                    ii += 8
            for i in range(cur_mc):
                for j in range(cur_nc):
                    c[unsafe_offset=(i0 + i) * N + j0 + j] = Float16(
                        acc[unsafe_offset=i * cur_nc + j]
                    )
