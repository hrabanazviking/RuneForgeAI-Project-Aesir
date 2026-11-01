"""Placement under memory pressure (Janas road J-048).

Part II built the expert cache and its pressure honesty: J-028's
plan_pressure_budget (core/expert_cache.mojo) re-charges the
reserve (resident set + KV allowance + scratch + OS headroom) on
every call, sheds the cache first under pressure, regrows only
toward the open-time budget, and refuses cleanly below the floor
(one token's full routed demand). Part III then built placement:
J-031's plan_moe_gpu_division (core/moe_gpu_plan.mojo) charges a
device pool in the order resident set first, then KV /
activation / reserve, the remainder as a whole-expert device
cache; J-036--J-042 choose per pass kind; J-044 persists choices;
J-047 states supremacy: a hand choice is never argued with.

This module is the contention rule where those two lines meet:
the expert cache and a device placement competing for the SAME
memory pool (a device's VRAM holding both the placed resident
set and a device expert cache; a unified/host pool holding both
the placed passes' fixed bytes and the host expert cache; a
device copy of cached bytes -- the census's NPU pattern, J-003:
Janas keeps its NPU closed where the cache cannot hold the
feed-forward weights, because its 8-bit copies' memory is the
cache's memory). The rule, stated before any measurement in
docs/janas/J048_PLACEMENT_MEMORY_PRESSURE.md, is Aesir's own,
derived from Aesir's filed numbers (J-016/J-024 trace counters,
J-028 pressure schedules, J-031 division accounting):

1. FIXED FIRST. The governing placement's fixed bytes (resident
   set + KV + activation/scratch + reserve, in J-031's / J-028's
   charging order) are charged in full, first, on every plan --
   at open and at every mid-run re-plan. The cache never
   cannibalises them, and they are never shed to feed the cache.
2. CACHE ELASTIC. The expert cache is the only elastic consumer
   in the pool: its budget is min(open-time budget, expert body
   where a body bounds it, pool - fixed - admitted copies). It
   sheds first under pressure (J-028's policy order and token-
   boundary cadence are the host's mechanics), and regrows only
   toward the open-time budget, never beyond it.
3. DUPLICATE COPIES ARE CACHE-CLASS, UNLESS A HAND NAMES THEM.
   A copy that duplicates bytes the cache/host already holds
   (the NPU-copy shape) is admitted only if the cache still
   holds at least the floor after charging it; otherwise the
   copy stays CLOSED and the cache keeps its budget -- the
   original bytes remain, so closing the copy loses an
   accelerator copy, never the weights. A copy a hand choice
   names for its kind is charged as fixed instead (rule 5).
4. DEGRADE BEFORE REFUSE, WHERE A FALLBACK EXISTS. If the
   remainder cannot hold the cache floor (or, for an optional
   device cache, one largest whole expert -- the J-017 atomic
   unit): an OPTIONAL cache (a device expert cache whose
   experts still live in the host cache) degrades to zero --
   the placement stands, experts compute where they land on
   the host, exactly J-031's RESIDENT_GPU division. A REQUIRED
   cache (the host cache a streamed session has no fallback
   without) refuses cleanly instead (J-028's REFUSE).
5. MANUAL SUPREMACY IS NEVER TRADED AWAY (J-047). A governing
   hand choice is never shrunk, migrated, substituted, or
   trimmed to cure contention, and its named copies charge as
   fixed (rule 3). If fixed bytes alone exceed the pool, or a
   required cache is left below its floor by a hand placement,
   the plan is REFUSE -- the whole session refuses at open
   with the numbers stated, which is J-047's whole-refusal
   shape, not an override: choice_overridden is False on
   every plan this module can return.
6. PLACEMENT NEVER MIGRATES MID-RUN. A re-plan (the host calls
   this planner at a token boundary with a fresh pool sample,
   J-028's cadence; never mid-token) may change only the cache
   budget and a copy's admitted state. Placement itself is
   session-kept (J-040--J-042); moving it is an open-time or
   next-session (learned / re-trial, J-044/J-045) decision.

HOST CONTRACT (binding; this module fakes no integration): a
surface opening a session (1) resolves precedence (J-047) and
validates named devices at open, (2) derives the placement's
fixed bytes from the opened model's directory-true sizes plus
the KV / activation / reserve allowances it charges (J-031's
contract), (3) calls plan_placement_pressure per contested
pool with the floor from J-028 (one token's full routed
demand), the largest whole-expert size, and whether that
pool's cache is required or optional, (4) follows the plan:
FULL / SHRUNK place and size the cache as stated; NO_CACHE
places with no device cache; REFUSE stops the open cleanly
stating the plan's numbers; a closed copy is not opened.
Mid-run, the host re-plans at token boundaries only. This
slice wires the module into NO live session path: no session
consumes a contention plan yet, and claiming otherwise would
fake the integration. See docs/janas/
J048_PLACEMENT_MEMORY_PRESSURE.md.
"""

