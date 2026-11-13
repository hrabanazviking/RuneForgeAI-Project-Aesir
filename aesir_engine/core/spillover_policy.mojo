# core/spillover_policy.mojo
# A-102: Spillover policy - capacity pressure spills accelerator
# -> CPU per the accelerator-first law, in the open.
#
# A-076 (core/gpu_pressure.mojo) routes ONE weight at a time under
# measured pool pressure. A model run, though, places LAYERS: an
# ordered stack that must be decided whole, before any allocation
# exists, so a run never starts half-placed and dies mid-stack.
# This module is that whole-model layer policy. It is built on
# the banked A-076 governor (the identical routing arithmetic and
# ledgers, reused - not re-implemented), the A-017 accelerator-
# first order (NPU -> GPU -> CPU; on this slice the accelerator
# tier is the A-086 winner, Vulkan on the Radeon 8060S), and the
# A-064 residency accounting discipline.
#
# The policy, in the open:
#   1. Accelerator-first: layers are considered in stack order
#      and every layer that fits the accelerator room (configured
#      GPU cap AND live effective room, A-076 semantics) is
#      placed on the accelerator. The CPU is never first choice.
#   2. Capacity spill: a layer that no longer fits the
#      accelerator room spills to the CPU path when it is
#      spillable and fits the bounded spill ledger - the same
#      bytes on the unified pool (A-008 zero-copy rule), computed
#      by the CPU path, logged with reason CAPACITY_SPILL.
#   3. Fail closed, atomically: a non-spillable layer that does
#      not fit, or a spill that would exceed the spill cap,
#      refuses the WHOLE plan (MEM-003 taxonomy) before any
#      allocation exists. A refused plan places nothing - the
#      scratch governor it was simulated on is discarded, so no
#      ledger moves. There is no partial placement.
#   4. The one lawful non-spill CPU placement: a layer the
#      caller marks assist-eligible MAY sit on the CPU when it
#      carries measured evidence (assist_evidence) that the CPU
#      assist is measurably massive (the accelerator-first law's
#      second clause, A-070). Without the evidence flag the mark
#      is ignored and the layer follows the ordinary rules -
#      an unproven assist claim never moves work off the
#      accelerator. Assist bytes charge the same bounded spill
#      ledger, so total CPU placement is always capped.
#   5. Logged and reproducible: every plan emits a deterministic
#      placement log - one line per layer naming its placement
#      and reason, header/footer with the exact inputs and
#      totals, and an FNV-1a digest over the log text. The plan
#      is a pure function of (layers, config, availability
#      figures): same inputs in, byte-identical log out. Live
#      figures are inputs, printed in the header, never hidden
#      state - a logged plan can be replayed exactly.
#
# A-100 INTEGRATION POINT (honest dependency): the A-100
# placement planner (team-27, in flight, NOT on banked main at
# A-102 build time) assigns per-op devices from measured cost
# tables. This policy is the capacity layer beneath it: when the
# planner's assignment exceeds accelerator capacity, it hands
# the ordered layer stack + capacity figures here and consumes
# PlacementPlan (entries + digest) unchanged. Nothing in this
# module duplicates the planner's cost-table work.

from core.gpu_pressure import (
    ROUTE_GPU,
    ROUTE_REFUSE,
    ROUTE_SPILL_CPU,
    GpuPressureConfig,
    GpuPressureGovernor,
    live_pressure,
)

comptime PLACE_GPU = 0
comptime PLACE_CPU_SPILL = 1
comptime PLACE_CPU_ASSIST = 2


def place_name(place: Int) -> String:
    if place == PLACE_GPU:
        return String("GPU")
    if place == PLACE_CPU_SPILL:
        return String("CPU_SPILL")
    return String("CPU_ASSIST")


def fnv1a64(text: String) -> UInt64:
    """FNV-1a 64-bit digest over the UTF-8 bytes of text.
    Deterministic across runs and machines - the reproducibility
    anchor for placement logs."""
    var hash: UInt64 = 14695981039346656037
    var prime: UInt64 = 1099511628211
    var bytes = text.as_bytes()
    for i in range(len(bytes)):
        hash = hash ^ UInt64(bytes[i])
        hash = hash * prime
    return hash


struct LayerSpec(Copyable, ImplicitlyCopyable):
    """One layer of the stack to place: its byte size, whether
    capacity pressure may spill it to the CPU path, and whether
    the caller claims a measured CPU assist for it (honoured
    only with assist_evidence set)."""

    var name: String
    var bytes: Int
    var spillable: Bool
    var assist: Bool
    var assist_evidence: Bool

    def __init__(
        out self,
        name: String,
        bytes: Int,
        spillable: Bool,
        assist: Bool = False,
        assist_evidence: Bool = False,
    ):
        self.name = name
        self.bytes = bytes
        self.spillable = spillable
        self.assist = assist
        self.assist_evidence = assist_evidence


struct PlacementPlan(Copyable):
    """The whole-model verdict. ok=False is a MEM-003 refusal:
    nothing was placed, entries holds only the header and the
    refusal line. ok=True: entries is the full placement log
    (header, one line per layer, totals footer) and digest is
    fnv1a64 over the joined log text."""

    var ok: Bool
    var refusal_reason: String
    var entries: List[String]
    var gpu_bytes: Int
    var cpu_spill_bytes: Int
    var cpu_assist_bytes: Int
    var gpu_layers: Int
    var cpu_layers: Int
    var digest: UInt64

    def __init__(out self):
        self.ok = False
        self.refusal_reason = String("")
        self.entries = List[String]()
        self.gpu_bytes = 0
        self.cpu_spill_bytes = 0
        self.cpu_assist_bytes = 0
        self.gpu_layers = 0
        self.cpu_layers = 0
        self.digest = 0

    def log_text(self) -> String:
        var text = String("")
        for i in range(len(self.entries)):
            text += self.entries[i] + String("\n")
        return text

    def cpu_bytes(self) -> Int:
        return self.cpu_spill_bytes + self.cpu_assist_bytes


