# tests/test_npu_edge.mojo
# Verification of the NPU Realm Gateway: Edge & Heterogeneous Acceleration

from core.mimir_well import MimirWell, RuneTensor, DeviceTopology, NPUBackendType, NPUBuffer, f16, f32
from core.compute import gemm_f16, gemm_f16_arm_neon, rmsnorm_arm_neon, gemm_f16_npu

def test_npu_backend_enum():
    print("--- Testing NPUBackendType (The Edge Acceleration Realm) ---")
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
        print("NPUBackendType: FAIL")


def test_device_topology_npu():
    print("--- Testing DeviceTopology NPU Discovery (The Realm Mapping) ---")
    var success = True
    var topo = DeviceTopology(2)
    if len(topo.npu_backends) == 0:
        print("FAIL: DeviceTopology failed to discover NPU backends")
        success = False

    var found_arm = False
    for i in range(len(topo.npu_backends)):
        if topo.npu_backends[i].value == NPUBackendType.ARM_NEON:
            found_arm = True
            break
    if not found_arm:
        print("FAIL: ARM_NEON backend not discovered by DeviceTopology")
        success = False

    if success:
        print("DeviceTopology NPU Discovery: PASS")
    else:
        print("DeviceTopology NPU Discovery: FAIL")


def test_npu_buffer_zero_copy():
    print("--- Testing NPUBuffer Zero-Copy Allocation (The Mímisbrunnr Shared Stream) ---")
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

    var tensor = buf.as_rune_tensor(16, 32)
    for i in range(tensor.size):
        tensor.data.unsafe_store(i, Scalar[f16](1.5))

    for i in range(tensor.size):
        if tensor.data.unsafe_load(i) != Scalar[f16](1.5):
            print("FAIL: NPUBuffer tensor memory read back mismatch")
            success = False
            break

    if success:
        print("NPUBuffer Zero-Copy: PASS")
    else:
        print("NPUBuffer Zero-Copy: FAIL")


def test_arm_neon_precision():
    print("--- Testing ARM NEON SIMD Precision (128-bit Vector Lanes) ---")
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
        print("ARM NEON Precision: PASS")
    else:
        print("ARM NEON Precision: FAIL")


def test_npu_gemm_parity():
    print("--- Testing NPU GEMM Parity across Acceleration Backends ---")
    var success = True

    # K=32 ensures gemm_f16 (simd_w_f16=32) and gemm_f16_arm_neon (neon_w=8) both iterate cleanly
    var M = 4
    var K = 32
    var N = 4
    # Expected: each C[m,n] = sum(A[m,k]*B[n,k] for k=0..31) = K * 2.0 * 1.5 = 96.0
    var expected = Scalar[f16](96.0)

    for b in range(6):
        var well = MimirWell(1024 * 1024)
        var a_ptr = well.allocate(M * K)
        var A = RuneTensor[f16](M, K, a_ptr)
        var b_ptr = well.allocate(N * K)
        var B = RuneTensor[f16](N, K, b_ptr)
        var c_cpu_ptr = well.allocate(M * N)
        var C_CPU = RuneTensor[f16](M, N, c_cpu_ptr)
        var c_npu_ptr = well.allocate(M * N)
        var C_NPU = RuneTensor[f16](M, N, c_npu_ptr)

        for i in range(M * K):
            A.data.unsafe_store(i, Scalar[f16](2.0))
        for i in range(N * K):
            B.data.unsafe_store(i, Scalar[f16](1.5))
        for i in range(M * N):
            C_CPU.data.unsafe_store(i, Scalar[f16](0.0))
            C_NPU.data.unsafe_store(i, Scalar[f16](0.0))

        gemm_f16(A, B, C_CPU)

        var backend = NPUBackendType(b)
        gemm_f16_npu(A, B, C_NPU, backend)

        for i in range(M * N):
            var npu_val = C_NPU.data.unsafe_load(i)
            var cpu_val = C_CPU.data.unsafe_load(i)
            if npu_val != cpu_val or npu_val != expected:
                print("FAIL: NPU backend", backend.name(), "mismatch at index", i, "got", npu_val, "expected", expected)
                success = False
                break

    if success:
        print("NPU GEMM Parity: PASS")
    else:
        print("NPU GEMM Parity: FAIL")
