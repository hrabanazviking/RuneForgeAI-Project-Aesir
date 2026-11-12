"""A-041: thread scaling law -- choke-guard default policy and the
C-008 config cache.

Policy cases pin par_default_threads / par_resolve_threads as pure
functions (the scaling curve they encode is filed in
docs/bench/A041_THREAD_SCALING_LAW.md). Cache cases prove the
A-037 census row C-008 fix behaviorally: after the shim's one-time
snapshot, sysconf probes stay at 1 and env reads do not grow per
dispatch; a raw setenv WITHOUT par_refresh_config leaves the
served config unchanged (no per-call getenv remains), and the
thread_topology knob setters -- which do refresh -- keep the
J-039 set/read-back/clear contract exact. The dispatch case runs
the bench's GEMV partition through par_for at 4 threads and
requires the serial checksum bit-exactly, with the chunk count as
proof the rung's threads ran.
"""
from std.ffi import external_call
from std.memory import alloc
from core.parallel import (
    PAR_DEFAULT_MIN_WORK,
    par_cpu_count,
    par_default_threads,
    par_env_reads,
    par_for,
    par_min_work,
    par_refresh_config,
    par_resolve_threads,
    par_sysconf_probes,
    par_thread_count,
)
from core.thread_topology import clear_thread_knobs, set_thread_knobs


def _eq(got: Int, want: Int, what: String) raises:
    if got != want:
        raise Error(
            "A041 " + what + ": got " + String(got) + " want " + String(want)
        )


def _set_env_raw(name: String, value: String):
    # setenv(3) through FFI with NO par_refresh_config -- the point
    # of the stale-cache case is that this alone changes nothing.
    var name_buf = InlineArray[Int8, 32](fill=0)
    var name_bytes = name.as_bytes()
    for i in range(len(name_bytes)):
        if i < 31:
            name_buf[i] = Int8(name_bytes[i])
    var value_buf = InlineArray[Int8, 32](fill=0)
    var value_bytes = value.as_bytes()
    for i in range(len(value_bytes)):
        if i < 31:
            value_buf[i] = Int8(value_bytes[i])
    _ = external_call["setenv", Int32](
        name_buf.unsafe_ptr(), value_buf.unsafe_ptr(), Int32(1)
    )


def test_thread_scaling_default_policy() raises:
    print("--- Testing choke-guard default policy (A-041) ---")
    _eq(par_default_threads(0), 1, "default(0)")
    _eq(par_default_threads(1), 1, "default(1)")
    _eq(par_default_threads(2), 2, "default(2)")
    _eq(par_default_threads(3), 2, "default(3)")
    _eq(par_default_threads(4), 3, "default(4)")
    _eq(par_default_threads(8), 6, "default(8)")
    _eq(par_default_threads(16), 12, "default(16)")
    _eq(par_default_threads(32), 24, "default(32) Z13")
    _eq(par_default_threads(64), 32, "default(64) capped")
    _eq(par_default_threads(128), 32, "default(128) capped")
    _eq(par_resolve_threads(0, 32), 24, "resolve unset -> default")
    _eq(par_resolve_threads(1, 32), 1, "resolve 1 -> serial")
    _eq(par_resolve_threads(2, 32), 2, "resolve 2")
    _eq(par_resolve_threads(7, 4), 7, "resolve explicit wins over cpus")
    _eq(par_resolve_threads(2000, 32), 1024, "resolve cap 1024")
    _eq(par_resolve_threads(0, 4), 3, "resolve unset on 4 cpus")
    print("PASS: choke-guard default policy table")


def test_thread_scaling_cache_probes() raises:
    print("--- Testing config cache probes (A-041/C-008) ---")
    par_refresh_config()
    _eq(par_sysconf_probes(), 1, "sysconf probed exactly once")
    var reads0 = par_env_reads()
    if reads0 < 2:
        raise Error("A041 env reads after refresh: got " + String(reads0))
    var acc = 0
    for _ in range(1000):
        acc += par_cpu_count()
        acc += par_thread_count()
        if par_min_work() < 1:
            raise Error("A041 min_work below 1")
    if acc < 1000:
        raise Error("A041 accumulator sanity")
    _eq(par_sysconf_probes(), 1, "sysconf still once after 1000 dispatches")
    _eq(par_env_reads(), reads0, "env reads unchanged after 1000 dispatches")
    print("PASS: sysconf once, env reads frozen across 1000 getter calls")


def test_thread_scaling_knob_readback() raises:
    print("--- Testing knob set/read-back/clear (A-041, J-039 contract) ---")
    set_thread_knobs(2)
    _eq(par_thread_count(), 2, "AESIR_THREADS=2 reads back as 2")
    set_thread_knobs(3)
    _eq(par_thread_count(), 3, "AESIR_THREADS=3 reads back as 3")
    clear_thread_knobs()
    _eq(
        par_thread_count(),
        par_default_threads(par_cpu_count()),
        "cleared knobs restore the choke-guard default",
    )
    if par_cpu_count() == 32:
        _eq(par_thread_count(), 24, "Z13 default is 24 of 32")
    print("PASS: knobs set/read back/clear through the cached layer")


