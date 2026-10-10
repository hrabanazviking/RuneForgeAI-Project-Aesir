# H007 SPIKE — NEON FP16 GEMM baseline (pure Mojo).
#
# Runs NATIVELY on Mimir (Raspberry Pi 5, aarch64). This is a measurement
# spike, not shipped engine code.
#
# Method: 64x64x64 FP16 matmul with an 8-wide SIMD inner kernel (8x fp16 =
# one 128-bit NEON register; explicit FMA lowers to NEON FMLA on v8f16),
# checked against a naive scalar triple-loop reference. Timing via
# clock_gettime(CLOCK_MONOTONIC) through std.ffi external_call — pure Mojo,
# no libraries (libc is the OS interface, not a dependency).
#
# Correctness inputs are deterministic dyadic rationals k/64 with k in
# [-4, 4]: every product and every partial sum of the 64-term dot product is
# exactly representable in fp16, so kernel and reference must agree bit-for-bit
# (any nonzero error is a real bug, not rounding noise).
#
# Mojo 1.1.0 API notes (all verified on-device 2026-10-10):
# - No module-level `alias`, and `alias` is gone entirely; the SIMD width is a
#   function parameter [W: Int] and sizes are plain vars/literals.
# - `Pointer` needs a concrete origin for mutable access through function
#   parameters: `Pointer[Float16, MutUntrackedOrigin]` from `std.origin`.
# - Vector load: `ptr.unsafe_offset(i).unsafe_load[W]()` (dtype inferred).
# - Scalar access: `ptr[unsafe_offset=i]`; allocation: `unsafe_alloc[T](n)`.
# - `UnsafePointer` is deprecated; `from time` / `from sys.ffi` do not exist;
#   use `from std.ffi import external_call` and run mojo via `pixi run`
#   (direct binary invocation cannot find the stdlib).

from std.ffi import external_call
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from std.memory.alloc import unsafe_alloc


def now_ns() -> Int64:
    var ts = unsafe_alloc[Int64](2)
    _ = external_call["clock_gettime", Int32, Int32, type_of(ts)](0, ts)
    var sec: Int64 = ts[unsafe_offset=0]
    var nsec: Int64 = ts[unsafe_offset=1]
    return sec * 1_000_000_000 + nsec


def fill_dyadic(p: Pointer[Float16, MutUntrackedOrigin], n: Int, sa: Int, sb: Int):
    for i in range(n):
        for j in range(n):
            var k = (i * sa + j * sb + 11) % 9 - 4
            p[unsafe_offset=i * n + j] = Float16(k) / Float16(64)


def transpose(
    b: Pointer[Float16, MutUntrackedOrigin],
    bt: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
):
    for i in range(n):
        for j in range(n):
            bt[unsafe_offset=j * n + i] = b[unsafe_offset=i * n + j]


def matmul_scalar(
    a: Pointer[Float16, MutUntrackedOrigin],
    b: Pointer[Float16, MutUntrackedOrigin],
    c: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
):
    for i in range(n):
        for j in range(n):
            var s = Float16(0)
            for k in range(n):
                s += a[unsafe_offset=i * n + k] * b[unsafe_offset=k * n + j]
            c[unsafe_offset=i * n + j] = s


def matmul_neon[W: Int](
    a: Pointer[Float16, MutUntrackedOrigin],
    bt: Pointer[Float16, MutUntrackedOrigin],
    c: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
):
    # bt holds B transposed, so the k-loop streams two contiguous 8xfp16
    # vectors. av.fma(bv, acc) = av*bv + acc -> NEON FMLA on v8f16.
    for i in range(n):
        for j in range(n):
            var acc = SIMD[DType.float16, W](0)
            for k in range(0, n, W):
                var av = a.unsafe_offset(i * n + k).unsafe_load[W]()
                var bv = bt.unsafe_offset(j * n + k).unsafe_load[W]()
                acc = av.fma(bv, acc)
            c[unsafe_offset=i * n + j] = acc.reduce_add()


def max_abs_err(
    c: Pointer[Float16, MutUntrackedOrigin],
    cref: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
) -> Float16:
    var m = Float16(0)
    for i in range(n * n):
        var d = c[unsafe_offset=i] - cref[unsafe_offset=i]
        if d < Float16(0):
            d = -d
        if d > m:
            m = d
    return m


def main():
    var n = 64
    var a = unsafe_alloc[Float16](n * n)
    var b = unsafe_alloc[Float16](n * n)
    var bt = unsafe_alloc[Float16](n * n)
    var c_ref = unsafe_alloc[Float16](n * n)
    var c_neon = unsafe_alloc[Float16](n * n)

    fill_dyadic(a, n, 7, 13)
    fill_dyadic(b, n, 13, 7)
    transpose(b, bt, n)

    # Correctness: scalar reference vs NEON kernel.
    matmul_scalar(a, b, c_ref, n)
    matmul_neon[8](a, bt, c_neon, n)
    var err = max_abs_err(c_neon, c_ref, n)
    print("H007_MAX_ABS_ERR", err)

    # Benchmark: warmup, then 11 timed runs; each run = 50 matmuls.
    for _ in range(3):
        matmul_neon[8](a, bt, c_neon, n)
    for r in range(11):
        var t0 = now_ns()
        for _ in range(50):
            matmul_neon[8](a, bt, c_neon, n)
        var t1 = now_ns()
        var ns_per_matmul = (t1 - t0) / 50
        print("H007_RUN", r, ns_per_matmul)
