# tests/test_intel_realm.mojo
# Verification of Intel OneAPI Level Zero GPU Acceleration Gateway & Memory Management

from core.intel_gate import IntelGate
from core.mimir_well import MimirWell, RuneTensor, GPURealmType, f16, Scalar
from core.compute import gemm_f16_gpu

def test_intel_gate_availability() raises:
    print("--- Testing IntelGate driver & runtime availability ---")
    var avail = IntelGate.is_available()
    var count = IntelGate.get_device_count()

    if avail:
        print("Intel Level Zero (libze_loader.so/libze_intel_gpu.so): AVAILABLE (" + String(count) + " devices)")
        if count <= 0:
            raise Error("IntelGate reported available but device count is 0")
    else:
        print("Intel Level Zero: UNAVAILABLE on current host platform (Fail-Closed)")
        if count != 0:
            raise Error("IntelGate reported unavailable but device count is non-zero")

    print("IntelGate driver & runtime availability: PASS")


def test_intel_gemm_dispatch_bounds() raises:
    print("--- Testing gemm_f16_gpu Intel shape mismatch handling ---")
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(4 * 32)
    var A = RuneTensor[f16](4, 32, a_ptr)
    var b_ptr = well.allocate(4 * 16)
    var B = RuneTensor[f16](4, 16, b_ptr)
    var c_ptr = well.allocate(4 * 4)
    var C = RuneTensor[f16](4, 4, c_ptr)

    var shape_rejected = False
    try:
        IntelGate.launch_gemm_intel(A, B, C)
    except error:
        shape_rejected = True
        if "GEMM shape mismatch" not in String(error):
            raise Error("IntelGate shape mismatch check produced unexpected error text: " + String(error))

    if not shape_rejected:
        raise Error("IntelGate failed to reject mismatched GEMM shapes")

    print("gemm_f16_gpu Intel shape mismatch handling: PASS")


def test_intel_realm_unsupported_gateways() raises:
    print("--- Testing Intel Level Zero realm error gateways ---")
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(4 * 32)
    var A = RuneTensor[f16](4, 32, a_ptr)
    var b_ptr = well.allocate(4 * 32)
    var B = RuneTensor[f16](4, 32, b_ptr)
    var c_ptr = well.allocate(4 * 4)
    var C = RuneTensor[f16](4, 4, c_ptr)

    if not IntelGate.is_available():
        var rejected = False
        try:
            gemm_f16_gpu(A, B, C, GPURealmType(GPURealmType.INTEL_ONEAPI_XE))
        except error:
            rejected = True
            var err_str = String(error)
            if "Intel OneAPI Level Zero GPU execution error" not in err_str and "libze_loader.so" not in err_str:
                raise Error("Intel gateway rejection omitted stable error text: " + err_str)
        if not rejected:
            raise Error("Intel gateway failed to reject execution on host without Level Zero runtime")

    print("Intel Level Zero realm error gateways: PASS")
