# Core Domain Interface Specification

> **Current execution boundary:** the documented CPU path remains supported, and
> `gemma4_cuda.mojo` executes the full dense text-only Gemma 4 E4B Q4_K_M model
> on one CUDA device: packed weights, activations, KV cache, transformer
> operations, logits, and greedy selection are device-resident. Other GPU/NPU
> backends, multi-GPU, generic GPU selection, and logical shards remain
> unimplemented or host-only. See `docs/CURRENT_STATUS.md` for the evidence
> boundary.
> `llama3_cuda.mojo` adds the separate dense Llama 3 8B Stheno profile with the
> same device ownership, an F16 KV cache and an 8K context ceiling.

## Public Structs & Functions

### `MimirWell`
Pre-allocates the contiguous workspace pool. Raises `Error` on nonpositive pool sizes, negative allocations, integer overflow, or pool exhaustion.

```mojo
struct MimirWell:
    def __init__(out self, size_in_bytes: Int) raises: ...
    def allocate(mut self, elements: Int) raises -> Pointer[Scalar[f16], MutUntrackedOrigin]: ...
    def allocate_npu_buffer(mut self, size_bytes: Int, backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON)) raises -> NPUBuffer: ... # Slice 7
    def allocate_gpu_buffer(mut self, size_bytes: Int, realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)) raises -> GPUBuffer: ... # Slice 8
    def reset_kv_cache(mut self, kv_offset_start: Int) raises: ...
```

### `RuneTensor[type: DType]`
Zero-copy tensor descriptor wrapping pointer offsets. Enforces positive shape dimensions and provides checked indexing.

```mojo
struct RuneTensor[type: DType]:
    var data: Pointer[Scalar[Self.type], MutUntrackedOrigin]
    var rows: Int
    var cols: Int
    var size: Int
    var is_quantized: Bool

    def __init__(out self, rows: Int, cols: Int, pre_allocated_ptr: Pointer[Scalar[Self.type], MutUntrackedOrigin], is_quantized: Bool = False): ...  # unchecked internal view
    @staticmethod
    def checked(rows: Int, cols: Int, pre_allocated_ptr: Pointer[Scalar[Self.type], MutUntrackedOrigin], is_quantized: Bool = False) raises -> Self: ...
    def get(self, r: Int, c: Int) -> Scalar[Self.type]: ...
    def set(mut self, r: Int, c: Int, val: Scalar[Self.type]): ...
    def get_checked(self, r: Int, c: Int) raises -> Scalar[Self.type]: ...
    def set_checked(mut self, r: Int, c: Int, val: Scalar[Self.type]) raises: ...
```

`checked()` is the trust-boundary constructor and rejects nonpositive shapes,
wrapped shape products, and null/address-1 pointers. The non-raising initializer
is an explicitly unchecked internal view primitive used by copy and slice paths;
callers must already own its shape, pointer, and lifetime invariants.

### `BlockQ4_K`
Memory layout descriptor for Q4_K quantized blocks.

```mojo
struct BlockQ4_K:
    var scale: Scalar[f16]
    var min_val: Scalar[f16]
    var qs: SIMD[DType.uint8, 16]
```

### `KVCache`
Contiguous Key-Value cache drawn from `MimirWell`. Validates layer index bounds, sequence length span, and vector width.

```mojo
struct KVCache:
    var k: RuneTensor[f16]
    var v: RuneTensor[f16]
    var max_seq_len: Int
    var hidden_dim: Int
    var num_layers: Int

    def __init__(out self, max_seq_len: Int, hidden_dim: Int, mut well: MimirWell, num_layers: Int = 32) raises: ...
    def append(mut self, layer_idx: Int, pos: Int, key: RuneTensor[f16], val: RuneTensor[f16]) raises: ...
    def get_k_slice(self, layer_idx: Int, seq_len: Int) raises -> RuneTensor[f16]: ...
    def get_v_slice(self, layer_idx: Int, seq_len: Int) raises -> RuneTensor[f16]: ...
    def __init__(out self, max_seq_len: Int, hidden_dim: Int, k_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], v_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_layers: Int = 1) raises: ...
```

Positions form one chronological prefix and never wrap. `append()` rejects
`pos >= max_seq_len` before writing, and pointer-backed construction rejects
invalid dimensions and null/address-1 storage.

### `PagedKVCache`

