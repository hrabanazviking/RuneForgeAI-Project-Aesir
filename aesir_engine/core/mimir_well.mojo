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

struct NPUBackendType(Copyable, ImplicitlyCopyable):
    """
    ᚾᛈᚢ·ᛒᚨᚲᚲᛖᚾᛞ·ᛏᚤᛈᛖ — The Sigil of Edge Realms (NPUBackendType)
    ══════════════════════════════════════════════════════════════════

    Each integer constant names a sovereign compute spirit — a Dvergar craftsman
    forged in a different land of silicon, each with its own architecture of
    data-paths and tensor-pipelines:

      0 · HAILO_10           — The Hailo Spear of the Edge (Hailo-10 NPU):
                               Event-driven dataflow NPU with dedicated on-chip SRAM.
                               Routes matrix ops through fixed compiled dataflow graphs.
                               Sovereign over edge computer-vision inference (<26 TOPS).

      1 · QUALCOMM_HEXAGON   — The Hexagon Warden of Midgard's Palm (Qualcomm DSP/HTA):
                               Qualcomm Hexagon Tensor Accelerator (HTA) embedded within
                               Snapdragon SoCs. Executes vectorized VLIW DSP instructions
                               alongside dedicated HVX (Hexagon Vector eXtensions) lanes.
                               Master of mobile-edge transformer inference.

      2 · ARM_NEON           — The NEON Weaver of the Iron Thread (ARM NEON/SVE):
                               128-bit SIMD vector ISA intrinsic to all Cortex-A and
                               Apple Silicon cores. Executes 8 × f16 FMAs per cycle per core.
                               Default runic path when no dedicated NPU spirit is present.

      3 · JETSON_NVIDIA       — The Volta/Ampere Torch of the Jetson Shore (NVIDIA Jetson):
                               CUDA-capable GPU tensor cores on Jetson Nano/Orin/Xavier.
                               Falls through to `gemm_f16` (the 32×32 SIMD tiled CUDA path).

      4 · APPLE_NEURAL_ENGINE — The Neural Engine of Valhöll's Tablet (Apple ANE):
                               Apple Neural Engine — 16-core fixed-function matrix engine
                               on M-series and A-series SoCs. 15.8–38 TOPS at sub-5W TDP.
                               Routes through ARM NEON fallback pending Core ML bridge.

      5 · GENERIC_NPU        — The Unnamed Forge Spirit (Generic NPU):
                               Fallback realm for unrecognized edge accelerators.
                               Routes through the universal SIMD GEMM path.

    This struct is a zero-overhead discriminated integer tag — no vtable, no heap,
    no dynamic dispatch overhead. The selection rune is read once at dispatch time
    and the correct kernel stream is struck directly.
    """
    comptime HAILO_10 = 0
    comptime QUALCOMM_HEXAGON = 1
    comptime ARM_NEON = 2
    comptime JETSON_NVIDIA = 3
    comptime APPLE_NEURAL_ENGINE = 4
    comptime GENERIC_NPU = 5

    var value: Int

    def __init__(out self, value: Int = 2):
        self.value = value

    def __copyinit__(out self, existing: Self):
        self.value = existing.value

    @always_inline
    def copy(self) -> Self:
        return Self(self.value)

    @always_inline
    def __eq__(self, rhs: Self) -> Bool:
        return self.value == rhs.value

    @always_inline
    def __eq__(self, rhs: Int) -> Bool:
        return self.value == rhs

    @always_inline
    def __ne__(self, rhs: Self) -> Bool:
        return self.value != rhs.value

    @always_inline
    def __ne__(self, rhs: Int) -> Bool:
        return self.value != rhs

    def name(self) -> String:
        if self.value == 0:
            return "HAILO_10"
        elif self.value == 1:
            return "QUALCOMM_HEXAGON"
        elif self.value == 2:
            return "ARM_NEON"
        elif self.value == 3:
            return "JETSON_NVIDIA"
        elif self.value == 4:
            return "APPLE_NEURAL_ENGINE"
        else:
            return "GENERIC_NPU"


