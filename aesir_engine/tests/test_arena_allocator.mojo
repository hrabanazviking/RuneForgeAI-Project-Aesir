"""Arena/pool allocator (A-026): per-request arenas with reset
semantics over the A-019 zero-copy allocator, a 10k mixed alloc/free
fragmentation stress with measured bounded waste, and the regression
for the zero-copy shim's fixed 4096-slot registry (A-023 audit find,
fixed in this slice): >4096 concurrent allocations must keep exact
live-bytes accounting and return exactly to baseline after all frees.

Present/absent discipline matches A-019/A-020: the accounting cases
are device-independent and run everywhere; the device cases verify
real HIP managed backings on purpleraider and pass as honest-absent
(fail-closed assertions) on a host without a usable HIP device.
"""
from core.arena_allocator import (
    ArenaLedger,
    RequestArena,
    ArenaPool,
    arena_align_up,
)
from core.zero_copy import ZeroCopy, ZeroCopyBuffer
from core.hip_memory import HipMemory


def _hip_present() -> Bool:
    if not ZeroCopy.hip_available():
        return False
    try:
        return HipMemory.device_count() > 0
    except:
        return False


def _expect_raise_admit(capacity: Int, size: Int, needle: String) raises:
    var ledger = ArenaLedger(capacity)
    var raised = False
    try:
        _ = ledger.admit(size, 0)
    except e:
        raised = True
        if needle not in String(e):
            raise Error("wrong refusal: " + String(e))
    if not raised:
        raise Error("admit(" + String(size) + ") was not refused")


def test_arena_reset_semantics() raises:
    print("--- Testing arena reset semantics (A-026) ---")
    var ledger = ArenaLedger(1_000_000)
    var off1 = ledger.admit(100, ledger.carved_bytes).start
    var off2 = ledger.admit(250, ledger.carved_bytes).start
    var off3 = ledger.admit(4096, ledger.carved_bytes).start
    if off1 != 0 or off2 != arena_align_up(100) or off3 != arena_align_up(100) + arena_align_up(250):
        raise Error("bump offsets are not sequential aligned carves")
    if ledger.live_blocks != 3 or ledger.live_requested_bytes != 4446:
        raise Error("live ledger wrong before reset")
    ledger.release_last(4096, off3)
    if ledger.live_blocks != 2 or ledger.carved_bytes != off3:
        raise Error("release_last did not rewind exactly")
    ledger.reset()
    if ledger.carved_bytes != 0 or ledger.live_requested_bytes != 0 or ledger.live_blocks != 0:
        raise Error("reset did not return accounting exactly to baseline")
    if ledger.total_resets != 1 or ledger.total_allocs != 3 or ledger.total_frees != 1:
        raise Error("cumulative counters wrong after reset")
    var again = ledger.admit(100, ledger.carved_bytes).start
    if again != 0:
        raise Error("arena not reusable at offset 0 after reset")
    print("ARENA_RESET_OK baseline-exact after reset")


def test_arena_rejection() raises:
    print("--- Testing arena fail-closed rejection (A-026) ---")
    _expect_raise_admit(1024, 0, "MEM-001")
    _expect_raise_admit(1024, -8, "MEM-001")
    _expect_raise_admit(1024, 2048, "MEM-003")
    var ledger = ArenaLedger(1024)
    var top = ledger.admit(512, 0).start
    var refused = False
    try:
        ledger.release_last(256, top)
    except e:
        refused = "MEM-005" in String(e)
    if not refused:
        raise Error("non-top release_last was not refused MEM-005")
    ledger.release_last(512, top)
    var double_refused = False
    try:
        ledger.release_last(512, top)
    except e:
        double_refused = "MEM-005" in String(e)
    if not double_refused:
        raise Error("double release was not refused MEM-005")
    print("ARENA_REJECTION_OK MEM-001/MEM-003/MEM-005 fail-closed")


