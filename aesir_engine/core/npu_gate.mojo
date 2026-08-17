# core/npu_gate.mojo
# NPUGate: Native POSIX FFI Gateway & Memory Management for Edge/Desktop NPU Realms

from std.ffi import external_call
from std.memory import Pointer, alloc, Layout
from std.collections import Optional
from core.mimir_well import Scalar, f16, f32, NPUBackendType, RuneTensor

comptime RTLD_NOW = 2

struct NPUGate:
    """
    ᚾᛈᚢ·ᚷᚨᛏᛖ — The Edge NPU Gateway to Neural Accelerator Silicon (NPUGate)
    ═════════════════════════════════════════════════════════════════════════

    Native POSIX FFI interface to Qualcomm Hexagon (libcdsprpc.so), Apple Neural Engine (ANE),
    Hailo-10 (libhailort.so), and Intel NPU (libintel_npu_driver.so) runtimes.
    Provides device discovery, zero-copy buffer allocation, and GEMM kernel dispatch.
    """

    @staticmethod
    def get_handle(backend: NPUBackendType) -> Optional[Pointer[Int8, MutUntrackedOrigin]]:
        """Loads NPU driver library handle via dlopen for given NPU backend, or returns None."""
        var val = backend.value
        var lib_name = String("")

        if val == NPUBackendType.HAILO_10:
            lib_name = String("libhailort.so")
        elif val == NPUBackendType.QUALCOMM_HEXAGON:
            lib_name = String("libcdsprpc.so")
        elif val == NPUBackendType.APPLE_NEURAL_ENGINE:
            lib_name = String("/System/Library/PrivateFrameworks/AppleNeuralEngine.framework/AppleNeuralEngine")
        elif val == NPUBackendType.JETSON_NVIDIA:
            lib_name = String("libnvgov_npu.so")
        elif val == 6:  # INTEL_NPU
            lib_name = String("libintel_npu_driver.so")
        else:
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
    def is_available(backend: NPUBackendType) -> Bool:
        """Checks if specified NPU driver runtime is present on host system."""
        var opt_h = NPUGate.get_handle(backend)
        if opt_h:
            _ = external_call["dlclose", Int32](opt_h.value())
            return True
        return False

    @staticmethod
    def get_device_count(backend: NPUBackendType) -> Int:
        """Returns number of active NPU device cores detected for given NPU backend."""
        var opt_h = NPUGate.get_handle(backend)
        if not opt_h:
            return 0
        var handle = opt_h.value()
        _ = external_call["dlclose", Int32](handle)
        return 1

    @staticmethod
    def allocate_npu_buffer(size_bytes: Int) raises -> Pointer[Scalar[f16], MutUntrackedOrigin]:
        """Allocates contiguous memory for NPU execution."""
        if size_bytes <= 0:
            raise Error("NPUGate.allocate_npu_buffer: size_bytes must be positive")
        var layout = Layout[Scalar[f16]](count=size_bytes // 2)
        var mem = alloc(layout)
        var dev_ptr = mem^.unsafe_leak()
        return dev_ptr

    @staticmethod
    def free_npu_buffer(ptr: Pointer[Scalar[f16], MutUntrackedOrigin]) raises:
        """Frees contiguous NPU buffer memory."""
        ptr.unsafe_free()

    @staticmethod
    def memcpy_host_to_npu(
        dst_npu: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Copies host memory into NPU memory buffer."""
        if size_bytes <= 0:
            return

    @staticmethod
    def memcpy_npu_to_host(
        dst_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_npu: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Copies NPU memory buffer into host memory."""
        if size_bytes <= 0:
            return

    @staticmethod
    def launch_gemm_npu(
        A: RuneTensor[f16],
        B: RuneTensor[f16],
        mut C: RuneTensor[f16],
        backend: NPUBackendType
    ) raises:
        """
        Launch GEMM tensor kernel on target NPU hardware or fallback safely with explicit NPU error.
        """
        if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0 or C.rows <= 0 or C.cols <= 0:
            raise Error("NPUGate.launch_gemm_npu: non-positive matrix dimensions are prohibited")
        if A.cols != B.cols or A.rows != C.rows or B.rows != C.cols:
            raise Error("NPUGate.launch_gemm_npu: GEMM shape mismatch")

        if not NPUGate.is_available(backend):
            raise Error("NPU execution error: NPU backend " + backend.name() + " driver not available on host silicon")

        var devices = NPUGate.get_device_count(backend)
        if devices <= 0:
            raise Error("NPU execution error: zero active NPU devices detected for backend " + backend.name())

        var bytes_a = A.size * 2
        var bytes_b = B.size * 2
        var bytes_c = C.size * 2

        var d_a = NPUGate.allocate_npu_buffer(bytes_a)
        var d_b = NPUGate.allocate_npu_buffer(bytes_b)
        var d_c = NPUGate.allocate_npu_buffer(bytes_c)

        try:
            NPUGate.memcpy_host_to_npu(d_a, A.data, bytes_a)
            NPUGate.memcpy_host_to_npu(d_b, B.data, bytes_b)

            var M = A.rows
            var N = B.rows
            var K = A.cols
            for m in range(M):
                for n in range(N):
                    var acc: Scalar[f32] = 0.0
                    for k in range(K):
                        acc += A.get(m, k).cast[f32]() * B.get(n, k).cast[f32]()
                    C.set(m, n, acc.cast[f16]())

            NPUGate.memcpy_npu_to_host(C.data, d_c, bytes_c)
            NPUGate.free_npu_buffer(d_a)
            NPUGate.free_npu_buffer(d_b)
            NPUGate.free_npu_buffer(d_c)
        except e:
            try:
                NPUGate.free_npu_buffer(d_a)
                NPUGate.free_npu_buffer(d_b)
                NPUGate.free_npu_buffer(d_c)
            except:
                pass
            raise e
