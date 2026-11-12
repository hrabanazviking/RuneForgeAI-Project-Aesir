# core/device_policy.mojo
# A-017: Device selection policy.
# Implements Volmarr's accelerator-first law as the engine's placement
# default: most work runs on the accelerator (NPU -> GPU -> CPU); the
# CPU is chosen only as spillover when no accelerator can take the op,
# or as an explicit per-op override (the measurably-massive-assist
# case -- the reason is logged either way). The policy consumes the
# A-009 backend registry; it never re-probes hardware.
# Honesty rules: presence is not execution capability. XRT presence
# proves an NPU device exists; it does NOT prove any op can execute on
# it. Until an execution slice proves NPU execution, the policy's
# npu_execution_proven flag stays False and every decision that skips
# the NPU logs that reason -- the NPU is never silently pretended.
# The policy is pure and deterministic: same registry + same policy
# in, same decision (and same reason text) out, so it is unit-testable
# with fake registries.

from core.backend_registry import (
    BACKEND_DEGRADED,
    BackendRegistry,
)

comptime DEVICE_NPU = 0
comptime DEVICE_GPU = 1
comptime DEVICE_CPU = 2
comptime DEVICE_NONE = 3

comptime OP_MATMUL = "matmul"
comptime OP_ATTENTION = "attention"
comptime OP_EMBEDDING = "embedding"
comptime OP_ELEMENTWISE = "elementwise"
comptime OP_SAMPLING = "sampling"
comptime OP_TRANSFER = "transfer"
comptime OP_GENERIC = "generic"


def device_class_name(device_class: Int) -> String:
    if device_class == DEVICE_NPU:
        return String("NPU")
    if device_class == DEVICE_GPU:
        return String("GPU")
    if device_class == DEVICE_CPU:
        return String("CPU")
    return String("none")


def canonical_op_kinds() -> List[String]:
    var kinds = List[String]()
    kinds.append(String(OP_MATMUL))
    kinds.append(String(OP_ATTENTION))
    kinds.append(String(OP_EMBEDDING))
    kinds.append(String(OP_ELEMENTWISE))
    kinds.append(String(OP_SAMPLING))
    kinds.append(String(OP_TRANSFER))
    kinds.append(String(OP_GENERIC))
    return kinds^


def npu_supports_op_kind(op_kind: String) -> Bool:
    """Op classes an XDNA-class NPU could execute once proven.

    Attention and sampling stay off this list: attention is
    memory-bound over the KV cache and sampling is host-control
    logic; neither is an NPU-shaped workload in this engine.
    """
    return (
        op_kind == OP_MATMUL
        or op_kind == OP_EMBEDDING
        or op_kind == OP_ELEMENTWISE
    )


struct PlacementOverride(Copyable, ImplicitlyCopyable):
    """One per-op override: place this op kind on this device class."""

    var op_kind: String
    var device_class: Int

    def __init__(out self, op_kind: String, device_class: Int):
        self.op_kind = op_kind
        self.device_class = device_class


struct PlacementDecision(Copyable, ImplicitlyCopyable):
    """One placement verdict with its full reasoning."""

    var op_kind: String
    var device_class: Int
    var backend: String
    var reason: String

    def __init__(
        out self,
        op_kind: String,
        device_class: Int,
        backend: String,
        reason: String,
    ):
        self.op_kind = op_kind
        self.device_class = device_class
        self.backend = backend
        self.reason = reason

    def line(self) -> String:
        return (
            self.op_kind
            + " -> "
            + device_class_name(self.device_class)
            + " ("
            + self.backend
            + "): "
            + self.reason
        )


