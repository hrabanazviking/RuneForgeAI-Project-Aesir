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
        print("AMD ROCm HIP (libamdhip64.so/libhipblas.so): AVAILABLE (" + String(count) + " devices)")
        if count <= 0:
            raise Error("AMDGate reported available but device count is 0")
    else:
        print("AMD ROCm HIP: UNAVAILABLE on current host platform (Fail-Closed)")
        if count != 0:
            raise Error("AMDGate reported unavailable but device count is non-zero")

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

    if not AMDGate.is_available():
        var rejected = False
        try:
            gemm_f16_gpu(A, B, C, GPURealmType(GPURealmType.AMD_ROCM_HIP))
        except error:
            rejected = True
            var err_str = String(error)
            if "AMD ROCm HIP GPU execution error" not in err_str and "libamdhip64.so" not in err_str:
                raise Error("AMD gateway rejection omitted stable error text: " + err_str)
        if not rejected:
            raise Error("AMD gateway failed to reject execution on host without HIP runtime")

    print("AMD ROCm HIP realm error gateways: PASS")
