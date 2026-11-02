# Project A.E.S.I.R. — Android Tablet, Qwen3-1.7B and Heterogeneous Inference Roadmap

**Status:** roadmap and engineering proposal, 2026-11-02. No Android implementation, hardware test, inference benchmark, NPU compatibility, or app installation is claimed here.  
**Target hypothesis:** Samsung Galaxy Tab S10 Lite Wi-Fi SM-X400, based on the current client identification; confirm on the device.  
**Initial model:** Qwen3-1.7B instruct/thinking, GGUF Q4_K_M.  
**Repository baseline:** main at `69357ab732114805cd2efe1f6bdb7c6d2e068a14`. Recheck the current tree before implementation.  
**Priority:** Qwen3-1.7B usable and well behaved, then evidence-led acceleration.  
**Related:** [Capability Ledger](../CAPABILITY_LEDGER.md), [architecture](../ARCHITECTURE.md), [agent onboarding](../AGENT_ONBOARDING.md), [model wave](MODEL_WAVE_CLOUD_HYPERVISOR_EPYC.md), core/npu_gate_evidence.mojo, core/vulkan_port_surface.mojo, core/memory_ceiling.mojo.

## 1. Mission and outcomes

Build a stable local inference experience that shares the tablet responsibly with normal activity. Explore CPU, Mali GPU and Exynos NPU, including cooperative execution where physically supported and measurably useful. Select placements from measured performance and responsiveness, not an assumption that engaging all three is always faster. The first useful outcome is accurate Qwen3-1.7B Q4_K_M generation with a responsive device and explicit fallback.

This roadmap authorizes an autonomous, iterative engineering workflow within the owner's request: inspect, implement bounded slices, test, fix, document, commit on a feature branch, and continue without asking for permission on each routine decision. Do not block on cosmetic choices. Follow existing repository doctrine, security boundaries, license obligations, and genuine platform authorization requirements. Never disable device security or misrepresent a platform prompt as optional. Obtain user action only for an actual missing prerequisite that cannot be resolved independently; explain the exact blocker and continue independent work.

## 2. Hardware truth and capability boundary

Samsung identifies SM-X400 as Tab S10 Lite; retail configurations list Exynos 1380 and 6 or 8 GB RAM. Samsung identifies Mali-G68 five-core GPU and the Exynos 1380 NPU in its hardware/security material. These are a starting hypothesis, not a device inventory. Exact SKU, available RAM, Android version, GPU driver, Vulkan support, NPU runtime and permissions must be observed. Device-specific NPU support by an open, accessible runtime remains unproven.

Android's normal application sandbox restricts vendor drivers and background execution. Presence of an NPU does not prove that a third-party app can compile this transformer or execute its GGUF tensors there. GGUF Q4_K_M is not automatically a LiteRT or NPU deployment format; conversion changes representation and requires independent correctness checks. Model loading, ownership, license and redistribution need explicit verification.

The Aesir README describes native Mojo inference, Qwen3 correctness fixes on another CPU host, and bounded Vulkan/NPU planning. None establishes Android buildability or an SM-X400 inference result. Determine supported Mojo targets, Android ABI, libc and cross-compilation from the installed compiler and vendor documentation; an ARM64 Linux executable is not automatically an Android/bionic executable. Do not silently substitute another inference engine for Aesir or introduce a permanent runtime dependency. An external reference engine can be used for independent validation with provenance and dependency-policy review.

## 3. First-success definition

A single-user on-device session with a verified Qwen3-1.7B Q4_K_M file:
1. Launches and loads without exceeding a measured admission budget.
2. Uses the model's actual chat template, correct Qwen3 RoPE/QK normalization, GQA, tokenizer, EOS and thinking-mode controls.
3. Completes and cancels short and long requests; produces coherent multi-turn output with documented greedy/reference comparison.
4. Preserves foreground responsiveness under a concurrent scrolling/video or equivalent repeatable workload.
5. Recovers after a worker crash and supports safe restart without losing acknowledged conversation state.
6. States actual backend, memory, context, model identity and any fallback; no claims of NPU/GPU execution without physical dispatch evidence.
7. Documents sustained speed, temperature/thermal state and memory high-water marks; no fabricated target numbers.

