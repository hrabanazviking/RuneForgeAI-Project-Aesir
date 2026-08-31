# Asgard Facade Interface Specification (`aesir.mojo`)

> *"The sovereign facade speaks to all realms but bows to none. Every configuration rune is set here; every kernel is struck below."*  
> — **Rúnhild Svartdóttir, The Architect**

---

## Public Struct: `GenerationResult`

The facade also exports the separate native `Gemma4CUDASession` and
`Llama3CUDASession` types from core. Their persistent CUDA chat interfaces are
specified in `core/INTERFACE.md`; they do not pass through the older
`AesirEngine` accelerator-dispatch fields below.

`NativeSamplingConfig` is exported through this facade for native CUDA chat.
Both session constructors accept it after device index and reserve bytes.
`configure_sampling()` and `reset()` operate only between healthy turns.
`NativeModelPlan` exposes device bytes, bounded host staging bytes and host
mapping/upload allowance; `choose_native_cuda` applies explicit or fitting-device
selection. Policy semantics, opt-in physical tests and remaining limitations
are documented in `docs/NATIVE_RUNTIME.md`.

The truth-bearing result of one deterministic generation request. Prompt token
IDs are not repeated in `token_ids`; a generated EOS ID is recorded there but
is excluded from `text`.

```mojo
struct GenerationResult(Copyable):
    var token_ids: List[Int]
    var text: String
    var stop_reason: String
    var prompt_token_count: Int

    def generated_token_count(self) -> Int: ...
```

Stable terminal reasons are `eos`, `length`, and `context_exhausted`.

## Public Function: `generation_stop_reason`

```mojo
def generation_stop_reason(
    generated_token_id: Int,
    eos_token_id: Int,
    generated_token_count: Int,
    max_new_tokens: Int,
    next_position: Int,
    context_length: Int,
) -> String: ...
```

Returns one of the stable terminal reasons or an empty string when generation
may continue. This pure boundary function allows EOS and context behavior to be
tested without inventing model logits.

## Public Struct: `AesirEngine`

The central orchestration facade retains the documented CPU F16 GGUF path. The
module exports the separate `Gemma4CUDASession` used by `chat --accel cuda` and
`run --accel cuda`. That CUDA session is limited to dense text-only Gemma 4 E4B
Q4_K_M and keeps model operations on one NVIDIA GPU. Multi-device, NPU, general
GPU selection, RAG, resilience, and swarm fields remain bounded or scaffolded;
see `docs/CURRENT_STATUS.md` and `CAPABILITY_LEDGER.md`.

The module also exports `Llama3CUDASession` for `chat --profile llama3`, with
32 device-resident layers and F16 KV. Both native sessions are separate from
the `AesirEngine` struct and its legacy accelerator fields.

```mojo
struct AesirEngine:
    var pool: MimirWell
    var parser: GGUFSeer
    var tokenizer: RuneWeaver
    var knowledge_base: MimirStore
    var topology: DeviceTopology
    var blocks: List[TransformerBlock]
    var enable_npu: Bool                    # reserved; true is rejected
    var target_backend: NPUBackendType      # requested-backend metadata only
    var enable_gpu_realm: Bool              # reserved; true is rejected
    var target_gpu_realm: GPURealmType      # requested-realm metadata only
    var supervisor: SelfHealingSupervisor  # explicit local simulation marker
    var event_bus: AesirEventBus            # local last-event marker scaffold
    var thread_pool: RuneThreadPool         # worker-state scaffold; no threads
    var swarm_cluster: SwarmCluster         # empty/inactive local scaffold
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

    def generate_tokens(mut self, prompt: String, max_new_tokens: Int) raises -> GenerationResult: ...
    def generate(mut self, prompt: String) raises -> String: ...  # 32-token facade
    def generate_stream(mut self, prompt: String, client_fd: Int32) raises: ...
```

```mojo
def validate_runtime_backend_config(
    num_devices: Int,
    enable_npu: Bool,
    enable_gpu_realm: Bool,
) raises: ...
```

## Verified Real-GGUF CPU Path

Construction first inspects validated GGUF metadata, derives the exact
`MimirWell` capacity, then maps the model and builds its configured transformer
blocks. `generate_tokens()` inserts the model-controlled BOS token, prefills
every prompt token exactly once through one request-owned GQA KV cache, then
evaluates each generated token at its absolute position to select the next
deterministic argmax token. It records generated IDs, decoded text, prompt
length, and the terminal reason. `generate()` delegates to that canonical path
with a 32-token limit; `generate_stream()` also reuses it rather than owning a
second token loop.

The pinned TinyStories F16 fixture is verified for the complete 32-token greedy
sequence documented in `TASK_verified_multi_token_generation.md`. The verified
scope remains GGUF v3, Llama architecture, F16 matrices, F32 normalization
vectors, single-device CPU, and deterministic greedy generation. Sampling,
quantized inference, server conformance, and accelerator parity are not implied.

---

## Reserved NPU Configuration Boundary

`AesirEngine` is the **sole configuration owner** of NPU backend selection. The following rules are law:

