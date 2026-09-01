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
comptime int4 = DType.int8  # Mojo natively handles down to int8, we bitshift for int4


struct NPUBackendType(Copyable, ImplicitlyCopyable):
    """
    ᚾᛈᚢ·ᛒᚨᚲᚲᛖᚾᛞ·ᛏᚤᛈᛖ — The Sigil of Edge Realms (NPUBackendType)
    ══════════════════════════════════════════════════════════════════

    Integer names reserved for possible future NPU backends. They record desired
    configuration only; no backend is detected or executed.
    """

    comptime HAILO_10 = 0
    comptime QUALCOMM_HEXAGON = 1
    comptime ARM_NEON = 2
    comptime JETSON_NVIDIA = 3
    comptime APPLE_NEURAL_ENGINE = 4
    comptime GENERIC_NPU = 5
    comptime INTEL_NPU = 6

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
        elif self.value == 6:
            return "INTEL_NPU"
        else:
            return "GENERIC_NPU"


struct GPURealmType(Copyable, ImplicitlyCopyable):
    """
    ᚷᛈᚢ·ᚱᛖᚨᛚᛗ·ᛏᚤᛈᛖ — The Sigil of Universal GPU Realms (GPURealmType)
    ═════════════════════════════════════════════════════════════════════════

    Integer names reserved for possible future GPU backends:

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

    These values record desired configuration only; no GPU backend is detected
    or executed.
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
    comptime APPLE_METAL = 10

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
        elif self.value == 10:
            return "APPLE_METAL"
        else:
            return "GENERIC_GPU"


struct DiscoveryStatus(Copyable, ImplicitlyCopyable):
    """Classifies a physical accelerator discovery outcome without guessing."""

    comptime SUCCESS = 0
    comptime PARTIAL = 1
    comptime UNSUPPORTED_RUNTIME = 2
    comptime NO_DEVICE = 3
    comptime INCOMPATIBLE_DRIVER = 4
    comptime UNSUPPORTED_ARCHITECTURE = 5
    comptime MISSING_COMPILER_TOOL = 6
    comptime PERMISSION_DENIED = 7
    comptime PROBE_FAILED = 8

    var value: Int

    def __init__(out self, value: Int = Self.PROBE_FAILED):
        self.value = value

    def __copyinit__(out self, existing: Self):
        self.value = existing.value

    @always_inline
    def copy(self) -> Self:
        return Self(self.value)

    @always_inline
    def is_success(self) -> Bool:
        return self.value == Self.SUCCESS

    @always_inline
    def has_devices(self) -> Bool:
        return self.value == Self.SUCCESS or self.value == Self.PARTIAL

    def name(self) -> String:
        if self.value == Self.SUCCESS:
            return "SUCCESS"
        elif self.value == Self.PARTIAL:
            return "PARTIAL"
        elif self.value == Self.UNSUPPORTED_RUNTIME:
            return "UNSUPPORTED_RUNTIME"
        elif self.value == Self.NO_DEVICE:
            return "NO_DEVICE"
        elif self.value == Self.INCOMPATIBLE_DRIVER:
            return "INCOMPATIBLE_DRIVER"
        elif self.value == Self.UNSUPPORTED_ARCHITECTURE:
            return "UNSUPPORTED_ARCHITECTURE"
        elif self.value == Self.MISSING_COMPILER_TOOL:
            return "MISSING_COMPILER_TOOL"
        elif self.value == Self.PERMISSION_DENIED:
            return "PERMISSION_DENIED"
        return "PROBE_FAILED"


struct DeviceCapabilities(Copyable):
    """Observed runtime capabilities for one physical accelerator."""

    var is_compatible: Bool
    var api_version: Int
    var free_memory_bytes: UInt
    var total_memory_bytes: UInt
    var compute_capability_major: Int
    var compute_capability_minor: Int
    var multiprocessor_count: Int
    var max_threads_per_block: Int

    def __init__(
        out self,
        is_compatible: Bool,
        api_version: Int,
        free_memory_bytes: UInt,
        total_memory_bytes: UInt,
        compute_capability_major: Int,
        compute_capability_minor: Int,
        multiprocessor_count: Int,
        max_threads_per_block: Int,
    ):
        self.is_compatible = is_compatible
        self.api_version = api_version
        self.free_memory_bytes = free_memory_bytes
        self.total_memory_bytes = total_memory_bytes
        self.compute_capability_major = compute_capability_major
        self.compute_capability_minor = compute_capability_minor
        self.multiprocessor_count = multiprocessor_count
        self.max_threads_per_block = max_threads_per_block

    def __copyinit__(out self, existing: Self):
        self.is_compatible = existing.is_compatible
        self.api_version = existing.api_version
        self.free_memory_bytes = existing.free_memory_bytes
        self.total_memory_bytes = existing.total_memory_bytes
        self.compute_capability_major = existing.compute_capability_major
        self.compute_capability_minor = existing.compute_capability_minor
        self.multiprocessor_count = existing.multiprocessor_count
        self.max_threads_per_block = existing.max_threads_per_block

    @always_inline
    def copy(self) -> Self:
        return Self(
            self.is_compatible,
            self.api_version,
            self.free_memory_bytes,
            self.total_memory_bytes,
            self.compute_capability_major,
            self.compute_capability_minor,
            self.multiprocessor_count,
            self.max_threads_per_block,
        )

    def validate(self) raises:
        if self.api_version <= 0:
            raise Error("DeviceCapabilities: api_version must be positive")
        if self.total_memory_bytes == 0:
            raise Error(
                "DeviceCapabilities: total_memory_bytes must be positive"
            )
        if self.free_memory_bytes > self.total_memory_bytes:
            raise Error("DeviceCapabilities: free memory exceeds total memory")
        if (
            self.compute_capability_major < 0
            or self.compute_capability_minor < 0
        ):
            raise Error(
                "DeviceCapabilities: compute capability must not be negative"
            )
        if self.multiprocessor_count <= 0:
            raise Error(
                "DeviceCapabilities: multiprocessor_count must be positive"
            )
        if self.max_threads_per_block <= 0:
            raise Error(
                "DeviceCapabilities: max_threads_per_block must be positive"
            )


struct PhysicalDevice(Copyable):
    """One accelerator identity and its capabilities observed from a runtime."""

    var realm: GPURealmType
    var backend_index: Int
    var runtime_id: Int64
    var stable_id: String
    var name: String
    var api: String
    var capabilities: DeviceCapabilities

    def __init__(
        out self,
        realm: GPURealmType,
        backend_index: Int,
        runtime_id: Int64,
        stable_id: String,
        name: String,
        api: String,
        capabilities: DeviceCapabilities,
    ):
        self.realm = realm.copy()
        self.backend_index = backend_index
        self.runtime_id = runtime_id
        self.stable_id = stable_id
        self.name = name
        self.api = api
        self.capabilities = capabilities.copy()

    def __copyinit__(out self, existing: Self):
        self.realm = existing.realm.copy()
        self.backend_index = existing.backend_index
        self.runtime_id = existing.runtime_id
        self.stable_id = existing.stable_id
        self.name = existing.name
        self.api = existing.api
        self.capabilities = existing.capabilities.copy()

    @always_inline
    def copy(self) -> Self:
        return Self(
            self.realm.copy(),
            self.backend_index,
            self.runtime_id,
            self.stable_id,
            self.name,
            self.api,
            self.capabilities.copy(),
        )

    def validate(self) raises:
        if self.backend_index < 0:
            raise Error("PhysicalDevice: backend_index must not be negative")
        if self.runtime_id < 0:
            raise Error("PhysicalDevice: runtime_id must not be negative")
        if self.stable_id.byte_length() == 0:
            raise Error("PhysicalDevice: stable_id must not be empty")
        if self.name.byte_length() == 0:
            raise Error("PhysicalDevice: name must not be empty")
        if self.api.byte_length() == 0:
            raise Error("PhysicalDevice: api must not be empty")
        if self.realm.value == GPURealmType.NVIDIA_CUDA and self.api != "cuda":
            raise Error("PhysicalDevice: NVIDIA_CUDA requires api=cuda")
        self.capabilities.validate()


struct HardwareDiscoveryResult(Copyable):
    """A validated production result or explicitly injected test snapshot."""

    var status: DiscoveryStatus
    var message: String
    var devices: List[PhysicalDevice]

    def __init__(
        out self,
        status: DiscoveryStatus,
        message: String,
        devices: List[PhysicalDevice],
    ):
        self.status = status.copy()
        self.message = message
        self.devices = devices.copy()

    def __copyinit__(out self, existing: Self):
        self.status = existing.status.copy()
        self.message = existing.message
        self.devices = existing.devices.copy()

    @always_inline
    def copy(self) -> Self:
        return Self(self.status.copy(), self.message, self.devices.copy())

    def validate(self) raises:
        if (
            self.status.value < DiscoveryStatus.SUCCESS
            or self.status.value > DiscoveryStatus.PROBE_FAILED
        ):
            raise Error("HardwareDiscoveryResult: unknown discovery status")
        if self.status.is_success() and len(self.devices) == 0:
            raise Error(
                "HardwareDiscoveryResult: SUCCESS requires at least one device"
            )
        if (
            self.status.value == DiscoveryStatus.PARTIAL
            and len(self.devices) == 0
        ):
            raise Error(
                "HardwareDiscoveryResult: PARTIAL requires an observed device"
            )
        if not self.status.has_devices() and len(self.devices) != 0:
            raise Error(
                "HardwareDiscoveryResult: failure status cannot carry devices"
            )
        if not self.status.has_devices() and self.message.byte_length() == 0:
            raise Error(
                "HardwareDiscoveryResult: failure status requires a message"
            )
        for i in range(len(self.devices)):
            self.devices[i].validate()
            for j in range(i):
                if self.devices[i].stable_id == self.devices[j].stable_id:
                    raise Error("HardwareDiscoveryResult: duplicate stable_id")
                if (
                    self.devices[i].realm == self.devices[j].realm
                    and self.devices[i].backend_index
                    == self.devices[j].backend_index
                ):
                    raise Error(
                        "HardwareDiscoveryResult: duplicate backend index"
                    )


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
      14 · Q8_1             — 8-bit GGML block quantization (F32 scale + auxiliary sum)
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
    comptime FP8_E4M3 = 21
    comptime FP8_E5M2 = 22
    comptime IQ1_S = 23
    comptime IQ2_XXS = 24
    comptime TERNARY_155BIT = 25
    comptime TQ1_0 = 25  # Canonical GGML name for the ternary descriptor.

    var value: Int

    def __init__(out self, value: Int = 7):  # default Q4_K_M
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
        if self.value == 0:
            return "Q2_K"
        elif self.value == 1:
            return "Q3_K_S"
        elif self.value == 2:
            return "Q3_K_M"
        elif self.value == 3:
            return "Q3_K_L"
        elif self.value == 4:
            return "Q4_0"
        elif self.value == 5:
            return "Q4_1"
        elif self.value == 6:
            return "Q4_K_S"
        elif self.value == 7:
            return "Q4_K_M"
        elif self.value == 8:
            return "Q5_0"
        elif self.value == 9:
            return "Q5_1"
        elif self.value == 10:
            return "Q5_K_S"
        elif self.value == 11:
            return "Q5_K_M"
        elif self.value == 12:
            return "Q6_K"
        elif self.value == 13:
            return "Q8_0"
        elif self.value == 14:
            return "Q8_1"
        elif self.value == 15:
            return "GPTQ_4BIT"
        elif self.value == 16:
            return "GPTQ_8BIT"
        elif self.value == 17:
            return "AWQ_4BIT"
        elif self.value == 18:
            return "EXL2_VARBIT"
        elif self.value == 19:
            return "HQQ"
        elif self.value == 20:
            return "SMOOTHQUANT_INT8"
        elif self.value == 21:
            return "FP8_E4M3"
        elif self.value == 22:
            return "FP8_E5M2"
        elif self.value == 23:
            return "IQ1_S"
        elif self.value == 24:
            return "IQ2_XXS"
        elif self.value == 25:
            return "TQ1_0"
        return "UNKNOWN"


struct GPUBuffer(Copyable, ImplicitlyCopyable):
    """
    ᚷᛈᚢ·ᛒᚢᚠᚠᛖᚱ — Host Buffer Descriptor Reserved for Future GPU Work
    ═════════════════════════════════════════════════════════════════

    This currently describes CPU-resident memory carved from MimirWell. The
    `realm` field is configuration metadata only; no GPU allocation, mapping,
    transfer, or execution occurs.
    """

    var ptr: Pointer[Scalar[f16], MutUntrackedOrigin]
    var size_bytes: Int
    var handle_fd: Int32
    var realm: GPURealmType

    def __init__(
        out self,
        ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int,
        handle_fd: Int32 = 0,
        realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA),
    ):
        self.ptr = ptr
        self.size_bytes = size_bytes
        self.handle_fd = handle_fd
        self.realm = realm

    def __init__(
        out self,
        mut well: MimirWell,
        size_bytes: Int,
        realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA),
    ) raises:
        if size_bytes < 0:
            raise Error("buffer size_bytes must not be negative")
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
        return Self(
            self.ptr, self.size_bytes, self.handle_fd, self.realm.copy()
        )

    @always_inline
    def as_rune_tensor(self, rows: Int, cols: Int) -> RuneTensor[f16]:
        return RuneTensor[f16](rows, cols, self.ptr, False)

    def validate_zero_copy_contract(self) raises:
        """
        Validates whether direct zero-copy device mmap / DMA-BUF frame mapping is backed by physical driver evidence.
        Raises explicit Error unless backed by validated physical driver evidence.
        """
        if self.handle_fd <= 0:
            raise Error("GPUBuffer zero-copy contract unverified: host buffer lacks physical OS DMA-BUF handle_fd or mmap evidence (" + self.realm.name() + ")")



struct NPUBuffer(Copyable, ImplicitlyCopyable):
    """
    ᚾᛈᚢ·ᛒᚢᚠᚠᛖᚱ — The Yggdrasil Root Channel (NPUBuffer)
    ══════════════════════════════════════════════════════

    This currently describes CPU-resident memory carved from MimirWell. It does
    not establish DMA-BUF, ION, AHardwareBuffer, IOMMU, or NPU visibility.

    The fields reserve a future integration boundary. `ptr` is a host pointer,
    `handle_fd` remains zero, `is_dma_buf` remains false, and `backend` is only a
    requested-backend discriminant. No field currently proves accelerator
    allocation, exportability, IOMMU mapping, alignment, or dispatch.
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
        is_dma_buf: Bool = False,
        backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON),
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
        backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON),
    ) raises:
        if size_bytes < 0:
            raise Error("buffer size_bytes must not be negative")
        var elements = size_bytes // 2
        self.ptr = well.allocate(elements)
        self.size_bytes = size_bytes
        self.handle_fd = 0
        self.is_dma_buf = False
        self.backend = backend.copy()

    def __copyinit__(out self, existing: Self):
        self.ptr = existing.ptr
        self.size_bytes = existing.size_bytes
        self.handle_fd = existing.handle_fd
        self.is_dma_buf = existing.is_dma_buf
        self.backend = existing.backend.copy()

    @always_inline
    def copy(self) -> Self:
        return Self(
            self.ptr,
            self.size_bytes,
            self.handle_fd,
            self.is_dma_buf,
            self.backend.copy(),
        )

    def validate_zero_copy_contract(self) raises:
        """
        Validates whether direct zero-copy NPU DMA-BUF frame mapping is backed by physical driver evidence.
        Raises explicit Error unless backed by validated physical driver evidence.
        """
        if not self.is_dma_buf or self.handle_fd <= 0:
            raise Error(
                "NPUBuffer zero-copy contract unverified: host buffer lacks"
                " physical OS DMA-BUF handle_fd or mmap evidence ("
                + self.backend.name()
                + ")"
            )


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
    var quant_format: CompressedFormatType

    def __init__(
        out self,
        rows: Int,
        cols: Int,
        pre_allocated_ptr: Pointer[Scalar[Self.type], MutUntrackedOrigin],
        is_quantized: Bool = False,
        quant_format: CompressedFormatType = CompressedFormatType(
            CompressedFormatType.Q4_K_M
        ),
    ):
        """Creates an unchecked internal view; use checked() at trust boundaries.
        """
        self.rows = rows
        self.cols = cols
        self.size = rows * cols
        self.data = pre_allocated_ptr
        self.is_quantized = is_quantized
        self.quant_format = quant_format.copy()

    @staticmethod
    def checked(
        rows: Int,
        cols: Int,
        pre_allocated_ptr: Pointer[Scalar[Self.type], MutUntrackedOrigin],
        is_quantized: Bool = False,
        quant_format: CompressedFormatType = CompressedFormatType(
            CompressedFormatType.Q4_K_M
        ),
    ) raises -> Self:
        """Validates an untrusted shape and pointer before creating a view."""
        if rows <= 0 or cols <= 0:
            raise Error("RuneTensor.checked: dimensions must be positive")
        var size = rows * cols
        if size <= 0 or size // rows != cols:
            raise Error("RuneTensor.checked: shape product overflow")
        var address = Int(pre_allocated_ptr)
        if address == 0 or address == 1:
            raise Error("RuneTensor.checked: pointer is null or sentinel")
        return Self(
            rows, cols, pre_allocated_ptr, is_quantized, quant_format.copy()
        )

    def __copyinit__(out self, existing: Self):
        self.rows = existing.rows
        self.cols = existing.cols
        self.size = existing.size
        self.data = existing.data
        self.is_quantized = existing.is_quantized
        self.quant_format = existing.quant_format.copy()

    @always_inline
    def copy(self) -> Self:
        return Self(
            self.rows,
            self.cols,
            self.data,
            self.is_quantized,
            self.quant_format.copy(),
        )

    @always_inline
    def get(self, r: Int, c: Int) -> Scalar[Self.type]:
        return self.data.unsafe_load(r * self.cols + c)

    @always_inline
    def set(mut self, r: Int, c: Int, val: Scalar[Self.type]):
        self.data.unsafe_store(r * self.cols + c, val)

    def get_checked(self, r: Int, c: Int) raises -> Scalar[Self.type]:
        if r < 0 or r >= self.rows or c < 0 or c >= self.cols:
            raise Error("RuneTensor: index out of bounds")
        return self.get(r, c)

    def set_checked(mut self, r: Int, c: Int, val: Scalar[Self.type]) raises:
        if r < 0 or r >= self.rows or c < 0 or c >= self.cols:
            raise Error("RuneTensor: index out of bounds")
        self.set(r, c, val)

    @always_inline
    def is_borrowed(self) -> Bool:
        return True

    @always_inline
    def is_owned(self) -> Bool:
        return False