def test_thread_scaling_stale_until_refresh() raises:
    print("--- Testing stale-until-refresh cache proof (A-041/C-008) ---")
    set_thread_knobs(2)
    _eq(par_thread_count(), 2, "baseline knob 2")
    _set_env_raw("AESIR_THREADS", "5")
    _eq(
        par_thread_count(),
        2,
        "raw setenv without refresh leaves the served config unchanged",
    )
    par_refresh_config()
    _eq(par_thread_count(), 5, "explicit refresh serves the new value")
    clear_thread_knobs()
    print("PASS: no per-call getenv; refresh is the only re-read")


def test_thread_scaling_min_work_cached() raises:
    print("--- Testing cached engagement threshold (A-041) ---")
    set_thread_knobs(2)
    if par_min_work() != Int64(1):
        raise Error("A041 knob min_work: got " + String(par_min_work()))
    _set_env_raw("AESIR_PAR_MIN_WORK", "7")
    if par_min_work() != Int64(1):
        raise Error("A041 min_work moved without refresh")
    par_refresh_config()
    if par_min_work() != Int64(7):
        raise Error("A041 min_work after refresh: got " + String(par_min_work()))
    clear_thread_knobs()
    if par_min_work() != PAR_DEFAULT_MIN_WORK:
        raise Error("A041 min_work default not restored")
    print("PASS: AESIR_PAR_MIN_WORK served from the same cache")


def _gemv_range(
    input_addr: Int64,
    matrix_addr: Int64,
    output_addr: Int64,
    k: Int,
    n: Int,
    col_lo: Int,
    col_hi: Int,
):
    var input = Pointer[Float32, MutUntrackedOrigin](
        unsafe_from_address=Int(input_addr)
    )
    var matrix = Pointer[Float32, MutUntrackedOrigin](
        unsafe_from_address=Int(matrix_addr)
    )
    var output = Pointer[Float32, MutUntrackedOrigin](
        unsafe_from_address=Int(output_addr)
    )
    for j in range(col_lo, col_hi):
        var acc = Float32(0)
        for kk in range(k):
            acc += input.unsafe_load(kk) * matrix.unsafe_load(kk * n + j)
        output.unsafe_store(j, acc)


def _gemv_worker(ctx_addr: Int64, start: Int64, end: Int64):
    var ctx = Pointer[Int64, MutUntrackedOrigin](
        unsafe_from_address=Int(ctx_addr)
    )
    _gemv_range(
        ctx.unsafe_load(0),
        ctx.unsafe_load(1),
        ctx.unsafe_load(2),
        Int(ctx.unsafe_load(3)),
        Int(ctx.unsafe_load(4)),
        Int(start),
        Int(end),
    )


def test_thread_scaling_dispatch_identity() raises:
    print("--- Testing threaded dispatch identity (A-041) ---")
    comptime K = 64
    comptime N = 256
    var input = alloc[Float32](K)
    var matrix = alloc[Float32](K * N)
    var out_serial = alloc[Float32](N)
    var out_threaded = alloc[Float32](N)
    var state: UInt64 = 0xA041
    for i in range(K * N):
        state = state * 6364136223846793005 + 1442695040888963407
        matrix.unsafe_store(
            i, Float32(Int(state >> 40) & 0xFF) / Float32(255.0) - Float32(0.5)
        )
    for i in range(K):
        state = state * 6364136223846793005 + 1442695040888963407
        input.unsafe_store(
            i, Float32(Int(state >> 40) & 0xFF) / Float32(255.0) - Float32(0.5)
        )
    var ctx = alloc[Int64](5)
    ctx.unsafe_store(0, Int64(Int(input)))
    ctx.unsafe_store(1, Int64(Int(matrix)))
    ctx.unsafe_store(3, Int64(K))
    ctx.unsafe_store(4, Int64(N))
    var work = Int64(K) * Int64(N)
    set_thread_knobs(1)
    ctx.unsafe_store(2, Int64(Int(out_serial)))
    var chunks_serial = par_for[_gemv_worker](Int64(Int(ctx)), N, work)
    _eq(chunks_serial, 1, "serial rung uses 1 chunk")
    set_thread_knobs(4)
    ctx.unsafe_store(2, Int64(Int(out_threaded)))
    var chunks_threaded = par_for[_gemv_worker](Int64(Int(ctx)), N, work)
    _eq(chunks_threaded, 4, "threaded rung uses 4 chunks")
    clear_thread_knobs()
    for j in range(N):
        if out_serial.unsafe_load(j) != out_threaded.unsafe_load(j):
            raise Error("A041 threaded output differs at column " + String(j))
    ctx.unsafe_free()
    input.unsafe_free()
    matrix.unsafe_free()
    out_serial.unsafe_free()
    out_threaded.unsafe_free()
    print("PASS: 4-thread dispatch bit-identical to serial, chunks == 4")