struct GPURealmType(Copyable, ImplicitlyCopyable):
    """
    ᚷᛈᚢ·ᚱᛖᚨᛚᛗ·ᛏᚤᛈᛖ — The Sigil of Universal GPU Realms (GPURealmType)
    ═════════════════════════════════════════════════════════════════════════

    A zero-overhead discriminated integer tag naming ten sovereign compute GPU hardware realms
    forged across global silicon in Asgard, Midgard, and Eastern realms:

      0 · NVIDIA_CUDA         — NVIDIA GeForce RTX / H100 / A100 / L40S / Jetson CUDA Tensor Cores
      1 · AMD_ROCM_HIP        — AMD Instinct MI300/MI250 & Radeon RX 7000/6000 (hipBLAS/ROCm/RDNA3)
      2 · INTEL_ONEAPI_XE     — Intel Arc A770 & Data Center GPU Max (Flex/Ponte Vecchio/Xe-HPG)
      3 · MOORE_THREADS_MUSA  — Moore Threads MTT S80 / S4000 (MUSA GPGPU architecture, China)
      4 · BIREN_SUPA          — Biren Technology BR100 / BR104 (SUPA GPGPU architecture, China)
      5 · METAX_MACA          — MetaX C500 / N100 (MACA GPGPU architecture, China)
      6 · HYGON_DCU           — Hygon Haiguang DCU (Zhaoxin/DTK GPGPU architecture, China)
      7 · ARM_MALI_OPENCL     — ARM Mali-G78 & Immortalis (Smartphones, VR Headsets, Wearables)
      8 · QUALCOMM_ADRENO     — Qualcomm Adreno 740/750 (Snapdragon XR2 VR Headsets, Mobile SoCs, Watches)
      9 · IMAGINATION_POWERVR — Imagination PowerVR / B-Series (Embedded IoT / Automotive / Appliances)

    The selection rune operates without vtables, dynamic heap allocations, or virtual method dispatch overhead.
    """
    comptime NVIDIA_CUDA = 0
    comptime AMD_ROCM_HIP = 1
    comptime INTEL_ONEAPI_XE = 2
    comptime MOORE_THREADS_MUSA = 3
    comptime BIREN_SUPA = 4
    comptime METAX_MACA = 5
    comptime HYGON_DCU = 6
    comptime ARM_MALI_OPENCL = 7
    comptime QUALCOMM_ADRENO = 8
    comptime IMAGINATION_POWERVR = 9

    var value: Int

    def __init__(out self, value: Int = 0):
        self.value = value

    def __copyinit__(out self, existing: Self):
        self.value = existing.value

    @always_inline
    def copy(self) -> Self:
        return Self(self.value)

    @always_inline
    def __eq__(self, rhs: Self) -> Bool:
        return self.value == rhs.value

    @always_inline
    def __eq__(self, rhs: Int) -> Bool:
        return self.value == rhs

    @always_inline
    def __ne__(self, rhs: Self) -> Bool:
        return self.value != rhs.value

    @always_inline
    def __ne__(self, rhs: Int) -> Bool:
        return self.value != rhs

    def name(self) -> String:
        if self.value == 0:
            return "NVIDIA_CUDA"
        elif self.value == 1:
            return "AMD_ROCM_HIP"
        elif self.value == 2:
            return "INTEL_ONEAPI_XE"
        elif self.value == 3:
            return "MOORE_THREADS_MUSA"
        elif self.value == 4:
            return "BIREN_SUPA"
        elif self.value == 5:
            return "METAX_MACA"
        elif self.value == 6:
            return "HYGON_DCU"
        elif self.value == 7:
            return "ARM_MALI_OPENCL"
        elif self.value == 8:
            return "QUALCOMM_ADRENO"
        elif self.value == 9:
            return "IMAGINATION_POWERVR"
        else:
            return "GENERIC_GPU"


