# A-095 dispatch check (team-25 spike driver, not an E-MASTER case).
# Exercises aesir_engine/core/npu_offload.mojo against the A-094 band:
# run with: pixi run mojo run -I aesir_engine spikes/a095_measure/dispatch_check.mojo
from core.mimir_well import NPUBackendType
from core.npu_offload import npu_offload_dispatch, npu_offload_log_line


def check(
    label: String,
    m: Int,
    k: Int,
    n: Int,
    flag: Bool,
    backend: NPUBackendType,
    want_selected: String,
    want_reason: String,
) raises:
    var d = npu_offload_dispatch(m, k, n, flag, backend)
    print(npu_offload_log_line(m, k, n, flag, d))
    if d.selected != want_selected or d.reason != want_reason:
        raise Error(
            "dispatch_check "
            + label
            + ": got "
            + d.selected
            + "/"
            + d.reason
            + " want "
            + want_selected
            + "/"
            + want_reason
        )


def main() raises:
    var xdna = NPUBackendType(NPUBackendType.AMD_XDNA)
    print("AMD_XDNA value =", xdna.value, " name =", xdna.name())
    if xdna.value != 7 or xdna.name() != "AMD_XDNA":
        raise Error("dispatch_check: AMD_XDNA discriminant mismatch")
    var neon = NPUBackendType(NPUBackendType.ARM_NEON)
    # Flag OFF: production default - CPU, whatever the shape/backend.
    check("flag_off", 128, 1024, 1024, False, xdna, "CPU", "FLAG_DISABLED")
    # Flag ON + XDNA + projection shape: the A-094 winner dispatches.
    check("winner", 128, 1024, 1024, True, xdna, "AMD_XDNA", "OK_XDNA")
    # Band floor shape 64^3 (262144 MACs) still dispatches (A-094: 1.88x).
    check("band_floor", 64, 64, 64, True, xdna, "AMD_XDNA", "OK_XDNA")
    # M below 64: decode-class rows never dispatch (A-094 floor law).
    check("below_m", 32, 1024, 1024, True, xdna, "CPU", "BELOW_M_BAND")
    # M in band but under the ~0.1M MAC floor: dispatch cannot repay.
    check("below_macs", 64, 32, 32, True, xdna, "CPU", "BELOW_MAC_FLOOR")
    # Wrong backend: registry entry is XDNA-only.
    check("wrong_backend", 128, 1024, 1024, True, neon, "CPU", "BACKEND_NOT_XDNA")
    print("DISPATCH_CHECK PASS 6/6 decisions + discriminant")
