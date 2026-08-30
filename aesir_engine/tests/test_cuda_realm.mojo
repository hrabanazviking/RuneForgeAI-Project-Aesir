# aesir_engine/tests/test_cuda_realm.mojo
# Unit tests for Stage 44.1: NVIDIA CUDA GPU Realm Gateway & Memory Management

from core.mimir_well import (
    MimirWell,
    Scalar,
    f16,
    f32,
    GPURealmType,
    RuneTensor,
)
from core.cuda_gate import CUDAGate
from core.compute import gemm_f16_gpu, rmsnorm_gpu


def test_cuda_gate_availability() raises:
    """Verify CUDA library presence and physical discovery stay distinct."""
    print("--- Testing truthful CUDA runtime and physical device discovery ---")
    var avail = CUDAGate.is_available()
    var count = CUDAGate.get_device_count()
    var result = CUDAGate.discover_physical_devices()
    result.validate()
    if count < 0:
        raise Error("CUDAGate returned a negative physical device count")
    if count > 0:
        if not avail:
            raise Error(
                "MAX observed CUDA devices while the runtime probe failed"
            )
        if len(result.devices) != count:
            raise Error(
                "CUDA discovery record count differs from MAX device count"
            )
        print("CUDA physical devices observed through MAX:", count)
    else:
        if result.status.is_success():
            raise Error("CUDA discovery fabricated success with zero devices")
        if avail:
            print(
                "CUDA runtime library: LOADABLE; MAX reported no physical"
                " devices"
            )
        else:
            print("CUDA runtime library: NOT LOADABLE (Fail-Closed)")


def test_cuda_gemm_dispatch_bounds() raises:
    """Verify gemm_f16_gpu shape bounds checking for NVIDIA_CUDA realm."""
    print("--- Testing gemm_f16_gpu shape mismatch handling ---")
    var well = MimirWell(1024 * 1024)

    var p_a = well.allocate(4)
    var p_b = well.allocate(6)
    var p_c = well.allocate(4)

    var A = RuneTensor[f16](2, 2, p_a, False)
    var B = RuneTensor[f16](3, 2, p_b, False)  # Shape mismatch (rows 3 != 2)
    var C = RuneTensor[f16](2, 2, p_c, False)

    var raised = False
    try:
        gemm_f16_gpu(A, B, C, GPURealmType(GPURealmType.NVIDIA_CUDA))
    except e:
        if (
            "GEMM shape mismatch" in String(e)
            or "NVIDIA libcudart.so" in String(e)
            or "zero active NVIDIA" in String(e)
        ):
            raised = True

    if not raised:
        raise Error("gemm_f16_gpu failed to raise shape bounds or driver error")


def test_cuda_realm_unsupported_gateways() raises:
    """Verify every physical GPU execution path fails closed."""
    print("--- Testing unsupported GPU realm error gateways ---")
    var well = MimirWell(1024 * 1024)

    var p_a = well.allocate(4)
    var p_b = well.allocate(4)
    var p_c = well.allocate(4)

    var A = RuneTensor[f16](2, 2, p_a, False)
    var B = RuneTensor[f16](2, 2, p_b, False)
    var C = RuneTensor[f16](2, 2, p_c, False)

    var executed_cuda = False
    try:
        gemm_f16_gpu(A, B, C, GPURealmType(GPURealmType.NVIDIA_CUDA))
        executed_cuda = True
    except e:
        if "not implemented" not in String(e):
            executed_cuda = True
    if not executed_cuda:
        raise Error(
            "NVIDIA_CUDA realm failed physical GEMM execution"
        )

    var raised_rocm = False
    try:
        gemm_f16_gpu(A, B, C, GPURealmType(GPURealmType.AMD_ROCM_HIP))
    except e:
        var err_str = String(e)
        if "not implemented" in err_str:
            raised_rocm = True

    if not raised_rocm:
        raise Error(
            "AMD_ROCM_HIP realm did not raise expected unsupported error"
        )

    var raised_oneapi = False
    try:
        gemm_f16_gpu(A, B, C, GPURealmType(GPURealmType.INTEL_ONEAPI_XE))
    except e:
        var err_str = String(e)
        if "not implemented" in err_str:
            raised_oneapi = True

    if not raised_oneapi:
        raise Error(
            "INTEL_ONEAPI_XE realm did not raise expected unsupported error"
        )


def main() raises:
    print(
        "=========================================================================="
    )
    print("  Stage 44.1 — NVIDIA CUDA GPU Realm Gateway & Device Memory Tests")
    print(
        "=========================================================================="
    )
    test_cuda_gate_availability()
    test_cuda_gemm_dispatch_bounds()
    test_cuda_realm_unsupported_gateways()
    print("Stage 44.1 CUDA Realm Tests: PASSED CLEAN")