struct CompressedFormatType(Copyable, ImplicitlyCopyable):
    """
    ᚲᛟᛗᛈᚱᛖᛋᛋᛖᛞ·ᚠᛟᛱᛗᚨᛏ — The Sigil of Universal Compressed LLM Formats (CompressedFormatType)
    ════════════════════════════════════════════════════════════════════════════════════════════════

    Discriminates 21 universal sub-byte, integer, and block-compressed LLM formats:
      0  · Q2_K             — 2-bit K-quantization block format
      1  · Q3_K_S           — 3-bit K-quantization small format
      2  · Q3_K_M           — 3-bit K-quantization medium format
      3  · Q3_K_L           — 3-bit K-quantization large format
      4  · Q4_0             — Legacy 4-bit block quantization (scale only)
      5  · Q4_1             — Legacy 4-bit block quantization (scale + min)
      6  · Q4_K_S           — 4-bit K-quantization small format
      7  · Q4_K_M           — 4-bit K-quantization medium format (default rune)
      8  · Q5_0             — Legacy 5-bit block quantization (scale only)
      9  · Q5_1             — Legacy 5-bit block quantization (scale + min)
      10 · Q5_K_S           — 5-bit K-quantization small format
      11 · Q5_K_M           — 5-bit K-quantization medium format
      12 · Q6_K             — 6-bit K-quantization block format
      13 · Q8_0             — 8-bit block quantization (scale only)
      14 · Q8_1             — 8-bit block quantization (scale + min)
      15 · GPTQ_4BIT        — GPTQ 4-bit weight-only quantization
      16 · GPTQ_8BIT        — GPTQ 8-bit weight-only quantization
      17 · AWQ_4BIT         — Activation-aware Weight Quantization (AWQ 4-bit)
      18 · EXL2_VARBIT      — ExLlamaV2 variable bitrate quantization
      19 · HQQ              — Half-Quadratic Quantization (HQQ)
      20 · SMOOTHQUANT_INT8 — SmoothQuant INT8 activation/weight quantization

    The selection rune operates without vtables, dynamic heap allocations, or virtual method dispatch overhead.
    """
    comptime Q2_K = 0
    comptime Q3_K_S = 1
    comptime Q3_K_M = 2
    comptime Q3_K_L = 3
    comptime Q4_0 = 4
    comptime Q4_1 = 5
    comptime Q4_K_S = 6
    comptime Q4_K_M = 7
    comptime Q5_0 = 8
    comptime Q5_1 = 9
    comptime Q5_K_S = 10
    comptime Q5_K_M = 11
    comptime Q6_K = 12
    comptime Q8_0 = 13
    comptime Q8_1 = 14
    comptime GPTQ_4BIT = 15
    comptime GPTQ_8BIT = 16
    comptime AWQ_4BIT = 17
    comptime EXL2_VARBIT = 18
    comptime HQQ = 19
    comptime SMOOTHQUANT_INT8 = 20

    var value: Int

    def __init__(out self, value: Int = 7): # default Q4_K_M
        self.value = value

    def __copyinit__(out self, existing: Self):
        self.value = existing.value

    @always_inline
    def copy(self) -> Self:
        return Self(self.value)

    @always_inline
    def __eq__(self, rhs: Self) -> Bool:
        return self.value == rhs.value

    @always_inline
    def __eq__(self, rhs: Int) -> Bool:
        return self.value == rhs

    @always_inline
    def name(self) -> String:
        if self.value == 0: return "Q2_K"
        elif self.value == 1: return "Q3_K_S"
        elif self.value == 2: return "Q3_K_M"
        elif self.value == 3: return "Q3_K_L"
        elif self.value == 4: return "Q4_0"
        elif self.value == 5: return "Q4_1"
        elif self.value == 6: return "Q4_K_S"
        elif self.value == 7: return "Q4_K_M"
        elif self.value == 8: return "Q5_0"
        elif self.value == 9: return "Q5_1"
        elif self.value == 10: return "Q5_K_S"
        elif self.value == 11: return "Q5_K_M"
        elif self.value == 12: return "Q6_K"
        elif self.value == 13: return "Q8_0"
        elif self.value == 14: return "Q8_1"
        elif self.value == 15: return "GPTQ_4BIT"
        elif self.value == 16: return "GPTQ_8BIT"
        elif self.value == 17: return "AWQ_4BIT"
        elif self.value == 18: return "EXL2_VARBIT"
        elif self.value == 19: return "HQQ"
        else: return "SMOOTHQUANT_INT8"


