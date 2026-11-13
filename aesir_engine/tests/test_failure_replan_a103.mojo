# tests/test_failure_replan_a103.mojo
# A-103: Mid-run device failure re-planning -- the remaining
# work of a generation is re-planned onto the survivors of a
# device error, and the injected-failure drill completes with
# final tokens exactly equal to the uninterrupted control.
# Fake registries throughout (the A-100 standard registry:
# all backends present, Vulkan first-class per A-086, HIP
# probe-only; the standard context is the A-095 proven path).

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
from core.failure_replan import (
    REPLAN_FAILED_CLOSED,
    REPLAN_NO_REMAINING,
    REPLAN_OK,
    build_generation_plan,
    control_tokens,
    replan_remaining,
    replan_summary,
    run_failure_drill,
    survivor_registry,
)
from core.placement_planner import (
    OP_EMBEDDING_LOOKUP,
    OP_GEMM,
    OP_GEMV,
    OP_PREFILL_PROJECTION,
    PlannerRequest,
    plan_op,
    standard_context,
)
from core.device_policy import OP_ATTENTION, OP_SAMPLING


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


def _mixed_requests() -> List[PlannerRequest]:
    var reqs = List[PlannerRequest]()
    reqs.append(PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024))
    reqs.append(PlannerRequest(OP_ATTENTION, 128, 4096, 4096))
    reqs.append(PlannerRequest(OP_GEMV, 1, 4096, 4096))
    reqs.append(PlannerRequest(OP_SAMPLING, 1, 0, 131072))
    reqs.append(PlannerRequest(OP_GEMM, 32, 32, 32))
    reqs.append(
        PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024, False, True)
    )
    return reqs^


def test_replan_gpu_loss_onto_survivors() raises:
    var reg = _standard_registry()
    var context = standard_context()
    var plan = build_generation_plan(reg, context, _mixed_requests())
    # Sanity: the first three steps sit on the GPU pre-failure.
    for i in range(3):
        if plan.steps[i].decision.device_class != DEVICE_GPU:
            raise Error("pre-failure step not on GPU: " + String(i))
    var rr = replan_remaining(
        reg, context, plan, 1, DEVICE_GPU, "VK_ERROR_DEVICE_LOST"
    )
    if rr.outcome != REPLAN_OK:
        raise Error("GPU-loss re-plan not OK: " + rr.reason)
    if rr.remaining_count != 5 or len(rr.steps) != 5:
        raise Error("GPU-loss re-plan kept the wrong tail")
    for step in rr.steps:
        if step.decision.device_class == DEVICE_GPU:
            raise Error("re-planned step still on the failed GPU")
        if step.decision.device_class == DEVICE_NONE:
            raise Error("re-planned step placed nowhere")
    # Attention and decode GEMV spill to CPU; the power-capped
    # prefill lands on the NPU survivor with its A-099 fallback.
    if rr.steps[0].decision.device_class != DEVICE_CPU:
        raise Error("attention did not spill to CPU")
    if rr.steps[1].decision.device_class != DEVICE_CPU:
        raise Error("decode GEMV did not spill to CPU")
    if rr.steps[4].decision.device_class != DEVICE_NPU:
        raise Error("power-capped prefill did not land on NPU")
    if rr.steps[4].decision.fallback == "":
        raise Error("NPU re-plan decision lost its A-099 fallback")
    # Exactly two steps move: attention and decode GEMV spill
    # to CPU. Sampling and the small GEMM were already on CPU
    # and the power-capped prefill was already on the NPU
    # survivor -- re-planning must not churn unmoved steps.
    if rr.moved_count != 2:
        raise Error("moved count wrong: " + String(rr.moved_count))
    if len(rr.audit) != 5:
        raise Error("audit does not cover every re-planned step")
    if "VK_ERROR_DEVICE_LOST" not in rr.audit[0]:
        raise Error("audit lost the injected error name")


