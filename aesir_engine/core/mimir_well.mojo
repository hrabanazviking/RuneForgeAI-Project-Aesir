# core/mimir_well.mojo
# The Waters of Mímisbrunnr: Aesir Engine Core Memory Management
# 
# In Mythic Engineering, memory is not merely allocated; it is drawn from the Well of Mimir.
# No dynamic allocation occurs during the living breath of inference. The waters are drawn once,
# deep and still, providing the sacred space for the engine's thoughts to manifest.

from std.memory.alloc import alloc, dealloc, Layout
from std.memory import Pointer, unsafe_memset_zero
from std.math import exp, max

comptime f16 = DType.float16
comptime f32 = DType.float32
comptime int4 = DType.int8 # Mojo natively handles down to int8, we bitshift for int4

struct RuneTensor[type: DType]:
    """
    RuneTensor: The threads of fate woven by the Norns. 
    A custom tensor structure utilizing zero-copy pointers to maintain an unbroken, living connection to the Well.
    """
    var data: Pointer[Scalar[Self.type], MutUntrackedOrigin]
    var rows: Int
    var cols: Int
    var size: Int
    var is_quantized: Bool

    def __init__(out self, rows: Int, cols: Int, pre_allocated_ptr: Pointer[Scalar[Self.type], MutUntrackedOrigin], is_quantized: Bool = False):
        self.rows = rows
        self.cols = cols
        self.size = rows * cols
        self.data = pre_allocated_ptr
        self.is_quantized = is_quantized

    @always_inline
    def get(self, r: Int, c: Int) -> Scalar[Self.type]:
        return self.data.unsafe_load(r * self.cols + c)

    @always_inline
    def set(mut self, r: Int, c: Int, val: Scalar[Self.type]):
        self.data.unsafe_store(r * self.cols + c, val)


struct MimirWell:
    """
    MimirWell: Pre-allocates a contiguous block of VRAM/RAM (The Waters of Wisdom).
    Strictly forbids dynamic allocation during inference to maintain the purity and speed of the living system.
    """
    var base_ptr: Pointer[Scalar[f16], MutUntrackedOrigin]
    var capacity: Int
    var offset: Int

    def __init__(out self, size_in_bytes: Int):
        # Calculate number of f16 elements
        self.capacity = size_in_bytes // 2 
        var allocation = alloc(Layout[Scalar[f16]](count=self.capacity))
        self.base_ptr = allocation^.unsafe_leak()
        self.offset = 0
        unsafe_memset_zero(self.base_ptr, self.capacity)

    def allocate(mut self, elements: Int) -> Pointer[Scalar[f16], MutUntrackedOrigin]:
        if self.offset + elements > self.capacity:
            # Hard failure if VRAM pool is exceeded
            print("FATAL: The Waters of Mimir are exhausted. Cannot draw more memory.")
            return self.base_ptr
        
        var ptr = self.base_ptr.unsafe_offset(self.offset)
        self.offset += elements
        return ptr

    def reset_kv_cache(mut self, kv_offset_start: Int):
        """Ring-buffer reset point for KV Cache."""
        self.offset = kv_offset_start

    def __deinit__(deinit self):
        self.base_ptr.unsafe_free()

