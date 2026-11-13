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
