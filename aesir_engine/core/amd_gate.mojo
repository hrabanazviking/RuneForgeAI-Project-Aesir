# core/amd_gate.mojo
# AMDGate: Native POSIX FFI Gateway & Memory Management for AMD ROCm / HIP Realm (Jötunheim)

from std.ffi import external_call
from std.memory import Pointer
from std.collections import Optional
from core.mimir_well import Scalar, f16, RuneTensor

comptime RTLD_NOW = 2

struct AMDGate:
    """
    ᛁᛟ·ᚷᚨᛏᛖ — The Jötunheim Gateway to AMD ROCm / HIP Silicon (AMDGate)
    ════════════════════════════════════════════════════════════════════

    Native POSIX FFI interface to libamdhip64.so / libhipblas.so.
    Probes whether an AMD runtime library is loadable. Physical device
    discovery, HIP allocation, transfers, and kernel launch are unsupported.
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
        """Returns zero until hipGetDeviceCount is genuinely invoked."""
        return 0

    @staticmethod
    def allocate_vram(size_bytes: Int) raises -> Pointer[Scalar[f16], MutUntrackedOrigin]:
        """Rejects simulated HIP allocation until hipMalloc is integrated."""
        if size_bytes <= 0:
            raise Error("AMDGate.allocate_vram: size_bytes must be positive")
        raise Error("AMDGate.allocate_vram: physical HIP VRAM allocation is not implemented")

    @staticmethod
    def free_vram(ptr: Pointer[Scalar[f16], MutUntrackedOrigin]) raises:
        """Reserved AMD free entry point; always fails closed."""
        _ = ptr
        raise Error("AMDGate.free_vram: physical HIP VRAM ownership is not implemented")

    @staticmethod
    def memcpy_host_to_device(
        dst_dev: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Reserved AMD host-to-device transfer; always fails closed."""
        _ = dst_dev
        _ = src_host
        if size_bytes <= 0:
            return
        raise Error("AMDGate.memcpy_host_to_device: physical HIP transfer is not implemented")

    @staticmethod
    def memcpy_device_to_host(
        dst_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_dev: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Reserved AMD device-to-host transfer; always fails closed."""
        _ = dst_host
        _ = src_dev
        if size_bytes <= 0:
            return
        raise Error("AMDGate.memcpy_device_to_host: physical HIP transfer is not implemented")

    @staticmethod
    def launch_gemm_amd(
        A: RuneTensor[f16],
        B: RuneTensor[f16],
        mut C: RuneTensor[f16]
    ) raises:
        """
        Validates shapes and rejects execution until a real HIP kernel exists.
        """
        if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0 or C.rows <= 0 or C.cols <= 0:
            raise Error("AMDGate.launch_gemm_amd: non-positive matrix dimensions are prohibited")
        if A.cols != B.cols or A.rows != C.rows or B.rows != C.cols:
            raise Error("AMDGate.launch_gemm_amd: GEMM shape mismatch")

        raise Error("AMD ROCm HIP GPU execution is not implemented: no physical HIP kernel was launched")
