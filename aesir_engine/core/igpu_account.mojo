"""iGPU awareness: the integrated GPU's real shape (Janas road J-067).

The roadmap text: "On machines with only an integrated GPU,
prefill placement measured honestly (shared-memory bandwidth
is the tax); the placement engine (Part III) taught the iGPU's
real shape."

THE SHAPE, stated before any building (docs/janas/
J067_IGPU_AWARENESS.md section 1 is its normative text):

- An integrated GPU has NO VRAM of its own. The bytes a probe
  or a vendor tool calls its "device memory" are the same
  system RAM the CPU, the Part II expert cache, and the OS
  share. Its pool identity is therefore the SYSTEM pool --
  the one contested pool of J-048's rule -- never a second
  pool beside it.
- Its usable budget is an ALLOWANCE drawn from that system
  pool, charged in J-048's order (placement fixed bytes
  first, expert cache elastic after, floor held). A discrete
  card's budget (J-031: a stated usable device budget, a
  separate pool) applied to an iGPU double-counts memory:
  system_pool + claimed_vram counts the same bytes twice.
  That double-count is the J-026-class error (two consumers
  each sizing against the full snapshot) in device dress.
- Data "transfers" to an iGPU are not copies over a bus.
  plan_igpu_prefill_tax therefore charges ZERO copy bytes
  for an integrated device, always -- and refuses a caller
  who states copy bytes for one, because that statement is
  the discrete shape leaking back in. What the iGPU pays
  instead is BANDWIDTH CONTENTION: every byte its prefill
  pass touches (weights + activations + KV) competes for
  the shared memory fabric with every byte the CPU side
  touches in the same window. The tax is stated in bytes
  contended, never in time: no bandwidth figure exists in
  this tree's record for any iGPU, and none is invented.

WHAT THE ACCOUNT DECIDES, AND WHAT IT REFUSES TO DECIDE
(the verdict rule, pre-registered in the doc section 1):

- PERMITTED BY ACCOUNT (accounting alone): admitting an
  iGPU prefill placement as a candidate, and choosing it
  as the placement of record, when its fixed bytes fit the
  shared allowance and the expert cache keeps its floor
  after them (J-048). Accounting can also REFUSE outright:
  a placement whose fixed bytes break the floor, or whose
  budget was derived additively, does not fit and no
  measurement can make it fit.
- REQUIRES LIVE MEASUREMENT (the account refuses to
  decide): any claim that iGPU prefill is FASTER than the
  same machine's CPU prefill (or slower, or equal); any
  reply-pass (single-token) placement win for an iGPU --
  the J-041 question, where per-token fixed costs meet the
  bandwidth tax at the smallest work size; any co-work
  split ratio; any bandwidth, wall, or tok/s figure. Those
  are measurements on hardware in hand or they are nothing.

This module is pure arithmetic in the J-066 pattern: it
executes nothing, opens no device, and contains no speed.
It does NOT change J-037's inventory, J-031's discrete
division, or J-048's planner: the discrete account stands
exactly as filed, and this module is the shape a host uses
INSTEAD of the discrete division when the device kind is
integrated. Wiring it into a live session awaits a backend
that can execute on an iGPU at all (J-066: DEFER) plus the
live leg filed in the doc section 7.

HOST CONTRACT: (1) classify the device kind from inventory
truth -- a device is integrated only when the machine's own
sources say its memory is shared; an unclassified GPU is
treated as discrete-shaped for budgeting ONLY where a real
separate VRAM probe answered (J-037), never assumed shared
and never assumed separate without a probe; (2) for an
integrated device, call plan_igpu_budget against the ONE
system pool -- never plan_moe_gpu_division with a claimed
VRAM figure; (3) price any prefill claim through
plan_igpu_prefill_tax and evaluate_igpu_claim before
stating it; (4) on the first iGPU machine in hand, run the
doc section 7 recipe before quoting any number.
"""

# GPU device kinds. CPU is not a GPU kind; absence is kind 0.
comptime GPU_KIND_NONE = 0
comptime GPU_KIND_DISCRETE = 1
comptime GPU_KIND_INTEGRATED = 2