def plan_spillover(
    config: GpuPressureConfig,
    layers: List[LayerSpec],
    available_bytes: Int,
    total_bytes: Int,
) -> PlacementPlan:
    """Decide the placement of the whole layer stack, before
    any allocation exists. Pure and deterministic: the A-076
    routing arithmetic runs on a scratch governor, so a refusal
    leaves every real ledger untouched (atomicity), and equal
    inputs always produce a byte-identical log and digest.

    Order of decision per layer, in stack order:
      assist+evidence -> CPU_ASSIST (bounded by the spill cap);
      fits accelerator room -> GPU (accelerator-first);
      spillable + fits spill ledger -> CPU_SPILL;
      otherwise -> the whole plan is refused (MEM-003)."""
    var plan = PlacementPlan()
    var header = (
        String("spillover-plan v1 layers=") + String(len(layers))
        + String(" avail=") + String(available_bytes)
        + String(" total=") + String(total_bytes)
        + String(" gpu_cap=") + String(config.gpu_cap_bytes)
        + String(" spill_cap=") + String(config.spill_cap_bytes)
        + String(" reserve=") + String(config.reserve_bytes)
    )
    plan.entries.append(header)
    var gov = GpuPressureGovernor(config)
    var assist_live = 0
    for i in range(len(layers)):
        var layer = layers[i].copy()
        if layer.assist and layer.assist_evidence:
            if layer.bytes <= 0 or layer.bytes > config.spill_cap_bytes - assist_live - gov.spilled_live_bytes:
                plan.ok = False
                plan.entries = List[String]()
                plan.entries.append(header)
                plan.gpu_bytes = 0
                plan.cpu_spill_bytes = 0
                plan.cpu_assist_bytes = 0
                plan.gpu_layers = 0
                plan.cpu_layers = 0
                plan.refusal_reason = (
                    String("MEM-003 assist layer exceeds bounded CPU budget: ")
                    + layer.name
                )
                plan.entries.append(
                    String("REFUSE layer=") + layer.name
                    + String(" bytes=") + String(layer.bytes)
                    + String(" code=MEM-003 reason=ASSIST_BUDGET")
                )
                plan.digest = fnv1a64(plan.log_text())
                return plan^
            assist_live += layer.bytes
            plan.cpu_assist_bytes += layer.bytes
            plan.cpu_layers += 1
            plan.entries.append(
                String("layer ") + String(i) + String(" name=") + layer.name
                + String(" bytes=") + String(layer.bytes)
                + String(" place=") + place_name(PLACE_CPU_ASSIST)
                + String(" reason=ASSIST_MEASURED")
            )
            continue
        var verdict = gov.route(layer.bytes, layer.spillable, available_bytes, total_bytes)
        if verdict == ROUTE_GPU:
            plan.gpu_bytes += layer.bytes
            plan.gpu_layers += 1
            plan.entries.append(
                String("layer ") + String(i) + String(" name=") + layer.name
                + String(" bytes=") + String(layer.bytes)
                + String(" place=") + place_name(PLACE_GPU)
                + String(" reason=ACCELERATOR_FIRST")
            )
        elif verdict == ROUTE_SPILL_CPU:
            plan.cpu_spill_bytes += layer.bytes
            plan.cpu_layers += 1
            plan.entries.append(
                String("layer ") + String(i) + String(" name=") + layer.name
                + String(" bytes=") + String(layer.bytes)
                + String(" place=") + place_name(PLACE_CPU_SPILL)
                + String(" reason=CAPACITY_SPILL")
            )
        else:
            plan.ok = False
            plan.entries = List[String]()
            plan.entries.append(header)
            plan.gpu_bytes = 0
            plan.cpu_spill_bytes = 0
            plan.cpu_assist_bytes = 0
            plan.gpu_layers = 0
            plan.cpu_layers = 0
            plan.refusal_reason = (
                String("MEM-003 layer does not fit accelerator room and may not spill: ")
                + layer.name
            )
            plan.entries.append(
                String("REFUSE layer=") + layer.name
                + String(" bytes=") + String(layer.bytes)
                + String(" spillable=") + (String("true") if layer.spillable else String("false"))
                + String(" code=MEM-003 reason=NO_FIT_NO_SPILL")
            )
            plan.digest = fnv1a64(plan.log_text())
            return plan^
    plan.ok = True
    plan.entries.append(
        String("totals gpu_bytes=") + String(plan.gpu_bytes)
        + String(" cpu_spill_bytes=") + String(plan.cpu_spill_bytes)
        + String(" cpu_assist_bytes=") + String(plan.cpu_assist_bytes)
        + String(" gpu_layers=") + String(plan.gpu_layers)
        + String(" cpu_layers=") + String(plan.cpu_layers)
    )
    plan.digest = fnv1a64(plan.log_text())
    return plan^


def plan_spillover_live(
    config: GpuPressureConfig,
    layers: List[LayerSpec],
) -> PlacementPlan:
    """plan_spillover under the pool pressure measured NOW
    (A-076 live_pressure: MemTotal + MemAvailable from
    /proc/meminfo). The measured figures land in the plan
    header, so the logged plan still replays exactly."""
    var reading = live_pressure()
    return plan_spillover(config, layers, reading.available_bytes, reading.total_bytes)