struct GPUBuffer(Copyable, ImplicitlyCopyable):
    """
    ᚷᛈᚢ·ᛒᚢᚠᚠᛖᚱ — The Bifrost Physical Stream Channel (GPUBuffer)
    ═════════════════════════════════════════════════════════════════

    A zero-copy physical GPU memory buffer descriptor carved directly from the pre-allocated slab of MimirWell.
    Establishes unified physical memory frame sharing between host MMU and accelerator hardware page tables across:
      · CUDA Unified Memory (managed physical pages)
      · ROCm hipHostMalloc / SVM
      · Level Zero Shared Virtual Memory (SVM)
      · OpenCL Shared Virtual Memory (SVM)
      · Android Hardware Buffers / DMA-BUF zero-copy channels

    Zero heap allocations are performed during buffer carving — preserving living memory integrity.
    """
    var ptr: Pointer[Scalar[f16], MutUntrackedOrigin]
    var size_bytes: Int
    var handle_fd: Int32
    var realm: GPURealmType

    def __init__(out self, ptr: Pointer[Scalar[f16], MutUntrackedOrigin], size_bytes: Int, handle_fd: Int32 = 0, realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)):
        self.ptr = ptr
        self.size_bytes = size_bytes
        self.handle_fd = handle_fd
        self.realm = realm

    def __init__(out self, mut well: MimirWell, size_bytes: Int, realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)):
        var elements = size_bytes // 2
        self.ptr = well.allocate(elements)
        self.size_bytes = size_bytes
        self.handle_fd = 0
        self.realm = realm

    def __copyinit__(out self, existing: Self):
        self.ptr = existing.ptr
        self.size_bytes = existing.size_bytes
        self.handle_fd = existing.handle_fd
        self.realm = existing.realm.copy()

    @always_inline
    def copy(self) -> Self:
        return Self(self.ptr, self.size_bytes, self.handle_fd, self.realm.copy())

    @always_inline
    def as_rune_tensor(self, rows: Int, cols: Int) -> RuneTensor[f16]:
        return RuneTensor[f16](rows, cols, self.ptr, False)



struct NPUBuffer(Copyable, ImplicitlyCopyable):
    """
    ᚾᛈᚢ·ᛒᚢᚠᚠᛖᚱ — The Yggdrasil Root Channel (NPUBuffer)
    ══════════════════════════════════════════════════════

    A sacred conduit between the CPU mortal plane and the NPU spirit realm.
    Physical memory mapped once into the host address space is shared directly
    with the accelerator without copy — the tensor data flows as breath flows
    through Yggdrasil's roots: continuous, unbroken, alive.

    Implementation Contract (Zero-Copy DMA-BUF / ION / Android HardwareBuffer):
    ─────────────────────────────────────────────────────────────────────────────
    · `ptr`        — Raw f16 pointer into the pre-allocated MimirWell slab.
                     This is the same physical frame visible to both CPU MMU
                     and the NPU's IOMMU page table, enabling true zero-copy
                     host↔accelerator data sharing.

    · `handle_fd`  — Linux DMA-BUF file descriptor (or Android AHardwareBuffer
                     handle on Android targets). Zero (0) indicates a plain host
                     pointer without a DMA-BUF backing — still zero-copy within
                     MimirWell, but without IOMMU mapping for external NPU DMA.

    · `is_dma_buf` — True when `handle_fd` refers to a valid DMA-BUF / ION
                     allocation exportable via `dma_buf_export` or `ion_alloc`.
                     When False, the buffer is CPU-resident only (ARM NEON path).

    · `backend`    — The NPUBackendType rune that dictates which hardware spirit
                     consumes this buffer during kernel dispatch in `gemm_f16_npu`.

    The buffer is always carved from MimirWell's living memory pool — never from
    the fragmented heap of Midgard. Size is recorded in bytes (`size_bytes`) to
    preserve byte-level alignment guarantees for DMA descriptor construction.
    """
    var ptr: Pointer[Scalar[f16], MutUntrackedOrigin]
    var size_bytes: Int
    var handle_fd: Int32
    var is_dma_buf: Bool
    var backend: NPUBackendType

    def __init__(
        out self,
        ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int,
        handle_fd: Int32 = 0,
        is_dma_buf: Bool = True,
        backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON)
    ):
        self.ptr = ptr
        self.size_bytes = size_bytes
        self.handle_fd = handle_fd
        self.is_dma_buf = is_dma_buf
        self.backend = backend.copy()

    def __init__(
        out self,
        mut well: MimirWell,
        size_bytes: Int,
        backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON)
    ):
        var elements = size_bytes // 2
        self.ptr = well.allocate(elements)
        self.size_bytes = size_bytes
        self.handle_fd = 0
        self.is_dma_buf = True
        self.backend = backend.copy()

    def __copyinit__(out self, existing: Self):
        self.ptr = existing.ptr
        self.size_bytes = existing.size_bytes
        self.handle_fd = existing.handle_fd
        self.is_dma_buf = existing.is_dma_buf
        self.backend = existing.backend.copy()

    @always_inline
    def copy(self) -> Self:
        return Self(self.ptr, self.size_bytes, self.handle_fd, self.is_dma_buf, self.backend.copy())

    @always_inline
    def as_rune_tensor(self, rows: Int, cols: Int) -> RuneTensor[f16]:
        return RuneTensor[f16](rows, cols, self.ptr, False)