struct KVCache(Copyable):
    """
    KVCache: Fixed-capacity Key-Value Cache drawn from the Well of Mimir.
    Manages contiguous pre-allocated buffers for chronological positions
    [0, max_seq_len). It does not wrap or reorder positions.
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
        num_layers: Int = 32,
    ) raises:
        if max_seq_len <= 0 or hidden_dim <= 0 or num_layers <= 0:
            raise Error("KVCache: dimensions must be positive")
        self.max_seq_len = max_seq_len
        self.hidden_dim = hidden_dim
        self.num_layers = num_layers

        var cache_rows = num_layers * max_seq_len
        if cache_rows <= 0 or cache_rows // num_layers != max_seq_len:
            raise Error("KVCache: row product overflow")
        var total_elements = cache_rows * hidden_dim
        if total_elements <= 0 or total_elements // cache_rows != hidden_dim:
            raise Error("KVCache: element product overflow")
        var k_ptr = well.allocate(total_elements)
        var v_ptr = well.allocate(total_elements)

        self.k = RuneTensor[f16].checked(cache_rows, hidden_dim, k_ptr, False)
        self.v = RuneTensor[f16].checked(cache_rows, hidden_dim, v_ptr, False)

    def __init__(
        out self,
        max_seq_len: Int,
        hidden_dim: Int,
        k_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
        v_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
        num_layers: Int = 1,
    ) raises:
        if max_seq_len <= 0 or hidden_dim <= 0 or num_layers <= 0:
            raise Error("KVCache: dimensions must be positive")
        if Int(k_ptr) == 0 or Int(k_ptr) == 1:
            raise Error("KVCache: key storage pointer is invalid")
        if Int(v_ptr) == 0 or Int(v_ptr) == 1:
            raise Error("KVCache: value storage pointer is invalid")
        self.max_seq_len = max_seq_len
        self.hidden_dim = hidden_dim
        self.num_layers = num_layers

        var cache_rows = num_layers * max_seq_len
        if cache_rows <= 0 or cache_rows // num_layers != max_seq_len:
            raise Error("KVCache: row product overflow")
        self.k = RuneTensor[f16].checked(cache_rows, hidden_dim, k_ptr, False)
        self.v = RuneTensor[f16].checked(cache_rows, hidden_dim, v_ptr, False)

    def __init__(
        out self,
        k: RuneTensor[f16],
        v: RuneTensor[f16],
        max_seq_len: Int,
        hidden_dim: Int,
        num_layers: Int,
    ):
        """Internal constructor for previously validated cache storage views."""
        self.k = k.copy()
        self.v = v.copy()
        self.max_seq_len = max_seq_len
        self.hidden_dim = hidden_dim
        self.num_layers = num_layers

    def __copyinit__(out self, existing: Self):
        self.k = existing.k
        self.v = existing.v
        self.max_seq_len = existing.max_seq_len
        self.hidden_dim = existing.hidden_dim
        self.num_layers = existing.num_layers

    @always_inline
    def append(
        mut self,
        layer_idx: Int,
        pos: Int,
        key: RuneTensor[f16],
        val: RuneTensor[f16],
    ) raises:
        """Appends single-token Key and Value vectors into the cache at position pos.
        """
        if layer_idx < 0 or layer_idx >= self.num_layers:
            raise Error("KVCache.append: layer_idx out of bounds")
        if pos < 0:
            raise Error("KVCache.append: pos must be non-negative")
        if pos >= self.max_seq_len:
            raise Error("KVCache.append: pos exceeds fixed cache capacity")
        if key.size < self.hidden_dim or val.size < self.hidden_dim:
            raise Error("KVCache.append: key/val width mismatch")
        var offset = (layer_idx * self.max_seq_len + pos) * self.hidden_dim
        for c in range(self.hidden_dim):
            self.k.data.unsafe_store(offset + c, key.data.unsafe_load(c))
            self.v.data.unsafe_store(offset + c, val.data.unsafe_load(c))

    @always_inline
    def get_k_slice(
        self, layer_idx: Int, seq_len: Int
    ) raises -> RuneTensor[f16]:
        """Returns a RuneTensor view over active Key tokens [0..seq_len) for layer_idx.
        """
        if layer_idx < 0 or layer_idx >= self.num_layers:
            raise Error("KVCache.get_k_slice: layer_idx out of bounds")
        if seq_len <= 0 or seq_len > self.max_seq_len:
            raise Error("KVCache.get_k_slice: seq_len out of bounds")
        var offset = layer_idx * self.max_seq_len * self.hidden_dim
        return RuneTensor[f16](
            seq_len, self.hidden_dim, self.k.data.unsafe_offset(offset), False
        )

    @always_inline
    def get_v_slice(
        self, layer_idx: Int, seq_len: Int
    ) raises -> RuneTensor[f16]:
        """Returns a RuneTensor view over active Value tokens [0..seq_len) for layer_idx.
        """
        if layer_idx < 0 or layer_idx >= self.num_layers:
            raise Error("KVCache.get_v_slice: layer_idx out of bounds")
        if seq_len <= 0 or seq_len > self.max_seq_len:
            raise Error("KVCache.get_v_slice: seq_len out of bounds")
        var offset = layer_idx * self.max_seq_len * self.hidden_dim
        return RuneTensor[f16](
            seq_len, self.hidden_dim, self.v.data.unsafe_offset(offset), False
        )


struct PagedKVCache(Copyable):
    """
    Preallocated host K/V page pool with per-sequence logical page tables.

    Physical pages never move. Mapping, release, and reuse mutate only bounded
    metadata built at construction; token reads and writes translate through the
    owning sequence's logical-to-physical table.
    """
    var base_cache: KVCache
    var max_seq_len: Int
    var hidden_dim: Int
    var num_layers: Int
    var block_size: Int
    var num_blocks: Int
    var free_blocks: Int
    var max_sequences: Int
    var max_blocks_per_sequence: Int
    var page_table: List[Int]
    var block_owner: List[Int]
    var block_logical_index: List[Int]
    var sequence_lengths: List[Int]
    var layer_lengths: List[Int]
    var owns_storage: Bool

    def __init__(
        out self,
        max_seq_len: Int,
        hidden_dim: Int,
        mut well: MimirWell,
        num_layers: Int = 32,
        block_size: Int = 16,
        max_sequences: Int = 1,
        physical_blocks: Int = 0,
    ) raises:
        if (
            max_seq_len <= 0
            or hidden_dim <= 0
            or num_layers <= 0
            or block_size <= 0
            or max_sequences <= 0
        ):
            raise Error("PagedKVCache: dimensions must be positive")
        if max_seq_len > 9223372036854775807 - (block_size - 1):
            raise Error("PagedKVCache: logical block count overflow")
        var logical_blocks = (max_seq_len + block_size - 1) // block_size
        if logical_blocks <= 0:
            raise Error("PagedKVCache: logical block count is invalid")
        if max_sequences > 9223372036854775807 // logical_blocks:
            raise Error("PagedKVCache: page-table size overflow")
        var table_entries = max_sequences * logical_blocks
        if max_sequences > 9223372036854775807 // num_layers:
            raise Error("PagedKVCache: layer-state size overflow")
        var layer_entries = max_sequences * num_layers
        var actual_physical_blocks = physical_blocks
        if actual_physical_blocks == 0:
            actual_physical_blocks = table_entries
        if actual_physical_blocks <= 0 or actual_physical_blocks > table_entries:
            raise Error(
                "PagedKVCache: physical_blocks must be 1..logical page capacity"
            )
        if actual_physical_blocks > 9223372036854775807 // block_size:
            raise Error("PagedKVCache: physical token capacity overflow")
        var physical_tokens = actual_physical_blocks * block_size
        self.base_cache = KVCache(
            physical_tokens, hidden_dim, well, num_layers
        )
        self.max_seq_len = max_seq_len
        self.hidden_dim = hidden_dim
        self.num_layers = num_layers
        self.block_size = block_size
        self.num_blocks = actual_physical_blocks
        self.free_blocks = actual_physical_blocks
        self.max_sequences = max_sequences
        self.max_blocks_per_sequence = logical_blocks
        self.page_table = List[Int]()
        self.block_owner = List[Int]()
        self.block_logical_index = List[Int]()
        self.sequence_lengths = List[Int]()
        self.layer_lengths = List[Int]()
        for _ in range(table_entries):
            self.page_table.append(-1)
        for _ in range(actual_physical_blocks):
            self.block_owner.append(-1)
            self.block_logical_index.append(-1)
        for _ in range(max_sequences):
            self.sequence_lengths.append(0)
        for _ in range(layer_entries):
            self.layer_lengths.append(0)
        self.owns_storage = False

    def __copyinit__(out self, existing: Self):
        var elements = existing.base_cache.k.size
        var k_allocation = alloc(Layout[Scalar[f16]](count=elements))
        var v_allocation = alloc(Layout[Scalar[f16]](count=elements))
        var k_pointer = k_allocation^.unsafe_leak()
        var v_pointer = v_allocation^.unsafe_leak()
        for index in range(elements):
            k_pointer.unsafe_store(
                index, existing.base_cache.k.data.unsafe_load(index)
            )
            v_pointer.unsafe_store(
                index, existing.base_cache.v.data.unsafe_load(index)
            )
        self.base_cache = KVCache(
            existing.base_cache.max_seq_len,
            existing.base_cache.hidden_dim,
            k_pointer,
            v_pointer,
            existing.base_cache.num_layers,
        )
        self.max_seq_len = existing.max_seq_len
        self.hidden_dim = existing.hidden_dim
        self.num_layers = existing.num_layers
        self.block_size = existing.block_size
        self.num_blocks = existing.num_blocks
        self.free_blocks = existing.free_blocks
        self.max_sequences = existing.max_sequences
        self.max_blocks_per_sequence = existing.max_blocks_per_sequence
        self.page_table = existing.page_table.copy()
        self.block_owner = existing.block_owner.copy()
        self.block_logical_index = existing.block_logical_index.copy()
        self.sequence_lengths = existing.sequence_lengths.copy()
        self.layer_lengths = existing.layer_lengths.copy()
        self.owns_storage = True

    def __init__(
        out self,
        existing: Self,
        owned_k: Pointer[Scalar[f16], MutUntrackedOrigin],
        owned_v: Pointer[Scalar[f16], MutUntrackedOrigin],
    ):
        """Builds an internal independent snapshot from already-copied storage."""
        self.base_cache = KVCache(
            RuneTensor[f16](
                existing.base_cache.k.rows,
                existing.base_cache.k.cols,
                owned_k,
                False,
            ),
            RuneTensor[f16](
                existing.base_cache.v.rows,
                existing.base_cache.v.cols,
                owned_v,
                False,
            ),
            existing.base_cache.max_seq_len,
            existing.base_cache.hidden_dim,
            existing.base_cache.num_layers,
        )
        self.max_seq_len = existing.max_seq_len
        self.hidden_dim = existing.hidden_dim
        self.num_layers = existing.num_layers
        self.block_size = existing.block_size
        self.num_blocks = existing.num_blocks
        self.free_blocks = existing.free_blocks
        self.max_sequences = existing.max_sequences
        self.max_blocks_per_sequence = existing.max_blocks_per_sequence
        self.page_table = existing.page_table.copy()
        self.block_owner = existing.block_owner.copy()
        self.block_logical_index = existing.block_logical_index.copy()
        self.sequence_lengths = existing.sequence_lengths.copy()
        self.layer_lengths = existing.layer_lengths.copy()
        self.owns_storage = True

    def copy(self) -> Self:
        """Returns an independent metadata and K/V-storage snapshot."""
        var elements = self.base_cache.k.size
        var k_allocation = alloc(Layout[Scalar[f16]](count=elements))
        var v_allocation = alloc(Layout[Scalar[f16]](count=elements))
        var k_pointer = k_allocation^.unsafe_leak()
        var v_pointer = v_allocation^.unsafe_leak()
        for index in range(elements):
            k_pointer.unsafe_store(
                index, self.base_cache.k.data.unsafe_load(index)
            )
            v_pointer.unsafe_store(
                index, self.base_cache.v.data.unsafe_load(index)
            )
        return Self(self, k_pointer, v_pointer)

    def __deinit__(deinit self):
        if self.owns_storage:
            self.base_cache.k.data.unsafe_free()
            self.base_cache.v.data.unsafe_free()

    @always_inline
    def _validate_sequence(self, sequence_id: Int) raises:
        if sequence_id < 0 or sequence_id >= self.max_sequences:
            raise Error("PagedKVCache: sequence_id out of bounds")

    @always_inline
    def _validate_logical_block(self, logical_block: Int) raises:
        if logical_block < 0 or logical_block >= self.max_blocks_per_sequence:
            raise Error("PagedKVCache: logical block out of bounds")

    @always_inline
    def _page_index(self, sequence_id: Int, logical_block: Int) -> Int:
        return (
            sequence_id * self.max_blocks_per_sequence + logical_block
        )

    @always_inline
    def _layer_index(self, sequence_id: Int, layer_idx: Int) -> Int:
        return sequence_id * self.num_layers + layer_idx

    def mapped_block(self, sequence_id: Int, logical_block: Int) raises -> Int:
        self._validate_sequence(sequence_id)
        self._validate_logical_block(logical_block)
        return self.page_table[self._page_index(sequence_id, logical_block)]

    def allocate_block(
        mut self, sequence_id: Int, logical_block: Int
    ) raises -> Int:
        self._validate_sequence(sequence_id)
        self._validate_logical_block(logical_block)
        var page_index = self._page_index(sequence_id, logical_block)
        if self.page_table[page_index] >= 0:
            raise Error("PagedKVCache: logical block is already mapped")
        if logical_block > 0:
            var previous = self.page_table[
                self._page_index(sequence_id, logical_block - 1)
            ]
            if previous < 0:
                raise Error("PagedKVCache: logical pages must be mapped in order")
        if self.free_blocks <= 0:
            raise Error("PagedKVCache: out of physical blocks")
        var physical_block = -1
        for candidate in range(self.num_blocks):
            if self.block_owner[candidate] < 0:
                physical_block = candidate
                break
        if physical_block < 0:
            raise Error("PagedKVCache: free-block accounting invariant failed")
        self.page_table[page_index] = physical_block
        self.block_owner[physical_block] = sequence_id
        self.block_logical_index[physical_block] = logical_block
        self.free_blocks -= 1
        return physical_block

    def allocate_block(mut self) raises -> Int:
        for logical_block in range(self.max_blocks_per_sequence):
            if self.page_table[self._page_index(0, logical_block)] < 0:
                return self.allocate_block(0, logical_block)
        raise Error("PagedKVCache: sequence 0 has no unmapped logical blocks")

    def _free_mapping(
        mut self,
        sequence_id: Int,
        logical_block: Int,
        require_tail: Bool,
    ) raises:
        var page_index = self._page_index(sequence_id, logical_block)
        var physical_block = self.page_table[page_index]
        if physical_block < 0:
            raise Error("PagedKVCache: logical block is not mapped")
        if require_tail:
            for later in range(
                logical_block + 1, self.max_blocks_per_sequence
            ):
                if self.page_table[self._page_index(sequence_id, later)] >= 0:
                    raise Error("PagedKVCache: only the mapped tail can be freed")
        if (
            physical_block >= self.num_blocks
            or self.block_owner[physical_block] != sequence_id
            or self.block_logical_index[physical_block] != logical_block
        ):
            raise Error("PagedKVCache: page ownership invariant failed")
        self.page_table[page_index] = -1
        self.block_owner[physical_block] = -1
        self.block_logical_index[physical_block] = -1
        self.free_blocks += 1
        var new_length = logical_block * self.block_size
        if self.sequence_lengths[sequence_id] > new_length:
            self.sequence_lengths[sequence_id] = new_length
        for layer_idx in range(self.num_layers):
            var layer_index = self._layer_index(sequence_id, layer_idx)
            if self.layer_lengths[layer_index] > new_length:
                self.layer_lengths[layer_index] = new_length

    def free_sequence_block(
        mut self, sequence_id: Int, logical_block: Int
    ) raises:
        self._validate_sequence(sequence_id)
        self._validate_logical_block(logical_block)
        self._free_mapping(sequence_id, logical_block, True)

    def free_block(mut self, block_idx: Int) raises:
        if block_idx < 0 or block_idx >= self.num_blocks:
            raise Error("PagedKVCache: block_idx out of bounds")
        var owner = self.block_owner[block_idx]
        var logical_block = self.block_logical_index[block_idx]
        if owner < 0 or logical_block < 0:
            raise Error("PagedKVCache: physical block is already free")
        self._free_mapping(owner, logical_block, True)

    def release_sequence(mut self, sequence_id: Int) raises:
        self._validate_sequence(sequence_id)
        for logical_block in range(self.max_blocks_per_sequence - 1, -1, -1):
            if self.page_table[
                self._page_index(sequence_id, logical_block)
            ] >= 0:
                self._free_mapping(sequence_id, logical_block, False)
        self.sequence_lengths[sequence_id] = 0
        for layer_idx in range(self.num_layers):
            self.layer_lengths[self._layer_index(sequence_id, layer_idx)] = 0

    def sequence_length(self, sequence_id: Int) raises -> Int:
        self._validate_sequence(sequence_id)
        return self.sequence_lengths[sequence_id]

    def append(
        mut self,
        sequence_id: Int,
        layer_idx: Int,
        pos: Int,
        key: RuneTensor[f16],
        val: RuneTensor[f16],
    ) raises:
        self._validate_sequence(sequence_id)
        if layer_idx < 0 or layer_idx >= self.num_layers:
            raise Error("PagedKVCache.append: layer_idx out of bounds")
        if pos < 0 or pos >= self.max_seq_len:
            raise Error("PagedKVCache.append: pos out of bounds")
        var layer_index = self._layer_index(sequence_id, layer_idx)
        if pos > self.layer_lengths[layer_index]:
            raise Error("PagedKVCache.append: layer positions must be contiguous")
        if (
            key.size < self.hidden_dim
            or val.size < self.hidden_dim
            or Int(key.data) <= 1
            or Int(val.data) <= 1
        ):
            raise Error("PagedKVCache.append: key/value storage is invalid")
        var logical_block = pos // self.block_size
        var page_index = self._page_index(sequence_id, logical_block)
        var physical_block = self.page_table[page_index]
        if physical_block < 0:
            physical_block = self.allocate_block(sequence_id, logical_block)
        var physical_pos = physical_block * self.block_size + pos % self.block_size
        self.base_cache.append(layer_idx, physical_pos, key, val)
        if pos == self.layer_lengths[layer_index]:
            self.layer_lengths[layer_index] += 1
        if pos == self.sequence_lengths[sequence_id]:
            self.sequence_lengths[sequence_id] += 1

    def get_k(
        self, sequence_id: Int, layer_idx: Int, pos: Int, column: Int
    ) raises -> Scalar[f16]:
        self._validate_sequence(sequence_id)
        if layer_idx < 0 or layer_idx >= self.num_layers:
            raise Error("PagedKVCache.get_k: layer_idx out of bounds")
        if pos < 0 or pos >= self.layer_lengths[
            self._layer_index(sequence_id, layer_idx)
        ]:
            raise Error("PagedKVCache.get_k: pos out of bounds")
        if column < 0 or column >= self.hidden_dim:
            raise Error("PagedKVCache.get_k: column out of bounds")
        var logical_block = pos // self.block_size
        var physical_block = self.page_table[
            self._page_index(sequence_id, logical_block)
        ]
        if physical_block < 0:
            raise Error("PagedKVCache.get_k: logical page is not mapped")
        var physical_pos = physical_block * self.block_size + pos % self.block_size
        var row = layer_idx * self.base_cache.max_seq_len + physical_pos
        return self.base_cache.k.get_checked(row, column)

    def get_v(
        self, sequence_id: Int, layer_idx: Int, pos: Int, column: Int
    ) raises -> Scalar[f16]:
        self._validate_sequence(sequence_id)
        if layer_idx < 0 or layer_idx >= self.num_layers:
            raise Error("PagedKVCache.get_v: layer_idx out of bounds")
        if pos < 0 or pos >= self.layer_lengths[
            self._layer_index(sequence_id, layer_idx)
        ]:
            raise Error("PagedKVCache.get_v: pos out of bounds")
        if column < 0 or column >= self.hidden_dim:
            raise Error("PagedKVCache.get_v: column out of bounds")
        var logical_block = pos // self.block_size
        var physical_block = self.page_table[
            self._page_index(sequence_id, logical_block)
        ]
        if physical_block < 0:
            raise Error("PagedKVCache.get_v: logical page is not mapped")
        var physical_pos = physical_block * self.block_size + pos % self.block_size
        var row = layer_idx * self.base_cache.max_seq_len + physical_pos
        return self.base_cache.v.get_checked(row, column)



struct MimirWell:
    """
    MimirWell: Pre-allocates a contiguous block of VRAM/RAM (The Waters of Wisdom).
    Strictly forbids dynamic allocation during inference to maintain the purity and speed of the living system.
    """

    var base_ptr: Pointer[Scalar[f16], MutUntrackedOrigin]
    var capacity: Int
    var offset: Int

    def __init__(out self, size_in_bytes: Int) raises:
        if size_in_bytes <= 0:
            raise Error("MimirWell: pool size must be positive")
        # Calculate number of f16 elements
        self.capacity = size_in_bytes // 2
        var allocation = alloc(Layout[Scalar[f16]](count=self.capacity))
        self.base_ptr = allocation^.unsafe_leak()
        self.offset = 0
        unsafe_memset_zero(self.base_ptr, self.capacity)

    def allocate(
        mut self, elements: Int
    ) raises -> Pointer[Scalar[f16], MutUntrackedOrigin]:
        if elements <= 0:
            raise Error("MimirWell: allocation count must be positive")
        if self.offset + elements > self.capacity:
            raise Error("MimirWell: memory pool exhausted")

        var ptr = self.base_ptr.unsafe_offset(self.offset)
        self.offset += elements
        return ptr

    def allocate_npu_buffer(
        mut self,
        size_bytes: Int,
        backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON),
    ) raises -> NPUBuffer:
        """Returns a CPU-resident host descriptor; no NPU mapping occurs."""
        return NPUBuffer(self, size_bytes, backend)

    def allocate_gpu_buffer(
        mut self,
        size_bytes: Int,
        realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA),
    ) raises -> GPUBuffer:
        """Returns a CPU-resident host descriptor; no GPU mapping occurs."""
        return GPUBuffer(self, size_bytes, realm)

    def reset_kv_cache(mut self, kv_offset_start: Int) raises:
        """Reset point for KV Cache."""
        if kv_offset_start < 0 or kv_offset_start > self.offset:
            raise Error("MimirWell: invalid reset offset")
        self.offset = kv_offset_start

    def reset(mut self):
        """Resets offset to 0 for zero-overhead arena recycling."""
        self.offset = 0

    def allocated_bytes(self) -> Int:
        """Returns currently allocated byte count in MimirWell pool."""
        return self.offset * 2

    def capacity_bytes(self) -> Int:
        """Returns total pool byte capacity of MimirWell."""
        return self.capacity * 2

    def free_bytes(self) -> Int:
        """Returns remaining unallocated byte count in MimirWell pool."""
        return max(0, (self.capacity - self.offset) * 2)

    def utilization_pct(self) -> Float32:
        """Returns pool utilization percentage (0.0 to 100.0)."""
        if self.capacity <= 0:
            return 0.0
        return (Float32(self.offset) / Float32(self.capacity)) * 100.0

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

    def __init__(out self, max_docs: Int, dim: Int, mut well: MimirWell) raises:
        if max_docs <= 0 or dim <= 0:
            raise Error("MimirStore: dimensions must be positive")
        self.max_docs = max_docs
        self.dim = dim
        self.count = 0
        self.documents = List[String]()
        var ptr = well.allocate(max_docs * dim)
        self.embeddings = RuneTensor[f16](max_docs, dim, ptr, False)

    def __init__(
        out self, mut well: MimirWell, max_docs: Int = 100, dim: Int = 4096
    ) raises:
        if max_docs <= 0 or dim <= 0:
            raise Error("MimirStore: dimensions must be positive")
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

    def clear(mut self):
        """Clears all stored documents and resets embedding index count."""
        self.count = 0
        self.documents = List[String]()

    def add_document(mut self, doc: String, embedding: RuneTensor[f16]) raises:
        """Appends text document chunks and vectors into MimirStore."""
        if self.count >= self.max_docs:
            raise Error("MimirStore: capacity reached")
        if embedding.size != self.dim:
            raise Error("MimirStore: embedding dimension mismatch")
        self.documents.append(doc)
        var offset = self.count * self.dim
        for i in range(self.dim):
            var val = embedding.data.unsafe_load(i)
            self.embeddings.data.unsafe_store(offset + i, val)
        self.count += 1

    def search_knn(
        self, query_emb: RuneTensor[f16], top_k: Int = 3
    ) raises -> List[String]:
        """Using SIMD cosine_similarity to retrieve nearest document strings."""
        from core.compute import cosine_similarity

        if top_k <= 0:
            raise Error("MimirStore.search_knn: top_k must be positive")
        if query_emb.size != self.dim:
            raise Error(
                "MimirStore.search_knn: query vector dimension mismatch"
            )

        var result = List[String]()
        if self.count == 0:
            return result^

        var scores = List[Scalar[f32]]()
        var indices = List[Int]()

        for i in range(self.count):
            var doc_emb = RuneTensor[f16](
                1,
                self.dim,
                self.embeddings.data.unsafe_offset(i * self.dim),
                False,
            )
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
    Describes configured logical host partitions and validated accelerator
    records. Default construction performs no physical hardware probe.
    """

    var num_devices: Int
    var device_names: List[String]
    var npu_backends: List[NPUBackendType]
    var gpu_realms: List[GPURealmType]
    var physical_devices: List[PhysicalDevice]
    var last_gpu_discovery_status: DiscoveryStatus

    def __init__(out self, num_devices: Int = 1):
        self.num_devices = max(1, num_devices)
        self.device_names = List[String]()
        for i in range(self.num_devices):
            self.device_names.append("host:" + String(i))
        self.npu_backends = List[NPUBackendType]()
        self.gpu_realms = List[GPURealmType]()
        self.physical_devices = List[PhysicalDevice]()
        self.last_gpu_discovery_status = DiscoveryStatus(
            DiscoveryStatus.NO_DEVICE
        )
        self.detect_edge_npus()
        self.detect_gpu_realms()

    def __init__(out self, num_devices: Int, device_names: List[String]):
        self.num_devices = max(1, num_devices)
        self.device_names = device_names.copy()
        self.npu_backends = List[NPUBackendType]()
        self.gpu_realms = List[GPURealmType]()
        self.physical_devices = List[PhysicalDevice]()
        self.last_gpu_discovery_status = DiscoveryStatus(
            DiscoveryStatus.NO_DEVICE
        )
        self.detect_edge_npus()
        self.detect_gpu_realms()

    def __copyinit__(out self, existing: Self):
        self.num_devices = existing.num_devices
        self.device_names = existing.device_names.copy()
        self.npu_backends = existing.npu_backends.copy()
        self.gpu_realms = existing.gpu_realms.copy()
        self.physical_devices = existing.physical_devices.copy()
        self.last_gpu_discovery_status = (
            existing.last_gpu_discovery_status.copy()
        )

    def detect_edge_npus(mut self):
        """Reports default edge NPUs (comptime safe)."""
        self.npu_backends.clear()

    def probe_npu_realms(mut self):
        """Runtime probe for edge/desktop NPU backends."""
        self.npu_backends.clear()
        from core.npu_gate import NPUGate

        for b_id in range(7):
            var b = NPUBackendType(b_id)
            if NPUGate.is_available(b) and NPUGate.get_device_count(b) > 0:
                self.npu_backends.append(b)

    def detect_gpu_realms(mut self):
        """Default constructor initialization (comptime safe)."""
        self.gpu_realms.clear()
        self.physical_devices.clear()
        self.last_gpu_discovery_status = DiscoveryStatus(
            DiscoveryStatus.NO_DEVICE
        )

    def _append_gpu_realm_if_missing(mut self, realm: GPURealmType):
        for existing in self.gpu_realms:
            if existing == realm:
                return
        self.gpu_realms.append(realm.copy())

    def apply_gpu_discovery(mut self, result: HardwareDiscoveryResult) raises:
        """Apply a production result or an explicitly injected test snapshot."""
        result.validate()
        self.last_gpu_discovery_status = result.status.copy()
        for device in result.devices:
            for existing in self.physical_devices:
                if existing.stable_id == device.stable_id:
                    raise Error("DeviceTopology: duplicate physical stable_id")
                if (
                    existing.realm == device.realm
                    and existing.backend_index == device.backend_index
                ):
                    raise Error(
                        "DeviceTopology: duplicate physical backend index"
                    )
            self.physical_devices.append(device.copy())
            self._append_gpu_realm_if_missing(device.realm)

    def probe_cuda_realm(mut self) raises:
        """Discover NVIDIA CUDA devices through the selected MAX runtime."""
        from core.cuda_gate import CUDAGate

        self.apply_gpu_discovery(CUDAGate.discover_physical_devices())

    def probe_metal_realm(mut self):
        """Runtime probe for Apple Metal GPU realm."""
        from core.metal_gate import MetalGate

        if MetalGate.is_available() and MetalGate.get_device_count() > 0:
            self._append_gpu_realm_if_missing(
                GPURealmType(GPURealmType.APPLE_METAL)
            )

    def probe_intel_realm(mut self):
        """Runtime probe for Intel OneAPI / Level Zero GPU realm."""
        from core.intel_gate import IntelGate

        if IntelGate.is_available() and IntelGate.get_device_count() > 0:
            self._append_gpu_realm_if_missing(
                GPURealmType(GPURealmType.INTEL_ONEAPI_XE)
            )

    def probe_amd_realm(mut self):
        """Runtime probe for AMD ROCm / HIP GPU realm."""
        from core.amd_gate import AMDGate

        if AMDGate.is_available() and AMDGate.get_device_count() > 0:
            self._append_gpu_realm_if_missing(
                GPURealmType(GPURealmType.AMD_ROCM_HIP)
            )

    def probe_all_hardware(mut self):
        """
        Probes all physical NPU backends and GPU hardware realms.
        Populates discovered backends and returns active physical hardware count.
        """
        self.probe_npu_realms()
        try:
            self.probe_cuda_realm()
        except:
            pass
        self.probe_intel_realm()
        self.probe_amd_realm()

    def require_npu_backend(self, backend: NPUBackendType) raises:
        """
        Validates that requested NPU backend is physically discovered.
        Raises explicit Error if absent, preventing CPU silent fallback under hardware label.
        """
        for i in range(len(self.npu_backends)):
            if self.npu_backends[i].value == backend.value:
                return
        raise Error("Hardware accelerator NPU backend '" + backend.name() + "' is not physically discovered or supported on this platform")

    def require_gpu_realm(self, realm: GPURealmType) raises:
        """
        Validates that requested GPU realm is physically discovered.
        Raises explicit Error if absent, preventing CPU silent fallback under hardware label.
        """
        for i in range(len(self.gpu_realms)):
            if self.gpu_realms[i].value == realm.value:
                return
        raise Error("Hardware accelerator GPU realm '" + realm.name() + "' is not physically discovered or supported on this platform")


    def select_gpu_by_index(
        self, realm: GPURealmType, backend_index: Int
    ) raises -> PhysicalDevice:
        """Select a compatible observed device by realm-local index."""
        if backend_index < 0:
            raise Error("DeviceTopology: backend_index must not be negative")
        for device in self.physical_devices:
            if device.realm == realm and device.backend_index == backend_index:
                if not device.capabilities.is_compatible:
                    raise Error(
                        "DeviceTopology: selected GPU is incompatible with MAX"
                    )
                return device.copy()
        raise Error(
            "DeviceTopology: GPU realm '"
            + realm.name()
            + "' has no observed device at backend index "
            + String(backend_index)
        )

    def select_gpu_by_stable_id(
        self, stable_id: String
    ) raises -> PhysicalDevice:
        """Select a compatible observed device by its runtime-derived stable ID.
        """
        if stable_id.byte_length() == 0:
            raise Error("DeviceTopology: stable_id must not be empty")
        for device in self.physical_devices:
            if device.stable_id == stable_id:
                if not device.capabilities.is_compatible:
                    raise Error(
                        "DeviceTopology: selected GPU is incompatible with MAX"
                    )
                return device.copy()
        raise Error(
            "DeviceTopology: no observed GPU has stable_id '" + stable_id + "'"
        )



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


