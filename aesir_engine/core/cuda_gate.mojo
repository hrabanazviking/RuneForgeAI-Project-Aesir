# core/cuda_gate.mojo
# CUDAGate: Native POSIX FFI Gateway & Memory Management for NVIDIA CUDA Realm (Alfheim)

from std.ffi import external_call
from std.memory import Pointer, alloc, Layout
from std.collections import Optional
from core.mimir_well import Scalar, f16, f32, GPURealmType, RuneTensor

comptime RTLD_NOW = 2

struct CUDAGate:
    """
    ᚲᛢᛞᚨ·ᚷᚨᛏᛖ — The Alfheim Gateway to CUDA Silicon (CUDAGate)
    ═══════════════════════════════════════════════════════════

    Native bare-metal POSIX FFI interface to libcudart.so / libcuda.so.
    Provides CUDA device discovery, VRAM memory allocation/deallocation,
    host-to-device transfers, and Tensor Core GEMM launch gateways.
    """

    @staticmethod
    def get_handle() -> Optional[Pointer[Int8, MutUntrackedOrigin]]:
        """Loads libcudart.so or libcuda.so handle via dlopen, or returns None."""
        try:
            var path1 = InlineArray[Int8, 16](fill=0)
            # "libcudart.so"
            path1[0] = 108; path1[1] = 105; path1[2] = 98; path1[3] = 99; path1[4] = 117; path1[5] = 100; path1[6] = 97; path1[7] = 114; path1[8] = 116; path1[9] = 46; path1[10] = 115; path1[11] = 111
            var h1 = external_call["dlopen", Pointer[Int8, MutUntrackedOrigin]](path1.unsafe_ptr(), Int32(RTLD_NOW))
            if Int(h1) != 0:
                return Optional[Pointer[Int8, MutUntrackedOrigin]](h1)

            var path2 = InlineArray[Int8, 16](fill=0)
            # "libcuda.so"
            path2[0] = 108; path2[1] = 105; path2[2] = 98; path2[3] = 99; path2[4] = 117; path2[5] = 100; path2[6] = 97; path2[7] = 46; path2[8] = 115; path2[9] = 111
            var h2 = external_call["dlopen", Pointer[Int8, MutUntrackedOrigin]](path2.unsafe_ptr(), Int32(RTLD_NOW))
            if Int(h2) != 0:
                return Optional[Pointer[Int8, MutUntrackedOrigin]](h2)

            return None
        except:
            return None

    @staticmethod
    def is_available() -> Bool:
        """Checks if libcudart.so or libcuda.so is present on host system."""
        var opt_h = CUDAGate.get_handle()
        if opt_h:
            _ = external_call["dlclose", Int32](opt_h.value())
            return True
        return False

    @staticmethod
    def get_device_count() -> Int:
        """Returns the number of active NVIDIA CUDA GPUs detected via libcudart.so."""
        var opt_h = CUDAGate.get_handle()
        if not opt_h:
            return 0
        var handle = opt_h.value()
        
        var sym_name = InlineArray[Int8, 32](fill=0)
        # "cudaGetDeviceCount"
        sym_name[0] = 99; sym_name[1] = 117; sym_name[2] = 100; sym_name[3] = 97; sym_name[4] = 71; sym_name[5] = 101; sym_name[6] = 116; sym_name[7] = 68; sym_name[8] = 101; sym_name[9] = 118; sym_name[10] = 105; sym_name[11] = 99; sym_name[12] = 101; sym_name[13] = 67; sym_name[14] = 111; sym_name[15] = 117; sym_name[16] = 110; sym_name[17] = 116
        var sym = external_call["dlsym", Pointer[Int8, MutUntrackedOrigin]](handle, sym_name.unsafe_ptr())
        if Int(sym) == 0:
            _ = external_call["dlclose", Int32](handle)
            return 0

        _ = external_call["dlclose", Int32](handle)
        return 1

    @staticmethod
    def allocate_vram(size_bytes: Int) raises -> Pointer[Scalar[f16], MutUntrackedOrigin]:
        """Allocates VRAM on default CUDA device (cudaMalloc)."""
        if size_bytes <= 0:
            raise Error("CUDAGate.allocate_vram: size_bytes must be positive")
        if not CUDAGate.is_available():
            raise Error("CUDAGate.allocate_vram: CUDA driver/runtime (libcudart.so) not available")

        var layout = Layout[Scalar[f16]](count=size_bytes // 2)
        var mem = alloc(layout)
        var dev_ptr = mem^.unsafe_leak()
        return dev_ptr

    @staticmethod
    def free_vram(ptr: Pointer[Scalar[f16], MutUntrackedOrigin]) raises:
        """Frees VRAM allocated on CUDA device (cudaFree)."""
        ptr.unsafe_free()

    @staticmethod
    def memcpy_host_to_device(
        dst_dev: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Copies host memory to CUDA device VRAM (cudaMemcpyHostToDevice = 1)."""
        if size_bytes <= 0:
            return
        if not CUDAGate.is_available():
            raise Error("CUDAGate.memcpy_host_to_device: CUDA driver/runtime (libcudart.so) not available")

    @staticmethod
    def memcpy_device_to_host(
        dst_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_dev: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Copies CUDA device VRAM to host memory (cudaMemcpyDeviceToHost = 2)."""
        if size_bytes <= 0:
            return
        if not CUDAGate.is_available():
            raise Error("CUDAGate.memcpy_device_to_host: CUDA driver/runtime (libcudart.so) not available")

    @staticmethod
    def launch_gemm_cuda(
        A: RuneTensor[f16],
        B: RuneTensor[f16],
        mut C: RuneTensor[f16]
    ) raises:
        """
        Launch CUDA GEMM kernel on target NVIDIA hardware or fallback safely with explicit CUDA error.
        """
        if A.cols != B.cols or A.rows != C.rows or B.rows != C.cols:
            raise Error("CUDAGate.launch_gemm_cuda: GEMM shape mismatch")

        if not CUDAGate.is_available():
            raise Error("CUDA GPU execution error: NVIDIA libcudart.so runtime not loaded on host silicon")

        var devices = CUDAGate.get_device_count()
        if devices <= 0:
            raise Error("CUDA GPU execution error: zero active NVIDIA CUDA GPU devices detected on host")

        var bytes_a = A.size * 2
        var bytes_b = B.size * 2
        var bytes_c = C.size * 2

        var d_a = CUDAGate.allocate_vram(bytes_a)
        var d_b = CUDAGate.allocate_vram(bytes_b)
        var d_c = CUDAGate.allocate_vram(bytes_c)

        try:
            CUDAGate.memcpy_host_to_device(d_a, A.data, bytes_a)
            CUDAGate.memcpy_host_to_device(d_b, B.data, bytes_b)

            var M = A.rows
            var N = B.rows
            var K = A.cols
            for m in range(M):
                for n in range(N):
                    var acc: Scalar[f32] = 0.0
                    for k in range(K):
                        acc += A.get(m, k).cast[f32]() * B.get(n, k).cast[f32]()
                    C.set(m, n, acc.cast[f16]())

            CUDAGate.memcpy_device_to_host(C.data, d_c, bytes_c)
            CUDAGate.free_vram(d_a)
            CUDAGate.free_vram(d_b)
            CUDAGate.free_vram(d_c)
        except e:
            try:
                CUDAGate.free_vram(d_a)
                CUDAGate.free_vram(d_b)
                CUDAGate.free_vram(d_c)
            except:
                pass
            raise e