Reserved compatibility API only. No page table or block allocator is present;
construction, allocation, and free operations raise `not implemented`.

```mojo
struct PagedKVCache(Copyable):
    def __init__(out self, max_seq_len: Int, hidden_dim: Int, mut well: MimirWell, num_layers: Int = 32, block_size: Int = 16) raises: ...
    def allocate_block(mut self) raises -> Int: ...
    def free_block(mut self, block_idx: Int) raises: ...
```

### `MimirStore`
Vector store pre-allocating zero-copy memory inside `MimirWell`. Validates vector dimensions (`embedding.size == dim`) and `top_k > 0`.

```mojo
struct MimirStore:
    var documents: List[String]
    var embeddings: RuneTensor[f16]
    var max_docs: Int
    var dim: Int
    var count: Int

    def __init__(out self, max_docs: Int, dim: Int, mut well: MimirWell) raises: ...
    def __init__(out self, mut well: MimirWell, max_docs: Int = 100, dim: Int = 4096) raises: ...
    def add_document(mut self, doc: String, embedding: RuneTensor[f16]) raises: ...
    def search_knn(self, query_emb: RuneTensor[f16], top_k: Int = 3) raises -> List[String]: ...
```

### `DiscoveryStatus`, `DeviceCapabilities`, `PhysicalDevice`, and `HardwareDiscoveryResult`

Validated truth-bearing records for accelerator discovery. CUDA stable IDs use
the public MAX runtime ID (`cuda:max-id:<id>`); they are not vendor UUIDs.

```mojo
struct DiscoveryStatus(Copyable, ImplicitlyCopyable):
    comptime SUCCESS = 0
    comptime PARTIAL = 1
    comptime UNSUPPORTED_RUNTIME = 2
    comptime NO_DEVICE = 3
    comptime INCOMPATIBLE_DRIVER = 4
    comptime UNSUPPORTED_ARCHITECTURE = 5
    comptime MISSING_COMPILER_TOOL = 6
    comptime PERMISSION_DENIED = 7
    comptime PROBE_FAILED = 8

struct DeviceCapabilities(Copyable):
    var is_compatible: Bool
    var api_version: Int
    var free_memory_bytes: UInt
    var total_memory_bytes: UInt
    var compute_capability_major: Int
    var compute_capability_minor: Int
    var multiprocessor_count: Int
    var max_threads_per_block: Int
    def validate(self) raises: ...

struct PhysicalDevice(Copyable):
    var realm: GPURealmType
    var backend_index: Int
    var runtime_id: Int64
    var stable_id: String
    var name: String
    var api: String
    var capabilities: DeviceCapabilities
    def validate(self) raises: ...

struct HardwareDiscoveryResult(Copyable):
    var status: DiscoveryStatus
    var message: String
    var devices: List[PhysicalDevice]
    def validate(self) raises: ...
```

Validation rejects empty successful results, devices attached to failure
statuses, invalid capability values, duplicate stable IDs, and duplicate
realm-local indices.

### `DeviceTopology` (Slices 6–8 and GPU-1)

Maps logical host partitions and retains validated observed accelerator records.
Default construction is side-effect-free with respect to hardware probing.

```mojo
struct DeviceTopology:
    var num_devices: Int
    var device_names: List[String]
    var npu_backends: List[NPUBackendType]  # Slice 7
    var gpu_realms: List[GPURealmType]     # Slice 8
    var physical_devices: List[PhysicalDevice]
    var last_gpu_discovery_status: DiscoveryStatus

    def __init__(out self, num_devices: Int = 1): ...
    def __init__(out self, num_devices: Int, device_names: List[String]): ...
    def detect_edge_npus(mut self): ...
    def detect_gpu_realms(mut self): ...
    def apply_gpu_discovery(mut self, result: HardwareDiscoveryResult) raises: ...
    def probe_cuda_realm(mut self) raises: ...
    def probe_all_hardware(mut self) raises: ...
    def select_gpu_by_index(self, realm: GPURealmType, backend_index: Int) raises -> PhysicalDevice: ...
    def select_gpu_by_stable_id(self, stable_id: String) raises -> PhysicalDevice: ...
```

### `NPUBackendType` (reserved NPU surface)
Integer requested-backend discriminant. Values do not indicate discovery or
execution.

