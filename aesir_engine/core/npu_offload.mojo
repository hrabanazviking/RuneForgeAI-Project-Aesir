"""
A-095 - NPU offload registry entry: prefill projection GEMM on AMD XDNA.

The registry decision for ONE op class: prefill projection GEMM (the QKV /
out-projection and MLP gate/up/down projections whose row count M is the
prompt length), per the banked A-094 candidate table
(docs/bench/A094_NPU_SHAPED_OPS.md). Measured law behind the band:

  - one warm NPU dispatch costs a ~93 us floor (launch + DMA, not math);
  - cubic i16 GEMM crosses the in-program CPU oracle between 32^3 (NPU
    loses, 0.29x) and 64^3 (NPU wins, 1.88x);
  - the projection proxy 128x1024x1024 measured 99x vs the oracle CPU;
  - decode GEMV (M = 1) is not expressible in the stood-up design
    (tile M = 32) and is never dispatched here.

So a dispatch is eligible only when the feature flag is ON, the registry
backend is AMD_XDNA, M >= 64, and the dispatch carries >= ~0.1M MACs.
Every other case selects CPU with a named fallback reason - the existing
CPU path is then used unchanged. The flag is the AesirEngine facade's
enable_npu (default False, config-owned by the facade per the GPU-realm
law); with the flag OFF this function is never consulted by a live path
and engine behavior is bit-identical to before this slice.

This module decides and logs; it does not execute. Device execution for
the selected shapes is proven by the XRT host runner
aesir_engine/npu_prefill_offload.cpp (resident hw context, sentinel +
ert_cmd_state evidence, exact compare vs the CPU oracle), which mirrors
this decision function exactly. In-engine gemm_f16_npu stays fail-closed
(GPU-002, H011) until a future slice bridges XRT into the engine itself:
an XDNA selection here never silently claims in-engine NPU execution.
"""

from .mimir_well import NPUBackendType


struct NPUOffloadBand:
    """Shape band for the A-095 registry entry (A-094 measured table)."""

    comptime MIN_M = 64  # prefill rows; below this the dispatch floor wins
    comptime MIN_MACS = 100000  # ~0.1M MACs per dispatch (A-094 threshold)


struct NPUOffloadDecision(Copyable, ImplicitlyCopyable):
    """One registry dispatch decision for a prefill projection GEMM."""

    var selected: String  # "AMD_XDNA" or "CPU"
    var reason: String  # OK_XDNA / FLAG_DISABLED / BACKEND_NOT_XDNA /
    #                     BELOW_M_BAND / BELOW_MAC_FLOOR
    var macs: Int

    def __init__(out self, selected: String, reason: String, macs: Int):
        self.selected = selected
        self.reason = reason
        self.macs = macs

    def __copyinit__(out self, existing: Self):
        self.selected = existing.selected
        self.reason = existing.reason
        self.macs = existing.macs


def npu_offload_dispatch(
    m: Int, k: Int, n: Int, flag_enabled: Bool, backend: NPUBackendType
) -> NPUOffloadDecision:
    """Registry dispatch for a prefill projection GEMM of shape MxKxN.

    flag_enabled is the facade's enable_npu (default False). backend is
    the facade's target_backend. Returns the selected backend and the
    reason; CPU is the fallback for every non-eligible case.
    """
    var macs = m * k * n
    if not flag_enabled:
        return NPUOffloadDecision("CPU", "FLAG_DISABLED", macs)
    if backend.value != NPUBackendType.AMD_XDNA:
        return NPUOffloadDecision("CPU", "BACKEND_NOT_XDNA", macs)
    if m < NPUOffloadBand.MIN_M:
        return NPUOffloadDecision("CPU", "BELOW_M_BAND", macs)
    if macs < NPUOffloadBand.MIN_MACS:
        return NPUOffloadDecision("CPU", "BELOW_MAC_FLOOR", macs)
    return NPUOffloadDecision("AMD_XDNA", "OK_XDNA", macs)


