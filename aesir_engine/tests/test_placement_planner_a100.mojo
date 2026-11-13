# tests/test_placement_planner_a100.mojo
# A-100: Placement planner -- decisions on the standard
# fixtures match the measured optima from Parts III-IV.
# Fake registries throughout: the standard registry is all
# backends present with the banked A-086 verdict applied
# (Vulkan first-class, HIP probe-only), exactly as
# observe_backend_registry builds the live one. The planner
# context is the standard one (A-095 proven path) unless a
# case says otherwise.

from core.backend_registry import (
    GPU_ROLE_FIRST_CLASS,
    GPU_ROLE_PROBE_ONLY,
    BackendRegistry,
    RawBackendProbe,
    build_backend_registry,
)
from core.device_policy import (
    DEVICE_CPU,
    DEVICE_GPU,
    DEVICE_NONE,
    DEVICE_NPU,
)
from core.placement_planner import (
    OP_EMBEDDING_LOOKUP,
    OP_GEMM,
    OP_PREFILL_PROJECTION,
    OP_SAMPLING,
    PlannerContext,
    PlannerRequest,
    npu_gemm_latency_table,
    plan_op,
    planner_fixture_lines,
    planner_summary,
    prefill_power_table,
    sampler_latency_table,
    standard_context,
    standard_fixtures,
)


def _fake(found: Bool, device: String) -> RawBackendProbe:
    return RawBackendProbe(found, False, "1", device, "fake probe")


def _standard_registry() -> BackendRegistry:
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
    return BackendRegistry(hip, vulkan, reg.xrt, reg.cpu)


def _gpu_absent_registry() -> BackendRegistry:
    var reg = build_backend_registry(
        _fake(False, ""),
        _fake(False, ""),
        _fake(True, "xrt-dev"),
        _fake(True, "cpu-dev"),
    )
    var hip = reg.hip
    var vulkan = reg.vulkan
    hip.gpu_role = GPU_ROLE_PROBE_ONLY
    vulkan.gpu_role = GPU_ROLE_FIRST_CLASS
    return BackendRegistry(hip, vulkan, reg.xrt, reg.cpu)


def test_planner_standard_fixtures() raises:
    var reg = _standard_registry()
    var context = standard_context()
    var fixtures = standard_fixtures()
    if len(fixtures) != 12:
        raise Error(
            "standard fixture count drifted: " + String(len(fixtures))
        )
    for fixture in fixtures:
        var decision = plan_op(reg, context, fixture.request)
        if decision.device_class != fixture.expected_device_class:
            raise Error(
                "fixture "
                + fixture.name
                + " landed on the wrong device: "
                + decision.line()
                + " [source: "
                + fixture.source
                + "]"
            )
        if decision.backend != fixture.expected_backend:
            raise Error(
                "fixture "
                + fixture.name
                + " landed on the wrong backend: "
                + decision.line()
            )


def test_planner_prefill_variants() raises:
    var reg = _standard_registry()
    var context = standard_context()
    # Default: the A-098 winner, with its measured estimate.
    var default = plan_op(
        reg,
        context,
        PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024),
    )
    if default.device_class != DEVICE_GPU or default.backend != "Vulkan":
        raise Error("prefill default not GPU/Vulkan: " + default.line())
    if default.est_us_x10 != 675:
        raise Error("prefill default lost the A-098 estimate")
    if "MEASURED_OPTIMUM_A098" not in default.reason:
        raise Error("prefill default reason lost its source")
    # Power-capped: the A-098 NPU value, fallback named (A-099).
    var capped = plan_op(
        reg,
        context,
        PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024, False, True),
    )
    if capped.device_class != DEVICE_NPU or capped.backend != "XRT":
        raise Error("prefill power-capped not NPU: " + capped.line())
    if "FALLBACK_" not in capped.fallback:
        raise Error("NPU decision lost its A-099 fallback")
    # Overlap: the A-096 positive.
    var overlap = plan_op(
        reg,
        context,
        PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024, True, False),
    )
    if overlap.device_class != DEVICE_NPU:
        raise Error("prefill overlap not NPU: " + overlap.line())
    if "OVERLAP_A096" not in overlap.reason:
        raise Error("overlap reason lost its source")


def test_planner_gemm_thresholds() raises:
    var reg = _standard_registry()
    var context = standard_context()
    # 32^3: below the floor, CPU wins (A-094 measured 0.29x).
    var small = plan_op(reg, context, PlannerRequest(OP_GEMM, 32, 32, 32))
    if small.device_class != DEVICE_CPU:
        raise Error("small GEMM not CPU: " + small.line())
    if small.est_us_x10 != 272:
        raise Error("small GEMM lost the A-094 CPU oracle estimate")
    # GPU absent, in the FIT band: NPU (A-094, 99x proxy class).
    var no_gpu = _gpu_absent_registry()
    var fit = plan_op(
        no_gpu,
        context,
        PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024),
    )
    if fit.device_class != DEVICE_NPU or "FIT_A094" not in fit.reason:
        raise Error("GPU-absent prefill not NPU/FIT: " + fit.line())
    # GPU absent, below the M band but above the MAC floor:
    # the A-094 crossover row (32x1024x1024, 103x vs oracle).
    var crossover = plan_op(
        no_gpu,
        context,
        PlannerRequest(OP_PREFILL_PROJECTION, 32, 1024, 1024),
    )
    if crossover.device_class != DEVICE_NPU:
        raise Error("crossover shape not NPU: " + crossover.line())
    if "CROSSOVER_A094" not in crossover.reason:
        raise Error("crossover reason lost its source")


