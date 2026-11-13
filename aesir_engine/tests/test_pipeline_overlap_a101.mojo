# tests/test_pipeline_overlap_a101.mojo
# A-101: Pipeline overlap. The timeline model in
# core/pipeline_overlap.mojo must compute pairwise overlaps,
# walls and the end-to-end delta exactly; the plan must gate the
# NPU assist leg on the banked A-095 dispatch (A-099 degradation);
# and the filed device trace from the A-101 harness (run 1, rep 0
# plus the 21-rep medians) must satisfy the acceptance predicate
# when replayed through the model.

from core.mimir_well import NPUBackendType
from core.pipeline_overlap import (
    PipelineLeg,
    e2e_delta_us,
    leg_overlap_us,
    leg_trace_line,
    overlap_proven,
    pipeline_plan,
    pipeline_plan_log_line,
    pipeline_wall_us,
    serial_wall_us,
)


def test_pipeline_overlap_pairwise_math() raises:
    print("--- Testing A-101 pairwise overlap interval math ---")
    var a = PipelineLeg("gpu_prefill", 0, 100)
    var b = PipelineLeg("cpu_sampling_prep", 50, 120)
    if leg_overlap_us(a, b) != 50:
        raise Error("A-101 partial overlap must be 50")
    if leg_overlap_us(b, a) != 50:
        raise Error("A-101 overlap must be symmetric")
    var inner = PipelineLeg("npu_assist", 20, 80)
    if leg_overlap_us(a, inner) != 60:
        raise Error("A-101 containment overlap must be 60")
    var apart = PipelineLeg("npu_assist", 200, 300)
    if leg_overlap_us(a, apart) != 0:
        raise Error("A-101 disjoint legs must overlap 0")
    var touching = PipelineLeg("npu_assist", 100, 200)
    if leg_overlap_us(a, touching) != 0:
        raise Error("A-101 touching endpoints are not overlap")
    print("A-101 pairwise math: PASS")


def test_pipeline_overlap_wall_and_delta() raises:
    print("--- Testing A-101 wall, serial sum and delta ---")
    var gpu = PipelineLeg("gpu_prefill", 40, 5643)
    var cpu = PipelineLeg("cpu_sampling_prep", 222, 10332)
    var npu = PipelineLeg("npu_assist", 0, 2567)
    if pipeline_wall_us(gpu, cpu, npu) != 10332:
        raise Error("A-101 wall must be latest end minus earliest start")
    if serial_wall_us(gpu, cpu, npu) != 5603 + 10110 + 2567:
        raise Error("A-101 serial wall must sum the leg durations")
    if e2e_delta_us(18961, 10079) != 8882:
        raise Error("A-101 delta must be serial minus overlapped")
    if e2e_delta_us(100, 130) != -30:
        raise Error("A-101 delta must go negative when overlap loses")
    print("A-101 wall/delta: PASS")


def test_pipeline_overlap_trace_line() raises:
    print("--- Testing A-101 timeline trace line format ---")
    var leg = PipelineLeg("gpu_prefill", 40, 5643)
    var line = leg_trace_line(leg)
    if line != "TRACE leg=gpu_prefill start_us=40 end_us=5643 dur_us=5603":
        raise Error("A-101 trace line drifted: " + line)
    print("A-101 trace line: PASS")


def test_pipeline_overlap_acceptance() raises:
    print("--- Testing A-101 acceptance predicate ---")
    var gpu = PipelineLeg("gpu_prefill", 40, 5643)
    var cpu = PipelineLeg("cpu_sampling_prep", 222, 10332)
    var npu = PipelineLeg("npu_assist", 0, 2567)
    if not overlap_proven(gpu, cpu, npu):
        raise Error("A-101 the filed overlapped step must prove")
    var s_gpu = PipelineLeg("gpu_prefill", 2500, 7442)
    var s_cpu = PipelineLeg("cpu_sampling_prep", 7442, 18151)
    var s_npu = PipelineLeg("npu_assist", 0, 2500)
    if overlap_proven(s_gpu, s_cpu, s_npu):
        raise Error("A-101 sequential legs must not prove overlap")
    print("A-101 acceptance predicate: PASS")


def test_pipeline_overlap_plan_gating() raises:
    print("--- Testing A-101 plan gating on the A-095 dispatch ---")
    var xdna = NPUBackendType(NPUBackendType.AMD_XDNA)
    var neon = NPUBackendType(NPUBackendType.ARM_NEON)
    var full = pipeline_plan(128, 1024, 1024, True, xdna)
    if not full.npu_assist or full.leg_count() != 3:
        raise Error("A-101 eligible shape must plan 3 legs")
    if full.assist_reason != "OK_XDNA":
        raise Error("A-101 eligible plan reason must be OK_XDNA")
    if not full.gpu_prefill or not full.cpu_sampling_prep:
        raise Error("A-101 GPU and CPU legs are always planned")
    var off = pipeline_plan(128, 1024, 1024, False, xdna)
    if off.npu_assist or off.leg_count() != 2 or off.assist_reason != "FLAG_DISABLED":
        raise Error("A-101 flag off must degrade to 2 legs FLAG_DISABLED")
    var wrong = pipeline_plan(128, 1024, 1024, True, neon)
    if wrong.npu_assist or wrong.assist_reason != "BACKEND_NOT_XDNA":
        raise Error("A-101 non-XDNA backend must degrade")
    var small_m = pipeline_plan(32, 1024, 1024, True, xdna)
    if small_m.npu_assist or small_m.assist_reason != "BELOW_M_BAND":
        raise Error("A-101 M below band must degrade")
    var small_mac = pipeline_plan(64, 10, 10, True, xdna)
    if small_mac.npu_assist or small_mac.assist_reason != "BELOW_MAC_FLOOR":
        raise Error("A-101 MACs below floor must degrade")
    var line = pipeline_plan_log_line(128, 1024, 1024, full)
    if "legs=3" not in line or "npu_assist=on" not in line:
        raise Error("A-101 plan log line lost its fields: " + line)
    print("A-101 plan gating: PASS")


def test_pipeline_overlap_filed_trace() raises:
    print("--- Testing A-101 filed device trace replay ---")
    # Filed run 1 (hidden_files/a101/run1.log): rep-0 timestamps
    # and 21-rep medians from the real XDNA 2 + Radeon 8060S run.
    var gpu = PipelineLeg("gpu_prefill", 40, 5643)
    var cpu = PipelineLeg("cpu_sampling_prep", 222, 10332)
    var npu = PipelineLeg("npu_assist", 0, 2567)
    if leg_overlap_us(npu, gpu) != 2527:
        raise Error("A-101 filed npu/gpu overlap must be 2527")
    if leg_overlap_us(gpu, cpu) != 5421:
        raise Error("A-101 filed gpu/cpu overlap must be 5421")
    if leg_overlap_us(npu, cpu) != 2345:
        raise Error("A-101 filed npu/cpu overlap must be 2345")
    if not overlap_proven(gpu, cpu, npu):
        raise Error("A-101 filed trace must satisfy acceptance")
    if e2e_delta_us(18961, 10079) != 8882:
        raise Error("A-101 filed median delta must be 8882 us")
    print("A-101 filed trace replay: PASS")
