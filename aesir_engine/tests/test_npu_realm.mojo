# tests/test_npu_realm.mojo
# H011: the dlopen NPU stub retired. These tests verify the DOCUMENTED ABSENCE:
# no dlopen probing exists, probe_npu_realms() clears the backend list,
# and gemm_f16_npu() raises the stable "not implemented" error.
# HAILBRU's real driver (H061+) will replace this absence.

from core.mimir_well import MimirWell, RuneTensor, NPUBackendType, f16
from core.compute import gemm_f16_npu

def test_npu_probe_absence() raises:
    print("--- Testing NPU probe absence (H011 retirement) ---")
    var well = MimirWell(1024 * 1024)
    well.probe_npu_realms()
    if len(well.npu_backends) != 0:
        raise Error("probe_npu_realms reported backends with no driver present")
    print("NPU probe absence: PASS")


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
        gemm_f16_npu(A, B, C, NPUBackendType(NPUBackendType.QUALCOMM_HEXAGON))
    except error:
        shape_rejected = True
        if "GEMM shape mismatch" not in String(error):
            raise Error("gemm_f16_npu shape mismatch check produced unexpected error text: " + String(error))

    if not shape_rejected:
        raise Error("gemm_f16_npu failed to reject mismatched GEMM shapes")

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
        var rejected = False
        try:
            gemm_f16_npu(A, B, C, b)
        except error:
            rejected = True
            if "not implemented" not in String(error):
                raise Error("NPU gateway rejection omitted stable error text: " + String(error))
        if not rejected:
            raise Error("NPU gateway reported execution without a physical kernel: " + b.name())

    print("NPU realm error gateways: PASS")