| Rule | Description |
| :--- | :--- |
| **Config ownership** | `enable_npu` and `target_backend` live **only** in `aesir.mojo`. The server and loader domains must never hold NPU state. |
| **Runtime behavior** | `enable_npu=True` raises `NPU engine execution is not implemented` before model loading. |
| **Import direction** | `NPUBackendType` is imported from `core/mimir_well.mojo`. The dependency arrow is Facade → Core (never the reverse). |
| **Logging** | No active-backend banner is emitted. |
| **Multi-device behavior** | `num_devices != 1` raises `multi-device engine execution is not implemented`. |

---

## Reserved GPU Configuration Boundary

`AesirEngine` is the **sole configuration owner** of GPU hardware realm selection. The following rules are law:

| Rule | Description |
| :--- | :--- |
| **Config ownership** | `enable_gpu_realm` and `target_gpu_realm` live **only** in `aesir.mojo`. Server and loader domains must never hold GPU realm state. |
| **Runtime behavior** | `enable_gpu_realm=True` raises `GPU engine execution is not implemented` before model loading. |
| **Import direction** | `GPURealmType` is imported from `core/mimir_well.mojo`. Dependency arrow is Facade → Core. |
| **Logging** | No active-realm banner is emitted. |
| **Multi-device behavior** | `num_devices != 1` is unsupported; no device sharding occurs in `AesirEngine`. |

---

## Reserved GPU Realm Discriminants (from `core/mimir_well.mojo`)

These names are configuration values. CUDA now supports real MAX discovery and
selection, but none currently dispatches physical engine compute.

| Constant | Value | Hardware Architecture Target | Current runtime behavior |
| :--- | :--- | :--- | :--- |
| `GPURealmType.NVIDIA_CUDA` | 0 | NVIDIA CUDA | Real MAX discovery and selection; engine compute unsupported |
| `GPURealmType.AMD_ROCM_HIP` | 1 | AMD ROCm/HIP | Execution unsupported |
| `GPURealmType.INTEL_ONEAPI_XE` | 2 | Intel OneAPI/Level Zero | Execution unsupported |
| `GPURealmType.MOORE_THREADS_MUSA` | 3 | Moore Threads MUSA | Execution unsupported |
| `GPURealmType.BIREN_SUPA` | 4 | Biren SUPA | Execution unsupported |
| `GPURealmType.METAX_MACA` | 5 | MetaX MACA | Execution unsupported |
| `GPURealmType.HYGON_DCU` | 6 | Hygon DCU | Execution unsupported |
| `GPURealmType.ARM_MALI_OPENCL` | 7 | ARM Mali OpenCL | Execution unsupported |
| `GPURealmType.QUALCOMM_ADRENO` | 8 | Qualcomm Adreno | Execution unsupported |
| `GPURealmType.IMAGINATION_POWERVR` | 9 | Imagination PowerVR | Execution unsupported |
| `GPURealmType.APPLE_METAL` | 10 | Apple Metal | Execution unsupported |

---

## Reserved NPU Backend Discriminants (from `core/mimir_well.mojo`)

These names are configuration values only. None currently dispatches physical
NPU work.

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
| **Cluster initialization** | `AesirEngine.__init__` owns an empty, inactive `SwarmCluster`; no active-cluster banner is emitted. |
| **Import direction** | `SwarmCluster` is imported from `core/swarm.mojo`. Dependency arrow is Facade → Core. |

---

## Boundary Prohibitions

- `aesir.mojo` **must not** import `server/api.mojo` for logic beyond `send_chunk_static` / `close_client_static`.
- `aesir.mojo` **must not** import `core/compute.mojo` directly — all compute is delegated via `core/inference.mojo`.
- `aesir.mojo` **must not** perform GEMM, RMSNorm, or attention operations.
- `aesir.mojo` **must not** read or write disk outside of initialization (delegated to `loader/`).

### Native cooperative generation control (2026-08-31)

`GenerationControl` and both CUDA sessions expose monotonic `timeout_ms`
(0..3600000, zero disabled) and a borrowed `cancel_fd` (-1 disabled). The owner
keeps the descriptor alive; core never consumes or closes it. Configure between
turns; calls are serialized. `cancel()` closes the active assistant with EOS;
interrupted prefill requires an explicit `reset()` before reuse. Failed CUDA
sessions stay failed. Chat exposes timeout/settings, `/show` reset state and
Ctrl+C through Linux signalfd plus a mask-preserving executable bootstrap.
See `docs/NATIVE_RUNTIME.md` for tested limits and physical reproduction.

### Serialized native service contract (2026-08-31)

The facade exports `ControlledTextSession`, `NativeGenerationStatus` and the
monotonic clock. Both CUDA sessions implement reset, begin/next/cancel, sampling
and deadline configuration, plus a copied status snapshot. The service holds
one session and serializes all mutation; this does not make sessions thread-safe.
`cli/native_serve.mojo` connects authenticated local requests to this contract.
`serve` is a foreground loopback command requiring an API key file; `daemon`
remains rejected. SIGINT/SIGTERM terminate cooperatively. API details and
production limitations are in `docs/NATIVE_SERVICE.md`.