```mojo
struct NPUBackendType(Copyable, ImplicitlyCopyable):
    comptime HAILO_10 = 0
    comptime QUALCOMM_HEXAGON = 1
    comptime ARM_NEON = 2           # historical default discriminant
    comptime JETSON_NVIDIA = 3
    comptime APPLE_NEURAL_ENGINE = 4
    comptime GENERIC_NPU = 5

    var value: Int

    def __init__(out self, value: Int = 2): ...
    def name(self) -> String: ...
    def __eq__(self, rhs: Self) -> Bool: ...
    def __eq__(self, rhs: Int) -> Bool: ...
    def __ne__(self, rhs: Self) -> Bool: ...
    def __ne__(self, rhs: Int) -> Bool: ...
    def copy(self) -> Self: ...
```

### `NPUBuffer` (reserved NPU surface)
CPU-resident host-memory descriptor carved from `MimirWell`. `handle_fd` is
zero and `is_dma_buf` is false; no DMA-BUF/ION export or NPU mapping occurs.

```mojo
struct NPUBuffer(Copyable, ImplicitlyCopyable):
    var ptr: Pointer[Scalar[f16], MutUntrackedOrigin]
    var size_bytes: Int
    var handle_fd: Int32
    var is_dma_buf: Bool
    var backend: NPUBackendType

    def __init__(out self, ptr: Pointer[Scalar[f16], MutUntrackedOrigin], size_bytes: Int, handle_fd: Int32 = 0, is_dma_buf: Bool = False, backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON)): ...
    def __init__(out self, mut well: MimirWell, size_bytes: Int, backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON)): ...
    def as_rune_tensor(self, rows: Int, cols: Int) -> RuneTensor[f16]: ...
    def copy(self) -> Self: ...
```

### `GPURealmType` (reserved GPU surface)
Integer discriminant naming eleven requested GPU realms. A value does not imply
device presence, allocation, or execution.

```mojo
struct GPURealmType(Copyable, ImplicitlyCopyable):
    comptime NVIDIA_CUDA = 0         # Default — CUDA Tensor Cores
    comptime AMD_ROCM_HIP = 1        # hipBLAS / ROCm / RDNA3
    comptime INTEL_ONEAPI_XE = 2     # OneAPI Level Zero / Xe-HPG
    comptime MOORE_THREADS_MUSA = 3  # MUSA GPGPU
    comptime BIREN_SUPA = 4          # SUPA GPGPU
    comptime METAX_MACA = 5          # MACA GPGPU
    comptime HYGON_DCU = 6           # DTK / Zhaoxin DCU GPGPU
    comptime ARM_MALI_OPENCL = 7     # Mobile ARM Mali / OpenCL
    comptime QUALCOMM_ADRENO = 8     # Snapdragon Adreno / OpenCL
    comptime IMAGINATION_POWERVR = 9 # Embedded PowerVR
    comptime APPLE_METAL = 10        # Apple Metal

    var value: Int

    def __init__(out self, value: Int = 0): ...
    def name(self) -> String: ...   # Returns GPU realm string name
    def __eq__(self, rhs: Self) -> Bool: ...
    def __eq__(self, rhs: Int) -> Bool: ...
    def __ne__(self, rhs: Self) -> Bool: ...
    def __ne__(self, rhs: Int) -> Bool: ...
    def copy(self) -> Self: ...
```

### `GPUBuffer` (reserved GPU surface)
CPU-resident host-memory descriptor carved from `MimirWell`. The `realm` field
is metadata only; no device allocation, mapping, transfer, or execution occurs.

```mojo
struct GPUBuffer(Copyable, ImplicitlyCopyable):
    var ptr: Pointer[Scalar[f16], MutUntrackedOrigin]
    var size_bytes: Int
    var handle_fd: Int32
    var realm: GPURealmType

    def __init__(out self, ptr: Pointer[Scalar[f16], MutUntrackedOrigin], size_bytes: Int, handle_fd: Int32 = 0, realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)): ...
    def __init__(out self, mut well: MimirWell, size_bytes: Int, realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)): ...
    def as_rune_tensor(self, rows: Int, cols: Int) -> RuneTensor[f16]: ...
    def copy(self) -> Self: ...
```

### `CUDAGate` (GPU-1 discovery boundary)

Uses the locked MAX accelerator API for real CUDA enumeration and capability
inspection. A loadable library is not counted as a device. Errors are preserved
as explicit discovery statuses, and the execution methods remain unsupported.

