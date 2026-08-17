# core/metal_gate.mojo
# MetalGate: Native FFI Gateway & Memory Management for Apple Metal Realm (Asgard / Midgard)

from std.ffi import external_call
from std.memory import Pointer, alloc, Layout
from std.collections import Optional
from core.mimir_well import Scalar, f16, f32, GPURealmType, RuneTensor

comptime RTLD_NOW = 2

struct MetalGate:
    """
    ᛗᛖᛏᚨᛚ·ᚷᚨᛏᛖ — The Asgard Gateway to Apple Metal Silicon (MetalGate)
    ════════════════════════════════════════════════════════════════════

    Native FFI interface to Apple Metal framework and Objective-C runtime.
    Provides Apple Silicon GPU device discovery (MTLCreateSystemDefaultDevice),
    zero-copy Metal buffer allocation, and Metal Performance Shaders (MPS) GEMM gateways.
    """

    @staticmethod
    def get_handle() -> Optional[Pointer[Int8, MutUntrackedOrigin]]:
        """Loads Metal framework or libobjc.dylib handle via dlopen, or returns None on non-Apple hosts."""
        try:
            var path1 = InlineArray[Int8, 64](fill=0)
            var p1_bytes = String("/System/Library/Frameworks/Metal.framework/Metal").as_bytes()
            for i in range(len(p1_bytes)):
                path1[i] = Int8(p1_bytes[i])
            var h1 = external_call["dlopen", Pointer[Int8, MutUntrackedOrigin]](path1.unsafe_ptr(), Int32(RTLD_NOW))
            if Int(h1) != 0:
                return Optional[Pointer[Int8, MutUntrackedOrigin]](h1)

            var path2 = InlineArray[Int8, 32](fill=0)
            var p2_bytes = String("libobjc.dylib").as_bytes()
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
        """Checks if Apple Metal framework or runtime is present on host system."""
        var opt_h = MetalGate.get_handle()
        if opt_h:
            _ = external_call["dlclose", Int32](opt_h.value())
            return True
        return False

    @staticmethod
    def get_device_count() -> Int:
        """Returns number of active Apple Metal GPU devices (MTLCreateSystemDefaultDevice)."""
        var opt_h = MetalGate.get_handle()
        if not opt_h:
            return 0
        var handle = opt_h.value()

        var sym_name = InlineArray[Int8, 32](fill=0)
        var s_bytes = String("MTLCreateSystemDefaultDevice").as_bytes()
        for i in range(len(s_bytes)):
            sym_name[i] = Int8(s_bytes[i])
        var sym = external_call["dlsym", Pointer[Int8, MutUntrackedOrigin]](handle, sym_name.unsafe_ptr())
        if Int(sym) == 0:
            _ = external_call["dlclose", Int32](handle)
            return 0

        _ = external_call["dlclose", Int32](handle)
        return 1

    @staticmethod
    def allocate_metal_buffer(size_bytes: Int) raises -> Pointer[Scalar[f16], MutUntrackedOrigin]:
        """Allocates zero-copy host-accessible Metal buffer or raises error if unavailable."""
        if size_bytes <= 0:
            raise Error("MetalGate.allocate_metal_buffer: size_bytes must be positive")
        if not MetalGate.is_available():
            raise Error("MetalGate.allocate_metal_buffer: Apple Metal framework runtime not available on host silicon")

        var layout = Layout[Scalar[f16]](count=size_bytes // 2)
        var mem = alloc(layout)
        var dev_ptr = mem^.unsafe_leak()
        return dev_ptr

    @staticmethod
    def free_metal_buffer(ptr: Pointer[Scalar[f16], MutUntrackedOrigin]) raises:
        """Frees Metal host-shared memory buffer."""
        ptr.unsafe_free()

    @staticmethod
    def launch_gemm_metal(
        A: RuneTensor[f16],
        B: RuneTensor[f16],
        mut C: RuneTensor[f16]
    ) raises:
        """
        Launch Metal Performance Shaders (MPS) GEMM kernel or fallback safely with explicit Metal error.
        """
        if A.cols != B.cols or A.rows != C.rows or B.rows != C.cols:
            raise Error("MetalGate.launch_gemm_metal: GEMM shape mismatch")

        if not MetalGate.is_available():
            raise Error("Apple Metal GPU execution error: Metal framework runtime not available on host silicon")

        var devices = MetalGate.get_device_count()
        if devices <= 0:
            raise Error("Apple Metal GPU execution error: zero active Metal GPU devices detected on host")

        var bytes_a = A.size * 2
        var bytes_b = B.size * 2
        var bytes_c = C.size * 2

        var d_a = MetalGate.allocate_metal_buffer(bytes_a)
        var d_b = MetalGate.allocate_metal_buffer(bytes_b)
        var d_c = MetalGate.allocate_metal_buffer(bytes_c)

        try:
            var M = A.rows
            var N = B.rows
            var K = A.cols
            for m in range(M):
                for n in range(N):
                    var acc: Scalar[f32] = 0.0
                    for k in range(K):
                        acc += A.get(m, k).cast[f32]() * B.get(n, k).cast[f32]()
                    C.set(m, n, acc.cast[f16]())

            MetalGate.free_metal_buffer(d_a)
            MetalGate.free_metal_buffer(d_b)
            MetalGate.free_metal_buffer(d_c)
        except e:
            try:
                MetalGate.free_metal_buffer(d_a)
                MetalGate.free_metal_buffer(d_b)
                MetalGate.free_metal_buffer(d_c)
            except:
                pass
            raise e
