# tests/test_amd_realm.mojo
# Verification of AMD ROCm / HIP GPU Acceleration Gateway & Memory Management

from core.amd_gate import AMDGate
from core.mimir_well import MimirWell, RuneTensor, GPURealmType, f16, Scalar
from core.compute import gemm_f16_gpu

def test_amd_gate_availability() raises:
    print("--- Testing AMDGate driver & runtime availability ---")
    var avail = AMDGate.is_available()
    var count = AMDGate.get_device_count()

    if avail:
        print("AMD HIP runtime library: LOADABLE; physical device count unverified")
    else:
        print("AMD ROCm HIP: UNAVAILABLE on current host platform (Fail-Closed)")
    if count != 0:
        raise Error("AMDGate fabricated a physical device count")

    print("AMDGate driver & runtime availability: PASS")


def test_amd_gemm_dispatch_bounds() raises:
    print("--- Testing gemm_f16_gpu AMD shape mismatch handling ---")
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(4 * 32)
    var A = RuneTensor[f16](4, 32, a_ptr)
    var b_ptr = well.allocate(4 * 16)
    var B = RuneTensor[f16](4, 16, b_ptr)
    var c_ptr = well.allocate(4 * 4)
    var C = RuneTensor[f16](4, 4, c_ptr)

    var shape_rejected = False
    try:
        AMDGate.launch_gemm_amd(A, B, C)
    except error:
        shape_rejected = True
        if "GEMM shape mismatch" not in String(error):
            raise Error("AMDGate shape mismatch check produced unexpected error text: " + String(error))

    if not shape_rejected:
        raise Error("AMDGate failed to reject mismatched GEMM shapes")

    print("gemm_f16_gpu AMD shape mismatch handling: PASS")


def test_amd_realm_unsupported_gateways() raises:
    print("--- Testing AMD ROCm HIP realm error gateways ---")
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(4 * 32)
    var A = RuneTensor[f16](4, 32, a_ptr)
    var b_ptr = well.allocate(4 * 32)
    var B = RuneTensor[f16](4, 32, b_ptr)
    var c_ptr = well.allocate(4 * 4)
    var C = RuneTensor[f16](4, 4, c_ptr)

    var rejected = False
    try:
        AMDGate.launch_gemm_amd(A, B, C)
    except error:
        rejected = True
        if "not implemented" not in String(error):
            raise Error("AMD gateway rejection omitted stable error text: " + String(error))
    if not rejected:
        raise Error("AMD gateway reported execution without a physical kernel")

    print("AMD ROCm HIP realm error gateways: PASS")