# Pool identities.
comptime POOL_NONE = 0
comptime POOL_SEPARATE_DEVICE = 1
comptime POOL_SHARED_SYSTEM = 2

# Budget decisions from plan_igpu_budget (J-048's shapes).
comptime IGPU_BUDGET_FULL = 0
comptime IGPU_BUDGET_SHRUNK = 1
comptime IGPU_BUDGET_REFUSE = 2

# Claim verdicts from evaluate_igpu_claim.
comptime IGPU_CLAIM_PERMITTED = 0
comptime IGPU_CLAIM_REQUIRES_LIVE = 1
comptime IGPU_CLAIM_REFUSED = 2


def gpu_kind_name(code: Int) raises -> String:
    if code == GPU_KIND_NONE:
        return String("none")
    if code == GPU_KIND_DISCRETE:
        return String("discrete")
    if code == GPU_KIND_INTEGRATED:
        return String("integrated")
    raise Error("IgpuAccount: unknown GPU kind code")


def pool_for_gpu_kind(kind: Int) raises -> Int:
    """The pool a GPU kind's budget is charged against.

    Discrete: its own device pool (J-031). Integrated: the
    system pool, shared with CPU + expert cache + OS (J-048's
    one contested pool). None: no pool at all.
    """
    if kind == GPU_KIND_DISCRETE:
        return POOL_SEPARATE_DEVICE
    if kind == GPU_KIND_INTEGRATED:
        return POOL_SHARED_SYSTEM
    if kind == GPU_KIND_NONE:
        return POOL_NONE
    raise Error("IgpuAccount: unknown GPU kind code")


def shares_system_pool(kind: Int) raises -> Bool:
    return pool_for_gpu_kind(kind) == POOL_SHARED_SYSTEM


def has_own_vram(kind: Int) raises -> Bool:
    """Only a discrete GPU owns a VRAM pool. An integrated
    GPU's reported 'device memory' IS system RAM."""
    return kind == GPU_KIND_DISCRETE


def naive_additive_total(system_pool_bytes: Int, claimed_vram_bytes: Int) -> Int:
    """What the discrete treatment would claim the machine
    holds for an iGPU: system pool PLUS claimed VRAM. Filed
    so the double-count has a name and a size in tests; the
    correct total for an integrated device is the system
    pool alone (correct_total_bytes)."""
    return system_pool_bytes + claimed_vram_bytes


def correct_total_bytes(system_pool_bytes: Int) -> Int:
    """The whole memory an iGPU machine's placement may
    charge against: the system pool, once."""
    return system_pool_bytes


struct IgpuBudgetPlan(Copyable, ImplicitlyCopyable):
    """One iGPU budget decision against the ONE system pool."""

    var decision: Int
    var system_pool_bytes: Int
    var fixed_bytes: Int
    var allowance_bytes: Int
    var cache_target_bytes: Int
    var cache_open_bytes: Int
    var floor_bytes: Int
    var below_floor: Bool
    var total_charged_bytes: Int

    def __init__(
        out self,
        decision: Int,
        system_pool_bytes: Int,
        fixed_bytes: Int,
        allowance_bytes: Int,
        cache_target_bytes: Int,
        cache_open_bytes: Int,
        floor_bytes: Int,
        below_floor: Bool,
    ):
        self.decision = decision
        self.system_pool_bytes = system_pool_bytes
        self.fixed_bytes = fixed_bytes
        self.allowance_bytes = allowance_bytes
        self.cache_target_bytes = cache_target_bytes
        self.cache_open_bytes = cache_open_bytes
        self.floor_bytes = floor_bytes
        self.below_floor = below_floor
        self.total_charged_bytes = fixed_bytes + cache_target_bytes

    def headroom_bytes(self) -> Int:
        var room = self.system_pool_bytes - self.total_charged_bytes
        if room < 0:
            return 0
        return room

    def describe(self) -> String:
        var name = String("full")
        if self.decision == IGPU_BUDGET_SHRUNK:
            name = String("shrunk")
        elif self.decision == IGPU_BUDGET_REFUSE:
            name = String("refuse")
        return (
            "decision=" + name
            + " system_pool_bytes=" + String(self.system_pool_bytes)
            + " fixed_bytes=" + String(self.fixed_bytes)
            + " allowance_bytes=" + String(self.allowance_bytes)
            + " cache_target_bytes=" + String(self.cache_target_bytes)
            + " cache_open_bytes=" + String(self.cache_open_bytes)
            + " floor_bytes=" + String(self.floor_bytes)
            + " below_floor=" + String(self.below_floor)
            + " total_charged_bytes=" + String(self.total_charged_bytes)
            + " headroom_bytes=" + String(self.headroom_bytes())
        )


