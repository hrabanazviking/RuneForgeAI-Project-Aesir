# tests/test_npu_realm.mojo
# Verification of Edge/Desktop NPU Acceleration Integration & Gateway Memory Management

from core.npu_gate import NPUGate
from core.mimir_well import MimirWell, RuneTensor, NPUBackendType, f16
from core.compute import gemm_f16_npu

def test_npu_gate_availability() raises:
    print("--- Testing NPUGate driver & runtime availability ---")
    for b_id in range(7):
        var backend = NPUBackendType(b_id)
        var avail = NPUGate.is_available(backend)
        var count = NPUGate.get_device_count(backend)

        if avail:
            print("NPU Backend " + backend.name() + ": AVAILABLE (" + String(count) + " devices)")
            if count <= 0:
                raise Error("NPUGate reported available for " + backend.name() + " but device count is 0")
        else:
            print("NPU Backend " + backend.name() + ": UNAVAILABLE on current host platform (Fail-Closed)")
            if count != 0:
                raise Error("NPUGate reported unavailable for " + backend.name() + " but device count is non-zero")

    print("NPUGate driver & runtime availability: PASS")


def test_npu_gemm_dispatch_bounds() raises:
    print("--- Testing gemm_f16_npu shape mismatch handling ---")
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(4 * 32)
    var A = RuneTensor[f16](4, 32, a_ptr)
    var b_ptr = well.allocate(4 * 16)
    var B = RuneTensor[f16](4, 16, b_ptr)
    var c_ptr = well.allocate(4 * 4)
    var C = RuneTensor[f16](4, 4, c_ptr)

    var shape_rejected = False
    try:
        NPUGate.launch_gemm_npu(A, B, C, NPUBackendType(NPUBackendType.QUALCOMM_HEXAGON))
    except error:
        shape_rejected = True
        if "GEMM shape mismatch" not in String(error):
            raise Error("NPUGate shape mismatch check produced unexpected error text: " + String(error))

    if not shape_rejected:
        raise Error("NPUGate failed to reject mismatched GEMM shapes")

    print("gemm_f16_npu shape mismatch handling: PASS")


def test_npu_realm_unsupported_gateways() raises:
    print("--- Testing NPU realm error gateways ---")
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(4 * 32)
    var A = RuneTensor[f16](4, 32, a_ptr)
    var b_ptr = well.allocate(4 * 32)
    var B = RuneTensor[f16](4, 32, b_ptr)
    var c_ptr = well.allocate(4 * 4)
    var C = RuneTensor[f16](4, 4, c_ptr)

    var test_backends = List[NPUBackendType]()
    test_backends.append(NPUBackendType(NPUBackendType.QUALCOMM_HEXAGON))
    test_backends.append(NPUBackendType(NPUBackendType.APPLE_NEURAL_ENGINE))
    test_backends.append(NPUBackendType(NPUBackendType.HAILO_10))
    test_backends.append(NPUBackendType(NPUBackendType.INTEL_NPU))

    for idx in range(len(test_backends)):
        var b = test_backends[idx]
        if not NPUGate.is_available(b):
            var rejected = False
            try:
                gemm_f16_npu(A, B, C, b)
            except error:
                rejected = True
                var err_str = String(error)
                if "NPU execution error" not in err_str and "driver not available" not in err_str:
                    raise Error("NPU gateway rejection omitted stable error text: " + err_str)
            if not rejected:
                raise Error("NPU gateway failed to reject execution on host without NPU driver: " + b.name())

    print("NPU realm error gateways: PASS")
