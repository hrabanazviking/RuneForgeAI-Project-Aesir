# core/arena_allocator.mojo
# A-026: Arena/pool allocator for inference.
#
# Per-request arenas with reset semantics for activations, built on
# the banked A-019 zero-copy allocator (core/zero_copy.mojo) and in
# the A-023 governor accounting style (core/memory_budget.mojo in the
# A-023 line): exact integer byte accounting, admission BEFORE any
# backing memory is requested, checked release, and fail-closed
# refusals named in the repo error taxonomy (ERROR_TAXONOMY.md):
#
#   * MEM-003 OUT_OF_MEMORY - an allocation that would exceed the
#     arena's fixed capacity is refused before anything is charged;
#     the arena never grows, never wraps, and never hands out a span
#     it cannot account for.
#   * MEM-005 DOUBLE_FREE - releasing the same live block twice (or
#     rewinding/freeing after a reset already reclaimed it) raises
#     instead of corrupting the ledger.
#   * MEM-001 HOST_MALLOC_FAILED - a zero or negative size is
#     refused at admission, like every other allocator in the repo.
#
# Design:
#   1. One arena = ONE backing ZeroCopy allocation (HIP managed by
#      default, the A-008/A-019 rule) carved by a bump pointer.
#      Individual activations are offsets into that backing, admitted
#      through core/checked_span before any pointer arithmetic.
#   2. Reset semantics: reset() returns the bump pointer, the live
#      ledger and every counter of live state to the exact baseline
#      in O(1) bookkeeping - no per-block free calls, no backing
#      release. A request's activations die together, which is the
#      inference access pattern (per-request lifetime).
#   3. Stack discipline between resets: free_last() rewinds only the
#      most recent live block (checked - anything else raises), and
#      mark()/rewind() give checkpoint rollback. External
#      fragmentation is therefore zero by construction; the only
#      waste is alignment padding plus the un-carved tail, both
#      measured exactly by waste_bytes() and filed by the stress
#      case (10k mixed alloc/free, see tests/test_arena_allocator).
#   4. ArenaPool: a fixed set of arenas handed out per request;
#      acquire() fails closed when every arena is checked out,
#      release() resets the arena and returns it to the pool.
#
# Nothing is simulated: the backing is a real zero-copy allocation,
# and on a host without a usable backend every device operation
# raises through ZeroCopy (honest-absent), while the pure accounting
# rules are testable everywhere through the ledger functions below.

from core.checked_span import checked_span, CheckedSpan
from core.zero_copy import ZeroCopy, ZeroCopyBuffer, BACKEND_HIP_MANAGED

comptime ARENA_ALIGNMENT = 16
comptime ARENA_DEFAULT_CAPACITY = 4 * 1024 * 1024