def test_replan_npu_loss_uses_survivors() raises:
    var reg = _standard_registry()
    var context = standard_context()
    var reqs = List[PlannerRequest]()
    reqs.append(
        PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024, False, True)
    )
    reqs.append(
        PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024, True, False)
    )
    reqs.append(PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024))
    var plan = build_generation_plan(reg, context, reqs)
    if plan.steps[0].decision.device_class != DEVICE_NPU:
        raise Error("capped prefill not on NPU pre-failure")
    if plan.steps[1].decision.device_class != DEVICE_NPU:
        raise Error("overlap prefill not on NPU pre-failure")
    var rr = replan_remaining(
        reg, context, plan, 0, DEVICE_NPU, "KERNEL_RUN_FAILED"
    )
    if rr.outcome != REPLAN_OK:
        raise Error("NPU-loss re-plan not OK: " + rr.reason)
    for step in rr.steps:
        if step.decision.device_class == DEVICE_NPU:
            raise Error("re-planned step still on the failed NPU")
    # On the survivor registry the A-098 optimum among the
    # survivors (GPU, 67.5 us) takes all three prefill steps.
    for step in rr.steps:
        if step.decision.device_class != DEVICE_GPU:
            raise Error("NPU-loss survivor step not on GPU")
        if step.decision.backend != "Vulkan":
            raise Error("NPU-loss survivor step not on Vulkan")
    if rr.moved_count != 2:
        raise Error("only the two NPU steps should move")


def test_replan_drill_gpu_loss_completes_exact() raises:
    var reg = _standard_registry()
    var context = standard_context()
    var drill = run_failure_drill(
        reg, context, _mixed_requests(), 4242, 2, DEVICE_GPU,
        "VK_ERROR_DEVICE_LOST",
    )
    if drill.outcome != REPLAN_OK:
        raise Error("GPU drill did not complete: " + drill.reason)
    if not drill.tokens_match_control:
        raise Error("GPU drill tokens differ from the control")
    if len(drill.tokens) != 6:
        raise Error("GPU drill lost steps")
    if drill.steps_on_failed_after_failure != 0:
        raise Error("work executed on the failed GPU after loss")
    if drill.moved_count < 1:
        raise Error("GPU drill re-plan moved nothing")
    if len(drill.audit) != 4:
        raise Error("GPU drill audit should cover steps 2..5")


def test_replan_drill_npu_loss_completes_exact() raises:
    var reg = _standard_registry()
    var context = standard_context()
    var reqs = List[PlannerRequest]()
    reqs.append(
        PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024, False, True)
    )
    reqs.append(
        PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024, True, False)
    )
    reqs.append(PlannerRequest(OP_SAMPLING, 1, 0, 32768))
    var drill = run_failure_drill(
        reg, context, reqs, 777, 0, DEVICE_NPU, "KERNEL_TIMEOUT",
    )
    if drill.outcome != REPLAN_OK:
        raise Error("NPU drill did not complete: " + drill.reason)
    if not drill.tokens_match_control:
        raise Error("NPU drill tokens differ from the control")
    if drill.steps_on_failed_after_failure != 0:
        raise Error("work executed on the failed NPU after loss")
    var control = control_tokens(777, 3)
    if len(control) != 3 or control[0] == control[1]:
        raise Error("control token model is degenerate")


