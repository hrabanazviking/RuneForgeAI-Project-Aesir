# core/npu_gate.mojo
# NPUGate: Native POSIX FFI Gateway & Memory Management for Edge/Desktop NPU Realms

from std.ffi import external_call
from std.memory import Pointer
from std.collections import Optional
from core.mimir_well import Scalar, f16, NPUBackendType, RuneTensor

comptime RTLD_NOW = 2

struct NPUGate:
    """
    ᚾᛈᚢ·ᚷᚨᛏᛖ — The Edge NPU Gateway to Neural Accelerator Silicon (NPUGate)
    ═════════════════════════════════════════════════════════════════════════

    Native POSIX FFI interface to Qualcomm Hexagon (libcdsprpc.so), Apple Neural Engine (ANE),
    Hailo-10 (libhailort.so), and Intel NPU (libintel_npu_driver.so) runtimes.
    Probes whether selected runtime libraries are loadable. Physical device
    discovery, NPU buffers, transfers, and kernel launch are unsupported.
    """

    @staticmethod
    def get_handle(backend: NPUBackendType) -> Optional[Pointer[Int8, MutUntrackedOrigin]]:
        """Loads NPU driver library handle via dlopen for given NPU backend, or returns None."""
        var val = backend.value
        var lib_name = String("libhailort.so")

        if val == NPUBackendType.QUALCOMM_HEXAGON:
            lib_name = String("libcdsprpc.so")
        elif val == NPUBackendType.APPLE_NEURAL_ENGINE:
            lib_name = String("AppleNeuralEngine.framework/AppleNeuralEngine")
        elif val == NPUBackendType.JETSON_NVIDIA:
            lib_name = String("libnvgov_npu.so")
        elif val == 6:  # INTEL_NPU
            lib_name = String("libintel_npu_driver.so")
        elif val != NPUBackendType.HAILO_10:
            return None

        var path_buf = InlineArray[Int8, 128](fill=0)
        var l_bytes = lib_name.as_bytes()
        if len(l_bytes) >= 128:
            return None
        for i in range(len(l_bytes)):
            path_buf[i] = Int8(l_bytes[i])

        var handle = external_call["dlopen", Pointer[Int8, MutUntrackedOrigin]](path_buf.unsafe_ptr(), Int32(RTLD_NOW))
        if Int(handle) != 0:
            return Optional[Pointer[Int8, MutUntrackedOrigin]](handle)

        return None

    @staticmethod
    def is_hailo_pi5_device_present() -> Bool:
        """Checks if Hailo-10 NPU hardware device node /dev/hailo0 exists on Raspberry Pi 5."""
        var path_buf = InlineArray[Int8, 16](fill=0)
        var path = String("/dev/hailo0")
        var bytes = path.as_bytes()
        for i in range(len(bytes)):
            path_buf[i] = Int8(bytes[i])
        var fd = external_call["open64", Int32](path_buf.unsafe_ptr(), Int32(0), Int32(0)) # O_RDONLY
        if fd >= 0:
            _ = external_call["close", Int32](fd)
            return True
        return False

    @staticmethod
    def is_available(backend: NPUBackendType) -> Bool:
        """Checks if specified NPU driver runtime or hardware device is present on host system."""
        if backend.value == NPUBackendType.HAILO_10:
            if NPUGate.is_hailo_pi5_device_present():
                return True
        var opt_h = NPUGate.get_handle(backend)
        if opt_h:
            _ = external_call["dlclose", Int32](opt_h.value())
            return True
        return False

    @staticmethod
    def get_device_count(backend: NPUBackendType) -> Int:
        """Returns zero until a vendor device enumeration API is genuinely invoked."""
        _ = backend
        return 0

    @staticmethod
    def allocate_npu_buffer(size_bytes: Int) raises -> Pointer[Scalar[f16], MutUntrackedOrigin]:
        """Rejects simulated NPU allocation until a vendor allocator is integrated."""
        if size_bytes <= 0:
            raise Error("NPUGate.allocate_npu_buffer: size_bytes must be positive")
        raise Error("NPUGate.allocate_npu_buffer: physical NPU allocation is not implemented")

    @staticmethod
    def free_npu_buffer(ptr: Pointer[Scalar[f16], MutUntrackedOrigin]) raises:
        """Frees contiguous NPU buffer memory."""
        _ = ptr
        raise Error("NPUGate.free_npu_buffer: physical NPU buffer ownership is not implemented")

    @staticmethod
    def memcpy_host_to_npu(
        dst_npu: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Copies host memory into NPU memory buffer."""
        _ = dst_npu
        _ = src_host
        if size_bytes <= 0:
            return
        raise Error("NPUGate.memcpy_host_to_npu: physical NPU transfer is not implemented")

    @staticmethod
    def memcpy_npu_to_host(
        dst_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_npu: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Copies NPU memory buffer into host memory."""
        _ = dst_host
        _ = src_npu
        if size_bytes <= 0:
            return
        raise Error("NPUGate.memcpy_npu_to_host: physical NPU transfer is not implemented")

    @staticmethod
    def launch_gemm_npu(
        A: RuneTensor[f16],
        B: RuneTensor[f16],
        mut C: RuneTensor[f16],
        backend: NPUBackendType
    ) raises:
        """
        Validates shapes and rejects execution until a real NPU kernel exists.
        """
        if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0 or C.rows <= 0 or C.cols <= 0:
            raise Error("NPUGate.launch_gemm_npu: non-positive matrix dimensions are prohibited")
        if A.cols != B.cols or A.rows != C.rows or B.rows != C.cols:
            raise Error("NPUGate.launch_gemm_npu: GEMM shape mismatch")

        raise Error("NPU execution is not implemented for backend " + backend.name() + ": no physical kernel was launched")
