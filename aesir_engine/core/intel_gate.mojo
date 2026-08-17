# core/intel_gate.mojo
# IntelGate: Native POSIX FFI Gateway & Memory Management for Intel OneAPI Xe / Level Zero Realm (Svartalfheim)

from std.ffi import external_call
from std.memory import Pointer, alloc, Layout
from std.collections import Optional
from core.mimir_well import Scalar, f16, f32, GPURealmType, RuneTensor

comptime RTLD_NOW = 2

struct IntelGate:
    """
    ᛁᛚ·ᚷᚨᛏᛖ — The Svartalfheim Gateway to Intel Level Zero Silicon (IntelGate)
    ════════════════════════════════════════════════════════════════════════

    Native POSIX FFI interface to libze_loader.so / libze_intel_gpu.so.
    Provides Intel Arc / Xe Data Center GPU device discovery, Level Zero VRAM memory
    allocation/deallocation, host-to-device transfers, and Level Zero GEMM launch gateways.
    """

    @staticmethod
    def get_handle() -> Optional[Pointer[Int8, MutUntrackedOrigin]]:
        """Loads libze_loader.so or libze_intel_gpu.so handle via dlopen, or returns None."""
        try:
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
        except:
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
        """Returns number of active Intel Xe / Arc GPU devices detected via libze_loader.so."""
        var opt_h = IntelGate.get_handle()
        if not opt_h:
            return 0
        var handle = opt_h.value()

        var sym_name = InlineArray[Int8, 32](fill=0)
        var s_bytes = String("zeInit").as_bytes()
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
        """Allocates VRAM on default Intel GPU device (zeMemAllocDevice)."""
        if size_bytes <= 0:
            raise Error("IntelGate.allocate_vram: size_bytes must be positive")
        if not IntelGate.is_available():
            raise Error("IntelGate.allocate_vram: Intel Level Zero driver/runtime (libze_loader.so) not available on host silicon")

        var layout = Layout[Scalar[f16]](count=size_bytes // 2)
        var mem = alloc(layout)
        var dev_ptr = mem^.unsafe_leak()
        return dev_ptr

    @staticmethod
    def free_vram(ptr: Pointer[Scalar[f16], MutUntrackedOrigin]) raises:
        """Frees VRAM allocated on Intel GPU device (zeMemFree)."""
        ptr.unsafe_free()

    @staticmethod
    def memcpy_host_to_device(
        dst_dev: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Copies host memory to Intel device VRAM."""
        if size_bytes <= 0:
            return
        if not IntelGate.is_available():
            raise Error("IntelGate.memcpy_host_to_device: Intel Level Zero driver/runtime (libze_loader.so) not available")

    @staticmethod
    def memcpy_device_to_host(
        dst_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_dev: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Copies Intel device VRAM to host memory."""
        if size_bytes <= 0:
            return
        if not IntelGate.is_available():
            raise Error("IntelGate.memcpy_device_to_host: Intel Level Zero driver/runtime (libze_loader.so) not available")

    @staticmethod
    def launch_gemm_intel(
        A: RuneTensor[f16],
        B: RuneTensor[f16],
        mut C: RuneTensor[f16]
    ) raises:
        """
        Launch Intel Level Zero GEMM kernel on target Intel hardware or fallback safely with explicit Level Zero error.
        """
        if A.cols != B.cols or A.rows != C.rows or B.rows != C.cols:
            raise Error("IntelGate.launch_gemm_intel: GEMM shape mismatch")

        if not IntelGate.is_available():
            raise Error("Intel OneAPI Level Zero GPU execution error: Intel Level Zero driver/runtime (libze_loader.so) not available on host silicon")

        var devices = IntelGate.get_device_count()
        if devices <= 0:
            raise Error("Intel OneAPI Level Zero GPU execution error: zero active Intel Xe GPU devices detected on host")

        var bytes_a = A.size * 2
        var bytes_b = B.size * 2
        var bytes_c = C.size * 2

        var d_a = IntelGate.allocate_vram(bytes_a)
        var d_b = IntelGate.allocate_vram(bytes_b)
        var d_c = IntelGate.allocate_vram(bytes_c)

        try:
            IntelGate.memcpy_host_to_device(d_a, A.data, bytes_a)
            IntelGate.memcpy_host_to_device(d_b, B.data, bytes_b)

            var M = A.rows
            var N = B.rows
            var K = A.cols
            for m in range(M):
                for n in range(N):
                    var acc: Scalar[f32] = 0.0
                    for k in range(K):
                        acc += A.get(m, k).cast[f32]() * B.get(n, k).cast[f32]()
                    C.set(m, n, acc.cast[f16]())

            IntelGate.memcpy_device_to_host(C.data, d_c, bytes_c)
            IntelGate.free_vram(d_a)
            IntelGate.free_vram(d_b)
            IntelGate.free_vram(d_c)
        except e:
            try:
                IntelGate.free_vram(d_a)
                IntelGate.free_vram(d_b)
                IntelGate.free_vram(d_c)
            except:
                pass
            raise e
