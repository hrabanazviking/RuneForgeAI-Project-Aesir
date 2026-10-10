# H021 — ARMVEGR shared utilities: timing, deterministic RNG, allocation.
#
# The RNG (splitmix64) is implemented IDENTICALLY in
# prof/armvegr/test_kernel_oracles.py (pure Python). Fixed seeds therefore
# produce bit-identical input streams on both sides of the H037 oracle.

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


def rng_next(state: Pointer[UInt64, MutUntrackedOrigin]) -> UInt64:
    # splitmix64. Returns the next output word and advances *state.
    var z = state[unsafe_offset=0] + UInt64(0x9E3779B97F4A7C15)
    state[unsafe_offset=0] = z
    z = (z ^ (z >> 30)) * UInt64(0xBF58476D1CE4E5B9)
    z = (z ^ (z >> 27)) * UInt64(0x94D049BB133111EB)
    return z ^ (z >> 31)


def rand_unit_f16(state: Pointer[UInt64, MutUntrackedOrigin]) -> Float16:
    # Deterministic fp16 in [-1, 1): the top 16 bits of the word give an
    # exact fp64 fraction; the fp64->fp16 conversion rounds to nearest-even,
    # exactly matching the Python oracle's fp16 encoder.
    var w = rng_next(state)
    var frac = Float64(w >> 48) / Float64(65536.0)
    return Float16(frac * 2.0 - 1.0)


def rand_range_f16(
    state: Pointer[UInt64, MutUntrackedOrigin], lo: Float64, hi: Float64
) -> Float16:
    var w = rng_next(state)
    var frac = Float64(w >> 48) / Float64(65536.0)
    return Float16(lo + frac * (hi - lo))


def fill_rand_f16(
    p: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
    state: Pointer[UInt64, MutUntrackedOrigin],
    lo: Float64,
    hi: Float64,
):
    for i in range(n):
        p[unsafe_offset=i] = rand_range_f16(state, lo, hi)


def max_abs_err_f16(
    a: Pointer[Float16, MutUntrackedOrigin],
    b: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
) -> Float64:
    # |a-b| max, measured in fp64 so the comparison itself adds no error.
    var m = Float64(0)
    for i in range(n):
        var d = Float64(a[unsafe_offset=i]) - Float64(b[unsafe_offset=i])
        if d < 0:
            d = -d
        if d > m:
            m = d
    return m


def sum_f64(
    a: Pointer[Float16, MutUntrackedOrigin], n: Int
) -> Float64:
    var s = Float64(0)
    for i in range(n):
        s += Float64(a[unsafe_offset=i])
    return s