def plan_igpu_budget(
    system_pool_bytes: Int,
    placement_fixed_bytes: Int,
    reserve_bytes: Int,
    cache_open_bytes: Int,
    cache_floor_bytes: Int,
    expert_body_bytes: Int,
) raises -> IgpuBudgetPlan:
    """Charge an iGPU prefill placement against the system pool.

    J-048's order, in the shared pool: the placement's fixed
    bytes (resident set + KV + activation/scratch, in J-031's
    charging order, plus the pool reserve) FIRST and in full;
    the expert cache LAST, elastic, capped at its open-time
    budget and at the expert body where a body is stated
    (expert_body_bytes 0 states no body bound). The iGPU
    ALLOWANCE is what remains for fixed bytes after the cache
    floor is held: allowance = pool - floor. Fixed bytes
    beyond the allowance leave the required host cache below
    its floor, and the plan is REFUSE -- the placement does
    not fit this machine, stated with numbers, and no other
    consumer is cannibalised to make it fit. Fixed bytes
    alone over the pool refuse in every case. The total
    charged NEVER exceeds the system pool: there is no
    second pool to charge.
    """
    if system_pool_bytes <= 0:
        raise Error("IgpuAccount: system pool must be positive")
    if placement_fixed_bytes < 0 or reserve_bytes < 0:
        raise Error("IgpuAccount: fixed bytes out of range")
    if cache_open_bytes <= 0 or cache_floor_bytes <= 0:
        raise Error("IgpuAccount: cache budget out of range")
    if cache_floor_bytes > cache_open_bytes:
        raise Error("IgpuAccount: floor above the open budget")
    if expert_body_bytes < 0:
        raise Error("IgpuAccount: expert body out of range")
    var fixed = placement_fixed_bytes + reserve_bytes
    var allowance = system_pool_bytes - cache_floor_bytes
    if allowance < 0:
        allowance = 0
    if fixed > system_pool_bytes:
        return IgpuBudgetPlan(
            IGPU_BUDGET_REFUSE, system_pool_bytes, fixed, allowance,
            0, cache_open_bytes, cache_floor_bytes, True,
        )
    var available = system_pool_bytes - fixed
    var target = cache_open_bytes
    if available < target:
        target = available
    if expert_body_bytes > 0 and target > expert_body_bytes:
        target = expert_body_bytes
    if target < cache_floor_bytes:
        return IgpuBudgetPlan(
            IGPU_BUDGET_REFUSE, system_pool_bytes, fixed, allowance,
            0, cache_open_bytes, cache_floor_bytes, True,
        )
    var decision = IGPU_BUDGET_FULL
    if target < cache_open_bytes:
        decision = IGPU_BUDGET_SHRUNK
    return IgpuBudgetPlan(
        decision, system_pool_bytes, fixed, allowance,
        target, cache_open_bytes, cache_floor_bytes, False,
    )