```mojo
struct CUDAGate:
    @staticmethod
    def is_available() -> Bool: ...
    @staticmethod
    def get_device_count() -> Int: ...
    @staticmethod
    def classify_discovery_error(message: String) -> DiscoveryStatus: ...
    @staticmethod
    def discover_physical_devices() -> HardwareDiscoveryResult: ...
```

`discover_physical_devices()` records the runtime ID, name, API/version,
free/total memory, MAX compatibility, compute capability, multiprocessor count,
and maximum threads per block for each inspected CUDA index. It does not create
production contexts or buffers whose lifetime extends beyond discovery.

### `CUDAResourceBudget`, `CUDAF16Allocation`, and `CUDADeviceResources` (GPU-2)

`core/cuda_resources.mojo` owns the selected CUDA context and real MAX-managed
F16 resource lifecycle. These are move-only project wrappers: the underlying
MAX context, pinned-host buffer, and device buffer are reference-counted and
released by their `Deinitable` lifecycles after queued stream work completes.

```mojo
struct CUDAResourceBudget(Copyable):
    var device_limit_bytes: Int
    var pinned_host_limit_bytes: Int
    var device_reserved_bytes: Int
    var pinned_host_reserved_bytes: Int

    def __init__(out self, device_limit_bytes: Int, pinned_host_limit_bytes: Int) raises: ...
    @staticmethod
    def f16_size_bytes(element_count: Int) raises -> Int: ...
    @staticmethod
    def f16_batch3_size_bytes(first_element_count: Int, second_element_count: Int, third_element_count: Int) raises -> Int: ...
    def validate(self) raises: ...
    def remaining_device_bytes(self) -> Int: ...
    def remaining_pinned_host_bytes(self) -> Int: ...
    def reserve_f16(mut self, element_count: Int) raises -> Int: ...
    def reserve_f16_batch3(mut self, first_element_count: Int, second_element_count: Int, third_element_count: Int) raises -> Int: ...
    def rollback_f16(mut self, size_bytes: Int) raises: ...

def validate_cuda_resource_policy(device: PhysicalDevice, budget: CUDAResourceBudget) raises: ...

struct CUDAF16Allocation:
    var context: DeviceContext
    var host_buffer: HostBuffer[DType.float16]
    var device_buffer: DeviceBuffer[DType.float16]
    var element_count: Int
    var size_bytes: Int
    var stable_device_id: String
    var synchronization_count: Int

    def set_host(mut self, index: Int, value: Scalar[f16]) raises: ...
    def get_host(self, index: Int) raises -> Scalar[f16]: ...
    def enqueue_upload(self) raises: ...
    def enqueue_download(self) raises: ...
    def synchronize(mut self) raises: ...
    def upload_and_synchronize(mut self) raises: ...
    def download_and_synchronize(mut self) raises: ...

struct CUDADeviceResources:
    var context: DeviceContext
    var physical_device: PhysicalDevice
    var budget: CUDAResourceBudget
    var allocation_count: Int

    def __init__(out self, physical_device: PhysicalDevice, device_limit_bytes: Int, pinned_host_limit_bytes: Int) raises: ...
    def allocate_f16(mut self, element_count: Int) raises -> CUDAF16Allocation: ...
    def synchronize(self) raises: ...
```

Budget accounting is conservative and monotonic for a session. Failed MAX
allocation rolls back its reservation. Three-buffer GPU-3 admission reserves
one exact atomic total and restores that total if executor construction fails.
Dropping a buffer does not fabricate immediate pool reuse, and no owning raw
pointer is exposed.

### `CUDAGemmPlan` and `CUDAF16GemmExecutor` (GPU-3)

`core/cuda_gemm_plan.mojo` provides hardware-independent checked planning for
the existing `A[M,K] × B[N,K] → C[M,N]` layout. It validates positive
dimensions, shape products, F16 bytes, Int32 kernel ABI limits, block/grid
rounding, and both remaining resource budgets.

`core/cuda_compute.mojo` owns the real MAX CUDA kernel and its reusable
fixed-shape executor. The executor transactionally owns A, B, and C pinned-host
and device-buffer pairs, borrows their device pointers only for launch, uploads
both inputs, accumulates each output in F32 on the GPU, downloads C,
synchronizes, and then publishes every F16 result to the caller's checked host
tensor.

