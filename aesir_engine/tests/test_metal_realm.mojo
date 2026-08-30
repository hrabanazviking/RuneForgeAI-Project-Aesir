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
        print("Apple Metal runtime library: LOADABLE; physical device count unverified")
    else:
        print("Apple Metal Framework: UNAVAILABLE on current host platform (Fail-Closed)")
    if count != 0:
        raise Error("MetalGate fabricated a physical device count")

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

    var rejected = False
    try:
        MetalGate.launch_gemm_metal(A, B, C)
    except error:
        rejected = True
        if "not implemented" not in String(error):
            raise Error("Metal gateway rejection omitted stable error text: " + String(error))
    if not rejected:
        raise Error("Metal gateway reported execution without a physical kernel")

    print("Apple Metal realm error gateways: PASS")