# Contention decisions returned by plan_placement_pressure.
comptime CONTENTION_FULL = 0
comptime CONTENTION_SHRUNK = 1
comptime CONTENTION_NO_CACHE = 2
comptime CONTENTION_REFUSE = 3


def contention_name(code: Int) -> String:
    if code == CONTENTION_SHRUNK:
        return String("shrunk")
    if code == CONTENTION_NO_CACHE:
        return String("no_cache")
    if code == CONTENTION_REFUSE:
        return String("refuse")
    return String("full")


struct PlacementPressurePlan(Copyable, ImplicitlyCopyable):
    """One contention decision for one pool, stated in full."""

    var decision: Int
    var pool_bytes: Int
    var fixed_bytes: Int
    var copy_charged_bytes: Int
    var copy_closed: Bool
    var cache_target_bytes: Int
    var cache_open_bytes: Int
    var floor_bytes: Int
    var below_floor: Bool
    var placement_stands: Bool
    var choice_overridden: Bool
    var manual_governing: Bool

    def __init__(
        out self,
        decision: Int,
        pool_bytes: Int,
        fixed_bytes: Int,
        copy_charged_bytes: Int,
        copy_closed: Bool,
        cache_target_bytes: Int,
        cache_open_bytes: Int,
        floor_bytes: Int,
        below_floor: Bool,
        placement_stands: Bool,
        manual_governing: Bool,
    ):
        self.decision = decision
        self.pool_bytes = pool_bytes
        self.fixed_bytes = fixed_bytes
        self.copy_charged_bytes = copy_charged_bytes
        self.copy_closed = copy_closed
        self.cache_target_bytes = cache_target_bytes
        self.cache_open_bytes = cache_open_bytes
        self.floor_bytes = floor_bytes
        self.below_floor = below_floor
        self.placement_stands = placement_stands
        self.choice_overridden = False
        self.manual_governing = manual_governing

    def headroom_bytes(self) -> Int:
        """Pool bytes no consumer in this plan holds."""
        var held = (
            self.fixed_bytes
            + self.copy_charged_bytes
            + self.cache_target_bytes
        )
        var room = self.pool_bytes - held
        if room < 0:
            return 0
        return room

    def describe(self) -> String:
        return (
            "decision="
            + contention_name(self.decision)
            + " pool_bytes="
            + String(self.pool_bytes)
            + " fixed_bytes="
            + String(self.fixed_bytes)
            + " copy_charged_bytes="
            + String(self.copy_charged_bytes)
            + " copy_closed="
            + String(self.copy_closed)
            + " cache_target_bytes="
            + String(self.cache_target_bytes)
            + " cache_open_bytes="
            + String(self.cache_open_bytes)
            + " floor_bytes="
            + String(self.floor_bytes)
            + " below_floor="
            + String(self.below_floor)
            + " placement_stands="
            + String(self.placement_stands)
            + " choice_overridden="
            + String(self.choice_overridden)
            + " manual_governing="
            + String(self.manual_governing)
            + " headroom_bytes="
            + String(self.headroom_bytes())
        )


