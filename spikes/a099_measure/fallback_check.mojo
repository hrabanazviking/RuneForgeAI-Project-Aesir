# A-099 fallback check (team-26 spike driver, not an E-MASTER case).
# Exercises the A-099 fallback contract in aesir_engine/core/npu_offload.mojo:
# every post-selection NPU failure mode resolves to CPU with a loud
# FALLBACK_<NAME> reason, and the pre-selection dispatch fallbacks from
# A-095 still hold. Run with:
#   pixi run mojo run -I aesir_engine spikes/a099_measure/fallback_check.mojo
from core.mimir_well import NPUBackendType
from core.npu_offload import (
    NPUFailure,
    npu_fallback_decision,
    npu_fallback_log_line,
    npu_offload_dispatch,
    npu_offload_log_line,
)


def check_failure(label: String, code: Int, want_name: String) raises:
    var f = NPUFailure(code)
    var d = npu_fallback_decision(f, 128 * 1024 * 1024)
    print(npu_fallback_log_line(128, 1024, 1024, f, d))
    if f.name() != want_name:
        raise Error("fallback_check " + label + ": name " + f.name())
    if d.selected != "CPU" or d.reason != "FALLBACK_" + want_name:
        raise Error(
            "fallback_check "
            + label
            + ": got "
            + d.selected
            + "/"
            + d.reason
            + " want CPU/FALLBACK_"
            + want_name
        )


def check_dispatch(
    label: String,
    m: Int,
    k: Int,
    n: Int,
    flag: Bool,
    backend: NPUBackendType,
    want_reason: String,
) raises:
    var d = npu_offload_dispatch(m, k, n, flag, backend)
    print(npu_offload_log_line(m, k, n, flag, d))
    if d.selected != "CPU" or d.reason != want_reason:
        raise Error(
            "fallback_check dispatch "
            + label
            + ": got "
            + d.selected
            + "/"
            + d.reason
            + " want CPU/"
            + want_reason
        )


def main() raises:
    # Post-selection failure taxonomy: every mode degrades to CPU.
    check_failure("device_absent", NPUFailure.DEVICE_ABSENT, "DEVICE_ABSENT")
    check_failure(
        "xclbin_load", NPUFailure.XCLBIN_LOAD_FAILED, "XCLBIN_LOAD_FAILED"
    )
    check_failure("instr_load", NPUFailure.INSTR_LOAD_FAILED, "INSTR_LOAD_FAILED")
    check_failure("run_failed", NPUFailure.KERNEL_RUN_FAILED, "KERNEL_RUN_FAILED")
    check_failure("timeout", NPUFailure.KERNEL_TIMEOUT, "KERNEL_TIMEOUT")
    check_failure("mismatch", NPUFailure.OUTPUT_MISMATCH, "OUTPUT_MISMATCH")
    check_failure("unknown_named", NPUFailure.UNKNOWN, "UNKNOWN")
    # An out-of-taxonomy code still degrades (never propagates).
    check_failure("unknown_raw", 99, "UNKNOWN")
    # Pre-selection dispatch fallbacks (A-095) still hold under A-099.
    var xdna = NPUBackendType(NPUBackendType.AMD_XDNA)
    var neon = NPUBackendType(NPUBackendType.ARM_NEON)
    check_dispatch("flag_off", 128, 1024, 1024, False, xdna, "FLAG_DISABLED")
    check_dispatch(
        "wrong_backend", 128, 1024, 1024, True, neon, "BACKEND_NOT_XDNA"
    )
    check_dispatch("below_m", 32, 1024, 1024, True, xdna, "BELOW_M_BAND")
    check_dispatch("below_macs", 64, 32, 32, True, xdna, "BELOW_MAC_FLOOR")
    print("FALLBACK_CHECK PASS 8/8 failures degrade + 4/4 dispatch fallbacks")