struct RuneTensor[type: DType](Copyable):


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

    def __copyinit__(out self, existing: Self):
        self.rows = existing.rows
        self.cols = existing.cols
        self.size = existing.size
        self.data = existing.data
        self.is_quantized = existing.is_quantized

    @always_inline
    def copy(self) -> Self:
        return Self(self.rows, self.cols, self.data, self.is_quantized)


    @always_inline
    def get(self, r: Int, c: Int) -> Scalar[Self.type]:
        return self.data.unsafe_load(r * self.cols + c)

    @always_inline
    def set(mut self, r: Int, c: Int, val: Scalar[Self.type]):
        self.data.unsafe_store(r * self.cols + c, val)



struct KVCache(Copyable):
    """
    KVCache: Ring-Buffer Key-Value Cache drawn from the Well of Mimir.
    Manages pre-allocated RuneTensor[f16] buffers for Key (K) and Value (V) tensors
    across sequence length (max_seq_len, default 2048 or 4096).
    """
    var k: RuneTensor[f16]
    var v: RuneTensor[f16]
    var max_seq_len: Int
    var hidden_dim: Int
    var num_layers: Int

    def __init__(
        out self, 
        max_seq_len: Int, 
        hidden_dim: Int, 
        mut well: MimirWell, 
        num_layers: Int = 32
    ):
        self.max_seq_len = max_seq_len
        self.hidden_dim = hidden_dim
        self.num_layers = num_layers
        
        var total_elements = num_layers * max_seq_len * hidden_dim
        var k_ptr = well.allocate(total_elements)
        var v_ptr = well.allocate(total_elements)
        
        self.k = RuneTensor[f16](num_layers * max_seq_len, hidden_dim, k_ptr, False)
        self.v = RuneTensor[f16](num_layers * max_seq_len, hidden_dim, v_ptr, False)

    def __init__(
        out self, 
        max_seq_len: Int, 
        hidden_dim: Int, 
        k_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], 
        v_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], 
        num_layers: Int = 1
    ):
        self.max_seq_len = max_seq_len
        self.hidden_dim = hidden_dim
        self.num_layers = num_layers
        
        self.k = RuneTensor[f16](num_layers * max_seq_len, hidden_dim, k_ptr, False)
        self.v = RuneTensor[f16](num_layers * max_seq_len, hidden_dim, v_ptr, False)

    def __copyinit__(out self, existing: Self):
        self.k = existing.k
        self.v = existing.v
        self.max_seq_len = existing.max_seq_len
        self.hidden_dim = existing.hidden_dim
        self.num_layers = existing.num_layers

    @always_inline
    def append(mut self, layer_idx: Int, pos: Int, key: RuneTensor[f16], val: RuneTensor[f16]):
        """Appends single-token Key and Value vectors into the ring buffer at position pos."""
        var slot = pos % self.max_seq_len
        var offset = (layer_idx * self.max_seq_len + slot) * self.hidden_dim
        for c in range(self.hidden_dim):
            self.k.data.unsafe_store(offset + c, key.data.unsafe_load(c))
            self.v.data.unsafe_store(offset + c, val.data.unsafe_load(c))

    @always_inline
    def get_k_slice(self, layer_idx: Int, seq_len: Int) -> RuneTensor[f16]:
        """Returns a RuneTensor view over active Key tokens [0..seq_len) for layer_idx."""
        var offset = layer_idx * self.max_seq_len * self.hidden_dim
        return RuneTensor[f16](seq_len, self.hidden_dim, self.k.data.unsafe_offset(offset), False)

    @always_inline
    def get_v_slice(self, layer_idx: Int, seq_len: Int) -> RuneTensor[f16]:
        """Returns a RuneTensor view over active Value tokens [0..seq_len) for layer_idx."""
        var offset = layer_idx * self.max_seq_len * self.hidden_dim
        return RuneTensor[f16](seq_len, self.hidden_dim, self.v.data.unsafe_offset(offset), False)


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
            return Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=1)
        
        var ptr = self.base_ptr.unsafe_offset(self.offset)
        self.offset += elements
        return ptr

    def allocate_npu_buffer(mut self, size_bytes: Int, backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON)) -> NPUBuffer:
        """Draws zero-copy NPU DMA shared buffer directly from MimirWell."""
        return NPUBuffer(self, size_bytes, backend)

    def allocate_gpu_buffer(mut self, size_bytes: Int, realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)) -> GPUBuffer:
        """Draws zero-copy GPU physical buffer directly from MimirWell."""
        return GPUBuffer(self, size_bytes, realm)


    def reset_kv_cache(mut self, kv_offset_start: Int):
        """Ring-buffer reset point for KV Cache."""
        self.offset = kv_offset_start

    def __deinit__(deinit self):
        self.base_ptr.unsafe_free()


