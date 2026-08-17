# tests/test_hardware_resilience.mojo
# Resilience & Self-Healing Hardening Suite for GPU and NPU Gateways

from core.cuda_gate import CUDAGate
from core.metal_gate import MetalGate
from core.intel_gate import IntelGate
from core.amd_gate import AMDGate
from core.npu_gate import NPUGate
from core.mimir_well import MimirWell, RuneTensor, GPURealmType, NPUBackendType, f16
from core.compute import gemm_f16_gpu, gemm_f16_npu

def test_non_positive_allocation_rejection() raises:
    print("--- Testing non-positive VRAM / NPU allocation rejection ---")
    
    var cuda_rej = False
    try:
        _ = CUDAGate.allocate_vram(-1024)
    except:
        cuda_rej = True
    if not cuda_rej:
        raise Error("CUDAGate failed to reject negative allocation size")

    var metal_rej = False
    try:
        _ = MetalGate.allocate_metal_buffer(0)
    except:
        metal_rej = True
    if not metal_rej:
        raise Error("MetalGate failed to reject zero allocation size")

    var intel_rej = False
    try:
        _ = IntelGate.allocate_vram(-64)
    except:
        intel_rej = True
    if not intel_rej:
        raise Error("IntelGate failed to reject negative allocation size")

    var amd_rej = False
    try:
        _ = AMDGate.allocate_vram(0)
    except:
        amd_rej = True
    if not amd_rej:
        raise Error("AMDGate failed to reject zero allocation size")

    var npu_rej = False
    try:
        _ = NPUGate.allocate_npu_buffer(-128)
    except:
        npu_rej = True
    if not npu_rej:
        raise Error("NPUGate failed to reject negative allocation size")

    print("non-positive VRAM / NPU allocation rejection: PASS")


def test_non_positive_dimension_gemm_rejection() raises:
    print("--- Testing non-positive GEMM dimension rejection ---")
    var well = MimirWell(1024 * 1024)
    var ptr_a = well.allocate(32)
    var A_zero = RuneTensor[f16](0, 32, ptr_a)
    var ptr_b = well.allocate(32)
    var B_zero = RuneTensor[f16](0, 32, ptr_b)
    var ptr_c = well.allocate(16)
    var C_zero = RuneTensor[f16](0, 0, ptr_c)

    var cuda_dim_rej = False
    try:
        CUDAGate.launch_gemm_cuda(A_zero, B_zero, C_zero)
    except e:
        if "non-positive matrix dimensions" in String(e):
            cuda_dim_rej = True
    if not cuda_dim_rej:
        raise Error("CUDAGate failed to reject non-positive matrix dimensions")

    var metal_dim_rej = False
    try:
        MetalGate.launch_gemm_metal(A_zero, B_zero, C_zero)
    except e:
        if "non-positive matrix dimensions" in String(e):
            metal_dim_rej = True
    if not metal_dim_rej:
        raise Error("MetalGate failed to reject non-positive matrix dimensions")

    var intel_dim_rej = False
    try:
        IntelGate.launch_gemm_intel(A_zero, B_zero, C_zero)
    except e:
        if "non-positive matrix dimensions" in String(e):
            intel_dim_rej = True
    if not intel_dim_rej:
        raise Error("IntelGate failed to reject non-positive matrix dimensions")

    var amd_dim_rej = False
    try:
        AMDGate.launch_gemm_amd(A_zero, B_zero, C_zero)
    except e:
        if "non-positive matrix dimensions" in String(e):
            amd_dim_rej = True
    if not amd_dim_rej:
        raise Error("AMDGate failed to reject non-positive matrix dimensions")

    var npu_dim_rej = False
    try:
        NPUGate.launch_gemm_npu(A_zero, B_zero, C_zero, NPUBackendType(NPUBackendType.QUALCOMM_HEXAGON))
    except e:
        if "non-positive matrix dimensions" in String(e):
            npu_dim_rej = True
    if not npu_dim_rej:
        raise Error("NPUGate failed to reject non-positive matrix dimensions")

    print("non-positive GEMM dimension rejection: PASS")


def test_self_healing_error_barriers() raises:
    print("--- Testing self-healing error barriers and memory safety ---")
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(4 * 32)
    var A = RuneTensor[f16](4, 32, a_ptr)
    var b_ptr = well.allocate(4 * 32)
    var B = RuneTensor[f16](4, 32, b_ptr)
    var c_ptr = well.allocate(4 * 4)
    var C = RuneTensor[f16](4, 4, c_ptr)

    # Test GPU dispatch error barrier on unavailable hardware
    if not MetalGate.is_available():
        var metal_caught = False
        try:
            gemm_f16_gpu(A, B, C, GPURealmType(GPURealmType.ARM_MALI_OPENCL))
        except:
            metal_caught = True
        if not metal_caught:
            raise Error("gemm_f16_gpu failed to trap Metal unavailable error")

    # Test NPU dispatch error barrier on unavailable hardware
    if not NPUGate.is_available(NPUBackendType(NPUBackendType.HAILO_10)):
        var hailo_caught = False
        try:
            gemm_f16_npu(A, B, C, NPUBackendType(NPUBackendType.HAILO_10))
        except:
            hailo_caught = True
        if not hailo_caught:
            raise Error("gemm_f16_npu failed to trap Hailo-10 unavailable error")

    print("self-healing error barriers and memory safety: PASS")
