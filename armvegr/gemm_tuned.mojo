# armvegr/gemm_tuned.mojo
# H164/H165 — tunable NEON FP16 GEMM driver (Domain D1 ARMVEGR, pure Mojo).
#
# Additive: gemm_fp16 in gemm.mojo is untouched. This module provides
# gemm_fp16_tuned with a GemmTune parameter (Mc/Kc/Nc blocking, software
# prefetch distance, hoisted B packing, micro-kernel variant) for the C9
# tuning sweeps. If a configuration wins the sweep, gemm_fp16 adopts it
# (in-place optimization, re-verified) — until then the shipped kernel is
# unchanged.
#
# Correctness contract: for every tune, gemm_fp16_tuned must be
# bit-identical to gemm_fp16 (same fp32 summation order: k ascending within
# each output element). The H023 shape-matrix oracle re-verifies this.

from std.ffi import external_call
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from std.memory.alloc import unsafe_alloc

from armvegr.gemm import gemm_micro_8x8, gemm_scalar_tile, gemm_pack_a, gemm_pack_b


struct GemmTune:
    # mc/kc/nc: cache-blocking parameters (rows of A / k-depth / cols of B).
    # prefetch_dist: bytes ahead for software prefetch in the micro-kernel
    #   (0 = off).
    # hoist_b: pack each B panel once per (j0, p0) and reuse it across all
    #   i0 row-blocks (False = original: re-pack B per i0 block).
    # micro: 0 = gemm_micro_8x8, 1 = pipelined 8x8 (k-loop unrolled x2 with
    #   next-row A prefetch).
    var mc: Int
    var kc: Int
    var nc: Int
    var prefetch_dist: Int
    var hoist_b: Bool
    var micro: Int

    def __init__(
        out self, mc: Int, kc: Int, nc: Int, prefetch_dist: Int, hoist_b: Bool, micro: Int
    ):
        self.mc = mc
        self.kc = kc
        self.nc = nc
        self.prefetch_dist = prefetch_dist
        self.hoist_b = hoist_b
        self.micro = micro


def gemm_default_tune() -> GemmTune:
    # The H023 shipped configuration.
    return GemmTune(64, 256, 64, 0, False, 0)


def gemm_tune_desc(t: GemmTune) -> String:
    var d = String("mc") + String(t.mc) + String("_kc") + String(t.kc)
    d += String("_nc") + String(t.nc) + String("_pf") + String(t.prefetch_dist)
    d += String("_hoist") + String(1 if t.hoist_b else 0)
    d += String("_micro") + String(t.micro)
    return d


def _gemm_pf(p: Pointer[Float16, MutUntrackedOrigin]):
    # Software prefetch for read, high temporal locality (L1).
    external_call["llvm.prefetch.p0", NoneType](p, Int32(0), Int32(3), Int32(1))


def gemm_micro_8x8_pf(
    ap: Pointer[Float16, MutUntrackedOrigin],
    bp: Pointer[Float16, MutUntrackedOrigin],
    acc: Pointer[Float32, MutUntrackedOrigin],
    kc: Int,
    ldc: Int,
    pf_elems: Int,
):
    # gemm_micro_8x8 with software prefetch: each k-iteration prefetches the
    # B stream pf_elems fp16 elements ahead (once, shared by all rows) and
    # each row's A stream pf_elems ahead. When pf_elems == 0 this is
    # instruction-identical to gemm_micro_8x8 (the branches fold).
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
            if pf_elems > 0:
                _gemm_pf(bp.unsafe_offset(k + pf_elems))
                _gemm_pf(ap.unsafe_offset(i * kc + k + pf_elems))
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