def plan_placement_pressure(
    pool_bytes: Int,
    placement_fixed_bytes: Int,
    reserve_bytes: Int,
    cache_open_bytes: Int,
    cache_floor_bytes: Int,
    largest_pair_bytes: Int,
    expert_body_bytes: Int,
    duplicate_copy_bytes: Int,
    copy_is_manual: Bool,
    cache_required: Bool,
    governing_is_manual: Bool,
) raises -> PlacementPressurePlan:
    """Decide cache vs placement in one shared memory pool.

    Charging order (the module docstring's rules 1--5): the
    placement's fixed bytes plus the pool reserve first; a
    hand-named duplicate copy as fixed with them; an unnamed
    (auto) duplicate copy only where the cache keeps at least
    the floor after it; the cache last, elastic, capped at its
    open-time budget and at the expert body where a body is
    stated (expert_body_bytes 0 states no body bound). The
    cache threshold is the floor, raised to the largest whole
    expert for an optional cache whose floor is smaller (a
    device cache that cannot hold one atomic expert holds
    nothing, J-031). Below the threshold an optional cache
    degrades to zero and the placement stands; a required
    cache refuses. Fixed bytes alone over the pool refuse in
    every case: no choice is overridden to make room.
    """
    if pool_bytes < 0:
        raise Error("Placement pressure pool out of range")
    if placement_fixed_bytes < 0 or reserve_bytes < 0:
        raise Error("Placement pressure fixed bytes out of range")
    if cache_open_bytes <= 0 or cache_floor_bytes <= 0:
        raise Error("Placement pressure cache budget out of range")
    if cache_floor_bytes > cache_open_bytes:
        raise Error("Placement pressure floor above the open budget")
    if largest_pair_bytes < 0 or expert_body_bytes < 0:
        raise Error("Placement pressure expert sizes out of range")
    if expert_body_bytes > 0 and largest_pair_bytes <= 0:
        raise Error("Placement pressure largest pair must be stated")
    if largest_pair_bytes > expert_body_bytes and expert_body_bytes > 0:
        raise Error("Placement pressure pair larger than the body")
    if duplicate_copy_bytes < 0:
        raise Error("Placement pressure copy bytes out of range")
    var fixed = placement_fixed_bytes + reserve_bytes
    if fixed < 0:
        raise Error("Placement pressure fixed overflow")
    # Rule 3: duplicate copies.
    var copy_charged = 0
    var copy_closed = False
    if duplicate_copy_bytes > 0:
        if copy_is_manual:
            copy_charged = duplicate_copy_bytes
        elif pool_bytes - fixed - duplicate_copy_bytes >= cache_floor_bytes:
            copy_charged = duplicate_copy_bytes
        else:
            copy_closed = True
    var available = pool_bytes - fixed - copy_charged
    if available < 0:
        return PlacementPressurePlan(
            CONTENTION_REFUSE,
            pool_bytes,
            fixed,
            copy_charged,
            copy_closed,
            0,
            cache_open_bytes,
            cache_floor_bytes,
            True,
            False,
            governing_is_manual,
        )
    var target = cache_open_bytes
    if available < target:
        target = available
    if expert_body_bytes > 0 and target > expert_body_bytes:
        target = expert_body_bytes
    var threshold = cache_floor_bytes
    if not cache_required and largest_pair_bytes > threshold:
        threshold = largest_pair_bytes
    if target < threshold:
        if cache_required:
            return PlacementPressurePlan(
                CONTENTION_REFUSE,
                pool_bytes,
                fixed,
                copy_charged,
                copy_closed,
                0,
                cache_open_bytes,
                cache_floor_bytes,
                True,
                False,
                governing_is_manual,
            )
        return PlacementPressurePlan(
            CONTENTION_NO_CACHE,
            pool_bytes,
            fixed,
            copy_charged,
            copy_closed,
            0,
            cache_open_bytes,
            cache_floor_bytes,
            target < cache_floor_bytes,
            True,
            governing_is_manual,
        )
    var decision = CONTENTION_FULL
    if target < cache_open_bytes:
        decision = CONTENTION_SHRUNK
    return PlacementPressurePlan(
        decision,
        pool_bytes,
        fixed,
        copy_charged,
        copy_closed,
        target,
        cache_open_bytes,
        cache_floor_bytes,
        False,
        True,
        governing_is_manual,
    )
