# Asgard Facade Interface Specification (`aesir.mojo`)

> *"The sovereign facade speaks to all realms but bows to none. Every configuration rune is set here; every kernel is struck below."*  
> — **Rúnhild Svartdóttir, The Architect**

---

## Public Struct: `AesirEngine`

The central orchestration facade. Coordinates `MimirWell`, `GGUFSeer`, `RuneWeaver`, `MimirStore` (RAG), `DeviceTopology` (multi-device), NPU backend selection, GPU realm targeting, and SwarmCluster (mesh cluster). All configuration knobs live here; all compute primitives live in `core/`.

```mojo
struct AesirEngine:
    var pool: MimirWell
    var parser: GGUFSeer
    var tokenizer: RuneWeaver
    var knowledge_base: MimirStore
    var topology: DeviceTopology
    var blocks: List[TransformerBlock]
    var enable_npu: Bool                    # Slice 7 — activates NPU Realm Gateway dispatch
    var target_backend: NPUBackendType      # Slice 7 — selects hardware backend (default: ARM_NEON)
    var enable_gpu_realm: Bool              # Slice 8 — activates Universal GPU Realm Matrix
    var target_gpu_realm: GPURealmType      # Slice 8 — selects GPU hardware realm (default: NVIDIA_CUDA)
    var supervisor: SelfHealingSupervisor  # Slice 12 — process guardian & crash recovery
    var event_bus: AesirEventBus            # Slice 12 — decoupled Pub/Sub messaging
    var thread_pool: RuneThreadPool        # Slice 12 — parallel worker pool
    var swarm_cluster: SwarmCluster        # Phase 14 — mesh cluster orchestrator
    var runtime_offset: Int                # Reusable workspace boundary after persistent allocations

    def __init__(
        out self,
        model_path: String,
        num_devices: Int = 1,
        enable_npu: Bool = False,                                          # Slice 7
        target_backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON),  # Slice 7
        enable_gpu_realm: Bool = False,                                    # Slice 8
        target_gpu_realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA),   # Slice 8
        knowledge_capacity: Int = 100
    ) raises: ...

    def generate(mut self, prompt: String) raises -> String: ...
    def generate_stream(mut self, prompt: String, client_fd: Int32) raises: ...
```

## Verified Real-GGUF CPU Path

Construction first inspects validated GGUF metadata, derives the exact
`MimirWell` capacity, then maps the model and builds its configured transformer
blocks. `generate()` inserts the model BOS token, prefills every prompt token
through a configuration-sized GQA KV cache, selects one deterministic argmax
token, and decodes that genuine model token. The verified scope is GGUF v3,
Llama architecture, F16 matrices, F32 normalization vectors, single-device CPU,
and one generated token. Quantized inference and accelerator parity are not
implied by this path.

---

## Slice 7: NPU Realm Gateway — Asgard Facade Contract

`AesirEngine` is the **sole configuration owner** of NPU backend selection. The following rules are law:

| Rule | Description |
| :--- | :--- |
| **Config ownership** | `enable_npu` and `target_backend` live **only** in `aesir.mojo`. The server and loader domains must never hold NPU state. |
| **Passthrough, not dispatch** | `aesir.mojo` passes `use_npu=enable_npu` and `npu_backend=target_backend` into `forward_pass()`. It does **not** call `gemm_f16_npu` directly — that is the responsibility of `core/compute.mojo`. |
| **Import direction** | `NPUBackendType` is imported from `core/mimir_well.mojo`. The dependency arrow is Facade → Core (never the reverse). |
| **Logging** | On `enable_npu=True`, `AesirEngine.__init__` logs: `"NPU Realm Gateway ACTIVE with backend: <name>"`. |
| **Multi-device precedence** | When `topology.num_devices > 1`, the Bifrost Shard Matrix (`gemm_f16_sharded`) executes regardless of `enable_npu`. NPU dispatch is operative only on the single-device path. |

---

## Slice 8: Universal Multi-GPU Realm Matrix — Asgard Facade Contract

`AesirEngine` is the **sole configuration owner** of GPU hardware realm selection. The following rules are law:

| Rule | Description |
| :--- | :--- |
| **Config ownership** | `enable_gpu_realm` and `target_gpu_realm` live **only** in `aesir.mojo`. Server and loader domains must never hold GPU realm state. |
| **Passthrough, not dispatch** | `aesir.mojo` passes `use_gpu_realm=enable_gpu_realm` and `gpu_realm=target_gpu_realm` into `forward_pass()`. It does **not** call `gemm_f16_gpu` directly — kernel dispatch is delegated to `core/compute.mojo`. |
| **Import direction** | `GPURealmType` is imported from `core/mimir_well.mojo`. Dependency arrow is Facade → Core. |
| **Logging** | On `enable_gpu_realm=True`, `AesirEngine.__init__` logs: `"Universal GPU Realm Gateway ACTIVE with realm: <name>"`. |
| **Multi-device precedence** | When `topology.num_devices > 1`, Bifrost multi-device sharding takes precedence over single-device GPU realm routing. |

---

## GPU Realm Values (from `core/mimir_well.mojo`)