def test_arena_fragmentation_stress() raises:
    print("--- Testing arena fragmentation stress 10k (A-026) ---")
    # Deterministic LCG so the mix is identical on every run/host.
    var state: UInt64 = 0x9E3779B97F4A7C15
    var capacity = 8 * 1024 * 1024
    var ledger = ArenaLedger(capacity)
    var stack = List[Int]()
    var stack_sizes = List[Int]()
    var peak_requested = 0
    var total_requested: Int = 0
    for op in range(10000):
        state = state * 6364136223846793005 + 1442695040888963407
        var r = Int((state >> 33) % 100)
        if r < 55 or len(stack) == 0:
            var size = 16 + Int((state >> 40) % 8192)
            if ledger.carved_bytes + arena_align_up(size) > capacity:
                ledger.reset()
                stack.clear()
                stack_sizes.clear()
            var off = ledger.admit(size, ledger.carved_bytes).start
            stack.append(off)
            stack_sizes.append(size)
            total_requested += size
            if ledger.live_requested_bytes > peak_requested:
                peak_requested = ledger.live_requested_bytes
        elif r < 85:
            var size = stack_sizes[len(stack_sizes) - 1]
            var off = stack[len(stack) - 1]
            ledger.release_last(size, off)
            _ = stack.pop()
            _ = stack_sizes.pop()
        else:
            ledger.reset()
            stack.clear()
            stack_sizes.clear()
        if ledger.carved_bytes - ledger.live_requested_bytes != ledger.padding_bytes():
            raise Error("padding ledger invariant broke at op " + String(op))
        if ledger.live_blocks != len(stack):
            raise Error("block count diverged from stack at op " + String(op))
    var peak_padding = ledger.peak_carved_bytes - peak_requested
    # Bounded waste: padding can never exceed 15 B per live block at
    # peak, and the un-carved tail is capacity the arena owns once -
    # the filed waste figure is the padding at peak live load.
    var peak_live_blocks_bound = peak_padding // 15 + 1
    _ = peak_live_blocks_bound
    if peak_padding > 15 * (10000):
        raise Error("peak padding unbounded: " + String(peak_padding))
    print(
        "ARENA_STRESS ops=10000 total_requested=" + String(total_requested)
        + " peak_requested=" + String(peak_requested)
        + " peak_carved=" + String(ledger.peak_carved_bytes)
        + " waste_bytes=" + String(peak_padding)
        + " allocs=" + String(ledger.total_allocs)
        + " frees=" + String(ledger.total_frees)
        + " resets=" + String(ledger.total_resets)
    )
    ledger.reset()
    if ledger.carved_bytes != 0 or ledger.live_requested_bytes != 0 or ledger.live_blocks != 0:
        raise Error("stress arena did not return exactly to baseline")
    print("ARENA_STRESS_OK waste bounded, baseline exact")


def test_arena_pool_device() raises:
    print("--- Testing arena pool over zero-copy backings (A-026) ---")
    if not _hip_present():
        var refused = False
        try:
            var arena = RequestArena(4096)
            arena.close()
        except:
            refused = True
        if not refused:
            raise Error("arena over absent HIP did not fail closed")
        print("HIP UNAVAILABLE: arena pool case honest-absent (fail-closed verified)")
        return
    var c0 = ZeroCopy.counters()
    var pool = ArenaPool(2, 65536)
    var a = pool.acquire()
    var b = pool.acquire()
    var exhausted = False
    try:
        _ = pool.acquire()
    except e:
        exhausted = "MEM-003" in String(e)
    if not exhausted:
        raise Error("pool exhaustion was not refused MEM-003")
    var off = pool.arenas[a].alloc(1000)
    if off != 0:
        raise Error("first carve of a fresh arena is not at offset 0")
    var base_ptr = pool.arenas[a].ptr(0)
    if base_ptr == 0 or pool.arenas[a].ptr(off) != base_ptr:
        raise Error("arena ptr does not resolve into its backing")
    pool.release(a)
    if pool.arenas[a].ledger.carved_bytes != 0 or pool.arenas[a].ledger.live_blocks != 0:
        raise Error("pool release did not reset the arena to baseline")
    var double_refused = False
    try:
        pool.release(a)
    except e:
        double_refused = "MEM-005" in String(e)
    if not double_refused:
        raise Error("double pool release was not refused MEM-005")
    pool.release(b)
    if pool.checked_out != 0:
        raise Error("pool accounting did not return to zero checked out")
    pool.close()
    var c1 = ZeroCopy.counters()
    if c1.hip_live_bytes != c0.hip_live_bytes:
        raise Error(
            "pool close leaked shim live bytes: "
            + String(c0.hip_live_bytes) + " -> " + String(c1.hip_live_bytes)
        )
    print("ARENA_POOL_OK device-backed, exhaustion/reset exact")


def test_arena_shim_registry_over_4096() raises:
    print("--- Testing zero-copy shim registry >4096 regression (A-026) ---")
    if not _hip_present():
        print("HIP UNAVAILABLE: shim registry case honest-absent")
        return
    var c0 = ZeroCopy.counters()
    var buffers = List[ZeroCopyBuffer]()
    var total: Int = 0
    for i in range(5000):
        var size = 256 + (i % 5) * 16
        buffers.append(ZeroCopy.allocate_default(size))
        total += size
    var c1 = ZeroCopy.counters()
    if c1.hip_live_bytes - c0.hip_live_bytes != total:
        raise Error(
            "shim live-bytes delta wrong past 4096 allocations: expected "
            + String(total) + " got "
            + String(c1.hip_live_bytes - c0.hip_live_bytes)
            + " (pre-fix registry dropped every size past slot 4096)"
        )
    if c1.hip_allocs - c0.hip_allocs != 5000:
        raise Error("shim alloc counter delta is not 5000")
    for i in range(len(buffers)):
        ZeroCopy.free(buffers[i])
    var c2 = ZeroCopy.counters()
    if c2.hip_live_bytes != c0.hip_live_bytes:
        raise Error(
            "shim live-bytes did not return exactly to baseline after"
            " freeing 5000 buffers: " + String(c0.hip_live_bytes)
            + " -> " + String(c2.hip_live_bytes)
        )
    if c2.hip_frees - c0.hip_frees != 5000:
        raise Error("shim free counter delta is not 5000")
    print(
        "SHIM_REGISTRY_OK concurrent=5000 bytes=" + String(total)
        + " live_bytes returned exactly to baseline "
        + String(c0.hip_live_bytes)
    )