def npu_offload_log_line(
    m: Int, k: Int, n: Int, flag_enabled: Bool, decision: NPUOffloadDecision
) -> String:
    """The one-line dispatch log record (op, shape, choice, reason)."""
    var flag_word = String("off")
    if flag_enabled:
        flag_word = String("on")
    return (
        "DISPATCH op=prefill_projection shape="
        + String(m)
        + "x"
        + String(k)
        + "x"
        + String(n)
        + " selected="
        + decision.selected
        + " reason="
        + decision.reason
        + " flag="
        + flag_word
        + " macs="
        + String(decision.macs)
    )


# ---- A-099: NPU fallback contract ------------------------------------
# Roadmap A-099: any NPU failure degrades to GPU/CPU - silent to the
# user, loud in the logs. This section is the contract half that pairs
# with the A-095 dispatch above: the dispatch reasons (FLAG_DISABLED /
# BACKEND_NOT_XDNA / BELOW_M_BAND / BELOW_MAC_FLOOR) already select CPU
# before any device work starts; the failure taxonomy below covers
# everything that can go wrong AFTER an AMD_XDNA selection, once device
# execution is attempted (host runner today, the future in-engine
# bridge tomorrow). Every failure - known or not - resolves to a CPU
# selection with reason FALLBACK_<NAME>; there is no path in this
# contract that propagates an NPU error to the caller or returns an
# unverified NPU result. The host runner
# (aesir_engine/npu_prefill_offload.cpp) mirrors this taxonomy exactly
# and proves each mode by fault injection (hidden_files/a099/): the
# fallback output is the CPU path's output, verified exact vs the CPU
# oracle before it is accepted - a fallback that cannot verify fails
# closed instead of answering wrong.


struct NPUFailure(Copyable, ImplicitlyCopyable):
    """One post-selection NPU failure mode (A-099 taxonomy)."""

    comptime DEVICE_ABSENT = 0  # no XDNA device / device open failed
    comptime XCLBIN_LOAD_FAILED = 1  # xclbin load/register/context failed
    comptime INSTR_LOAD_FAILED = 2  # AIE instruction stream unreadable
    comptime KERNEL_RUN_FAILED = 3  # run ended in an error state
    comptime KERNEL_TIMEOUT = 4  # run did not complete in the bound
    comptime OUTPUT_MISMATCH = 5  # NPU output != CPU oracle (incl. sentinel)
    comptime UNKNOWN = 6  # anything else; still degrades, never propagates

    var value: Int

    def __init__(out self, value: Int = 6):
        self.value = value

    def __copyinit__(out self, existing: Self):
        self.value = existing.value

    def name(self) -> String:
        if self.value == 0:
            return "DEVICE_ABSENT"
        elif self.value == 1:
            return "XCLBIN_LOAD_FAILED"
        elif self.value == 2:
            return "INSTR_LOAD_FAILED"
        elif self.value == 3:
            return "KERNEL_RUN_FAILED"
        elif self.value == 4:
            return "KERNEL_TIMEOUT"
        elif self.value == 5:
            return "OUTPUT_MISMATCH"
        return "UNKNOWN"


def npu_fallback_decision(failure: NPUFailure, macs: Int) -> NPUOffloadDecision:
    """The A-099 contract resolution: EVERY NPU failure selects CPU.

    The reason keeps the failure loud (FALLBACK_<NAME>) while the
    selection keeps the user silent - the CPU path then runs unchanged
    and its output is verified exact vs the CPU oracle by the executor.
    """
    return NPUOffloadDecision("CPU", "FALLBACK_" + failure.name(), macs)


def npu_fallback_log_line(
    m: Int, k: Int, n: Int, failure: NPUFailure, decision: NPUOffloadDecision
) -> String:
    """The one-line fallback log record (op, shape, failure, choice)."""
    return (
        "FALLBACK op=prefill_projection shape="
        + String(m)
        + "x"
        + String(k)
        + "x"
        + String(n)
        + " failure="
        + failure.name()
        + " selected="
        + decision.selected
        + " reason="
        + decision.reason
        + " macs="
        + String(decision.macs)
    )
