# aesir_engine/tests/test_cuda_realm.mojo
# Unit tests for Stage 44.1: NVIDIA CUDA GPU Realm Gateway & Memory Management

from core.mimir_well import MimirWell, Scalar, f16, f32, GPURealmType, RuneTensor
from core.cuda_gate import CUDAGate
from core.compute import gemm_f16_gpu, rmsnorm_gpu

def test_cuda_gate_availability() raises:
    """Verify CUDAGate availability probe does not crash."""
    print("--- Testing CUDAGate driver/runtime availability probe ---")
    var avail = CUDAGate.is_available()
    var count = CUDAGate.get_device_count()
    if avail:
        print("CUDA Runtime (libcudart.so/libcuda.so): AVAILABLE (" + String(count) + " devices)")
        if count < 0:
            raise Error("Device count must be non-negative")
    else:
        print("CUDA Runtime (libcudart.so/libcuda.so): NOT LOADED ON HOST (Fail-Closed)")
        if count != 0:
            raise Error("Device count must be 0 when CUDA runtime is unavailable")

def test_cuda_gemm_dispatch_bounds() raises:
    """Verify gemm_f16_gpu shape bounds checking for NVIDIA_CUDA realm."""
    print("--- Testing gemm_f16_gpu shape mismatch handling ---")
    var well = MimirWell(1024 * 1024)

    var p_a = well.allocate(4)
    var p_b = well.allocate(6)
    var p_c = well.allocate(4)

    var A = RuneTensor[f16](2, 2, p_a, False)
    var B = RuneTensor[f16](3, 2, p_b, False) # Shape mismatch (rows 3 != 2)
    var C = RuneTensor[f16](2, 2, p_c, False)

    var raised = False
    try:
        gemm_f16_gpu(A, B, C, GPURealmType(GPURealmType.NVIDIA_CUDA))
    except e:
        if "GEMM shape mismatch" in String(e) or "NVIDIA libcudart.so" in String(e) or "zero active NVIDIA" in String(e):
            raised = True

    if not raised:
        raise Error("gemm_f16_gpu failed to raise shape bounds or driver error")

def test_cuda_realm_unsupported_gateways() raises:
    """Verify non-CUDA GPU realms raise explicit unsupported errors."""
    print("--- Testing unsupported GPU realm error gateways ---")
    var well = MimirWell(1024 * 1024)

    var p_a = well.allocate(4)
    var p_b = well.allocate(4)
    var p_c = well.allocate(4)

    var A = RuneTensor[f16](2, 2, p_a, False)
    var B = RuneTensor[f16](2, 2, p_b, False)
    var C = RuneTensor[f16](2, 2, p_c, False)

    var raised_rocm = False
    try:
        gemm_f16_gpu(A, B, C, GPURealmType(GPURealmType.AMD_ROCM_HIP))
    except e:
        if "GPU execution is not implemented for realm AMD_ROCM_HIP" in String(e):
            raised_rocm = True

    if not raised_rocm:
        raise Error("AMD_ROCM_HIP realm did not raise expected unsupported error")

    var raised_oneapi = False
    try:
        gemm_f16_gpu(A, B, C, GPURealmType(GPURealmType.INTEL_ONEAPI_XE))
    except e:
        var err_str = String(e)
        if "GPU execution is not implemented for realm INTEL_ONEAPI_XE" in err_str or "Intel OneAPI Level Zero GPU execution error" in err_str or "libze_loader.so" in err_str:
            raised_oneapi = True

    if not raised_oneapi:
        raise Error("INTEL_ONEAPI_XE realm did not raise expected unsupported error")

def main() raises:
    print("==========================================================================")
    print("  Stage 44.1 — NVIDIA CUDA GPU Realm Gateway & Device Memory Tests")
    print("==========================================================================")
    test_cuda_gate_availability()
    test_cuda_gemm_dispatch_bounds()
    test_cuda_realm_unsupported_gateways()
    print("Stage 44.1 CUDA Realm Tests: PASSED CLEAN")
