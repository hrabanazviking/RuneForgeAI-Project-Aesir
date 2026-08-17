# tests/test_gpu_realms.mojo
# Verification of GPU descriptors and honest unsupported execution

from core.mimir_well import MimirWell, RuneTensor, DeviceTopology, GPURealmType, GPUBuffer, f16, f32
from core.compute import gemm_f16, gemm_f16_gpu, rmsnorm_gpu

def test_gpu_realm_enum() raises:
    print("--- Testing reserved GPU realm discriminants ---")
    var success = True

    var cuda = GPURealmType(GPURealmType.NVIDIA_CUDA)
    var rocm = GPURealmType(GPURealmType.AMD_ROCM_HIP)
    var intel = GPURealmType(GPURealmType.INTEL_ONEAPI_XE)
    var musa = GPURealmType(GPURealmType.MOORE_THREADS_MUSA)
    var supa = GPURealmType(GPURealmType.BIREN_SUPA)
    var maca = GPURealmType(GPURealmType.METAX_MACA)
    var dcu = GPURealmType(GPURealmType.HYGON_DCU)
    var mali = GPURealmType(GPURealmType.ARM_MALI_OPENCL)
    var adreno = GPURealmType(GPURealmType.QUALCOMM_ADRENO)
    var powervr = GPURealmType(GPURealmType.IMAGINATION_POWERVR)

    if cuda.value != 0 or cuda.name() != "NVIDIA_CUDA":
        print("FAIL: NVIDIA_CUDA expected value 0, name NVIDIA_CUDA")
        success = False
    if rocm.value != 1 or rocm.name() != "AMD_ROCM_HIP":
        print("FAIL: AMD_ROCM_HIP expected value 1, name AMD_ROCM_HIP")
        success = False
    if intel.value != 2 or intel.name() != "INTEL_ONEAPI_XE":
        print("FAIL: INTEL_ONEAPI_XE expected value 2, name INTEL_ONEAPI_XE")
        success = False
    if musa.value != 3 or musa.name() != "MOORE_THREADS_MUSA":
        print("FAIL: MOORE_THREADS_MUSA expected value 3, name MOORE_THREADS_MUSA")
        success = False
    if supa.value != 4 or supa.name() != "BIREN_SUPA":
        print("FAIL: BIREN_SUPA expected value 4, name BIREN_SUPA")
        success = False
    if maca.value != 5 or maca.name() != "METAX_MACA":
        print("FAIL: METAX_MACA expected value 5, name METAX_MACA")
        success = False
    if dcu.value != 6 or dcu.name() != "HYGON_DCU":
        print("FAIL: HYGON_DCU expected value 6, name HYGON_DCU")
        success = False
    if mali.value != 7 or mali.name() != "ARM_MALI_OPENCL":
        print("FAIL: ARM_MALI_OPENCL expected value 7, name ARM_MALI_OPENCL")
        success = False
    if adreno.value != 8 or adreno.name() != "QUALCOMM_ADRENO":
        print("FAIL: QUALCOMM_ADRENO expected value 8, name QUALCOMM_ADRENO")
        success = False
    if powervr.value != 9 or powervr.name() != "IMAGINATION_POWERVR":
        print("FAIL: IMAGINATION_POWERVR expected value 9, name IMAGINATION_POWERVR")
        success = False

    if success:
        print("GPURealmType: PASS")
    else:
        raise Error("GPURealmType invariant mismatch")


def test_device_topology_gpus() raises:
    print("--- Testing no fabricated GPU discovery ---")
    var topo = DeviceTopology(2)
    if len(topo.gpu_realms) != 0:
        raise Error("DeviceTopology fabricated unavailable GPU realms")
    print("no fabricated GPU discovery: PASS")


def test_gpu_buffer_zero_copy() raises:
    print("--- Testing GPU-labeled host buffer descriptor ---")
    var success = True
    var well = MimirWell(1024 * 1024)
    var buf_bytes = 2048
    var buf = well.allocate_gpu_buffer(buf_bytes, GPURealmType(GPURealmType.AMD_ROCM_HIP))

    if buf.size_bytes != buf_bytes:
        print("FAIL: GPUBuffer size_bytes mismatch")
        success = False
    if buf.realm.value != GPURealmType.AMD_ROCM_HIP:
        print("FAIL: GPUBuffer realm mismatch")
        success = False

    var tensor = buf.as_rune_tensor(32, 32)
    for i in range(tensor.size):
        tensor.data.unsafe_store(i, Scalar[f16](3.5))

    for i in range(tensor.size):
        if tensor.data.unsafe_load(i) != Scalar[f16](3.5):
            print("FAIL: GPUBuffer memory read back mismatch")
            success = False
            break

    # Negative buffer size rejection check
    var neg_rejected = False
    try:
        var bad_buf = well.allocate_gpu_buffer(-100, GPURealmType(GPURealmType.NVIDIA_CUDA))
    except error:
        neg_rejected = True
        if "size_bytes must not be negative" not in String(error):
            raise Error("GPUBuffer negative size rejection omitted expected error text")
    if not neg_rejected:
        raise Error("GPUBuffer failed to reject negative buffer size")

    if success:
        print("GPU-labeled host buffer descriptor: PASS")
    else:
        raise Error("GPUBuffer host-memory view invariant mismatch")


def test_gpu_gemm_parity() raises:
    print("--- Testing unsupported GPU execution gateway ---")
    var M = 4
    var K = 32
    var N = 4

    for b in range(10):
        if b == 0 or b == 1 or b == 2 or b == 7:
            continue
        var well = MimirWell(1024 * 1024)
        var a_ptr = well.allocate(M * K)
        var A = RuneTensor[f16](M, K, a_ptr)
        var b_ptr = well.allocate(N * K)
        var B = RuneTensor[f16](N, K, b_ptr)
        var c_gpu_ptr = well.allocate(M * N)
        var C_GPU = RuneTensor[f16](M, N, c_gpu_ptr)

        for i in range(M * K):
            A.data.unsafe_store(i, Scalar[f16](2.0))
        for i in range(N * K):
            B.data.unsafe_store(i, Scalar[f16](1.5))
        for i in range(M * N):
            C_GPU.data.unsafe_store(i, Scalar[f16](0.0))

        var realm = GPURealmType(b)
        var rejected = False
        try:
            gemm_f16_gpu(A, B, C_GPU, realm)
        except error:
            rejected = True
            var err_str = String(error)
            if "not implemented" not in err_str and "CUDA GPU execution error" not in err_str:
                raise Error("GPU gateway rejection omitted stable truth text")
        if not rejected:
            raise Error("GPU gateway executed a CPU fallback")
        for i in range(M * N):
            if C_GPU.data.unsafe_load(i) != Scalar[f16](0.0):
                raise Error("unsupported GPU gateway wrote an output tensor")

    print("unsupported GPU execution gateway: PASS")