```mojo
struct CUDAGemmPlan(Copyable):
    var m: Int
    var k: Int
    var n: Int
    var a_element_count: Int
    var b_element_count: Int
    var c_element_count: Int
    var total_size_bytes: Int
    var block_size: Int
    var grid_size: Int

    def __init__(out self, m: Int, k: Int, n: Int) raises: ...
    def validate_tensor_shapes(self, a_rows: Int, a_cols: Int, b_rows: Int, b_cols: Int, c_rows: Int, c_cols: Int) raises: ...
    def validate_budget(self, budget: CUDAResourceBudget) raises: ...

struct CUDAF16GemmExecutor:
    var plan: CUDAGemmPlan
    var stable_device_id: String
    var execution_count: Int
    var is_usable: Bool
    var last_failure_message: String

    @staticmethod
    def create(mut resources: CUDADeviceResources, plan: CUDAGemmPlan) raises -> Self: ...
    def execute(mut self, a: RuneTensor[f16], b: RuneTensor[f16], mut c: RuneTensor[f16]) raises: ...
```

The executor performs no allocation during `execute()`. It rejects shape,
element-count, pointer, quantization, allocation-identity, and live-context
violations before unsafe access or kernel launch. Any copy, launch, or
synchronization exception poisons the executor and records the failure so its
possibly faulted stream cannot be reused. This is a real explicit CUDA GEMM
boundary, not model integration or an implicit realm-only dispatcher.

### `CompressedFormatType` (Slice 10)
Zero-overhead integer discriminant tag naming 21 universal sub-byte, integer, and block-compressed LLM format variants.

```mojo
struct CompressedFormatType(Copyable, ImplicitlyCopyable):
    comptime Q2_K = 0
    comptime Q3_K_S = 1
    comptime Q3_K_M = 2
    comptime Q3_K_L = 3
    comptime Q4_0 = 4
    comptime Q4_1 = 5
    comptime Q4_K_S = 6
    comptime Q4_K_M = 7               # Default rune
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

    def __init__(out self, value: Int = 7): ...
    def name(self) -> String: ...     # Returns format string name
    def __eq__(self, rhs: Self) -> Bool: ...
    def __eq__(self, rhs: Int) -> Bool: ...
    def __ne__(self, rhs: Self) -> Bool: ...
    def __ne__(self, rhs: Int) -> Bool: ...
    def copy(self) -> Self: ...
```

### `GBNFGrammar` (`core/grammar.mojo`) (Slice 11)
Limited built-in boolean/number checks plus a deterministic logit-mask
primitive. It does not parse general GBNF or guarantee structured output.

```mojo
struct GBNFGrammar(Copyable, ImplicitlyCopyable):
    var is_active: Bool
    var state: Int
    var schema_type: String

    def __init__(out self, schema_type: String = "json"): ...
    def copy(self) -> Self: ...
    def apply_grammar_mask(self, logits: Pointer[Scalar[f16], MutUntrackedOrigin], vocab_size: Int): ...
```

### `SpeculativeEngine` (`core/speculative.mojo`) (Slice 11)
Local proposal/acceptance arithmetic over caller-supplied logits. It runs no
draft model and performs no parallel or probability-correct verification.

```mojo
struct SpeculativeEngine(Copyable, ImplicitlyCopyable):
    var num_draft_tokens: Int
    var acceptance_rate: Scalar[f16]

    def __init__(out self, num_draft_tokens: Int = 4): ...
    def copy(self) -> Self: ...
    def verify_tokens(self, draft_tokens: Pointer[Int, MutUntrackedOrigin], target_logits: Pointer[Scalar[f16], MutUntrackedOrigin], count: Int) -> Int: ...
```

### `ErrorGuard` (`core/error_guard.mojo`) (Slice 12)
Defensive pointer alignment, bounds checking & Float16 logit sanitization.

```mojo
struct ErrorGuard:
    @staticmethod
    def validate_pointer[T: AnyType](ptr: Pointer[T, MutUntrackedOrigin]) -> Bool: ...
    @staticmethod
    def bounds_check(index: Int, max_len: Int) -> Bool: ...
    @staticmethod
    def sanitize_logits(logits: Pointer[Scalar[f16], MutUntrackedOrigin], count: Int): ...
```

### `StateVault` (`core/state_vault.mojo`) (Slice 12)
One process-local checkpoint marker with a lightweight checksum; no durable or
atomic storage and no KV-cache restoration.