def gemm_micro_8x8_pipe(
    ap: Pointer[Float16, MutUntrackedOrigin],
    bp: Pointer[Float16, MutUntrackedOrigin],
    acc: Pointer[Float32, MutUntrackedOrigin],
    kc: Int,
    ldc: Int,
):
    # Micro-kernel variant 1: 8x8 tile, k-loop unrolled x2 with the two
    # halves' loads interleaved (software pipelining). Same arithmetic as
    # gemm_micro_8x8, same summation order class (k ascending); gives the
    # scheduler twice the independent FMA chains per iteration to hide the
    # ~4-cycle NEON FMA latency.
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
        while k + 16 <= kc:
            var av0 = ap.unsafe_offset(i * kc + k).unsafe_load[8]().cast[DType.float32]()
            var av1 = ap.unsafe_offset(i * kc + k + 8).unsafe_load[8]().cast[DType.float32]()
            var b0 = bp.unsafe_offset(0 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c0 = av0.fma(b0, c0)
            var b0b = bp.unsafe_offset(0 * kc + k + 8).unsafe_load[8]().cast[DType.float32]()
            c0 = av1.fma(b0b, c0)
            var b1 = bp.unsafe_offset(1 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c1 = av0.fma(b1, c1)
            var b1b = bp.unsafe_offset(1 * kc + k + 8).unsafe_load[8]().cast[DType.float32]()
            c1 = av1.fma(b1b, c1)
            var b2 = bp.unsafe_offset(2 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c2 = av0.fma(b2, c2)
            var b2b = bp.unsafe_offset(2 * kc + k + 8).unsafe_load[8]().cast[DType.float32]()
            c2 = av1.fma(b2b, c2)
            var b3 = bp.unsafe_offset(3 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c3 = av0.fma(b3, c3)
            var b3b = bp.unsafe_offset(3 * kc + k + 8).unsafe_load[8]().cast[DType.float32]()
            c3 = av1.fma(b3b, c3)
            var b4 = bp.unsafe_offset(4 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c4 = av0.fma(b4, c4)
            var b4b = bp.unsafe_offset(4 * kc + k + 8).unsafe_load[8]().cast[DType.float32]()
            c4 = av1.fma(b4b, c4)
            var b5 = bp.unsafe_offset(5 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c5 = av0.fma(b5, c5)
            var b5b = bp.unsafe_offset(5 * kc + k + 8).unsafe_load[8]().cast[DType.float32]()
            c5 = av1.fma(b5b, c5)
            var b6 = bp.unsafe_offset(6 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c6 = av0.fma(b6, c6)
            var b6b = bp.unsafe_offset(6 * kc + k + 8).unsafe_load[8]().cast[DType.float32]()
            c6 = av1.fma(b6b, c6)
            var b7 = bp.unsafe_offset(7 * kc + k).unsafe_load[8]().cast[DType.float32]()
            c7 = av0.fma(b7, c7)
            var b7b = bp.unsafe_offset(7 * kc + k + 8).unsafe_load[8]().cast[DType.float32]()
            c7 = av1.fma(b7b, c7)
            k += 16
        # Remainder: fall back to the standard 8-lane loop for k..kc.
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


def _tuned_tiles(
    ap: Pointer[Float16, MutUntrackedOrigin],
    bp: Pointer[Float16, MutUntrackedOrigin],
    acc: Pointer[Float32, MutUntrackedOrigin],
    cur_mc: Int,
    cur_nc: Int,
    cur_kc: Int,
    tune: GemmTune,
):
    # Dispatch the (cur_mc x cur_nc) tile over the packed panels to the
    # selected micro-kernel. acc has row stride cur_nc.
    var pf_elems = tune.prefetch_dist // 2
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
                if tune.micro == 1:
                    gemm_micro_8x8_pipe(
                        ap.unsafe_offset(ii * cur_kc),
                        bp.unsafe_offset(jj * cur_kc),
                        acc.unsafe_offset(ii * cur_nc + jj),
                        cur_kc,
                        cur_nc,
                    )
                elif pf_elems > 0:
                    gemm_micro_8x8_pf(
                        ap.unsafe_offset(ii * cur_kc),
                        bp.unsafe_offset(jj * cur_kc),
                        acc.unsafe_offset(ii * cur_nc + jj),
                        cur_kc,
                        cur_nc,
                        pf_elems,
                    )
                else:
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


def gemm_fp16_tuned(
    a: Pointer[Float16, MutUntrackedOrigin],
    b: Pointer[Float16, MutUntrackedOrigin],
    c: Pointer[Float16, MutUntrackedOrigin],
    M: Int,
    N: Int,
    K: Int,
    tune: GemmTune,
):
    # Tunable GEMM: C[M,N] = A[M,K] x B[K,N], fp32 accumulation, fp16 out.
    #
    # hoist_b=False: original H023 loop nest (i0 -> j0 -> p0), B re-packed
    #   per i0 block; accumulator tile is mc x nc.
    # hoist_b=True: restructured nest (j0 -> p0 -> i0); each B panel is
    #   packed once per (j0, p0) and reused across all i0 row-blocks;
    #   accumulator is M x nc (one full column-block of C), zeroed per j0.
    # Both nests accumulate k ascending, so results are bit-identical to
    # gemm_fp16 for every tune.
    var mc = tune.mc
    var kc = tune.kc
    var nc = tune.nc
    if mc <= 0 or kc <= 0 or nc <= 0:
        # Fail closed on nonsense tunes (the sweep driver validates too).
        return
    if tune.hoist_b:
        var acc = unsafe_alloc[Float32](M * nc)
        var ap = unsafe_alloc[Float16](mc * kc)
        var bp = unsafe_alloc[Float16](nc * kc)
        for j0 in range(0, N, nc):
            var cur_nc = nc
            if j0 + cur_nc > N:
                cur_nc = N - j0
            for t in range(M * cur_nc):
                acc[unsafe_offset=t] = Float32(0)
            for p0 in range(0, K, kc):
                var cur_kc = kc
                if p0 + cur_kc > K:
                    cur_kc = K - p0
                gemm_pack_b(b, bp, N, j0, cur_nc, p0, cur_kc)
                for i0 in range(0, M, mc):
                    var cur_mc = mc
                    if i0 + cur_mc > M:
                        cur_mc = M - i0
                    gemm_pack_a(a, ap, K, i0, cur_mc, p0, cur_kc)
                    _tuned_tiles(
                        ap, bp, acc.unsafe_offset(i0 * cur_nc),
                        cur_mc, cur_nc, cur_kc, tune,
                    )
            for i in range(M):
                for j in range(cur_nc):
                    c[unsafe_offset=i * N + j0 + j] = Float16(
                        acc[unsafe_offset=i * cur_nc + j]
                    )
        acc.unsafe_free()
        ap.unsafe_free()
        bp.unsafe_free()
    else:
        var acc = unsafe_alloc[Float32](mc * nc)
        var ap = unsafe_alloc[Float16](mc * kc)
        var bp = unsafe_alloc[Float16](nc * kc)
        for i0 in range(0, M, mc):
            var cur_mc = mc
            if i0 + cur_mc > M:
                cur_mc = M - i0
            for j0 in range(0, N, nc):
                var cur_nc = nc
                if j0 + cur_nc > N:
                    cur_nc = N - j0
                for t in range(cur_mc * cur_nc):
                    acc[unsafe_offset=t] = Float32(0)
                for p0 in range(0, K, kc):
                    var cur_kc = kc
                    if p0 + cur_kc > K:
                        cur_kc = K - p0
                    gemm_pack_a(a, ap, K, i0, cur_mc, p0, cur_kc)
                    gemm_pack_b(b, bp, N, j0, cur_nc, p0, cur_kc)
                    _tuned_tiles(ap, bp, acc, cur_mc, cur_nc, cur_kc, tune)
                for i in range(cur_mc):
                    for j in range(cur_nc):
                        c[unsafe_offset=(i0 + i) * N + j0 + j] = Float16(
                            acc[unsafe_offset=i * cur_nc + j]
                        )
        acc.unsafe_free()
        ap.unsafe_free()
        bp.unsafe_free()


def gemm_tuned_version() -> String:
    return "0.1.0"
