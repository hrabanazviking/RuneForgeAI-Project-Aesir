# spikes/a100_planner/check.mojo
# A-100 standalone check: every standard fixture decided on a
# fake standard registry (all present, Vulkan first-class per
# A-086, A-095 proven context) must match its measured optimum.

from core.backend_registry import (
    GPU_ROLE_FIRST_CLASS,
    GPU_ROLE_PROBE_ONLY,
    BackendRegistry,
    RawBackendProbe,
    build_backend_registry,
)
from core.placement_planner import (
    plan_op,
    standard_context,
    standard_fixtures,
)


def _fake(found: Bool, device: String) -> RawBackendProbe:
    return RawBackendProbe(found, False, "1", device, "fake probe")


def main():
    var reg = build_backend_registry(
        _fake(True, "hip-dev"),
        _fake(True, "vk-dev"),
        _fake(True, "xrt-dev"),
        _fake(True, "cpu-dev"),
    )
    var hip = reg.hip
    var vulkan = reg.vulkan
    hip.gpu_role = GPU_ROLE_PROBE_ONLY
    vulkan.gpu_role = GPU_ROLE_FIRST_CLASS
    var standard = BackendRegistry(hip, vulkan, reg.xrt, reg.cpu)
    var context = standard_context()
    var passed = 0
    for fixture in standard_fixtures():
        var decision = plan_op(standard, context, fixture.request)
        var ok = (
            decision.device_class == fixture.expected_device_class
            and decision.backend == fixture.expected_backend
        )
        print(
            ("PASS " if ok else "FAIL ")
            + fixture.name
            + ": "
            + decision.line()
        )
        if ok:
            passed += 1
    print(
        "A100_CHECK "
        + String(passed)
        + "/"
        + String(len(standard_fixtures()))
        + " fixtures at their measured optima"
    )