struct MimirStore(Copyable):
    """
    MimirStore: Vector store pre-allocating zero-copy memory inside MimirWell.
    Holds text document chunks and f16 embeddings (N x D).
    """
    var documents: List[String]
    var embeddings: RuneTensor[f16]
    var max_docs: Int
    var dim: Int
    var count: Int

    def __init__(out self, max_docs: Int, dim: Int, mut well: MimirWell):
        self.max_docs = max_docs
        self.dim = dim
        self.count = 0
        self.documents = List[String]()
        var ptr = well.allocate(max_docs * dim)
        self.embeddings = RuneTensor[f16](max_docs, dim, ptr, False)

    def __init__(out self, mut well: MimirWell, max_docs: Int = 100, dim: Int = 4096):
        self.max_docs = max_docs
        self.dim = dim
        self.count = 0
        self.documents = List[String]()
        var ptr = well.allocate(max_docs * dim)
        self.embeddings = RuneTensor[f16](max_docs, dim, ptr, False)

    def __copyinit__(out self, existing: Self):
        self.documents = existing.documents
        self.embeddings = existing.embeddings
        self.max_docs = existing.max_docs
        self.dim = existing.dim
        self.count = existing.count

    def add_document(mut self, doc: String, embedding: RuneTensor[f16]):
        """Appends text document chunks and vectors into MimirStore."""
        if self.count >= self.max_docs:
            print("Warning: MimirStore capacity reached. Cannot add document.")
            return
        self.documents.append(doc)
        var copy_len = min(embedding.size, self.dim)
        var offset = self.count * self.dim
        for i in range(copy_len):
            var val = embedding.data.unsafe_load(i)
            self.embeddings.data.unsafe_store(offset + i, val)
        for i in range(copy_len, self.dim):
            self.embeddings.data.unsafe_store(offset + i, Scalar[f16](0.0))
        self.count += 1

    def search_knn(self, query_emb: RuneTensor[f16], top_k: Int = 3) -> List[String]:
        """Using SIMD cosine_similarity to retrieve nearest document strings."""
        from core.compute import cosine_similarity
        
        var result = List[String]()
        if self.count == 0:
            return result^

        var scores = List[Scalar[f32]]()
        var indices = List[Int]()

        for i in range(self.count):
            var doc_emb = RuneTensor[f16](1, self.dim, self.embeddings.data.unsafe_offset(i * self.dim), False)
            var score = cosine_similarity(query_emb, doc_emb)
            scores.append(score)
            indices.append(i)
            _ = doc_emb

        var k_limit = min(top_k, self.count)
        for i in range(k_limit):
            var max_idx = i
            for j in range(i + 1, self.count):
                if scores[j] > scores[max_idx]:
                    max_idx = j
            var temp_score = scores[i]
            scores[i] = scores[max_idx]
            scores[max_idx] = temp_score

            var temp_idx = indices[i]
            indices[i] = indices[max_idx]
            indices[max_idx] = temp_idx

        for i in range(k_limit):
            result.append(self.documents[indices[i]])

        return result^


