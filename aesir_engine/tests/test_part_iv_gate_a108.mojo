# tests/test_part_iv_gate_a108.mojo
# A-108: Part IV gate -- the verdict table is complete, no
# row is unexplained, the in-flight rows are honest, and the
# planner scope the gate files is the scope the banked
# planner actually implements.

from core.backend_registry import (
    GPU_ROLE_FIRST_CLASS,
    GPU_ROLE_PROBE_ONLY,
    BackendRegistry,
    RawBackendProbe,
    build_backend_registry,
)
from core.device_policy import DEVICE_CPU, DEVICE_GPU, DEVICE_NPU
from core.part_iv_gate import (
    VERDICT_IN_FLIGHT,
    VERDICT_NEGATIVE,
    VERDICT_POSITIVE,
    VERDICT_SCOPED,
    part_iv_gate_summary,
    part_iv_verdicts,
)
from core.placement_planner import (
    OP_GEMM,
    OP_PREFILL_PROJECTION,
    OP_SAMPLING,
    PlannerRequest,
    plan_op,
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


def test_gate_verdict_table_complete() raises:
    var rows = part_iv_verdicts()
    if len(rows) != 26:
        raise Error("verdict count drifted: " + String(len(rows)))
    for i in range(len(rows)):
        var num = 82 + i
        var expect = "A-0" + String(num) if num < 100 else "A-" + String(num)
        if rows[i].slice_id != expect:
            raise Error("row order drifted at " + String(i))


def test_gate_no_unexplained_rows() raises:
    var rows = part_iv_verdicts()
    for row in rows:
        if row.verdict != VERDICT_POSITIVE and row.verdict != VERDICT_NEGATIVE and row.verdict != VERDICT_SCOPED and row.verdict != VERDICT_IN_FLIGHT:
            raise Error("unclassified verdict on " + row.slice_id)
        if row.headline.byte_length() == 0 or row.evidence.byte_length() == 0:
            raise Error("unexplained row: " + row.slice_id)


def test_gate_in_flight_rows_honest() raises:
    var rows = part_iv_verdicts()
    for row in rows:
        var in_flight = row.slice_id == "A-106" or row.slice_id == "A-107"
        if in_flight and row.verdict != VERDICT_IN_FLIGHT:
            raise Error("in-flight slice overclaimed: " + row.slice_id)
        if not in_flight and row.verdict == VERDICT_IN_FLIGHT:
            raise Error("banked slice filed in-flight: " + row.slice_id)
    if "IN_FLIGHT" not in part_iv_gate_summary():
        raise Error("gate summary lost the in-flight honesty")
    if "SCOPED" not in part_iv_gate_summary():
        raise Error("gate summary lost the scoped planner decision")


def test_gate_negative_verdicts_present() raises:
    var rows = part_iv_verdicts()
    var negatives = 0
    for row in rows:
        if row.verdict == VERDICT_NEGATIVE:
            negatives += 1
    if negatives != 3:
        raise Error("expected the 3 measured negatives (A-088, A-090, A-097)")


def test_gate_planner_scope_matches_planner() raises:
    var reg = _standard_registry()
    var context = standard_context()
    for fixture in standard_fixtures():
        var decision = plan_op(reg, context, fixture.request)
        if decision.device_class != fixture.expected_device_class:
            raise Error("fixture drifted: " + fixture.name)
        if decision.backend == "HIP":
            raise Error("planner placed parked HIP: " + fixture.name)
    var sampling = plan_op(reg, context, PlannerRequest(OP_SAMPLING, 1, 0, 131072))
    if sampling.device_class != DEVICE_CPU:
        raise Error("sampling left the CPU scope")
    var small = plan_op(reg, context, PlannerRequest(OP_GEMM, 32, 32, 32))
    if small.device_class != DEVICE_CPU:
        raise Error("below-floor GEMM left the CPU scope")
    var capped = plan_op(reg, context, PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024, False, True))
    if capped.device_class != DEVICE_NPU:
        raise Error("power-capped prefill left the NPU scope")
    var prefill = plan_op(reg, context, PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024))
    if prefill.device_class != DEVICE_GPU:
        raise Error("default prefill left the GPU scope")


def test_gate_summary_names_scope() raises:
    var summary = part_iv_gate_summary()
    if "HIP parked" not in summary or "Vulkan primary" not in summary:
        raise Error("gate summary lost the GPU road verdict")