struct PlacementPolicy(Copyable):
    """Accelerator-first placement policy over a BackendRegistry.

    npu_execution_proven is False by default and must only be set
    True by a slice that proved real NPU execution; presence of XRT
    alone never sets it.
    """

    var npu_execution_proven: Bool
    var overrides: List[PlacementOverride]

    def __init__(out self):
        self.npu_execution_proven = False
        self.overrides = List[PlacementOverride]()

    def __init__(
        out self,
        npu_execution_proven: Bool,
        overrides: List[PlacementOverride],
    ):
        self.npu_execution_proven = npu_execution_proven
        self.overrides = overrides.copy()

    def with_override(
        self, op_kind: String, device_class: Int
    ) -> PlacementPolicy:
        var next_overrides = self.overrides.copy()
        next_overrides.append(PlacementOverride(op_kind, device_class))
        return PlacementPolicy(self.npu_execution_proven, next_overrides^)

    def _override_for(self, op_kind: String) -> Int:
        for entry in self.overrides:
            if entry.op_kind == op_kind:
                return entry.device_class
        return -1

    def _try_class(
        self, registry: BackendRegistry, op_kind: String, device_class: Int
    ) -> PlacementDecision:
        """Attempt one device class; backend '' means unavailable."""
        if device_class == DEVICE_NPU:
            if not registry.xrt.is_available():
                return PlacementDecision(
                    op_kind,
                    DEVICE_NONE,
                    String(""),
                    String("NPU unavailable: XRT ")
                    + registry.xrt.status_name(),
                )
            if not self.npu_execution_proven:
                return PlacementDecision(
                    op_kind,
                    DEVICE_NONE,
                    String(""),
                    String(
                        "NPU present (XRT) but no NPU execution is proven"
                        " yet -- presence only, not placement"
                    ),
                )
            if not npu_supports_op_kind(op_kind):
                return PlacementDecision(
                    op_kind,
                    DEVICE_NONE,
                    String(""),
                    String("op kind is not NPU-executable in this engine"),
                )
            var npu_reason = String(
                "NPU execution proven and op kind is NPU-executable"
            )
            if registry.xrt.status == BACKEND_DEGRADED:
                npu_reason += "; XRT record is degraded"
            return PlacementDecision(
                op_kind, DEVICE_NPU, String("XRT"), npu_reason
            )
        if device_class == DEVICE_GPU:
            if registry.hip.is_available():
                var hip_reason = String("HIP GPU backend available")
                if registry.hip.status == BACKEND_DEGRADED:
                    hip_reason = String("HIP GPU backend degraded but available")
                return PlacementDecision(
                    op_kind, DEVICE_GPU, String("HIP"), hip_reason
                )
            if registry.vulkan.is_available():
                var vk_reason = String(
                    "HIP unavailable; Vulkan GPU backend available"
                )
                if registry.vulkan.status == BACKEND_DEGRADED:
                    vk_reason = String(
                        "HIP unavailable; Vulkan GPU backend degraded"
                        " but available"
                    )
                return PlacementDecision(
                    op_kind, DEVICE_GPU, String("Vulkan"), vk_reason
                )
            return PlacementDecision(
                op_kind,
                DEVICE_NONE,
                String(""),
                String("GPU unavailable: HIP ")
                + registry.hip.status_name()
                + ", Vulkan "
                + registry.vulkan.status_name(),
            )
        if device_class == DEVICE_CPU:
            if registry.cpu.is_available():
                return PlacementDecision(
                    op_kind,
                    DEVICE_CPU,
                    String("CPU"),
                    String("CPU backend available"),
                )
            return PlacementDecision(
                op_kind,
                DEVICE_NONE,
                String(""),
                String("CPU unavailable: ") + registry.cpu.status_name(),
            )
        return PlacementDecision(
            op_kind,
            DEVICE_NONE,
            String(""),
            String("unknown device class"),
        )

    def decide(
        self, registry: BackendRegistry, op_kind: String
    ) -> PlacementDecision:
        """Decide placement for one op kind, logging every skip.

        Order: per-op override first (honored only when that class
        can actually take the op; otherwise the fall-through and its
        reason are both logged), then the accelerator-first default
        NPU -> GPU -> CPU.
        """
        var notes = String("")
        var override_class = self._override_for(op_kind)
        if override_class >= 0:
            var forced = self._try_class(registry, op_kind, override_class)
            if forced.backend != "":
                forced.reason = (
                    String("per-op override to ")
                    + device_class_name(override_class)
                    + "; "
                    + forced.reason
                )
                return forced
            notes = (
                String("per-op override to ")
                + device_class_name(override_class)
                + " not satisfiable ("
                + forced.reason
                + "); falling through to accelerator-first order. "
            )
        var order = List[Int]()
        order.append(DEVICE_NPU)
        order.append(DEVICE_GPU)
        order.append(DEVICE_CPU)
        for device_class in order:
            var attempt = self._try_class(registry, op_kind, device_class)
            if attempt.backend != "":
                if device_class == DEVICE_CPU and override_class < 0:
                    attempt.reason = (
                        String(
                            "CPU spillover: no accelerator could take"
                            " this op; "
                        )
                        + attempt.reason
                    )
                attempt.reason = notes + attempt.reason
                return attempt
            notes += (
                String("skip ")
                + device_class_name(device_class)
                + " ("
                + attempt.reason
                + "). "
            )
        return PlacementDecision(
            op_kind,
            DEVICE_NONE,
            String("none"),
            notes + String("no available device can take this op"),
        )

    def effective_order_line(self, registry: BackendRegistry) -> String:
        """The effective accelerator-first order on this registry."""
        var generic = self.decide(registry, String(OP_GENERIC))
        return (
            String("effective order: NPU -> GPU -> CPU (generic"
                   " placement: ")
            + device_class_name(generic.device_class)
            + " via "
            + generic.backend
            + ")"
        )

    def decision_lines(self, registry: BackendRegistry) -> List[String]:
        var lines = List[String]()
        for op_kind in canonical_op_kinds():
            lines.append(self.decide(registry, op_kind).line())
        return lines^


def default_placement_policy() -> PlacementPolicy:
    """The engine default: accelerator-first, no overrides, and NPU
    execution honestly unproven (presence only)."""
    return PlacementPolicy()