| Constant | Value | Hardware Architecture Target | Kernel Dispatched |
| :--- | :--- | :--- | :--- |
| `GPURealmType.NVIDIA_CUDA` | 0 | NVIDIA GeForce RTX / H100 / A100 / Jetson CUDA | `gemm_f16` (32-wide SIMD) |
| `GPURealmType.AMD_ROCM_HIP` | 1 | AMD Instinct MI300/MI250 & Radeon RX 7000/6000 | `gemm_f16` (32-wide SIMD) |
| `GPURealmType.INTEL_ONEAPI_XE` | 2 | Intel Arc A770 & Data Center GPU Max | `gemm_f16` (32-wide SIMD) |
| `GPURealmType.MOORE_THREADS_MUSA` | 3 | Moore Threads MTT S80 / S4000 (MUSA GPGPU, China) | `gemm_f16_gpgpu_vector` (16-wide SIMD) |
| `GPURealmType.BIREN_SUPA` | 4 | Biren Technology BR100 / BR104 (SUPA GPGPU, China) | `gemm_f16_gpgpu_vector` (16-wide SIMD) |
| `GPURealmType.METAX_MACA` | 5 | MetaX C500 / N100 (MACA GPGPU, China) | `gemm_f16_gpgpu_vector` (16-wide SIMD) |
| `GPURealmType.HYGON_DCU` | 6 | Hygon Haiguang DCU (Zhaoxin/DTK GPGPU, China) | `gemm_f16_gpgpu_vector` (16-wide SIMD) |
| `GPURealmType.ARM_MALI_OPENCL` | 7 | ARM Mali-G78 & Immortalis (Mobile/VR OpenCL) | `gemm_f16_mobile_opencl` (8-wide SIMD) |
| `GPURealmType.QUALCOMM_ADRENO` | 8 | Qualcomm Adreno 740/750 (Snapdragon XR2) | `gemm_f16_mobile_opencl` (8-wide SIMD) |
| `GPURealmType.IMAGINATION_POWERVR` | 9 | Imagination PowerVR / B-Series (Embedded IoT) | `gemm_f16_mobile_opencl` (8-wide SIMD) |

---

## NPU Backend Values (from `core/mimir_well.mojo`)

| Constant | Value | Hardware Target | Kernel Dispatched |
| :--- | :--- | :--- | :--- |
| `NPUBackendType.HAILO_10` | 0 | Hailo-10 edge NPU | `gemm_f16` (RT bridge pending) |
| `NPUBackendType.QUALCOMM_HEXAGON` | 1 | Snapdragon Hexagon HTA/HVX | `gemm_f16_arm_neon` (HVX bridge pending) |
| `NPUBackendType.ARM_NEON` | 2 | ARM Cortex-A / Apple Silicon / RPi | `gemm_f16_arm_neon` (**sovereign path**) |
| `NPUBackendType.JETSON_NVIDIA` | 3 | NVIDIA Jetson (Volta/Ampere) | `gemm_f16` (CUDA tensor-core path) |
| `NPUBackendType.APPLE_NEURAL_ENGINE` | 4 | Apple ANE (M-series / A-series) | `gemm_f16_arm_neon` (Core ML bridge pending) |
| `NPUBackendType.GENERIC_NPU` | 5 | Unknown edge accelerator | `gemm_f16` (universal SIMD fallback) |

---

## Slice 12: Sovereign Resilience & Self-Healing Matrix — Asgard Facade Contract

`AesirEngine` orchestrates system resilience, Pub/Sub event messaging, and thread pool worker management:

| Rule | Description |
| :--- | :--- |
| **Resilience ownership** | `supervisor`, `event_bus`, and `thread_pool` instances are owned by `AesirEngine`. |
| **Heartbeat initialization** | `AesirEngine.__init__` instantiates `SelfHealingSupervisor`, `AesirEventBus`, `RuneThreadPool(8)`, and immediately calls `supervisor.pulse_heartbeat()`. |
| **Import direction** | `SelfHealingSupervisor`, `StateVault`, `AesirEventBus`, and `RuneThreadPool` are imported from `core/`. Dependency arrow is Facade → Core. |

---

## Phase 14: Autonomous Swarm Agents & Enterprise Mesh Cluster Matrix — Asgard Facade Contract

`AesirEngine` orchestrates mesh cluster topology and workload routing:

| Rule | Description |
| :--- | :--- |
| **Swarm ownership** | `swarm_cluster` instance is owned by `AesirEngine`. |
| **Cluster initialization** | `AesirEngine.__init__` instantiates `SwarmCluster()` and logs active resilience and swarm cluster status. |
| **Import direction** | `SwarmCluster` is imported from `core/swarm.mojo`. Dependency arrow is Facade → Core. |

---

## Boundary Prohibitions

- `aesir.mojo` **must not** import `server/api.mojo` for logic beyond `send_chunk_static` / `close_client_static`.
- `aesir.mojo` **must not** import `core/compute.mojo` directly — all compute is delegated via `core/inference.mojo`.
- `aesir.mojo` **must not** perform GEMM, RMSNorm, or attention operations.
- `aesir.mojo` **must not** read or write disk outside of initialization (delegated to `loader/`).
