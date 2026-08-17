# tests/test_npu_edge.mojo
# Verification of NPU descriptors and honest unsupported execution

from core.mimir_well import MimirWell, RuneTensor, DeviceTopology, NPUBackendType, NPUBuffer, f16, f32
from core.compute import gemm_f16, gemm_f16_arm_neon, rmsnorm_arm_neon, gemm_f16_npu

def test_npu_backend_enum() raises:
    print("--- Testing reserved NPU backend discriminants ---")
    var success = True

    var h10 = NPUBackendType(NPUBackendType.HAILO_10)
    var hex = NPUBackendType(NPUBackendType.QUALCOMM_HEXAGON)
    var neon = NPUBackendType(NPUBackendType.ARM_NEON)
    var jet = NPUBackendType(NPUBackendType.JETSON_NVIDIA)
    var ane = NPUBackendType(NPUBackendType.APPLE_NEURAL_ENGINE)
    var gen = NPUBackendType(NPUBackendType.GENERIC_NPU)

    if h10.value != 0 or h10.name() != "HAILO_10":
        print("FAIL: HAILO_10 expected value 0, name HAILO_10")
        success = False
    if hex.value != 1 or hex.name() != "QUALCOMM_HEXAGON":
        print("FAIL: QUALCOMM_HEXAGON expected value 1, name QUALCOMM_HEXAGON")
        success = False
    if neon.value != 2 or neon.name() != "ARM_NEON":
        print("FAIL: ARM_NEON expected value 2, name ARM_NEON")
        success = False
    if jet.value != 3 or jet.name() != "JETSON_NVIDIA":
        print("FAIL: JETSON_NVIDIA expected value 3, name JETSON_NVIDIA")
        success = False
    if ane.value != 4 or ane.name() != "APPLE_NEURAL_ENGINE":
        print("FAIL: APPLE_NEURAL_ENGINE expected value 4, name APPLE_NEURAL_ENGINE")
        success = False
    if gen.value != 5 or gen.name() != "GENERIC_NPU":
        print("FAIL: GENERIC_NPU expected value 5, name GENERIC_NPU")
        success = False

    if success:
        print("NPUBackendType: PASS")
    else:
        raise Error("NPUBackendType invariant mismatch")


def test_device_topology_npu() raises:
    print("--- Testing no fabricated NPU discovery ---")
    var topo = DeviceTopology(2)
    if len(topo.npu_backends) != 0:
        raise Error("DeviceTopology fabricated unavailable NPU backends")
    print("no fabricated NPU discovery: PASS")


def test_npu_buffer_zero_copy() raises:
    print("--- Testing NPU-labeled host buffer descriptor ---")
    var success = True
    var well = MimirWell(1024 * 1024)
    var buf_bytes = 1024
    var buf = well.allocate_npu_buffer(buf_bytes, NPUBackendType(NPUBackendType.HAILO_10))

    if buf.size_bytes != buf_bytes:
        print("FAIL: NPUBuffer size_bytes mismatch")
        success = False
    if buf.backend.value != NPUBackendType.HAILO_10:
        print("FAIL: NPUBuffer backend mismatch")
        success = False
    if buf.is_dma_buf:
        print("FAIL: host pool buffer claimed DMA-BUF backing")
        success = False

    var tensor = buf.as_rune_tensor(16, 32)
    for i in range(tensor.size):
        tensor.data.unsafe_store(i, Scalar[f16](1.5))

    for i in range(tensor.size):
        if tensor.data.unsafe_load(i) != Scalar[f16](1.5):
            print("FAIL: NPUBuffer tensor memory read back mismatch")
            success = False
            break

    if success:
        print("NPU-labeled host buffer descriptor: PASS")
    else:
        raise Error("NPUBuffer host-memory view invariant mismatch")


def test_arm_neon_precision() raises:
    print("--- Testing host 8-wide SIMD helper parity ---")
    var success = True
    var well = MimirWell(1024 * 1024)

    var M = 16
    var K = 32
    var N = 16

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr)

    var b_ptr = well.allocate(N * K)
    var B = RuneTensor[f16](N, K, b_ptr)

    var c_arm = well.allocate(M * N)
    var C_ARM = RuneTensor[f16](M, N, c_arm)

    var c_cpu = well.allocate(M * N)
    var C_CPU = RuneTensor[f16](M, N, c_cpu)

    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](1.0))
    for i in range(N * K):
        B.data.unsafe_store(i, Scalar[f16](1.0))

    gemm_f16_arm_neon(A, B, C_ARM)
    gemm_f16(A, B, C_CPU)

    for i in range(M * N):
        var val_arm = C_ARM.data.unsafe_load(i)
        var val_cpu = C_CPU.data.unsafe_load(i)
        if val_arm != val_cpu or val_arm != Scalar[f16](32.0):
            print("Mismatch at index", i, "ARM NEON:", val_arm, "CPU:", val_cpu)
            success = False
            break

    if success:
        print("host 8-wide SIMD helper parity: PASS")
    else:
        raise Error("ARM NEON synthetic parity mismatch")


def test_npu_gemm_parity() raises:
    print("--- Testing unsupported NPU execution gateway ---")
    var M = 4
    var K = 32
    var N = 4

    for b in range(6):
        var well = MimirWell(1024 * 1024)
        var a_ptr = well.allocate(M * K)
        var A = RuneTensor[f16](M, K, a_ptr)
        var b_ptr = well.allocate(N * K)
        var B = RuneTensor[f16](N, K, b_ptr)
        var c_npu_ptr = well.allocate(M * N)
        var C_NPU = RuneTensor[f16](M, N, c_npu_ptr)

        for i in range(M * K):
            A.data.unsafe_store(i, Scalar[f16](2.0))
        for i in range(N * K):
            B.data.unsafe_store(i, Scalar[f16](1.5))
        for i in range(M * N):
            C_NPU.data.unsafe_store(i, Scalar[f16](0.0))

        var backend = NPUBackendType(b)
        var rejected = False
        try:
            gemm_f16_npu(A, B, C_NPU, backend)
        except error:
            rejected = True
            var err_str = String(error)
            if "not implemented" not in err_str and "NPU execution error" not in err_str and "driver not available" not in err_str:
                raise Error("NPU gateway rejection omitted stable truth text: " + err_str)
        if not rejected:
            raise Error("NPU gateway executed a CPU fallback")
        for i in range(M * N):
            if C_NPU.data.unsafe_load(i) != Scalar[f16](0.0):
                raise Error("unsupported NPU gateway wrote an output tensor")

    print("unsupported NPU execution gateway: PASS")