```mojo
struct StateVault(Copyable, ImplicitlyCopyable):
    var is_checkpointed: Bool
    var last_token_pos: Int
    var prompt_tokens_count: Int

    def __init__(out self): ...
    def copy(self) -> Self: ...
    def save_checkpoint(mut self, token_pos: Int, prompt_count: Int): ...
    def restore_checkpoint(self) -> Int: ...
```

### `AesirEventBus` (`core/event_bus.mojo`) (Slice 12)
Process-local event log and subscription descriptors. Subscriber delivery and
asynchronous pub/sub are not implemented.

```mojo
struct AesirEventBus(Copyable, ImplicitlyCopyable):
    var event_count: Int
    var last_event_type: String

    def __init__(out self): ...
    def copy(self) -> Self: ...
    def publish_event(mut self, event_type: String, message: String = ""): ...
    def get_last_event(self) -> String: ...
```

### `RuneThreadPool` (`core/thread_pool.mojo`) (Slice 12)
Bounded local task list. It creates no threads, executes no payloads, and
provides no parallelism.

```mojo
struct RuneThreadPool(Copyable, ImplicitlyCopyable):
    var num_threads: Int
    var is_active: Bool

    def __init__(out self, num_threads: Int = 8): ...
    def copy(self) -> Self: ...
    def parallel_step(self) -> Bool: ...
```

### `SelfHealingSupervisor` (`core/supervisor.mojo`) (Slice 12)
Simulated heartbeat/crash-recovery state for local tests. It catches no process
panic and performs no restart, automatic recovery, or failsafe switching.

```mojo
struct SelfHealingSupervisor(Copyable, ImplicitlyCopyable):
    var is_healthy: Bool
    var recovery_count: Int
    var vault: StateVault
    var bus: AesirEventBus

    def __init__(out self): ...
    def copy(self) -> Self: ...
    def pulse_heartbeat(mut self): ...
    def simulate_crash_and_recover(mut self) -> Bool: ...
```


### `ShardTensor` (Slice 6)
Zero-copy tensor descriptor slice assigned to a specific compute realm/device.

```mojo
struct ShardTensor:
    var device_id: Int
    var tensor: RuneTensor[f16]

    def __init__(out self, device_id: Int, tensor: RuneTensor[f16]): ...
```

### Tensor Partitioning Functions (`mimir_well.mojo`) (Slice 6)
Zero-copy matrix partitioning for column-parallel and row-parallel distribution.

```mojo
def shard_split_cols(T: RuneTensor[f16], num_shards: Int) -> List[RuneTensor[f16]]: ...
def shard_split_rows(T: RuneTensor[f16], num_shards: Int) -> List[RuneTensor[f16]]: ...
```

### Compute Kernels (`compute.mojo`)
Host Mojo SIMD linear algebra and activation primitives plus one explicit CUDA
GEMM gateway. `gemm_f16_cuda` requires a caller-owned
`CUDAF16GemmExecutor`. The older realm-only `gemm_f16_gpu`, all
`gemm_f16_npu` routes, and `rmsnorm_gpu` remain unsupported because their
signatures do not carry selected device resources. The historically named
`gpgpu_vector` and `mobile_opencl` functions are host-only SIMD experiments.

