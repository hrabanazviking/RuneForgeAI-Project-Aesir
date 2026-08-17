# tests/test_metal_realm.mojo
# Verification of Apple Metal GPU Acceleration Gateway & Device Memory Management

from core.metal_gate import MetalGate
from core.mimir_well import MimirWell, RuneTensor, GPURealmType, f16, Scalar
from core.compute import gemm_f16_gpu

def test_metal_gate_availability() raises:
    print("--- Testing MetalGate driver & framework availability ---")
    var avail = MetalGate.is_available()
    var count = MetalGate.get_device_count()

    if avail:
        print("Apple Metal Framework: AVAILABLE (" + String(count) + " devices)")
        if count <= 0:
            raise Error("MetalGate reported available but device count is 0")
    else:
        print("Apple Metal Framework: UNAVAILABLE on current host platform (Fail-Closed)")
        if count != 0:
            raise Error("MetalGate reported unavailable but device count is non-zero")

    print("MetalGate driver & framework availability: PASS")


def test_metal_gemm_dispatch_bounds() raises:
    print("--- Testing gemm_f16_gpu Metal shape mismatch handling ---")
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(4 * 32)
    var A = RuneTensor[f16](4, 32, a_ptr)
    var b_ptr = well.allocate(4 * 16)
    var B = RuneTensor[f16](4, 16, b_ptr)
    var c_ptr = well.allocate(4 * 4)
    var C = RuneTensor[f16](4, 4, c_ptr)

    var shape_rejected = False
    try:
        MetalGate.launch_gemm_metal(A, B, C)
    except error:
        shape_rejected = True
        if "GEMM shape mismatch" not in String(error):
            raise Error("MetalGate shape mismatch check produced unexpected error text: " + String(error))

    if not shape_rejected:
        raise Error("MetalGate failed to reject mismatched GEMM shapes")

    print("gemm_f16_gpu Metal shape mismatch handling: PASS")


def test_metal_realm_unsupported_gateways() raises:
    print("--- Testing Apple Metal realm error gateways ---")
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(4 * 32)
    var A = RuneTensor[f16](4, 32, a_ptr)
    var b_ptr = well.allocate(4 * 32)
    var B = RuneTensor[f16](4, 32, b_ptr)
    var c_ptr = well.allocate(4 * 4)
    var C = RuneTensor[f16](4, 4, c_ptr)

    if not MetalGate.is_available():
        var rejected = False
        try:
            gemm_f16_gpu(A, B, C, GPURealmType(GPURealmType.ARM_MALI_OPENCL))
        except error:
            rejected = True
            var err_str = String(error)
            if "Apple Metal GPU execution error" not in err_str and "Metal framework runtime not available" not in err_str:
                raise Error("Metal gateway rejection omitted stable error text: " + err_str)
        if not rejected:
            raise Error("Metal gateway failed to reject execution on host without Metal runtime")

    print("Apple Metal realm error gateways: PASS")
