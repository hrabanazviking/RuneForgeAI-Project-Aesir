# core/buffer_ownership.mojo
# Buffer ownership law (slice A-022): the shared taxonomy mapping for
# every buffer type, plus the API-contract ownership registry for XRT
# buffer objects (A-016).
#
# THE LAW (full text in hidden_files/A022_LEDGER.md):
#   1. Every buffer has exactly one owner at any moment; ownership is
#      a registry entry, never the raw pointer/fd/handle itself.
#   2. States: LIVE -> HANDED_OFF (sender tombstone; receiver must
#      claim before use) -> LIVE; LIVE -> FREED (tombstone, so a
#      second free is detectable, never silent).
#   3. Borrows are non-owning views: they may never free, hand off,
#      or outlive a checked use; free/hand-off are refused while a
#      borrow is active.
#   4. A handle is valid only for its own kind, device, and
#      generation; cross-kind / cross-device / stale / foreign /
#      interior handles are refused before any driver call.
#   5. Fail closed: every refusal is a named taxonomy Error value
#      (MEM-004/MEM-005 from ERROR_TAXONOMY.md, plus the A-022
#      boundary codes MEM-011..MEM-015 recorded in the ledger).
#      Nothing crashes; a refused op moves no accounting counter.
#
# Enforcement points: the C shims enforce the law for HIP (A-011/
# A-012), Vulkan buffers (A-014/A-015), and ZeroCopy (A-019) - see
# aesir_engine/buffer_ownership.h. XRT BOs (A-016) exist today only
# as a host-side probe (xrt_bo_probe.c, no Mojo wrapper, no shim), so
# their law is enforced here at the API-contract level: every future
# XRT wrapper registers its BOs in XrtBoOwnership at alloc time and
# routes free/hand-off/use through it; the adversarial E-MASTER
# cases exercise this contract directly (no sudo, no device ioctls).

comptime OWN_DOUBLE_FREE = -22005  # MEM-005
comptime OWN_USE_AFTER_FREE = -22004  # MEM-004
comptime OWN_USE_AFTER_HANDOFF = -22011  # MEM-011 (boundary)
comptime OWN_CROSS_DEVICE = -22012  # MEM-012 (boundary)
comptime OWN_NOT_OWNER = -22013  # MEM-013 (boundary)
comptime OWN_STALE_HANDLE = -22014  # MEM-014 (boundary)
comptime OWN_INVALID = -22015
comptime OWN_FREE_WHILE_BORROWED = -22016  # MEM-015 (boundary)

comptime XRT_BO_LIVE = 1
comptime XRT_BO_HANDED_OFF = 2
comptime XRT_BO_FREED = 3


def ownership_taxonomy_name(rc: Int) -> String:
    """The named taxonomy result for an A-022 ownership code."""
    if rc == OWN_DOUBLE_FREE:
        return "MEM-005 DOUBLE_FREE"
    if rc == OWN_USE_AFTER_FREE:
        return "MEM-004 USE_AFTER_FREE"
    if rc == OWN_USE_AFTER_HANDOFF:
        return "MEM-011 USE_AFTER_HANDOFF"
    if rc == OWN_CROSS_DEVICE:
        return "MEM-012 CROSS_DEVICE_MISUSE"
    if rc == OWN_NOT_OWNER:
        return "MEM-013 NON_OWNER_FREE"
    if rc == OWN_STALE_HANDLE:
        return "MEM-014 STALE_HANDLE"
    if rc == OWN_FREE_WHILE_BORROWED:
        return "MEM-015 FREE_WITH_ACTIVE_BORROWS"
    return "MEM ownership violation"


struct XrtBoHandle(Copyable, ImplicitlyCopyable):
    """One XRT buffer-object handle value: device index, registry id,
    and generation. Copying the value never copies ownership - the
    registry decides which generation is the live owner."""

    var device: Int
    var id: Int
    var generation: Int

    def __init__(out self, device: Int, id: Int, generation: Int):
        self.device = device
        self.id = id
        self.generation = generation


