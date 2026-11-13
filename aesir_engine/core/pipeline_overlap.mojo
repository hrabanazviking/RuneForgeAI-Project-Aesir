"""
A-101 - Pipeline overlap: heterogeneous scheduling model.

Roadmap A-101: Prefill (GPU) in parallel with sampling prep (CPU)
in parallel with NPU assist where enabled. Acceptance: timeline
trace showing real overlap; end-to-end latency delta filed.

This module is the in-engine model of that pipeline. It decides
which legs a step runs (the NPU assist leg is gated by the banked
A-095 registry dispatch and degrades per the A-099 fallback
contract), and it owns the timeline arithmetic the acceptance
rests on: per-leg start/end timestamps on one monotonic clock,
pairwise overlap intervals, overlapped wall vs serial wall, and
the end-to-end delta. A claim of overlap is only made when every
pair of legs shares a positive interval AND the overlapped wall
beats the serial wall; leg durations alone never prove overlap.

Device execution is proven by the host harness
spikes/a101_pipeline/pipeline_probe.cpp, which mirrors this
timeline model exactly: NPU leg = A-094 p128 prefill projection
GEMM on XDNA 2 (async XRT run, waiter thread timestamps fence
completion), GPU leg = Vulkan prefill-shaped GEMV reps on the
Radeon 8060S (submit on the main thread, waiter thread timestamps
fence completion), CPU leg = sampling prep over previous-token
logits on the main thread. Filed measurements:
docs/bench/A101_PIPELINE_OVERLAP.md and hidden_files/a101/.

A-100 dependency (honest status): the placement planner slice
A-100 builds in parallel and had NOT landed when A-101 ran. This
module therefore takes its placement inputs from the banked
surfaces only - the A-017 device policy via the A-095 registry
entry in core/npu_offload.mojo and the A-086 winner registry
(Vulkan primary). When A-100 banks, the planner can feed the
same plan struct; no planner code is duplicated here.
"""

from .mimir_well import NPUBackendType
from .npu_offload import npu_offload_dispatch


struct PipelineLeg(Copyable, ImplicitlyCopyable):
    """One timed leg of a pipeline step (microseconds, one clock)."""

    var name: String  # gpu_prefill / cpu_sampling_prep / npu_assist
    var start_us: Int
    var end_us: Int

    def __init__(out self, name: String, start_us: Int, end_us: Int):
        self.name = name
        self.start_us = start_us
        self.end_us = end_us

    def __copyinit__(out self, existing: Self):
        self.name = existing.name
        self.start_us = existing.start_us
        self.end_us = existing.end_us

    def duration_us(self) -> Int:
        return self.end_us - self.start_us


def leg_overlap_us(a: PipelineLeg, b: PipelineLeg) -> Int:
    """Shared interval of two legs; zero when they do not overlap."""
    var s = a.start_us
    if b.start_us > s:
        s = b.start_us
    var e = a.end_us
    if b.end_us < e:
        e = b.end_us
    if e > s:
        return e - s
    return 0


def pipeline_wall_us(a: PipelineLeg, b: PipelineLeg, c: PipelineLeg) -> Int:
    """Wall of a three-leg step: latest end minus earliest start."""
    var s = a.start_us
    if b.start_us < s:
        s = b.start_us
    if c.start_us < s:
        s = c.start_us
    var e = a.end_us
    if b.end_us > e:
        e = b.end_us
    if c.end_us > e:
        e = c.end_us
    return e - s


def serial_wall_us(a: PipelineLeg, b: PipelineLeg, c: PipelineLeg) -> Int:
    """Serial wall: the sum of the three leg durations."""
    return a.duration_us() + b.duration_us() + c.duration_us()


def e2e_delta_us(serial_us: Int, overlap_us: Int) -> Int:
    """End-to-end latency delta: serial wall minus overlapped wall."""
    return serial_us - overlap_us


def overlap_proven(a: PipelineLeg, b: PipelineLeg, c: PipelineLeg) -> Bool:
    """Acceptance predicate: every pair overlaps by a positive
    interval AND the overlapped wall beats the serial wall."""
    if leg_overlap_us(a, b) <= 0:
        return False
    if leg_overlap_us(b, c) <= 0:
        return False
    if leg_overlap_us(a, c) <= 0:
        return False
    return e2e_delta_us(serial_wall_us(a, b, c), pipeline_wall_us(a, b, c)) > 0


def leg_trace_line(leg: PipelineLeg) -> String:
    """The one-line timeline trace record for one leg."""
    return (
        "TRACE leg="
        + leg.name
        + " start_us="
        + String(leg.start_us)
        + " end_us="
        + String(leg.end_us)
        + " dur_us="
        + String(leg.duration_us())
    )


struct PipelinePlan(Copyable, ImplicitlyCopyable):
    """Which legs one pipeline step runs, and why."""

    var gpu_prefill: Bool  # always on: prefill is the GPU leg (A-068/A-086)
    var cpu_sampling_prep: Bool  # always on: prep is free CPU work
    var npu_assist: Bool  # only when the A-095 dispatch selects XDNA
    var assist_reason: String  # A-095 reason, or the A-099 fallback reason

    def __init__(
        out self,
        gpu_prefill: Bool,
        cpu_sampling_prep: Bool,
        npu_assist: Bool,
        assist_reason: String,
    ):
        self.gpu_prefill = gpu_prefill
        self.cpu_sampling_prep = cpu_sampling_prep
        self.npu_assist = npu_assist
        self.assist_reason = assist_reason

    def __copyinit__(out self, existing: Self):
        self.gpu_prefill = existing.gpu_prefill
        self.cpu_sampling_prep = existing.cpu_sampling_prep
        self.npu_assist = existing.npu_assist
        self.assist_reason = existing.assist_reason

    def leg_count(self) -> Int:
        var n = 0
        if self.gpu_prefill:
            n += 1
        if self.cpu_sampling_prep:
            n += 1
        if self.npu_assist:
            n += 1
        return n


def pipeline_plan(
    m: Int, k: Int, n: Int, flag_enabled: Bool, backend: NPUBackendType
) -> PipelinePlan:
    """Plan one overlapped step for a prefill projection of MxKxN.

    GPU prefill and CPU sampling prep always run. The NPU assist
    leg runs only where enabled: the decision is the banked A-095
    registry dispatch, so flag-off, non-XDNA backend, small M and
    small MAC shapes all plan a two-leg pipeline instead, and any
    post-selection NPU failure degrades the same way per A-099
    (the assist leg is dropped, never propagated as an error).
    """
    var decision = npu_offload_dispatch(m, k, n, flag_enabled, backend)
    if decision.selected == "AMD_XDNA":
        return PipelinePlan(True, True, True, decision.reason)
    return PipelinePlan(True, True, False, decision.reason)


def pipeline_plan_log_line(m: Int, k: Int, n: Int, plan: PipelinePlan) -> String:
    """The one-line plan log record (shape, legs, assist reason)."""
    var assist_word = String("off")
    if plan.npu_assist:
        assist_word = String("on")
    return (
        "PLAN op=pipeline_overlap shape="
        + String(m)
        + "x"
        + String(k)
        + "x"
        + String(n)
        + " legs="
        + String(plan.leg_count())
        + " npu_assist="
        + assist_word
        + " assist_reason="
        + plan.assist_reason
    )