struct DeviceTopology(Copyable):
    """
    DeviceTopology (The Realm Mapping):
    Maps compute device IDs and hardware topology for multi-GPU sharding across the Nine Realms.
    Orchestrates device dispatch and discovery of heterogeneous edge NPUs (Hailo-10, Hexagon, ARM NEON, Jetson, Apple ANE).
    """
    var num_devices: Int
    var device_names: List[String]
    var npu_backends: List[NPUBackendType]
    var gpu_realms: List[GPURealmType]

    def __init__(out self, num_devices: Int = 1):
        self.num_devices = max(1, num_devices)
        self.device_names = List[String]()
        for i in range(self.num_devices):
            self.device_names.append("cuda:" + String(i))
        self.npu_backends = List[NPUBackendType]()
        self.gpu_realms = List[GPURealmType]()
        self.detect_edge_npus()
        self.detect_gpu_realms()

    def __init__(out self, num_devices: Int, device_names: List[String]):
        self.num_devices = max(1, num_devices)
        self.device_names = device_names.copy()
        self.npu_backends = List[NPUBackendType]()
        self.gpu_realms = List[GPURealmType]()
        self.detect_edge_npus()
        self.detect_gpu_realms()

    def __copyinit__(out self, existing: Self):
        self.num_devices = existing.num_devices
        self.device_names = existing.device_names.copy()
        self.npu_backends = existing.npu_backends.copy()
        self.gpu_realms = existing.gpu_realms.copy()

    def detect_edge_npus(mut self):
        """Scans platform topology and discovers available NPU hardware acceleration backends."""
        self.npu_backends.clear()
        self.npu_backends.append(NPUBackendType(NPUBackendType.HAILO_10))
        self.npu_backends.append(NPUBackendType(NPUBackendType.QUALCOMM_HEXAGON))
        self.npu_backends.append(NPUBackendType(NPUBackendType.ARM_NEON))
        self.npu_backends.append(NPUBackendType(NPUBackendType.JETSON_NVIDIA))
        self.npu_backends.append(NPUBackendType(NPUBackendType.APPLE_NEURAL_ENGINE))
        self.npu_backends.append(NPUBackendType(NPUBackendType.GENERIC_NPU))

    def detect_gpu_realms(mut self):
        """Scans platform topology and discovers available GPU hardware acceleration realms."""
        self.gpu_realms.clear()
        self.gpu_realms.append(GPURealmType(GPURealmType.NVIDIA_CUDA))
        self.gpu_realms.append(GPURealmType(GPURealmType.AMD_ROCM_HIP))
        self.gpu_realms.append(GPURealmType(GPURealmType.INTEL_ONEAPI_XE))
        self.gpu_realms.append(GPURealmType(GPURealmType.MOORE_THREADS_MUSA))
        self.gpu_realms.append(GPURealmType(GPURealmType.BIREN_SUPA))
        self.gpu_realms.append(GPURealmType(GPURealmType.METAX_MACA))
        self.gpu_realms.append(GPURealmType(GPURealmType.HYGON_DCU))
        self.gpu_realms.append(GPURealmType(GPURealmType.ARM_MALI_OPENCL))
        self.gpu_realms.append(GPURealmType(GPURealmType.QUALCOMM_ADRENO))
        self.gpu_realms.append(GPURealmType(GPURealmType.IMAGINATION_POWERVR))