def shard_split_cols(
    T: RuneTensor[f16], num_shards: Int, mut well: MimirWell
) raises -> List[RuneTensor[f16]]:
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
            result.append(
                RuneTensor[f16](T.rows, shard_cols, ptr, T.is_quantized)
            )

    return result^


def shard_split_cols(
    T: RuneTensor[f16], num_shards: Int
) -> List[RuneTensor[f16]]:
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
            var allocation = alloc(
                Layout[Scalar[f16]](count=T.rows * shard_cols)
            )
            var ptr = allocation^.unsafe_leak()
            for r in range(T.rows):
                for c in range(shard_cols):
                    var val = T.get(r, i * shard_cols + c)
                    ptr.unsafe_store(r * shard_cols + c, val)
            result.append(
                RuneTensor[f16](T.rows, shard_cols, ptr, T.is_quantized)
            )

    return result^


def shard_split_rows(
    T: RuneTensor[f16], num_shards: Int
) -> List[RuneTensor[f16]]:
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


def shard_split_gqa_heads(
    num_heads: Int,
    num_kv_heads: Int,
    head_dim: Int,
    num_devices: Int,
) raises -> Tuple[Int, Int]:
    """
    Computes GQA head partitioning across multi-device topology shards.
    Validates head divisibility and returns (heads_per_shard, kv_heads_per_shard).
    """
    if num_heads <= 0 or num_kv_heads <= 0 or head_dim <= 0 or num_devices <= 0:
        raise Error("shard_split_gqa_heads: all parameters must be positive")
    if num_heads % num_devices != 0:
        raise Error("shard_split_gqa_heads: num_heads must be divisible by num_devices")
    if num_kv_heads % num_devices != 0:
        raise Error("shard_split_gqa_heads: num_kv_heads must be divisible by num_devices")
    
    var heads_per_shard = num_heads // num_devices
    var kv_heads_per_shard = num_kv_heads // num_devices
    return (heads_per_shard, kv_heads_per_shard)

