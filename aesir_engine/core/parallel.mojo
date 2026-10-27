# core/parallel.mojo
# Real OS-thread parallelism for the CPU forward path, via FFI.
#
# This Mojo stdlib exposes `vectorize` but no `parallelize`, and
# RuneThreadPool is cooperative bookkeeping, not threads. The vehicle
# is the pthread shim in aesir_engine/thread_par.c (libaesir_par.so,
# staged and linked by scripts/launch.py exactly like the Hailo
# bridge): it splits an index range into contiguous chunks and calls a
# Mojo range callback once per chunk on genuine POSIX threads.
#
# Safety contract:
#   - Callbacks must compute each output element independently with a
#     fixed per-element reduction order, so threaded results are
#     bit-identical to the serial path (the GEMM kernels partition
#     output columns for exactly this reason).
#   - AESIR_THREADS=1 forces the serial path; AESIR_THREADS=N caps the
#     chunk count; unset/0/invalid selects the online CPU count (<= 32).
#   - AESIR_PAR_MIN_WORK overrides the engagement threshold (total
#     multiply-accumulates below which thread overhead is not paid).
#   - Any shim failure (bad return, thread-creation failure handled
#     inside the shim) degrades to the serial call — never a crash,
#     never a hang, never lost work.

from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray


alias RangeFn = def(Int64, Int64, Int64) thin -> None

comptime PAR_DEFAULT_MIN_WORK: Int64 = 1048576  # 2^20 multiply-accumulates


def _env_int(name: String, default: Int) -> Int:
    """Reads a non-negative decimal integer environment variable.

    Returns `default` when the variable is unset, empty, or contains
    anything but digits (a leading '-' or '+' is invalid, not a sign).
    """
    var buf = InlineArray[Int8, 32](fill=0)
    var bytes = name.as_bytes()
    if len(bytes) >= 32:
        return default
    for i in range(len(bytes)):
        buf[i] = Int8(bytes[i])
    var raw = external_call["getenv", Pointer[UInt8, MutUntrackedOrigin]](
        buf.unsafe_ptr()
    )
    if Int(raw) == 0:
        return default
    var value = 0
    var seen = False
    var i = 0
    while i < 24:
        var c = raw.unsafe_load(i)
        if c == 0:
            break
        if c < 48 or c > 57:
            return default
        value = value * 10 + Int(c) - 48
        seen = True
        if value > 100000000:
            return value
        i += 1
    if not seen:
        return default
    return value


def cpu_has_vnni() -> Bool:
    """True when CPU + OS expose AVX-512 VNNI (probed in the C shim
    via CPUID + XCR0, never assumed from build flags)."""
    return external_call["aesir_cpu_vnni", Int32]() == Int32(1)


def cpu_has_bf16() -> Bool:
    """True when CPU + OS expose AVX-512 BF16 (probed in the C shim)."""
    return external_call["aesir_cpu_bf16", Int32]() == Int32(1)


def par_cpu_count() -> Int:
    """Online CPUs as reported by the shim (sysconf); always >= 1."""
    var n = external_call["aesir_par_cpu_count", Int64]()
    if n < 1:
        return 1
    if n > 4096:
        return 4096
    return Int(n)


def par_thread_count() -> Int:
    """Worker chunk count for parallel ranges (1 = force serial)."""
    var v = _env_int("AESIR_THREADS", 0)
    if v == 1:
        return 1
    if v > 1:
        return v if v < 1024 else 1024
    var cpus = par_cpu_count()
    return cpus if cpus < 32 else 32


def par_min_work() -> Int64:
    """Engagement threshold in multiply-accumulates."""
    var v = _env_int("AESIR_PAR_MIN_WORK", 0)
    if v > 0:
        return Int64(v)
    return PAR_DEFAULT_MIN_WORK


def par_for[f: RangeFn](ctx: Int64, n: Int, work: Int64) -> Int:
    """Runs f(ctx, start, end) over the range [0, n).

    The worker is a compile-time parameter: in this toolchain a named
    def has a unique function type that only materializes as a C
    function pointer when passed concretely, which is also what lets
    the FFI shim call it back from other threads.

    Serial in-process when threading is disabled, the range is trivial,
    or the estimated work is below the engagement threshold; otherwise
    split across OS threads by the FFI shim. A shim return below 1
    falls back to the serial call. Returns the chunk count used.
    """
    var threads = par_thread_count()
    if threads <= 1 or n <= 1 or work < par_min_work():
        f(ctx, 0, Int64(n))
        return 1
    var chunks = external_call["aesir_par_for", Int64](
        f, ctx, Int64(n), Int64(threads)
    )
    if chunks < 1:
        f(ctx, 0, Int64(n))
        return 1
    return Int(chunks)