struct ShardTensor(Copyable):
    """
    ShardTensor (The Shard of Yggdrasil):
    Wraps zero-copy RuneTensor[f16] slices assigned to a specific compute realm/device.
    Preserves direct memory offset linkages into MimirWell without heap reallocation.
    """
    var device_id: Int
    var tensor: RuneTensor[f16]

    def __init__(out self, device_id: Int, tensor: RuneTensor[f16]):
        self.device_id = device_id
        self.tensor = tensor.copy()

    def __copyinit__(out self, existing: Self):
        self.device_id = existing.device_id
        self.tensor = existing.tensor.copy()


def shard_split_cols(T: RuneTensor[f16], num_shards: Int, mut well: MimirWell) -> List[RuneTensor[f16]]:
    """
    The Splitting of the Bifrost Stream (Column-Parallel Partitioning):
    Splits tensor T across column dimensions (dimension 1) for distributed activation matrices 
    or column-sharded weight layers within the Bifrost Shard Matrix. Memory for 2D slices
    is drawn directly from MimirWell to ensure zero dynamic heap allocations.
    """
    var result = List[RuneTensor[f16]]()
    if num_shards <= 1 or T.cols % num_shards != 0:
        result.append(T.copy())
        return result^

    var shard_cols = T.cols // num_shards

    if T.rows == 1:
        for i in range(num_shards):
            var ptr = T.data.unsafe_offset(i * shard_cols)
            result.append(RuneTensor[f16](1, shard_cols, ptr, T.is_quantized))
    else:
        for i in range(num_shards):
            var ptr = well.allocate(T.rows * shard_cols)
            for r in range(T.rows):
                for c in range(shard_cols):
                    var val = T.get(r, i * shard_cols + c)
                    ptr.unsafe_store(r * shard_cols + c, val)
            result.append(RuneTensor[f16](T.rows, shard_cols, ptr, T.is_quantized))

    return result^


def shard_split_cols(T: RuneTensor[f16], num_shards: Int) -> List[RuneTensor[f16]]:
    """
    Overload for column-parallel partitioning when MimirWell is omitted.
    For 1D row vectors (T.rows == 1), this is zero-copy offset slicing.
    """
    var result = List[RuneTensor[f16]]()
    if num_shards <= 1 or T.cols % num_shards != 0:
        result.append(T.copy())
        return result^

    var shard_cols = T.cols // num_shards

    if T.rows == 1:
        for i in range(num_shards):
            var ptr = T.data.unsafe_offset(i * shard_cols)
            result.append(RuneTensor[f16](1, shard_cols, ptr, T.is_quantized))
    else:
        for i in range(num_shards):
            var allocation = alloc(Layout[Scalar[f16]](count=T.rows * shard_cols))
            var ptr = allocation^.unsafe_leak()
            for r in range(T.rows):
                for c in range(shard_cols):
                    var val = T.get(r, i * shard_cols + c)
                    ptr.unsafe_store(r * shard_cols + c, val)
            result.append(RuneTensor[f16](T.rows, shard_cols, ptr, T.is_quantized))

    return result^


def shard_split_rows(T: RuneTensor[f16], num_shards: Int) -> List[RuneTensor[f16]]:
    """
    The Cleaving of the Runic Matrix (Row-Parallel Partitioning):
    Splits tensor T across row dimensions (dimension 0), providing zero-copy 
    contiguous slice views in row-major layout across allocated device shards.
    """
    var result = List[RuneTensor[f16]]()
    if num_shards <= 1 or T.rows % num_shards != 0:
        result.append(T.copy())
        return result^

    var shard_rows = T.rows // num_shards
    for i in range(num_shards):
        var ptr = T.data.unsafe_offset(i * shard_rows * T.cols)
        result.append(RuneTensor[f16](shard_rows, T.cols, ptr, T.is_quantized))

    return result^