struct IgpuPrefillTax(Copyable, ImplicitlyCopyable):
    """One prefill pass's shared-bandwidth account, in bytes.

    copy_bytes_charged is 0 by construction for an integrated
    device: there is no bus crossing to charge. contended_bytes
    is the traffic the pass itself puts on the shared fabric;
    shared_traffic_bytes adds the CPU side's concurrent traffic
    the caller states -- the contention the tax names. No time,
    no bandwidth rate, and no winner is stated here.
    """

    var weight_bytes: Int
    var activation_bytes: Int
    var kv_bytes: Int
    var cpu_co_load_bytes: Int
    var copy_bytes_charged: Int
    var contended_bytes: Int
    var shared_traffic_bytes: Int

    def __init__(
        out self,
        weight_bytes: Int,
        activation_bytes: Int,
        kv_bytes: Int,
        cpu_co_load_bytes: Int,
    ):
        self.weight_bytes = weight_bytes
        self.activation_bytes = activation_bytes
        self.kv_bytes = kv_bytes
        self.cpu_co_load_bytes = cpu_co_load_bytes
        self.copy_bytes_charged = 0
        self.contended_bytes = weight_bytes + activation_bytes + kv_bytes
        self.shared_traffic_bytes = self.contended_bytes + cpu_co_load_bytes

    def describe(self) -> String:
        return (
            "weight_bytes=" + String(self.weight_bytes)
            + " activation_bytes=" + String(self.activation_bytes)
            + " kv_bytes=" + String(self.kv_bytes)
            + " cpu_co_load_bytes=" + String(self.cpu_co_load_bytes)
            + " copy_bytes_charged=" + String(self.copy_bytes_charged)
            + " contended_bytes=" + String(self.contended_bytes)
            + " shared_traffic_bytes=" + String(self.shared_traffic_bytes)
        )


def plan_igpu_prefill_tax(
    weight_bytes: Int,
    activation_bytes: Int,
    kv_bytes: Int,
    cpu_co_load_bytes: Int,
    claimed_copy_bytes: Int,
) raises -> IgpuPrefillTax:
    """Price one iGPU prefill pass in contended bytes.

    claimed_copy_bytes is the caller's transfer statement: for
    an integrated device it must be 0. A nonzero claim is the
    discrete shape (J-031's per-token H2D/D2H account) applied
    where no bus exists, and it is refused, not silently
    zeroed -- the caller must restate the pass in the iGPU's
    shape. What IS charged: the weight, activation, and KV
    bytes the pass touches, plus the CPU co-load bytes the
    caller states for the same window. What is NOT charged:
    copies (none exist), and time (none is known).
    """
    if weight_bytes < 0 or activation_bytes < 0 or kv_bytes < 0:
        raise Error("IgpuAccount: prefill traffic out of range")
    if cpu_co_load_bytes < 0 or claimed_copy_bytes < 0:
        raise Error("IgpuAccount: co-load / copy claim out of range")
    if claimed_copy_bytes != 0:
        raise Error(
            "IgpuAccount: an integrated GPU has no copy traffic;"
            " restate the pass without transfer bytes"
        )
    return IgpuPrefillTax(
        weight_bytes, activation_bytes, kv_bytes, cpu_co_load_bytes
    )


def evaluate_igpu_claim(
    fits_shared_pool: Bool,
    floor_holds: Bool,
    pass_is_prefill: Bool,
    claims_speed_win: Bool,
    live_measured: Bool,
    measured_faster_than_cpu: Bool,
) -> Int:
    """The pre-registered verdict rule (doc section 1).

    - REFUSED: the placement does not fit the shared pool or
      breaks the cache floor. Accounting refuses outright; a
      measurement cannot cure a byte that does not fit.
    - REQUIRES LIVE: any non-prefill win claim (the reply
      question is never decided by accounting), and any
      speed-win claim not backed by a live measurement on
      the machine in hand that actually measured faster.
      A measured-but-not-faster speed claim is also not
      permitted: the measurement answered, and the answer
      was no win.
    - PERMITTED: a prefill placement that fits with the
      floor held and claims no speed win (admission /
      placement of record on accounting alone), or a speed
      claim backed by a live measurement that measured
      faster than the same machine's CPU line.
    """
    if not fits_shared_pool or not floor_holds:
        return IGPU_CLAIM_REFUSED
    if not pass_is_prefill:
        return IGPU_CLAIM_REQUIRES_LIVE
    if claims_speed_win:
        if live_measured and measured_faster_than_cpu:
            return IGPU_CLAIM_PERMITTED
        return IGPU_CLAIM_REQUIRES_LIVE
    return IGPU_CLAIM_PERMITTED


def claim_name(code: Int) raises -> String:
    if code == IGPU_CLAIM_PERMITTED:
        return String("PERMITTED")
    if code == IGPU_CLAIM_REQUIRES_LIVE:
        return String("REQUIRES_LIVE")
    if code == IGPU_CLAIM_REFUSED:
        return String("REFUSED")
    raise Error("IgpuAccount: unknown claim code")