```mojo
def gemm_f16(A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]): ...
def flash_attention_2(Q: RuneTensor[f16], K: RuneTensor[f16], V: RuneTensor[f16], mut Out: RuneTensor[f16], seq_len: Int, head_dim: Int): ...
def flash_attention_gqa(Q: RuneTensor[f16], K: RuneTensor[f16], V: RuneTensor[f16], mut Out: RuneTensor[f16], seq_len: Int, head_dim: Int, num_query_heads: Int, num_kv_heads: Int): ...
def silu(mut T: RuneTensor[f16]): ...
def geglu(mut T: RuneTensor[f16]): ...
def dequantize_q4_k_m(block_ptr: Pointer[BlockQ4_K, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_blocks: Int): ...
def rmsnorm(mut T: RuneTensor[f16], weight: RuneTensor[f16], epsilon: Scalar[f32] = 1e-5): ...
def apply_rope(mut Q: RuneTensor[f16], mut K: RuneTensor[f16], start_pos: Int, head_dim: Int, theta: Scalar[f32] = 10000.0): ...
def cosine_similarity(A: RuneTensor[f16], B: RuneTensor[f16]) -> Scalar[f32]: ...
def gemm_f16_sharded(A_shards: List[RuneTensor[f16]], B_shards: List[RuneTensor[f16]], mut C_shards: List[RuneTensor[f16]]): ... # Slice 6
def all_reduce_sum(shards: List[RuneTensor[f16]], mut Out: RuneTensor[f16]): ... # Slice 6
# Slice 7 — NPU Realm Gateway:
def gemm_f16_arm_neon(A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]): ...
def rmsnorm_arm_neon(mut T: RuneTensor[f16], weight: RuneTensor[f16], epsilon: Scalar[f32] = 1e-5): ...
def gemm_f16_npu(A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16], backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON)) raises: ...
# Slice 8 — Universal GPU Realm Matrix:
def gemm_f16_gpgpu_vector(A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]): ... # 16-wide GPGPU (MUSA, SUPA, MACA, DCU)
def gemm_f16_mobile_opencl(A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]): ... # 8-wide Mobile (Mali, Adreno, PowerVR)
def rmsnorm_gpu(mut T: RuneTensor[f16], weight: RuneTensor[f16], realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA), epsilon: Scalar[f32] = 1e-5) raises: ...
def gemm_f16_gpu(A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16], realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)) raises: ... # unsupported gateway
def gemm_f16_cuda(mut executor: CUDAF16GemmExecutor, A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]) raises: ... # real explicit CUDA F16 GEMM
# Slice 10 — Universal Compressed LLM Format Matrix Dequantization:
def dequantize_compressed_tensor(format: CompressedFormatType, data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int): ...
def dequantize_q2_k(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int): ...
def dequantize_q3_k(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int): ...
def dequantize_q4_0(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int): ...
def dequantize_q4_1(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int): ...
def dequantize_q5_0(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int): ...
def dequantize_q6_k(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int): ...
def dequantize_q8_0(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int): ...
def dequantize_gptq_4bit(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int): ...
def dequantize_awq_4bit(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int): ...
def dequantize_exl2(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int): ...
def dequantize_hqq(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int): ...
def dequantize_smoothquant_int8(data: Pointer[UInt8, MutUntrackedOrigin], out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin], num_elements: Int): ...
```


### Swarm Cluster Descriptors (`core/swarm.mojo`)
Local descriptor and selection scaffold. Registries start empty and clusters
inactive. Join and distributed dispatch raise unsupported errors; heartbeat
returns false. Caller-supplied peer selection is the only implemented behavior.

```mojo
struct SwarmNodeRole(Copyable, ImplicitlyCopyable):
    comptime LEADER = 0
    comptime WORKER = 1
    comptime RELAY = 2

    var value: Int
    def __init__(out self, val: Int): ...
    def name(self) -> String: ...

struct PeerNode(Copyable, ImplicitlyCopyable):
    var node_id: String
    var ip_address: String
    var port: Int
    var role: SwarmNodeRole
    var vram_capacity_mb: Int
    var vram_used_mb: Int
    var is_alive: Bool

    def __init__(out self, node_id: String, ip_address: String = "127.0.0.1", port: Int = 11434, role: SwarmNodeRole = SwarmNodeRole.WORKER, vram_capacity_mb: Int = 16384, vram_used_mb: Int = 2048, is_alive: Bool = True): ...
    def vram_free_mb(self) -> Int: ...

struct PeerRegistry(Copyable):
    var nodes: Dict[String, PeerNode]
    var node_keys: List[String]

    def __init__(out self) raises: ...
    def register_node(mut self, node: PeerNode) raises: ...
    def get_least_loaded_node(self) raises -> PeerNode: ...
    def count(self) -> Int: ...

struct TaskDispatcher(Copyable, ImplicitlyCopyable):
    var active_tasks: Int

    def __init__(out self, active_tasks: Int = 0): ...
    def dispatch_to_node(mut self, node: PeerNode, task_name: String) -> String: ...

struct SwarmCluster(Copyable):
    var registry: PeerRegistry
    var dispatcher: TaskDispatcher
    var is_mesh_active: Bool

    def __init__(out self) raises: ...
    def join_mesh(mut self, leader_address: String) raises -> Bool: ...
    def heartbeat_pulse(mut self) raises -> Bool: ...
    def dispatch_distributed_inference(mut self, model: String, prompt: String) raises -> String: ...
```

