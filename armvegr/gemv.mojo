# H024 — NEON FP16 GEMV: y[M] = A[M,N] @ x[N], the decode-phase kernel.
#
# Memory-bound by design: the matrix is streamed exactly once (2*M*N
# bytes). Unlike the GEMM driver there is no reuse to block for, so the
# optimization target is sustained load bandwidth: 8-wide fp16 loads
# widened to fp32 for the FMA accumulation, one row at a time. The x
# vector is reused across rows and stays L1-resident.

from std.memory import Pointer
from std.origin import MutUntrackedOrigin


def gemv_fp16(
    a: Pointer[Float16, MutUntrackedOrigin],
    x: Pointer[Float16, MutUntrackedOrigin],
    y: Pointer[Float16, MutUntrackedOrigin],
    M: Int,
    N: Int,
):
    for i in range(M):
        var acc = SIMD[DType.float32, 8](0)
        var k = 0
        while k + 8 <= N:
            var av = a.unsafe_offset(i * N + k).unsafe_load[8]().cast[DType.float32]()
            var xv = x.unsafe_offset(k).unsafe_load[8]().cast[DType.float32]()
            acc = av.fma(xv, acc)
            k += 8
        var s = acc.reduce_add()
        for kk in range(k, N):
            s += Float32(a.unsafe_offset(i * N + kk)) * Float32(x.unsafe_offset(kk))
        y[unsafe_offset=i] = Float16(s)


def gemv_bytes(M: Int, N: Int) -> Int64:
    # Bytes streamed by gemv_fp16: the matrix dominates (x and y negligible
    # but counted for honesty in bandwidth math).
    return Int64(2 * M * N + 2 * N + 2 * M)