struct XrtBoOwnership:
    """API-contract ownership registry for XRT buffer objects.

    Ids are monotonic and never reused, generations bump on hand-off,
    and freed entries stay as tombstones, so double-free, use-after-
    hand-off, cross-device misuse, borrow-after-free, and stale
    handles all fail closed with named taxonomy errors.
    """

    var _ids: List[Int]
    var _devs: List[Int]
    var _gens: List[Int]
    var _states: List[Int]
    var _borrows: List[Int]
    var _next_id: Int
    var _live: Int

    def __init__(out self):
        self._ids = List[Int]()
        self._devs = List[Int]()
        self._gens = List[Int]()
        self._states = List[Int]()
        self._borrows = List[Int]()
        self._next_id = 1
        self._live = 0

    def live_count(self) -> Int:
        return self._live

    def _find(self, handle: XrtBoHandle) -> Int:
        for i in range(len(self._ids)):
            if self._ids[i] == handle.id:
                return i
        return -1

    def register(mut self, device: Int) raises -> XrtBoHandle:
        """Register a freshly allocated BO on `device`; the returned
        handle is its sole owner."""
        if device < 0:
            raise Error(
                "XrtBoOwnership.register: "
                + ownership_taxonomy_name(OWN_INVALID)
                + " - negative device index"
            )
        var id = self._next_id
        self._next_id += 1
        self._ids.append(id)
        self._devs.append(device)
        self._gens.append(1)
        self._states.append(XRT_BO_LIVE)
        self._borrows.append(0)
        self._live += 1
        return XrtBoHandle(device, id, 1)

    def _validate(
        self, handle: XrtBoHandle, for_free: Bool
    ) raises -> Int:
        var i = self._find(handle)
        if i < 0:
            raise Error(
                "XrtBoOwnership: "
                + ownership_taxonomy_name(OWN_NOT_OWNER)
                + " - handle was never registered (foreign BO)"
            )
        if handle.device != self._devs[i]:
            raise Error(
                "XrtBoOwnership: "
                + ownership_taxonomy_name(OWN_CROSS_DEVICE)
                + " - BO lives on device "
                + String(self._devs[i])
                + ", presented on device "
                + String(handle.device)
            )
        if self._states[i] == XRT_BO_HANDED_OFF:
            raise Error(
                "XrtBoOwnership: "
                + ownership_taxonomy_name(OWN_USE_AFTER_HANDOFF)
                + " - BO was handed off; only the claimed receiver"
                + " handle may be used"
            )
        if self._states[i] == XRT_BO_FREED:
            if for_free:
                raise Error(
                    "XrtBoOwnership: "
                    + ownership_taxonomy_name(OWN_DOUBLE_FREE)
                    + " - BO already freed"
                )
            raise Error(
                "XrtBoOwnership: "
                + ownership_taxonomy_name(OWN_USE_AFTER_FREE)
                + " - BO already freed"
            )
        if handle.generation != self._gens[i]:
            raise Error(
                "XrtBoOwnership: "
                + ownership_taxonomy_name(OWN_STALE_HANDLE)
                + " - generation mismatch (stale handle)"
            )
        return i

    def use(self, handle: XrtBoHandle) raises:
        """Checked use (map/sync/read/write) of a live BO."""
        _ = self._validate(handle, False)

    def borrow(mut self, handle: XrtBoHandle) raises:
        """Take a non-owning borrow; borrows block free/hand-off."""
        var i = self._validate(handle, False)
        self._borrows[i] += 1

    def borrow_end(mut self, handle: XrtBoHandle) raises:
        var i = self._find(handle)
        if i < 0 or self._borrows[i] <= 0:
            raise Error(
                "XrtBoOwnership.borrow_end: "
                + ownership_taxonomy_name(OWN_NOT_OWNER)
                + " - no active borrow for this BO"
            )
        self._borrows[i] -= 1

    def handoff(
        mut self, handle: XrtBoHandle
    ) raises -> XrtBoHandle:
        """Move ownership: the sender's handle becomes a tombstone
        and the returned handle (generation + 1) is the receiver's,
        inert until claimed."""
        var i = self._validate(handle, False)
        if self._borrows[i] > 0:
            raise Error(
                "XrtBoOwnership.handoff: "
                + ownership_taxonomy_name(OWN_FREE_WHILE_BORROWED)
                + " - BO has active borrows"
            )
        self._states[i] = XRT_BO_HANDED_OFF
        self._gens[i] += 1
        return XrtBoHandle(handle.device, handle.id, self._gens[i])

    def claim(mut self, handle: XrtBoHandle) raises:
        """The receiver claims a handed-off BO, making it LIVE."""
        var i = self._find(handle)
        if i < 0:
            raise Error(
                "XrtBoOwnership.claim: "
                + ownership_taxonomy_name(OWN_NOT_OWNER)
                + " - handle was never registered"
            )
        if handle.device != self._devs[i]:
            raise Error(
                "XrtBoOwnership.claim: "
                + ownership_taxonomy_name(OWN_CROSS_DEVICE)
                + " - BO lives on another device"
            )
        if (
            self._states[i] != XRT_BO_HANDED_OFF
            or handle.generation != self._gens[i]
        ):
            raise Error(
                "XrtBoOwnership.claim: "
                + ownership_taxonomy_name(OWN_USE_AFTER_HANDOFF)
                + " - not the pending receiver handle"
            )
        self._states[i] = XRT_BO_LIVE

    def free(mut self, handle: XrtBoHandle) raises:
        """Free exactly once, by the live owner, with no borrows."""
        var i = self._validate(handle, True)
        if self._borrows[i] > 0:
            raise Error(
                "XrtBoOwnership.free: "
                + ownership_taxonomy_name(OWN_FREE_WHILE_BORROWED)
                + " - BO has active borrows"
            )
        self._states[i] = XRT_BO_FREED
        self._live -= 1
