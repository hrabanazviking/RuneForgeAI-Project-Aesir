# core/part_iv_gate.mojo
# A-108: Part IV gate -- the filed verdict table for every
# Part IV experiment (A-082..A-107) as data, plus the gate's
# planner decision. Built ONLY from banked evidence
# (A-082..A-105 banked at 9f75ab0d, 105 of 216); A-106 and
# A-107 were still building in parallel at gate time and are
# filed IN_FLIGHT -- no result is claimed for them.
#
# PLANNER DECISION (honest scope, not default-on): the A-100
# planner is NOT wired into the live generation dispatch --
# no generation path calls plan_op (grep-provable at this
# commit). It IS the decision authority for the placement-
# consuming surfaces that exist: doctor (planner lines +
# summary), A-103 failure re-planning, and the A-102/A-104/
# A-105 policies built on its measured tables. The gate
# therefore files the planner as SCOPED to where it wins:
# - GPU/Vulkan for prefill + decode GEMV (A-098: 67.5 us,
#   51.20 GFLOP/s/W at 128x1024x1024; A-085 bake-off medians
#   Vulkan 0.175-0.454 ms vs HIP 1.76-5.20 ms per call).
# - NPU only inside the A-094/A-095 band (prefill GEMM
#   M >= 64 and >= ~0.1M MACs, proven context) and only for
#   power-capped or overlapped work (A-096 overlap benefit
#   ~4.2 ms fully hidden; A-098 NPU 22.1 W vs GPU 77.7 W
#   package) -- never for decode GEMV, embedding lookup, or
#   sampling (A-094/A-097 measured NOT FIT).
# - CPU for sampling (A-097: 19.9 us vs NPU 104.8 us at
#   V=32768), below-floor shapes, and every fallback
#   (A-099 contract: FALLBACK_<NAME> logged).
# - HIP is never placed (A-085/A-086: parked probe-only).
# Default-on in generation dispatch is a named future road:
# it requires a slice that wires plan_op into the dispatch
# path and re-measures end-to-end; this gate does not claim
# it. Full record: docs/bench/A108_PART_IV_GATE.md and
# CAPABILITY_LEDGER.md section 25 (Z13-P4-*).

comptime VERDICT_POSITIVE = "POSITIVE"
comptime VERDICT_NEGATIVE = "NEGATIVE"
comptime VERDICT_SCOPED = "SCOPED"
comptime VERDICT_IN_FLIGHT = "IN_FLIGHT"


struct PartIvVerdict(Copyable, ImplicitlyCopyable):
    var slice_id: String
    var verdict: String
    var headline: String
    var evidence: String

    def __init__(
        out self,
        slice_id: String,
        verdict: String,
        headline: String,
        evidence: String,
    ):
        self.slice_id = slice_id
        self.verdict = verdict
        self.headline = headline
        self.evidence = evidence