def arena_align_up(size_bytes: Int) -> Int:
    """Round a byte size up to the arena alignment (16 B)."""
    return ((size_bytes + ARENA_ALIGNMENT - 1) // ARENA_ALIGNMENT) * ARENA_ALIGNMENT


struct ArenaLedger(Copyable, ImplicitlyCopyable):
    """Pure per-arena accounting (A-023 governor style): exact
    integer ledgers, admission checked before charging, release
    checked against live state. Device-independent."""

    var capacity_bytes: Int
    var carved_bytes: Int
    var live_requested_bytes: Int
    var live_blocks: Int
    var total_allocs: Int
    var total_frees: Int
    var total_resets: Int
    var peak_carved_bytes: Int

    def __init__(out self, capacity_bytes: Int):
        self.capacity_bytes = capacity_bytes
        self.carved_bytes = 0
        self.live_requested_bytes = 0
        self.live_blocks = 0
        self.total_allocs = 0
        self.total_frees = 0
        self.total_resets = 0
        self.peak_carved_bytes = 0

    def padding_bytes(self) -> Int:
        """Alignment padding inside the carved region."""
        return self.carved_bytes - self.live_requested_bytes

    def waste_bytes(self) -> Int:
        """Total waste = alignment padding + un-carved tail."""
        return self.padding_bytes() + (self.capacity_bytes - self.carved_bytes)

    def admit(mut self, size_bytes: Int, offset: Int) raises -> CheckedSpan:
        """Admit one block of size_bytes at the bump offset.

        Fail-closed: non-positive sizes (MEM-001) and any block that
        would pass the capacity (MEM-003) raise BEFORE charging.
        Returns the checked span of the carved block."""
        if size_bytes <= 0:
            raise Error(
                "MEM-001 HOST_MALLOC_FAILED: Arena.admit size_bytes"
                " must be positive, got " + String(size_bytes)
            )
        var aligned = arena_align_up(size_bytes)
        if offset + aligned > self.capacity_bytes:
            raise Error(
                "MEM-003 OUT_OF_MEMORY: Arena.admit " + String(size_bytes)
                + " bytes (aligned " + String(aligned) + ") at offset "
                + String(offset) + " exceeds arena capacity "
                + String(self.capacity_bytes) + " with "
                + String(self.live_requested_bytes) + " live bytes"
            )
        _ = checked_span(offset, aligned, self.capacity_bytes)
        self.carved_bytes = offset + aligned
        self.live_requested_bytes += size_bytes
        self.live_blocks += 1
        self.total_allocs += 1
        if self.carved_bytes > self.peak_carved_bytes:
            self.peak_carved_bytes = self.carved_bytes
        return checked_span(offset, size_bytes, self.capacity_bytes)

    def release_last(mut self, size_bytes: Int, offset: Int) raises:
        """Checked release of the most recent block (stack order).

        Anything else - wrong size, wrong offset, or a release after
        reset already reclaimed the block - raises MEM-005 instead
        of underflowing the ledger."""
        if self.live_blocks <= 0:
            raise Error(
                "MEM-005 DOUBLE_FREE: Arena.release_last with no live"
                " blocks (already freed or reclaimed by reset)"
            )
        var aligned = arena_align_up(size_bytes)
        if offset + aligned != self.carved_bytes:
            raise Error(
                "MEM-005 DOUBLE_FREE: Arena.release_last is stack-"
                "order only: block at offset " + String(offset)
                + " size " + String(size_bytes)
                + " is not the live top (carved "
                + String(self.carved_bytes) + ")"
            )
        self.carved_bytes = offset
        self.live_requested_bytes -= size_bytes
        self.live_blocks -= 1
        self.total_frees += 1

    def reset(mut self):
        """O(1) reset: every live block is reclaimed at once and the
        ledger returns exactly to baseline (carved/live/blocks = 0).
        Cumulative counters (allocs/frees/resets/peak) are history
        and are kept, in the governor style."""
        self.carved_bytes = 0
        self.live_requested_bytes = 0
        self.live_blocks = 0
        self.total_resets += 1


struct RequestArena(Copyable, ImplicitlyCopyable):
    """One per-request arena over a single zero-copy backing buffer.

    Owns its backing: close() releases it exactly once. alloc()
    returns a byte offset into the backing; ptr() resolves an offset
    to the CPU pointer through the ZeroCopy gateway (managed memory:
    the same pointer the GPU reads - no copy path exists)."""

    var ledger: ArenaLedger
    var backing: ZeroCopyBuffer
    var closed: Bool

    def __init__(out self, capacity_bytes: Int) raises:
        if capacity_bytes <= 0:
            raise Error(
                "MEM-001 HOST_MALLOC_FAILED: RequestArena capacity"
                " must be positive, got " + String(capacity_bytes)
            )
        self.ledger = ArenaLedger(capacity_bytes)
        self.backing = ZeroCopy.allocate(capacity_bytes, BACKEND_HIP_MANAGED)
        self.closed = False

    def alloc(mut self, size_bytes: Int) raises -> Int:
        """Carve one activation block; returns its byte offset."""
        if self.closed:
            raise Error("RequestArena.alloc: arena is closed")
        var span = self.ledger.admit(size_bytes, self.ledger.carved_bytes)
        return span.start

    def free_last(mut self, size_bytes: Int, offset: Int) raises:
        """Rewind the most recent live block (checked, MEM-005)."""
        if self.closed:
            raise Error("RequestArena.free_last: arena is closed")
        self.ledger.release_last(size_bytes, offset)

    def mark(self) -> Int:
        """Checkpoint = current bump offset, for rewind()."""
        return self.ledger.carved_bytes

    def rewind(mut self, mark_offset: Int) raises:
        """Roll back to a mark. Whole-block rollback goes through
        free_last (stack order, exact accounting); a raw mark is
        accepted only for the current top (no-op) or 0 (full
        reset) - anything else raises instead of guessing how many
        requested bytes the mark held."""
        if mark_offset == self.ledger.carved_bytes:
            return
        if mark_offset == 0:
            self.reset()
            return
        raise Error(
            "RequestArena.rewind: partial rewind must go through"
            " free_last (stack order); only the top or 0 are valid"
            " raw marks, got " + String(mark_offset)
        )

    def reset(mut self):
        """O(1) reset: all activations of the request are freed at
        once; accounting returns exactly to baseline."""
        self.ledger.reset()

    def waste_bytes(self) -> Int:
        return self.ledger.waste_bytes()

    def ptr(self, offset: Int) raises -> Int:
        """Backing pointer + checked offset (HIP managed address)."""
        if self.closed:
            raise Error("RequestArena.ptr: arena is closed")
        _ = checked_span(offset, 1, self.ledger.capacity_bytes)
        return self.backing.hip_addr + offset

    def close(mut self) raises:
        """Release the backing exactly once."""
        if self.closed:
            return
        ZeroCopy.free(self.backing)
        self.closed = True


struct ArenaPool:
    """A fixed pool of per-request arenas (A-026 pool half).

    acquire() hands out a free arena index or fails closed
    (MEM-003) when the pool is exhausted; release() resets the
    arena (O(1)) and returns it. Exact pool accounting: checked-out
    count returns to zero when every request releases."""

    var arenas: List[RequestArena]
    var in_use: List[Bool]
    var checked_out: Int
    var total_acquires: Int
    var total_releases: Int
    var total_refusals: Int

    def __init__(out self, arena_count: Int, capacity_bytes: Int) raises:
        if arena_count <= 0:
            raise Error(
                "MEM-001 HOST_MALLOC_FAILED: ArenaPool arena_count"
                " must be positive, got " + String(arena_count)
            )
        self.arenas = List[RequestArena]()
        self.in_use = List[Bool]()
        for _ in range(arena_count):
            self.arenas.append(RequestArena(capacity_bytes))
            self.in_use.append(False)
        self.checked_out = 0
        self.total_acquires = 0
        self.total_releases = 0
        self.total_refusals = 0

    def acquire(mut self) raises -> Int:
        """Check out one arena; returns its pool index."""
        for i in range(len(self.arenas)):
            if not self.in_use[i]:
                self.in_use[i] = True
                self.checked_out += 1
                self.total_acquires += 1
                return i
        self.total_refusals += 1
        raise Error(
            "MEM-003 OUT_OF_MEMORY: ArenaPool exhausted - all "
            + String(len(self.arenas)) + " arenas are checked out"
        )

    def release(mut self, index: Int) raises:
        """Reset and return one checked-out arena (MEM-005 on a
        double release or an out-of-range index)."""
        if index < 0 or index >= len(self.arenas):
            raise Error(
                "MEM-005 DOUBLE_FREE: ArenaPool.release index "
                + String(index) + " out of range"
            )
        if not self.in_use[index]:
            raise Error(
                "MEM-005 DOUBLE_FREE: ArenaPool.release of arena "
                + String(index) + " that is not checked out"
            )
        self.arenas[index].reset()
        self.in_use[index] = False
        self.checked_out -= 1
        self.total_releases += 1

    def close(mut self) raises:
        """Release every backing exactly once."""
        for i in range(len(self.arenas)):
            self.arenas[i].close()