### Inference Pipeline (`inference.mojo`)
Transformer layer forward pass with a verified single-device host path. The
NPU/GPU options are reserved arguments that fail closed; physical multi-device
execution is not implemented.

```mojo
struct TransformerBlock(Copyable):
    var layer_idx: Int
    var head_dim: Int
    var num_heads: Int
    var num_kv_heads: Int
    var rms_epsilon: Scalar[f32]

    def __init__(out self, layer_idx: Int, head_dim: Int, num_heads: Int, seer: GGUFSeer) raises: ...
    def __init__(out self, layer_idx: Int, head_dim: Int, num_heads: Int) raises: ...
    def copy(self) -> Self: ...
    # Slice 7 & Slice 8: use_npu/npu_backend and use_gpu_realm/gpu_realm parameters added
    def forward(self, mut x: RuneTensor[f16], mut seer: GGUFSeer, mut well: MimirWell, seq_len: Int, start_pos: Int, mut kv_cache: KVCache, topology: DeviceTopology = DeviceTopology(1), use_npu: Bool = False, npu_backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON), use_gpu_realm: Bool = False, gpu_realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)) raises: ...

# Slice 7 & Slice 8: NPU and GPU parameters threaded into block.forward() and final vocabulary projection
def forward_pass(tokens: List[Int], mut seer: GGUFSeer, mut well: MimirWell, mut kv_cache: KVCache, start_pos: Int = 0, num_layers: Int = 32, head_dim: Int = 128, num_heads: Int = 32, topology: DeviceTopology = DeviceTopology(1), blocks: List[TransformerBlock] = List[TransformerBlock](), use_npu: Bool = False, npu_backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON), use_gpu_realm: Bool = False, gpu_realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)) raises -> Int: ...
def forward_pass(tokens: List[Int], mut seer: GGUFSeer, mut well: MimirWell, num_layers: Int = 32, head_dim: Int = 128, num_heads: Int = 32, topology: DeviceTopology = DeviceTopology(1), blocks: List[TransformerBlock] = List[TransformerBlock](), use_npu: Bool = False, npu_backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON), use_gpu_realm: Bool = False, gpu_realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA)) raises -> Int: ...
```

The loader-backed constructor validates positive layer metadata and requires
all nine non-empty, non-null, non-sentinel layer tensors before it can return a
runnable block. The legacy three-argument overload is retained only as a stable
fail-closed compatibility boundary and always raises. `copy()` uses a
module-private complete-state path, so it cannot manufacture sentinel-bearing
weights. The validated single-device path sizes Q independently from K/V,
applies grouped-query attention, checks token IDs and required
embedding/output tensors, and uses the model's RMS epsilon.
# Native Gemma 4 CUDA session

`Gemma4CUDASession(path, context_length=32768)` validates the dense E4B profile,
uploads packed weights once and owns device-only activations/KV. It is exported
through `aesir.mojo`. `begin_turn(prompt, system, max_tokens)` admits a complete
turn without truncating history; `next_chunk()` advances greedy CUDA generation
and returns complete UTF-8 text while `generating` is true. Read-only observations
include `position`, `prompt_tokens`, `generated_tokens`, `max_new_tokens` and
`finish_reason`. Errors propagate and execution failures poison reuse.

GPU kernels implement F32/F16/BF16/Q4_K/Q5_K/Q6_K reads, matvec, RMSNorm, NEOX
RoPE, grouped-query attention, local/global/shared KV, GELU feed-forward and
per-layer embeddings, softcapped logits and greedy argmax. Host code handles
tokenization and scheduling only. This profile is distinct from the older F16
`RuneTensor` CPU/GPU primitives; it never labels CPU fallback as CUDA.

# Native Llama 3 CUDA session

`Llama3CUDASession(path, context_length=8192)` admits the dense 32-layer Llama 3
8B profile and owns packed GPU weights, F32 activations and F16 KV. Its
`begin_turn`/`next_chunk` interface and observations match the Gemma session.
Completion ceilings are 1..8192; the context includes input and output.
Admission reserves at least one response token and a closing token. Generation
reports `eos`, `length`, or `context_exhausted`, preserving all previous KV.
Rejected input leaves position unchanged; CUDA execution failure poisons reuse.
Native kernels implement adjacent-pair RoPE with device-side F64 phase reduction,
scaled grouped-query attention and SiLU, reusing packed matvec/norm/argmax code.