Reasonable initial experiments: 1,024–2,048 token context, one active generation, small bounded prefill chunks, low-priority workers and 2–4 CPU threads. These are test parameters, not promised defaults. Start from actual available memory and change only after measurements.

## 4. Model and memory accounting

The Qwen publisher identifies 28 transformer layers, 16 query heads, 8 KV heads and 32,768 native context. Read head dimension and exact tensor geometry from the pinned model metadata. For an illustrative head dimension of 128 and F16 keys and values, KV alone costs 2 × 28 × 8 × 128 × 2 = 114,688 bytes/token: about 112 MiB at 1,024 tokens and 224 MiB at 2,048. Validate against actual model config and cache layout. Quantized KV has scales and padding overhead; its quality and true allocations must be measured.

One published Q4_K_M file is approximately 1.28 GB decimal, not the runtime footprint. Count mapped resident weights, page residency, KV, transient prefill buffers, activations, tokenizer, app, shader/driver allocations, OS headroom and other processes. Avoid double-counting shared buffers but do count real copies. Use Android memory signals and `MemoryInfo.availMem`, the low-memory threshold, per-process measurements and observed allocation failures; available memory is dynamic, not a hard reservation. Reject unsafe admission and offer lower context. Do not promise a model fits merely from total RAM or GGUF file size.

## 5. Architecture and ownership

- **Android shell:** model import via Storage Access Framework, lifecycle, UI, explicit user controls, system thermal/memory/battery callbacks, error presentation.
- **Inference worker:** separate process or otherwise fault-contained native component with bounded IPC, cancellation and independently restartable lifetime. Validate if Android's process rules allow the selected architecture before committing.
- **Aesir core:** GGUF admission and integrity, existing CPU Qwen3 pipeline, generation, tokenizer and KV. Extend through existing interfaces and domain ownership; no dead integration stubs.
- **Capability inventory:** separate “hardware detected”, “API visible”, “model/operation supported”, “compiled”, “executed”, “verified” and “faster under workload”. Never promote an earlier stage to a later one.
- **Resource governor:** owns admission, worker count, bounded prefill, thermal response, memory-pressure response and user-visible mode. Obey foreground restrictions and user choice.
- **Backend interface:** typed operation/shape/quantization/layout support, buffer ownership and lifetimes, cancellation/fence semantics, diagnostics, deterministic fallback policy and per-request placement explanation.
- **Planner:** candidate CPU, CPU+GPU, and CPU+NPU partitions, eventually three-way only if each edge is real and legal. Track setup cost, transfer/synchronization, per-token memory bandwidth, memory duplication, thermal state and impact on other apps.
- **Evidence:** measured device run artifacts and a capability-ledger entry that describes exactly which revision and path was demonstrated.

## 6. Work slices and acceptance gates

### T0 — Inventory and reproducibility
Capture model number, ABI, Android API/build, security patch, total/available memory, storage, CPU topology, battery/thermal state, Vulkan feature and driver identifiers, app foreground status and NPU API/device availability, without sensitive identifiers. Record user-permitted app/device access and check for low-memory devices. Pin source revision and tool versions. **Gate:** redacted reproducible report from actual tablet; unknown remains unknown.

### T1 — Build feasibility spike
Inspect current Mojo toolchain for Android/bionic target, NDK compatibility, native packaging, dynamic libraries, threading, file I/O and exceptions. Build a minimal arm64 Android-linked Aesir-owned function, load it from a minimal shell, and test real calls including errors on hardware. If Mojo cannot target this Android version, document exact error and stop claiming native Android. Investigate a clearly labeled bridge/alternative build strategy without changing project dependency policy by assumption. **Gate:** reproducible build + on-device result or an evidence-backed blocker.