def test_replan_cpu_loss_fails_closed() raises:
    var reg = _standard_registry()
    var context = standard_context()
    var reqs = List[PlannerRequest]()
    reqs.append(PlannerRequest(OP_EMBEDDING_LOOKUP, 128, 0, 4096))
    var plan = build_generation_plan(reg, context, reqs)
    if plan.steps[0].decision.device_class != DEVICE_CPU:
        raise Error("embedding lookup not on CPU pre-failure")
    # With the CPU gone, embedding lookup has no survivor:
    # plan_op returns DEVICE_NONE and the re-plan fails closed.
    var rr = replan_remaining(
        reg, context, plan, 0, DEVICE_CPU, "CPU_FAULT"
    )
    if rr.outcome != REPLAN_FAILED_CLOSED:
        raise Error("CPU-loss re-plan did not fail closed")
    if len(rr.steps) != 0:
        raise Error("failed-closed re-plan still handed out steps")
    if "no survivor can take step 0" not in rr.reason:
        raise Error("fail-closed reason does not name the step")
    var drill = run_failure_drill(
        reg, context, reqs, 99, 0, DEVICE_CPU, "CPU_FAULT"
    )
    if drill.outcome != REPLAN_FAILED_CLOSED:
        raise Error("CPU drill did not fail closed")
    if len(drill.tokens) != 0:
        raise Error("failed-closed drill committed tokens")


def test_replan_second_failure_fails_closed() raises:
    var reg = _standard_registry()
    var context = standard_context()
    var drill = run_failure_drill(
        reg, context, _mixed_requests(), 4242, 2, DEVICE_GPU,
        "VK_ERROR_DEVICE_LOST", 4, DEVICE_CPU, "CPU_FAULT",
    )
    if drill.outcome != REPLAN_FAILED_CLOSED:
        raise Error("second failure did not fail the run closed")
    # Committed prefix intact: exactly the first four control
    # tokens, byte-for-byte (token-for-token).
    var control = control_tokens(4242, 6)
    if len(drill.tokens) != 4:
        raise Error("second-failure prefix length wrong")
    for i in range(4):
        if drill.tokens[i] != control[i]:
            raise Error("second-failure prefix token corrupted")
    if "law 3" not in drill.reason:
        raise Error("second-failure reason lost its law")


def test_replan_edges_and_summary() raises:
    var reg = _standard_registry()
    var context = standard_context()
    var plan = build_generation_plan(reg, context, _mixed_requests())
    var done = replan_remaining(
        reg, context, plan, 6, DEVICE_GPU, "VK_ERROR_DEVICE_LOST"
    )
    if done.outcome != REPLAN_NO_REMAINING:
        raise Error("failure after final commit not NO_REMAINING")
    var bad = replan_remaining(
        reg, context, plan, 7, DEVICE_GPU, "VK_ERROR_DEVICE_LOST"
    )
    if bad.outcome != REPLAN_FAILED_CLOSED:
        raise Error("invalid completed count did not fail closed")
    # Survivor registry: only the failed device changes.
    var survivors = survivor_registry(reg, DEVICE_NPU)
    if survivors.xrt.is_available():
        raise Error("survivor registry still offers the failed NPU")
    if not survivors.vulkan.is_available():
        raise Error("survivor registry lost the surviving GPU")
    if not survivors.cpu.is_available():
        raise Error("survivor registry lost the surviving CPU")
    # A mis-targeted drill (step not on the named device)
    # fails closed instead of silently passing.
    var miss = run_failure_drill(
        reg, context, _mixed_requests(), 1, 3, DEVICE_GPU,
        "VK_ERROR_DEVICE_LOST",
    )
    if miss.outcome != REPLAN_FAILED_CLOSED:
        raise Error("mis-targeted drill did not fail closed")
    if "A-103" not in replan_summary():
        raise Error("re-plan summary lost its slice mark")
    # The original plan is untouched by re-planning (prefix
    # law): step 0 still carries its original GPU decision.
    var again = plan_op(
        reg, context, PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024)
    )
    if again.device_class != DEVICE_GPU:
        raise Error("original registry was mutated by re-planning")


def main() raises:
    test_replan_gpu_loss_onto_survivors()
    test_replan_npu_loss_uses_survivors()
    test_replan_drill_gpu_loss_completes_exact()
    test_replan_drill_npu_loss_completes_exact()
    test_replan_cpu_loss_fails_closed()
    test_replan_second_failure_fails_closed()
    test_replan_edges_and_summary()
    print("A103_CHECK 7/7")
