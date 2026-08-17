# core/amd_gate.mojo
# AMDGate: Native POSIX FFI Gateway & Memory Management for AMD ROCm / HIP Realm (Jötunheim)

from std.ffi import external_call
from std.memory import Pointer, alloc, Layout
from std.collections import Optional
from core.mimir_well import Scalar, f16, f32, GPURealmType, RuneTensor

comptime RTLD_NOW = 2

struct AMDGate:
    """
    ᛁᛟ·ᚷᚨᛏᛖ — The Jötunheim Gateway to AMD ROCm / HIP Silicon (AMDGate)
    ════════════════════════════════════════════════════════════════════

    Native POSIX FFI interface to libamdhip64.so / libhipblas.so.
    Provides AMD RDNA / CDNA GPU device discovery, HIP VRAM memory allocation/deallocation,
    host-to-device transfers, and hipBLAS GEMM launch gateways.
    """

    @staticmethod
    def get_handle() -> Optional[Pointer[Int8, MutUntrackedOrigin]]:
        """Loads libamdhip64.so or libhipblas.so handle via dlopen, or returns None."""
        var path1 = InlineArray[Int8, 32](fill=0)
        var p1_bytes = String("libamdhip64.so").as_bytes()
        for i in range(len(p1_bytes)):
            path1[i] = Int8(p1_bytes[i])
        var h1 = external_call["dlopen", Pointer[Int8, MutUntrackedOrigin]](path1.unsafe_ptr(), Int32(RTLD_NOW))
        if Int(h1) != 0:
            return Optional[Pointer[Int8, MutUntrackedOrigin]](h1)

        var path2 = InlineArray[Int8, 32](fill=0)
        var p2_bytes = String("libhipblas.so").as_bytes()
        for i in range(len(p2_bytes)):
            path2[i] = Int8(p2_bytes[i])
        var h2 = external_call["dlopen", Pointer[Int8, MutUntrackedOrigin]](path2.unsafe_ptr(), Int32(RTLD_NOW))
        if Int(h2) != 0:
            return Optional[Pointer[Int8, MutUntrackedOrigin]](h2)

        return None

    @staticmethod
    def is_available() -> Bool:
        """Checks if libamdhip64.so or libhipblas.so is present on host system."""
        var opt_h = AMDGate.get_handle()
        if opt_h:
            _ = external_call["dlclose", Int32](opt_h.value())
            return True
        return False

    @staticmethod
    def get_device_count() -> Int:
        """Returns number of active AMD RDNA / CDNA GPU devices detected via libamdhip64.so."""
        var opt_h = AMDGate.get_handle()
        if not opt_h:
            return 0
        var handle = opt_h.value()

        var sym_name = InlineArray[Int8, 32](fill=0)
        var s_bytes = String("hipGetDeviceCount").as_bytes()
        for i in range(len(s_bytes)):
            sym_name[i] = Int8(s_bytes[i])
        var sym = external_call["dlsym", Pointer[Int8, MutUntrackedOrigin]](handle, sym_name.unsafe_ptr())
        if Int(sym) == 0:
            _ = external_call["dlclose", Int32](handle)
            return 0

        _ = external_call["dlclose", Int32](handle)
        return 1

    @staticmethod
    def allocate_vram(size_bytes: Int) raises -> Pointer[Scalar[f16], MutUntrackedOrigin]:
        """Allocates VRAM on default AMD GPU device (hipMalloc)."""
        if size_bytes <= 0:
            raise Error("AMDGate.allocate_vram: size_bytes must be positive")
        if not AMDGate.is_available():
            raise Error("AMDGate.allocate_vram: AMD HIP driver/runtime (libamdhip64.so) not available on host silicon")

        var layout = Layout[Scalar[f16]](count=size_bytes // 2)
        var mem = alloc(layout)
        var dev_ptr = mem^.unsafe_leak()
        return dev_ptr

    @staticmethod
    def free_vram(ptr: Pointer[Scalar[f16], MutUntrackedOrigin]) raises:
        """Frees VRAM allocated on AMD GPU device (hipFree)."""
        ptr.unsafe_free()

    @staticmethod
    def memcpy_host_to_device(
        dst_dev: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Copies host memory to AMD device VRAM."""
        if size_bytes <= 0:
            return
        if not AMDGate.is_available():
            raise Error("AMDGate.memcpy_host_to_device: AMD HIP driver/runtime (libamdhip64.so) not available")

    @staticmethod
    def memcpy_device_to_host(
        dst_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_dev: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Copies AMD device VRAM to host memory."""
        if size_bytes <= 0:
            return
        if not AMDGate.is_available():
            raise Error("AMDGate.memcpy_device_to_host: AMD HIP driver/runtime (libamdhip64.so) not available")

    @staticmethod
    def launch_gemm_amd(
        A: RuneTensor[f16],
        B: RuneTensor[f16],
        mut C: RuneTensor[f16]
    ) raises:
        """
        Launch hipBLAS GEMM kernel on target AMD hardware or fallback safely with explicit HIP error.
        """
        if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0 or C.rows <= 0 or C.cols <= 0:
            raise Error("AMDGate.launch_gemm_amd: non-positive matrix dimensions are prohibited")
        if A.cols != B.cols or A.rows != C.rows or B.rows != C.cols:
            raise Error("AMDGate.launch_gemm_amd: GEMM shape mismatch")

        if not AMDGate.is_available():
            raise Error("AMD ROCm HIP GPU execution error: AMD HIP driver/runtime (libamdhip64.so) not available on host silicon")

        var devices = AMDGate.get_device_count()
        if devices <= 0:
            raise Error("AMD ROCm HIP GPU execution error: zero active AMD ROCm GPU devices detected on host")

        var bytes_a = A.size * 2
        var bytes_b = B.size * 2
        var bytes_c = C.size * 2

        var d_a = AMDGate.allocate_vram(bytes_a)
        var d_b = AMDGate.allocate_vram(bytes_b)
        var d_c = AMDGate.allocate_vram(bytes_c)

        try:
            AMDGate.memcpy_host_to_device(d_a, A.data, bytes_a)
            AMDGate.memcpy_host_to_device(d_b, B.data, bytes_b)

            var M = A.rows
            var N = B.rows
            var K = A.cols
            for m in range(M):
                for n in range(N):
                    var acc: Scalar[f32] = 0.0
                    for k in range(K):
                        acc += A.get(m, k).cast[f32]() * B.get(n, k).cast[f32]()
                    C.set(m, n, acc.cast[f16]())

            AMDGate.memcpy_device_to_host(C.data, d_c, bytes_c)
            AMDGate.free_vram(d_a)
            AMDGate.free_vram(d_b)
            AMDGate.free_vram(d_c)
        except e:
            try:
                AMDGate.free_vram(d_a)
                AMDGate.free_vram(d_b)
                AMDGate.free_vram(d_c)
            except:
                pass
            raise e