### T2 — CPU compatibility
Audit CPU SIMD assumptions, page size, atomic alignment, endianness, threads, memory mapping and Android file descriptors. Fix only observed failures with portable code. Run existing unit tests and Android-adapted tests, include low-memory and cancellation cases. **Gate:** tested executable runs on tablet; no server/network dependency.

### T3 — Qwen3 CPU accuracy crown
Pin a specific Q4_K_M model repository, revision, filename, size and SHA-256. Import through an explicit user action and verify digest before load. Exercise actual template, prefill and decode, non-thinking and thinking choices, sampling defaults, EOS, UTF-8 and multi-turn continuity. Compare greedy logits/tokens to a pinned independent reference on identical token IDs and precision with documented tolerances and near ties. Include long prompt/chunk boundary checks. **Gate:** coherent, repeatable output and attributable numerical discrepancies, not just successful model loading.

### T4 — Memory admission and context guard
Use actual GGUF tensor geometry and cache precision to compute weights + KV + scratch + overhead conservatively, with device memory observations and a safety margin. Account for allocation high-water marks. Fail closed if required values are unknown or overflow. Dynamically offer a smaller context; do not silently truncate user text or change output. Verify behavior on induced memory pressure and allocation failures. **Gate:** no avoidable worker termination in an agreed stress matrix; document OS behavior beyond app control.

### T5 — Responsiveness governor
Split prompt processing into cancellable bounded chunks; tune worker count/priority by measured latency. Monitor Android thermal, memory, power-save, screen/app lifecycle and execution rules. Suspend or downshift at critical pressure and resume with hysteresis. Avoid spinning, uncontrolled parallel workers, forced high clocks and constant wake locks. Define interactive, balanced and throughput modes with transparent status. **Gate:** record baseline and inference-on UI frame delay, background task completion, energy and throughput; agree on budgets after device baseline. A governor reduces interference; Android cannot guarantee zero stutter.

### T6 — Real baseline and benchmark harness
Run fixed tokenized prompts and deterministic generation at context 1K/2K/4K, multiple prefill sizes, 1–4 threads and cold/warm starts. Capture prompt tokens/s, decode tokens/s, time to first token, end-to-end latency, p50/p95, peak RSS/PSS where available, thermal state, power where instrumentation permits, cancellation latency, and UI jank. Run repeated short trials plus 30–60 minute sustained session, with cooling and ambient notes. Compare against a pinned reference on the same conditions, respecting differing templates and sampler settings. **Gate:** raw results, versioned run command and failures preserved.

### T7 — Recovery and data durability
Use structured error categories (model corrupt, unsupported format, allocation, backend timeout, thermal, OS killed, invalid session); no endless retries. Persist explicit conversation events atomically with checksums, schema version and safe migration. Flush before acknowledging durable state. Restart worker only with bounded exponential backoff and a retry cap; quarantine repeatedly crashing backends or model files per model/driver/build, without deleting data. Reconstruct KV from saved tokens after crash and show interrupted generation; never pretend a partial answer completed. Test process death at write boundaries and corrupted/truncated state. **Gate:** no silent conversation corruption and bounded crash loops. This is application-level recovery, not hardware ECC.

### T8 — Safe GPU feasibility and correctness
Probe Vulkan APIs and driver features on the device. First execute a bounded buffer copy and selected Q4_K_M matrix-vector kernels with known inputs; compare numerical output to CPU reference including tails/alignment and malformed shapes. Test GPU cancellation, fences, memory lifetime and device loss. Measure CPU-only versus GPU-offloaded with exact same inputs while graphics workload runs. Reuse portable Aesir architecture when viable; identify and track any graphics library requirements. **Gate:** real GPU dispatch, numerical checks, sustained responsiveness and independent reproduction before claiming support.

