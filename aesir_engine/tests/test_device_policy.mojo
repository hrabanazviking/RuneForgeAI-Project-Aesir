# tests/test_device_policy.mojo
# A-017: device selection policy -- the accelerator-first order
# (NPU -> GPU -> CPU) is proven against fake registries in every
# presence combination that matters, with the reasoning logged.
# Honesty core: XRT presence alone never places an op on the NPU.

from core.backend_registry import (
    BackendRegistry,
    RawBackendProbe,
    build_backend_registry,
)
from core.device_policy import (
    DEVICE_CPU,
    DEVICE_GPU,
    DEVICE_NONE,
    DEVICE_NPU,
    OP_ATTENTION,
    OP_GENERIC,
    OP_MATMUL,
    OP_SAMPLING,
    PlacementOverride,
    PlacementPolicy,
    default_placement_policy,
)


def _fake(found: Bool, device: String) -> RawBackendProbe:
    return RawBackendProbe(found, False, "1", device, "fake probe")


def _fake_degraded(device: String) -> RawBackendProbe:
    return RawBackendProbe(True, True, "1", device, "fake degraded probe")


def _all_present() -> BackendRegistry:
    return build_backend_registry(
        _fake(True, "hip-dev"),
        _fake(True, "vk-dev"),
        _fake(True, "xrt-dev"),
        _fake(True, "cpu-dev"),
    )


def test_device_policy_accelerator_first_all_present() raises:
    var reg = _all_present()
    var policy = default_placement_policy()
    for kind in [String(OP_MATMUL), String(OP_ATTENTION), String(OP_GENERIC)]:
        var decision = policy.decide(reg, kind)
        if decision.device_class != DEVICE_GPU or decision.backend != "HIP":
            raise Error(
                "all-present default policy did not place "
                + kind
                + " on GPU/HIP: "
                + decision.line()
            )
        if "no NPU execution is proven" not in decision.reason:
            raise Error(
                "NPU presence-only skip was not logged for " + kind
            )
        if "skip NPU" not in decision.reason:
            raise Error("decision log lost the NPU skip for " + kind)


def test_device_policy_gpu_backend_fallback() raises:
    var policy = default_placement_policy()
    # HIP absent, Vulkan present -> GPU via Vulkan, reason names HIP.
    var vk_only = build_backend_registry(
        _fake(False, ""),
        _fake(True, "vk-dev"),
        _fake(True, "xrt-dev"),
        _fake(True, "cpu-dev"),
    )
    var decision = policy.decide(vk_only, String(OP_MATMUL))
    if decision.device_class != DEVICE_GPU or decision.backend != "Vulkan":
        raise Error("Vulkan fallback failed: " + decision.line())
    if "HIP unavailable" not in decision.reason:
        raise Error("Vulkan fallback reason does not name HIP")
    # HIP degraded still wins over Vulkan and says so.
    var degraded = build_backend_registry(
        _fake_degraded("hip-dev"),
        _fake(True, "vk-dev"),
        _fake(True, "xrt-dev"),
        _fake(True, "cpu-dev"),
    )
    var deg = policy.decide(degraded, String(OP_MATMUL))
    if deg.device_class != DEVICE_GPU or deg.backend != "HIP":
        raise Error("degraded HIP was not chosen: " + deg.line())
    if "degraded" not in deg.reason:
        raise Error("degraded HIP choice lost its degraded note")


def test_device_policy_cpu_spillover_and_none() raises:
    var policy = default_placement_policy()
    var cpu_only = build_backend_registry(
        _fake(False, ""),
        _fake(False, ""),
        _fake(False, ""),
        _fake(True, "cpu-dev"),
    )
    var decision = policy.decide(cpu_only, String(OP_MATMUL))
    if decision.device_class != DEVICE_CPU or decision.backend != "CPU":
        raise Error("CPU-only registry did not spill to CPU: " + decision.line())
    if "CPU spillover" not in decision.reason:
        raise Error("CPU choice was not logged as spillover")
    if "skip NPU" not in decision.reason or "skip GPU" not in decision.reason:
        raise Error("spillover decision lost its skip log")
    var empty = build_backend_registry(
        _fake(False, ""),
        _fake(False, ""),
        _fake(False, ""),
        _fake(False, ""),
    )
    var none = policy.decide(empty, String(OP_MATMUL))
    if none.device_class != DEVICE_NONE or none.backend != "none":
        raise Error("empty registry did not fail closed: " + none.line())
    if "no available device" not in none.reason:
        raise Error("empty-registry decision lost its reason")


def test_device_policy_override() raises:
    var reg = _all_present()
    # Satisfiable override: sampling pinned to CPU is honored + logged.
    var pinned = default_placement_policy().with_override(
        String(OP_SAMPLING), DEVICE_CPU
    )
    var decision = pinned.decide(reg, String(OP_SAMPLING))
    if decision.device_class != DEVICE_CPU or decision.backend != "CPU":
        raise Error("CPU override was not honored: " + decision.line())
    if "per-op override to CPU" not in decision.reason:
        raise Error("override choice lost its logged reason")
    # The override is per-op: matmul still follows the default order.
    var other = pinned.decide(reg, String(OP_MATMUL))
    if other.device_class != DEVICE_GPU:
        raise Error("override leaked onto another op kind")
    # Unsatisfiable override: NPU is presence-only, so a matmul->NPU
    # override falls through to GPU and logs both facts.
    var npu_pinned = default_placement_policy().with_override(
        String(OP_MATMUL), DEVICE_NPU
    )
    var fell = npu_pinned.decide(reg, String(OP_MATMUL))
    if fell.device_class != DEVICE_GPU or fell.backend != "HIP":
        raise Error("unsatisfiable NPU override did not fall through: " + fell.line())
    if "not satisfiable" not in fell.reason:
        raise Error("override fall-through was not logged")
    if "no NPU execution is proven" not in fell.reason:
        raise Error("override fall-through lost the NPU honesty reason")


def test_device_policy_npu_proven_path() raises:
    var reg = _all_present()
    var policy = PlacementPolicy(True, List[PlacementOverride]())
    var matmul = policy.decide(reg, String(OP_MATMUL))
    if matmul.device_class != DEVICE_NPU or matmul.backend != "XRT":
        raise Error("proven policy did not place matmul on NPU: " + matmul.line())
    var attention = policy.decide(reg, String(OP_ATTENTION))
    if attention.device_class != DEVICE_GPU or attention.backend != "HIP":
        raise Error(
            "proven policy placed attention on the NPU: " + attention.line()
        )
    if "not NPU-executable" not in attention.reason:
        raise Error("attention fall-through lost its reason")


def test_device_policy_deterministic_log() raises:
    var reg = _all_present()
    var policy = default_placement_policy()
    var first = policy.decision_lines(reg)
    var second = policy.decision_lines(reg)
    if len(first) != 7 or len(second) != 7:
        raise Error("decision_lines did not cover the 7 canonical op kinds")
    for i in range(len(first)):
        if first[i] != second[i]:
            raise Error("policy decisions are not deterministic")
    var order_line = policy.effective_order_line(reg)
    if "NPU -> GPU -> CPU" not in order_line:
        raise Error("effective order line lost the accelerator-first order")
    if "GPU via HIP" not in order_line:
        raise Error("effective order line lost this registry's GPU backend")
