# core/intel_gate.mojo
# IntelGate: Native POSIX FFI Gateway & Memory Management for Intel OneAPI Xe / Level Zero Realm (Svartalfheim)

from std.ffi import external_call
from std.memory import Pointer
from std.collections import Optional
from core.mimir_well import Scalar, f16, RuneTensor

comptime RTLD_NOW = 2

struct IntelGate:
    """
    ᛁᛚ·ᚷᚨᛏᛖ — The Svartalfheim Gateway to Intel Level Zero Silicon (IntelGate)
    ════════════════════════════════════════════════════════════════════════

    Native POSIX FFI interface to libze_loader.so / libze_intel_gpu.so.
    Probes whether a Level Zero runtime library is loadable. Physical device
    discovery, allocation, transfers, and kernel launch are unsupported.
    """

    @staticmethod
    def get_handle() -> Optional[Pointer[Int8, MutUntrackedOrigin]]:
        """Loads libze_loader.so or libze_intel_gpu.so handle via dlopen, or returns None."""
        var path1 = InlineArray[Int8, 32](fill=0)
        var p1_bytes = String("libze_loader.so").as_bytes()
        for i in range(len(p1_bytes)):
            path1[i] = Int8(p1_bytes[i])
        var h1 = external_call["dlopen", Pointer[Int8, MutUntrackedOrigin]](path1.unsafe_ptr(), Int32(RTLD_NOW))
        if Int(h1) != 0:
            return Optional[Pointer[Int8, MutUntrackedOrigin]](h1)

        var path2 = InlineArray[Int8, 32](fill=0)
        var p2_bytes = String("libze_intel_gpu.so").as_bytes()
        for i in range(len(p2_bytes)):
            path2[i] = Int8(p2_bytes[i])
        var h2 = external_call["dlopen", Pointer[Int8, MutUntrackedOrigin]](path2.unsafe_ptr(), Int32(RTLD_NOW))
        if Int(h2) != 0:
            return Optional[Pointer[Int8, MutUntrackedOrigin]](h2)

        return None

    @staticmethod
    def is_available() -> Bool:
        """Checks if libze_loader.so or libze_intel_gpu.so is present on host system."""
        var opt_h = IntelGate.get_handle()
        if opt_h:
            _ = external_call["dlclose", Int32](opt_h.value())
            return True
        return False

    @staticmethod
    def get_device_count() -> Int:
        """Returns zero until Level Zero device enumeration is genuinely invoked."""
        return 0

    @staticmethod
    def allocate_vram(size_bytes: Int) raises -> Pointer[Scalar[f16], MutUntrackedOrigin]:
        """Reserved Intel allocation entry point; always fails closed."""
        if size_bytes <= 0:
            raise Error("IntelGate.allocate_vram: size_bytes must be positive")
        raise Error("IntelGate.allocate_vram: physical Level Zero allocation is not implemented")

    @staticmethod
    def free_vram(ptr: Pointer[Scalar[f16], MutUntrackedOrigin]) raises:
        """Reserved Intel free entry point; always fails closed."""
        _ = ptr
        raise Error("IntelGate.free_vram: physical Level Zero ownership is not implemented")

    @staticmethod
    def memcpy_host_to_device(
        dst_dev: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Reserved Intel host-to-device transfer; always fails closed."""
        _ = dst_dev
        _ = src_host
        if size_bytes <= 0:
            return
        raise Error("IntelGate.memcpy_host_to_device: physical Level Zero transfer is not implemented")

    @staticmethod
    def memcpy_device_to_host(
        dst_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_dev: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Reserved Intel device-to-host transfer; always fails closed."""
        _ = dst_host
        _ = src_dev
        if size_bytes <= 0:
            return
        raise Error("IntelGate.memcpy_device_to_host: physical Level Zero transfer is not implemented")

    @staticmethod
    def launch_gemm_intel(
        A: RuneTensor[f16],
        B: RuneTensor[f16],
        mut C: RuneTensor[f16]
    ) raises:
        """
        Validates shapes and rejects execution until a real Level Zero kernel exists.
        """
        if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0 or C.rows <= 0 or C.cols <= 0:
            raise Error("IntelGate.launch_gemm_intel: non-positive matrix dimensions are prohibited")
        if A.cols != B.cols or A.rows != C.rows or B.rows != C.cols:
            raise Error("IntelGate.launch_gemm_intel: GEMM shape mismatch")

        raise Error("Intel Level Zero GPU execution is not implemented: no physical kernel was launched")
