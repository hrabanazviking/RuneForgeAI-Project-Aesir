# core/gpu_winner.mojo
# A-086: Winner integration -- preparatory scaffolding.
# The A-085 bake-off (HIP vs Vulkan, team-15) declares one road
# primary; this module is the integration surface for that verdict:
# a typed BakeoffVerdict, its application to the A-009 registry
# (winner first-class, loser probe-only), validation that the two
# GPU roles are always consistent, and the lines `doctor` renders.
# PREPARATORY STATE: no verdict is banked yet, so the live default
# everywhere is bakeoff_verdict_pending() -- no winner is declared
# and no primary-backend switch is made by this slice. When the
# A-085 verdict banks, the keeper applies it through
# apply_bakeoff_verdict() and the registry, placement policy
# (core/device_policy), backend selection (core/backend_config)
# and `doctor` all reflect it without further code changes.
# Honesty rules: a decided verdict must name a HIP/Vulkan winner
# and a non-empty source (the banked verdict doc); the loser is
# parked probe-only with re-open criteria in that doc -- never
# silently dropped, never placed, never selected for execution.

from core.backend_registry import (
    GPU_ROLE_UNDECIDED,
    BackendRegistry,
    gpu_first_class_runtime,
    gpu_probe_only_runtime,
    registry_with_gpu_winner,
    registry_without_gpu_winner,
)
from core.structured_errors import coded_error_text

comptime BAKEOFF_PENDING = 0
comptime BAKEOFF_DECIDED = 1


struct BakeoffVerdict(Copyable, ImplicitlyCopyable):
    """The A-085 verdict as data: pending, or decided with a source."""

    var state: Int
    var winner: String
    var loser: String
    var source: String

    def __init__(out self):
        self.state = BAKEOFF_PENDING
        self.winner = String("")
        self.loser = String("")
        self.source = String("")

    def __init__(
        out self, state: Int, winner: String, loser: String, source: String
    ):
        self.state = state
        self.winner = winner
        self.loser = loser
        self.source = source

    def is_pending(self) -> Bool:
        return self.state == BAKEOFF_PENDING

    def is_decided(self) -> Bool:
        return self.state == BAKEOFF_DECIDED

    def line(self) -> String:
        if self.is_pending():
            return String(
                "GPU bake-off: pending -- no A-085 verdict banked;"
                " no primary GPU backend declared"
            )
        return (
            String("GPU bake-off: decided -- ")
            + self.winner
            + " first-class, "
            + self.loser
            + " probe-only (source: "
            + self.source
            + ")"
        )


def bakeoff_verdict_pending() -> BakeoffVerdict:
    """The honest pre-verdict state: no winner, no loser, no source."""
    return BakeoffVerdict()


def bakeoff_verdict_decided(
    winner_runtime: String, source: String
) raises -> BakeoffVerdict:
    """Build a decided verdict, fail-closed on bad inputs.

    The winner must be exactly HIP or Vulkan (the A-085 pair) and
    the source must name the banked verdict evidence; an unnamed
    or sourceless winner is not a verdict.
    """
    if winner_runtime != "HIP" and winner_runtime != "Vulkan":
        raise Error(
            coded_error_text(
                "VAL-003",
                "bake-off winner must be HIP or Vulkan, got: "
                + winner_runtime,
            )
        )
    if source == "":
        raise Error(
            coded_error_text(
                "VAL-003",
                "bake-off verdict requires a source (the banked"
                " A-085 verdict doc); a sourceless winner is not"
                " a verdict",
            )
        )
    var loser = String("Vulkan") if winner_runtime == "HIP" else String("HIP")
    return BakeoffVerdict(BAKEOFF_DECIDED, winner_runtime, loser, source)


def validate_gpu_roles(registry: BackendRegistry) raises:
    """The only lawful role states: both undecided (pending), or
    exactly one first-class with the other probe-only (decided).
    XRT/CPU never carry a GPU role. Anything else raises VAL-003."""
    if (
        registry.xrt.gpu_role != GPU_ROLE_UNDECIDED
        or registry.cpu.gpu_role != GPU_ROLE_UNDECIDED
    ):
        raise Error(
            coded_error_text(
                "VAL-003", "non-GPU backend carries a GPU bake-off role"
            )
        )
    var first = gpu_first_class_runtime(registry)
    var probe = gpu_probe_only_runtime(registry)
    if first == "" and probe == "":
        return
    if first != "" and probe != "" and first != probe:
        return
    raise Error(
        coded_error_text(
            "VAL-003",
            "inconsistent GPU bake-off roles: first-class '"
            + first
            + "', probe-only '"
            + probe
            + "' (lawful states: both undecided, or one"
            + " first-class with the other probe-only)",
        )
    )


def bakeoff_verdict_from_registry(
    registry: BackendRegistry,
) raises -> BakeoffVerdict:
    """Derive the verdict state from a registry's GPU roles."""
    validate_gpu_roles(registry)
    var winner = gpu_first_class_runtime(registry)
    if winner == "":
        return bakeoff_verdict_pending()
    return bakeoff_verdict_decided(winner, String("registry GPU roles"))


def apply_bakeoff_verdict(
    registry: BackendRegistry, verdict: BakeoffVerdict
) raises -> BackendRegistry:
    """Apply a verdict to a registry copy; pending clears the roles."""
    if verdict.is_pending():
        return registry_without_gpu_winner(registry)
    return registry_with_gpu_winner(registry, verdict.winner)


def preferred_gpu_runtime(
    registry: BackendRegistry, verdict: BakeoffVerdict
) raises -> String:
    """The GPU runtime execution surfaces should prefer.

    Pending: the standing A-017 GPU preference (HIP, then Vulkan)
    over available records -- unchanged pre-verdict behaviour.
    Decided: the winner only, and only when it is available; the
    probe-only loser is never preferred, so '' means no GPU can
    take execution (callers spill or fail closed, saying why).
    """
    validate_gpu_roles(registry)
    if verdict.is_pending():
        if registry.hip.is_available():
            return String("HIP")
        if registry.vulkan.is_available():
            return String("Vulkan")
        return String("")
    if verdict.winner == "HIP" and registry.hip.is_available():
        return String("HIP")
    if verdict.winner == "Vulkan" and registry.vulkan.is_available():
        return String("Vulkan")
    return String("")


def gpu_winner_lines(
    registry: BackendRegistry, verdict: BakeoffVerdict
) -> List[String]:
    """The `doctor` rendering of the verdict over this registry."""
    var lines = List[String]()
    lines.append(verdict.line())
    if verdict.is_pending():
        lines.append(
            String("HIP: undecided (registry ")
            + registry.hip.status_name()
            + ") -- no role until the A-085 verdict banks"
        )
        lines.append(
            String("Vulkan: undecided (registry ")
            + registry.vulkan.status_name()
            + ") -- no role until the A-085 verdict banks"
        )
        return lines^
    lines.append(
        verdict.winner
        + ": first-class GPU backend (registry "
        + (registry.hip.status_name() if verdict.winner == "HIP" else registry.vulkan.status_name())
        + ")"
    )
    lines.append(
        verdict.loser
        + ": probe-only (registry "
        + (registry.hip.status_name() if verdict.loser == "HIP" else registry.vulkan.status_name())
        + ") -- parked, not dropped; re-open criteria live in"
        + " the A-085 verdict doc"
    )
    return lines^


def gpu_winner_summary(
    registry: BackendRegistry, verdict: BakeoffVerdict
) -> String:
    """One-line verdict summary (doctor JSON rendering)."""
    _ = registry
    return verdict.line()