### T9 — CPU/GPU splitting
Develop legal partitions by whole layer or explicit operation; model dependencies and memory layouts must match. Consider CPU tokenization/sampling plus GPU compute as a baseline, and partial layer offload when useful. Cache shape-specific benchmark profiles keyed by device, OS, driver, app, model hash, context and thermal class. Verify shared memory ownership and synchronization; do not assume unified memory means zero-copy. Under contention, revert to CPU or reduce GPU work. **Gate:** prove correctness and a measured benefit under the chosen objective, including UI jank and energy, not throughput alone.

### T10 — NPU discovery
Inspect available public Android accelerator interfaces, vendor documentation, runtime packaging and actual supported models/ops/quantization. Check model compiler access, supported Android version, driver ABI and licensing; verify whether the Exynos 1380 path is available to third-party apps on this precise OS build. Run an independently validated tiny operator or supported model; collect actual device dispatch trace if accessible. **Gate:** demonstrated real NPU computation and repeatable result. If not available, record blocked and continue CPU/GPU work.

### T11 — NPU model feasibility
If T10 passes, inspect Qwen3 topology, dynamic sequence/KV updates, normalization, attention, quantization and model format compatibility. Investigate supported conversion/compilation; preserve source-model version and verify token-level outputs. Measure offline compile cost, memory, inference and thermal behavior. Never label CPU fallback as NPU. **Gate:** real model subgraph, acceptable accuracy and end-to-end benchmark. If unsupported, retain accurate evidence and no fake acceleration.

### T12 — Three-device scheduler
Only if CPU/GPU/NPU paths and shared buffer/transfer contracts are proven: profile legal subgraphs and schedule a dependency DAG with explicit synchronization and cancellation. Explore pipeline overlap and stages; dependencies in autoregressive decode often limit parallelism. Measure conversions, copies, GPU contention and NPU scheduling overhead. Optimize subject to memory, thermal and responsiveness ceilings; fall back per whole session when migrating KV is unsafe. **Gate:** real device traces and quality match; select three-way only where it wins the stated user objective.

### T13 — Failure injection and soak
Test invalid GGUF headers/offsets, checksums, truncated downloads, wrong hashes, out-of-space, interrupted import, OOM admission, worker kill, UI crash, process kill, app background, reboot, driver error, thermal severe, storage removal and rapid cancellation. Check bounded recovery and privacy-safe reports. Soak for hours under repeatable conditions. Explicitly distinguish hardware/OS-imposed termination from an application crash.

### T14 — App experience
Offer local model import/download with provenance, resume and checksum; clear storage use and free-space checks; show memory/context estimate and actual active backend; expose thinking choice, cancel, retry and chat history. No network listeners by default. Comply with Android foreground-service restrictions. Accessibility, safe rotation, process lifecycle and offline startup are acceptance tests. An installable build is signed appropriately and traceable to source.

### T15 — Performance and power refinement
Profile hotspots before optimization; target ARM NEON, packed Q4 GEMV/GEMM, fused normalization/RoPE, batched prefill, KV cache reuse and allocation lifetime only when correct and beneficial. Compare energy per token and sustained performance, not benchmark bursts alone. Test context and weight formats separately. Never report theoretical TOPS as measured generation performance.

### T16 — Generalization
Separate model-specific assumptions from scheduler interfaces; add models only after each architecture/quantization/template passes independent correctness and memory tests. Unsupported cases return actionable errors. The phrase “any model” is an aspiration, not a compatibility claim.

## 7. Scheduling decision procedure

For each request: validate model and session state → capture device and app signals → determine memory admission → enumerate only proven backend/shape combinations → reject candidates exceeding responsive/thermal/memory constraints → estimate prefill and decode cost using matching measured profiles → select best candidate with deterministic CPU fallback → run and monitor → adjust only at safe boundaries. User mode determines the objective. Profile caches must invalidate on model, app, OS, driver or backend change. A missing profile chooses conservative CPU, not speculative acceleration.