def part_iv_verdicts() -> List[PartIvVerdict]:
    var rows = List[PartIvVerdict]()
    rows.append(PartIvVerdict("A-082", VERDICT_POSITIVE, "HIP Q8_0 GEMV executes on gfx1151 with CPU-oracle parity", "core/hip_gemv.mojo; dispatch-evidence counter"))
    rows.append(PartIvVerdict("A-083", VERDICT_POSITIVE, "HIP Q4_K GEMV executes on gfx1151, in-kernel decode byte-matches the oracle decode", "core/hip_q4k_gemv.mojo"))
    rows.append(PartIvVerdict("A-084", VERDICT_POSITIVE, "HIP RMSNorm/RoPE/GQA attention at parity per op", "core/hip_attention_norms.mojo"))
    rows.append(PartIvVerdict("A-085", VERDICT_SCOPED, "Bake-off: Vulkan PRIMARY, HIP PARKED probe-only with 4 re-open criteria", "docs/bench/A085_BAKEOFF.md"))
    rows.append(PartIvVerdict("A-086", VERDICT_POSITIVE, "Winner integrated: registry, doctor and placement reflect the A-085 verdict; probe-only never placed", "core/gpu_winner.mojo"))
    rows.append(PartIvVerdict("A-087", VERDICT_POSITIVE, "ROCm install scripted, pinned (9 packages) and idempotent-convergent", "scripts/install_rocm_z13.sh; core/rocm_pin.mojo"))
    rows.append(PartIvVerdict("A-088", VERDICT_NEGATIVE, "HIP managed memory does NOT beat A-064 Vulkan residency for static weights; residency stays", "docs/bench/A088_HIP_ZERO_COPY_RESIDENCY.md"))
    rows.append(PartIvVerdict("A-089", VERDICT_POSITIVE, "33 HIP error codes mapped into the taxonomy; gateways rewired per-code", "core/hip_errors.mojo"))
    rows.append(PartIvVerdict("A-090", VERDICT_NEGATIVE, "No HIP soak run and none claimed: HIP not integrated as a primary path; instability evidence filed as the verdict", "docs/bench/A090_HIP_INSTABILITY_VERDICT.md"))
    rows.append(PartIvVerdict("A-091", VERDICT_POSITIVE, "XDNA 2 census filed with every claim marked OBSERVED vs DOCUMENTED", "docs/bench/A091_XDNA2_CENSUS.md"))
    rows.append(PartIvVerdict("A-092", VERDICT_POSITIVE, "First AIE kernel execution: 64x64x64 i16 matmul exact vs CPU oracle, device-execution proven", "spikes/a092_npu_hello; npu_matmul_probe.cpp"))
    rows.append(PartIvVerdict("A-093", VERDICT_POSITIVE, "NPU BO shared via dma-buf and consumed byte-exact both directions; type-1 export EOPNOTSUPP filed", "aesir_engine/npu_share_probe.c"))
    rows.append(PartIvVerdict("A-094", VERDICT_SCOPED, "NPU FIT only for prefill projection GEMM M >= 64; decode GEMV, embedding and standalone norms NOT FIT", "docs/bench/A094_NPU_SHAPED_OPS.md"))
    rows.append(PartIvVerdict("A-095", VERDICT_SCOPED, "NPU offload #1 behind the registry in the A-094 band: NEUTRAL-WITH-VALUE, flag-gated with named fallbacks", "core/npu_offload.mojo"))
    rows.append(PartIvVerdict("A-096", VERDICT_POSITIVE, "NPU prefill chunk fully hidden inside the GPU decode shadow (~4.2 ms median benefit, 3 runs)", "docs/bench/A096_NPU_PREFILL_ASSIST.md"))
    rows.append(PartIvVerdict("A-097", VERDICT_NEGATIVE, "NPU sampler NOT FIT: argmax loses to a plain CPU scan at both vocab sizes", "docs/bench/A097_NPU_SAMPLER.md"))
    rows.append(PartIvVerdict("A-098", VERDICT_SCOPED, "At the prefill shape the GPU wins latency AND perf-per-watt; NPU value is its 22.1 W power cap and overlap", "docs/bench/A098_NPU_POWER_PROFILE.md"))
    rows.append(PartIvVerdict("A-099", VERDICT_POSITIVE, "NPU fallback contract proven by fault injection: every failure degrades to CPU, loud in the logs", "core/npu_offload.mojo"))
    rows.append(PartIvVerdict("A-100", VERDICT_SCOPED, "Placement planner decides all 12 standard fixtures from measured tables; scoped per the A-108 gate decision, not default-on in generation dispatch", "core/placement_planner.mojo; docs/bench/A100_PLACEMENT_PLANNER.md"))
    rows.append(PartIvVerdict("A-101", VERDICT_POSITIVE, "Pipeline overlap real: overlapped wall ~10.0 ms vs serial ~19.0 ms median on device", "core/pipeline_overlap.mojo; docs/bench/A101_PIPELINE_OVERLAP.md"))
    rows.append(PartIvVerdict("A-102", VERDICT_POSITIVE, "Spillover policy: oversized 8B run places GPU 6 layers / CPU spill 28 layers, log reproducible", "core/spillover_policy.mojo; docs/bench/A102_SPILLOVER_POLICY.md"))
    rows.append(PartIvVerdict("A-103", VERDICT_POSITIVE, "Mid-run device failure re-plans remaining work onto survivors; injected drills pass, tokens exact vs control", "core/failure_replan.mojo; docs/bench/A103_FAILURE_REPLAN.md"))
    rows.append(PartIvVerdict("A-104", VERDICT_POSITIVE, "Big-model placement: largest sha-pinned fixture runs with a GPU/CPU layer split and full accounting", "core/big_model_placement.mojo; docs/bench/A104_BIG_MODEL_PLACEMENT.md"))
    rows.append(PartIvVerdict("A-105", VERDICT_POSITIVE, "Two-model fairness: no starvation, per-model latency bounds held on the real device (Jain 0.759 at 1:1, 0.926 at 2:1)", "core/fair_scheduler.mojo; hidden_files/A105_LEDGER.md"))
    rows.append(PartIvVerdict("A-106", VERDICT_IN_FLIGHT, "Scheduler telemetry: building in parallel (team-27) at gate time -- NOT banked, no result claimed", "WAVE_PLAN.md assignment; gate re-check owed at banking"))
    rows.append(PartIvVerdict("A-107", VERDICT_IN_FLIGHT, "Placement regression battery: building in parallel (team-25) at gate time -- NOT banked, no result claimed", "WAVE_PLAN.md assignment; gate re-check owed at banking"))
    return rows^


def part_iv_gate_summary() -> String:
    return String(
        "A-108 Part IV gate: planner HONESTLY SCOPED (not"
        " default-on in generation dispatch); 26 verdicts"
        " filed for A-082..A-107 (24 banked, A-106/A-107"
        " IN_FLIGHT); HIP parked probe-only, Vulkan primary,"
        " NPU scoped to the A-094 band"
    )