def test_planner_decode_and_sampling() raises:
    var reg = _standard_registry()
    var context = standard_context()
    var gemv = plan_op(
        reg, context, PlannerRequest("gemv", 1, 4096, 4096)
    )
    if gemv.device_class != DEVICE_GPU or gemv.backend != "Vulkan":
        raise Error("decode GEMV not GPU/Vulkan: " + gemv.line())
    if "NOT_FIT_A094" not in gemv.reason:
        raise Error("GEMV reason lost its source")
    # A matmul-shaped request with M=1 is decode-shaped too.
    var m1 = plan_op(reg, context, PlannerRequest(OP_GEMM, 1, 4096, 4096))
    if m1.device_class != DEVICE_GPU:
        raise Error("M=1 GEMM not treated as decode: " + m1.line())
    var sampling = plan_op(
        reg, context, PlannerRequest(OP_SAMPLING, 1, 0, 131072)
    )
    if sampling.device_class != DEVICE_CPU:
        raise Error("sampling not CPU: " + sampling.line())
    if sampling.est_us_x10 != 767:
        raise Error("sampling lost the A-097 CPU estimate")
    if "MEASURED_A097" not in sampling.reason:
        raise Error("sampling reason lost its source")


def test_planner_honesty_and_fallback() raises:
    var reg = _standard_registry()
    # NPU presence without proven execution never places NPU,
    # even for the power-capped fixture (A-017 honesty law).
    var unproven = PlannerContext(False)
    var capped = plan_op(
        reg,
        unproven,
        PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024, False, True),
    )
    if capped.device_class == DEVICE_NPU:
        raise Error("unproven NPU was placed: " + capped.line())
    if capped.device_class != DEVICE_GPU:
        raise Error("unproven capped prefill not GPU: " + capped.line())
    # HIP probe-only is never a planner backend, in any fixture.
    var context = standard_context()
    for fixture in standard_fixtures():
        var decision = plan_op(reg, context, fixture.request)
        if decision.backend == "HIP":
            raise Error(
                "probe-only HIP placed by fixture " + fixture.name
            )
    # GPU absent + NPU unproven: large GEMM spills to CPU.
    var no_gpu = _gpu_absent_registry()
    var spill = plan_op(
        no_gpu,
        unproven,
        PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024),
    )
    if spill.device_class != DEVICE_CPU:
        raise Error("spillover not CPU: " + spill.line())
    # Nothing present at all: fail closed to NONE, never invent.
    var empty = build_backend_registry(
        _fake(False, ""),
        _fake(False, ""),
        _fake(False, ""),
        _fake(False, ""),
    )
    var none = plan_op(
        empty,
        context,
        PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024),
    )
    if none.device_class != DEVICE_NONE:
        raise Error("empty registry did not fail closed: " + none.line())
    var lookup = plan_op(
        reg, context, PlannerRequest(OP_EMBEDDING_LOOKUP, 128, 0, 4096)
    )
    if lookup.device_class != DEVICE_CPU:
        raise Error("embedding lookup not CPU: " + lookup.line())


def test_planner_cost_tables_and_lines() raises:
    # The encoded tables carry the filed numbers, verbatim.
    var gemm = npu_gemm_latency_table()
    if len(gemm) != 7:
        raise Error("A-094 table row count drifted")
    if gemm[0].npu_us_x10 != 930 or gemm[0].cpu_oracle_us_x10 != 272:
        raise Error("A-094 floor row drifted (32^3)")
    if gemm[6].npu_us_x10 != 25583 or gemm[6].m != 128:
        raise Error("A-094 projection row drifted (128x1024x1024)")
    var power = prefill_power_table()
    if len(power) != 3:
        raise Error("A-098 table row count drifted")
    if power[0].device != "GPU" or power[0].us_x10 != 675:
        raise Error("A-098 GPU row drifted")
    if power[2].device != "NPU" or power[2].package_w_x10 != 221:
        raise Error("A-098 NPU package row drifted")
    var sampler = sampler_latency_table()
    if len(sampler) != 2 or sampler[1].cpu_us_x10 != 767:
        raise Error("A-097 sampler table drifted")
    # Doctor lines: header + one line per fixture, deterministic.
    var reg = _standard_registry()
    var lines = planner_fixture_lines(reg)
    if len(lines) != 13:
        raise Error("planner doctor lines drifted: " + String(len(lines)))
    var again = planner_fixture_lines(reg)
    for i in range(len(lines)):
        if lines[i] != again[i]:
            raise Error("planner lines are not deterministic")
    if "A-100" not in planner_summary():
        raise Error("planner summary lost its slice mark")