Staged selection can optimize prefill separately from decode only when data conversion and KV transfer are correct and measured. A real performance plan must report producer/consumer ownership, synchronization, peak copies, migration time, stage utilization and numerical drift. Use CPU/GPU/NPU together for different tasks only if concurrent work benefits the user and remains within budget.

## 8. Test matrix and release evidence

| Dimension | Required coverage |
|---|---|
| Model | Exact 1.7B Q4_K_M file hash; malformed and truncated file |
| Mode | CPU baseline; each physically demonstrated accelerator and hybrid |
| Input | Empty, Unicode, long prompt, batch boundary, multi-turn, thinking on/off |
| Context | 1K/2K initial, 4K only when admitted, boundary/full context |
| Lifecycle | Cancel, rotate, background, kill/restart, process crash, low memory |
| Environmental | Cold/warm, thermal throttling, low battery, device multitasking |
| Quality | Identical tokens/template, greedy oracle/logit checks and task-level checks |
| Timing | Prefill, decode, TTFT, p50/p95, long-run variation, jank and memory |
| Safety | Hash mismatch, allocation failure, corruption, crash-loop cap, retry exhaustion |

Preserve model license, file hash, device build, exact app/source/reference versions, commands, raw logs, failures and methods. Remove personal conversations and device IDs. CI on a host or emulator helps but cannot certify this tablet's hardware drivers. Do not publish speed or reliability claims from synthetic tests alone.

Suggested promotion: unit and boundary tests → host integration → Android emulator functional tests → physical tablet correctness → repeated performance → sustained and failure injection → documented release. Set numerical budgets based on a real idle baseline and owner's preferences; do not invent a tokens-per-second guarantee.

## 9. Tooling and installation

Use a pinned compatible Mojo toolchain, Android SDK/NDK, JDK, build tooling, platform-tools/ADB, profiler and independent reference only where supported and policy-compatible. Record source, version, license and checksums. Install development tools in the authorized development environment; install tablet apps only when a direct authorized device-management channel exists. A remote cloud shell does not imply access to the Android client. Do not request broad permissions unrelated to inference.

## 10. Work sequencing and stop conditions

1. Inventory and build feasibility T0–T1.
2. CPU and Qwen3 crown T2–T3.
3. Resource protection and recovery T4–T7.
4. GPU path T8–T9 in parallel with documentation-based NPU discovery T10 when resources permit.
5. NPU model research T11, then three-way scheduler T12 only when gates pass.
6. Soak, app polish, performance and generalization T13–T16.

Move forward autonomously where access and evidence permit. Stop a particular path when a toolchain cannot target Android, a driver isn't exposed, correctness fails, the model cannot fit, or a mandatory OS authorization is unavailable. Document exact commands, errors, environment and a concrete resumption point. Continue other independent slices. Do not claim all slices are built while their gates remain open.

## 11. Source ledger

- Samsung SM-X400 identification: https://doc.samsungmobile.com/SM-X400/035861251023/eng.html
- Samsung Exynos 1380 GPU: https://semiconductor.samsung.com/processor/mobile-processor/exynos-1380/
- Samsung identifies Exynos 1380 NPU as a component: https://semiconductor.samsung.com/support/quality-support/product-security-updates/cve-2025-23101/
- Qwen official model card and architecture: https://huggingface.co/Qwen/Qwen3-1.7B
- Example Q4_K_M file listing; pin a concrete revision and checksum before use: https://huggingface.co/bartowski/Qwen_Qwen3-1.7B-GGUF
- Android thermal guidance and limitations: https://developer.android.com/games/optimize/adpf/thermal
- LiteRT overview; device/vendor support must be checked separately: https://developers.google.com/edge/litert/overview
- Qualcomm NPU example is chipset-specific and does not establish Exynos support: https://qualcomm.github.io/qidk/blogs/litert_llm.html
