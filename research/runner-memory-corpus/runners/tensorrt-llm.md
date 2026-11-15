# OR-2 — TensorRT-LLM: The Vendor-Native, Compile-First Pole

- **Project:** TensorRT-LLM (styled "TensorRT LLM" in current docs)
- **Vendor / steward:** NVIDIA Corporation
- **Repository:** https://github.com/NVIDIA/TensorRT-LLM
- **Documentation:** https://nvidia.github.io/TensorRT-LLM/
- **Licence — verified boundary (see note below):**
  - TensorRT-LLM repository code: **Apache License 2.0** (LICENSE file in the repo; README badge).
  - TensorRT SDK (the general inference compiler library the project was originally built on): **proprietary**, distributed under the NVIDIA Software License Agreement for SDKs — not Apache-2.0. The packaged SDK binaries, CUDA Toolkit, cuBLAS/cuDNN and driver stack it historically linked against are likewise proprietary NVIDIA software.
  - Practical consequence: you may read, fork and redistribute the TensorRT-LLM source under Apache-2.0, but the classic engine path also required accepting NVIDIA's SDK terms for TensorRT itself. NVIDIA's current migration guide states the `tensorrt` pip dependency has been **dropped** in the PyTorch-only line, which narrows — but does not erase — the proprietary surround: CUDA, the driver, and NVIDIA's kernel libraries remain closed, and the code only runs on NVIDIA hardware.
- **Languages:** Python (model definitions, LLM API, serving front ends) + C++ / CUDA (runtime, batch manager, KV-cache manager, kernels). Bindings connect the two; several hot components that look Python-facing are C++ underneath.
- **First public release:** v0.5.0, October 2023, as successor in spirit to FasterTransformer.
- **As of:** 2026-11-15. All claims below are tied to sources read on that date; §10 lists them. Where the live documentation tracks a development branch ahead of the latest stable release, that is flagged explicitly — TensorRT-LLM was mid-migration at the time of writing, and version sensitivity is itself a finding.

**Essence.** TensorRT-LLM is NVIDIA's own answer to the question "how fast can this model possibly run on this exact NVIDIA GPU, if we are allowed to decide everything in advance?" For most of its life the answer was literal compilation: convert a checkpoint, build a serialized TensorRT engine for one model, one precision, one GPU architecture and one envelope of batch/sequence shapes, then serve that engine with a C++ executor doing in-flight batching over a paged KV cache. That bought graph fusion, per-shape kernel autotuning and exact memory planning — and cost minutes-long builds, an artifact that fits nothing else, and a workflow closer to shipping firmware than to running a model. As of the 1.x line NVIDIA has been dismantling that bargain from inside: a PyTorch backend that loads Hugging Face checkpoints directly became first experimental (0.17+), then the default (1.0), and the current documentation declares the TensorRT engine backend removed with PyTorch as sole execution backend. The kernels, scheduler and quantization discipline survived the move; the engine file did not. Either way, the design centre never moved: datacentre NVIDIA GPUs, large batches, low-precision arithmetic, and performance per GPU-hour as the metric that outranks convenience. It is the extreme point of the runner design space — and §6 shows precisely where that space ends: one full GPU generation before the corpus's 6 GB RTX 2060 Max-Q.

---

## 2. The compile-first model — and its ongoing dismantling

### 2.1 The classic pipeline (dominant 2023–2025, still what most tutorials describe)

Serving a model the classic way took three distinct steps, each producing an artifact the next step consumed:

1. **Checkpoint conversion.** A per-model conversion script rearranged Hugging Face (or NeMo) weights into TensorRT-LLM's own checkpoint layout — weights pre-sharded for the chosen tensor-parallel degree, quantization scales baked in. Conversion was model-family-specific code, not a generic loader.
2. **Engine building.** A build command took the converted checkpoint plus an explicit envelope — maximum batch size, maximum input length, maximum total tokens per step, beam width, enabled plugins, KV-cache dtype — and invoked the TensorRT builder. The output was a serialized engine file plus a JSON config.
3. **Serving the engine.** Only then could the C++ runtime or Triton load anything. The engine, not the original checkpoint, was the deployable unit.

An engine was therefore keyed to a five-tuple at minimum: **(model + weights, precision/quantization, GPU architecture, parallelism layout, shape envelope)**. Change any element — a bigger batch cap, a longer context, FP8 instead of FP16, an A100 instead of an H100 — and the correct procedure was to rebuild.

### 2.2 What the build bought

The build was not ceremony. TensorRT's builder did real, measurable work that a load-anything runtime defers or skips:

- **Graph fusion.** Chains of small operations — normalisation, bias, activation, elementwise products, QKV projections with rotary embedding — were rewritten into single kernels, eliminating intermediate writes to HBM and whole kernel launches. Some fusions were automatic pattern matches; the most valuable ones (fused attention, fused GEMM) were explicit plugins substituted into the graph at build time.
- **Kernel autotuning / tactic selection.** For each layer and each shape in the declared profile, candidate kernel implementations were timed on the actual target GPU and the fastest retained. The engine thus encodes empirical knowledge about one specific chip — an H100 (SM90) engine's choices are meaningless on Ampere (SM80/86), which is one reason engines were not portable across architectures.
- **Memory planning.** With maximum shapes known in advance, activation workspaces, KV-cache capacity and buffer lifetimes could be planned statically. The runtime inherited a solved memory problem instead of discovering one request at a time.
- **Precision as a build decision.** Quantization was not a runtime flag; the quantized weights, scales and kernel choices were fixed into the engine. An FP8 engine and an INT4-AWQ engine for the same model were two different artifacts.
- **CUDA Graph capture.** The compiled graph could be captured and replayed as a unit, removing per-launch CPU overhead from the decode loop.

### 2.3 What the build cost

- **Build time.** Independent walkthroughs report roughly 3–10 minutes for an 8B-class model and 30–60 minutes for a 70B-class model; one controlled comparison measured ~28 minutes to a first served request for a 70B FP8 engine versus ~62 seconds for a runtime that loads and goes (see §7; hardware and version context there). Builds also needed substantial host RAM and a GPU of the target type present.
- **Artifact rigidity.** The shape envelope was a ceiling, not a hint: exceeding the built maximum batch size or sequence length was not a slowdown, it was a refusal or a rebuild. Capacity planning became a compile-time act.
- **No casual model swapping.** Trying a second model, a new fine-tune, or a different quantization meant another conversion + build cycle and another multi-gigabyte engine directory. A directory of engines for (models × precisions × GPUs) grows combinatorially.
- **Version coupling.** Engines were tied to the TensorRT version that built them; upgrading the library could invalidate the artifact store.
- **Onboarding friction.** Every new model family needed its conversion script and build recipe understood before the first token. This is the single most-cited operational complaint in independent comparisons.

This is the exact opposite pole from Ollama's world, and the contrast is worth stating flatly: a GGUF file is a portable, self-describing artifact that a general runtime loads on heterogeneous hardware in seconds, accepting whatever shapes arrive; a classic TensorRT engine is a non-portable, externally-configured artifact that one specific runtime loads on one specific GPU, accepting only the shapes it was told to expect. Ollama optimises for *time to first token for a human who just downloaded a model*; classic TensorRT-LLM optimised for *tokens per second for a fleet that will serve the same model for months*.

### 2.4 The PyTorch-backend shift — verified current state

This dossier was commissioned to treat TensorRT-LLM as the compile-first extreme. The research found that framing is now **historically true and currently incomplete**, and the dossier reports both halves rather than quietly studying a design NVIDIA is retiring:

- The PyTorch backend appeared as an experimental feature in **0.17** (docs: "available in version 0.17 and later", imported via the `_torch` namespace). Models are ordinary PyTorch modules; Hugging Face checkpoints load directly.
- In the **1.0 line** the PyTorch backend became the stable default for both the Python `LLM` API and the `trtllm-serve` server (per release-note summaries in secondary sources read for this dossier; the 1.0.0rc architecture docs already present PyTorch as a full peer backend).
- NVIDIA's current **migration guide** (live docs tree, read 2026-11-15) states the end point without hedging: the TensorRT engine backend **has been removed**; PyTorch is the **sole** execution backend. Concretely, per that guide: selecting the old backend now raises an error; the build/refit/prune commands have no replacement because there is no engine-build step; per-model checkpoint-conversion scripts are gone because no conversion is needed; the old argument class is replaced by its Torch counterpart; and the `tensorrt` pip dependency is dropped. Serving is now: point the server at a Hugging Face model id or local checkpoint path.
- **Version caveat (important):** the live documentation tracks the development tree. Secondary trackers reading the release pages report the latest *stable* release still shipping the legacy build tooling while 1.3/1.4 release candidates remove the remaining engine code. Treat "removed" as *the documented direction and the state of the current docs/main line*, and "still present but deprecated" as the state of pinned stable installs. Anyone reproducing this dossier should record the exact version first — for TensorRT-LLM in late 2026, the version *is* part of every claim.

**Why NVIDIA moved (analysis, marked as such):** NVIDIA has not, in the sources read, published a single post-mortem essay on the decision, so the following is inference from the shape of the change, not a quoted rationale. The engine model's costs (§2.3) were losing the adoption argument to runtimes that load checkpoints directly, while its benefits had become portable: fusion patterns, tuned kernels, CUDA-graph capture and the scheduler can all live *inside* a PyTorch runtime as libraries and warmup procedures, without a serialized artifact. Moving the optimisation from "compile the model" to "ship better kernels and capture graphs at startup" keeps most of the speed and deletes the worst operational step. The name stayed; the architecture changed underneath it. For our corpus the lesson cuts both ways — see §9.

What did **not** change in the move: the target hardware (§6), the quantization formats (§4), the scheduler/KV-cache design (§3), or the datacentre-first priorities. The PyTorch backend is a change of packaging, not of audience.

---

## 3. Runtime: batching, KV cache, and the executor split

### 3.1 In-flight batching

TensorRT-LLM's name for continuous/iteration-level batching is **in-flight batching**, present since the first public release and implemented originally in the C++ batch manager. The loop is the now-standard one, executed with unusual discipline:

- After **every** forward step, finished requests retire and waiting requests are admitted into the freed slots. The batch is rebuilt per iteration; no request waits for the slowest member of an earlier batch.
- Prefill (context) work and decode work are **packed into the same forward pass**. Inputs are stored padding-free: all requests' tokens for the step are concatenated into one sequence, with per-request length metadata telling the attention kernels where each request begins and ends.
- Two budgets bound each step: a maximum number of **requests** and a maximum number of **tokens**. The token budget is the real control — it caps activation memory and step latency, and it is what chunked prefill spends.
- Two capacity policies expose the throughput/predictability trade: a max-utilisation policy that packs aggressively and may have to pause requests under memory pressure, and a guaranteed-no-evict policy (the conservative default in recent versions) that only admits work it can run to completion. For a personal runner the second policy's *honesty* matters more than the first policy's peak numbers — see §9.

### 3.2 Paged KV cache

The KV cache is block-paged, in the family of designs vLLM popularised, implemented here by a dedicated KV-cache manager (C++ in the classic runtime; in the PyTorch line, a Python-facing manager over C++ bindings, with a "V2" stack visible in current sources):

- Reserved GPU memory (after weights) is carved into **fixed-size blocks**, each holding keys/values for a fixed number of token positions (32 tokens per block in the v1.2-era source examined by one independent architecture comparison). A sequence owns a list of blocks and acquires a new one only when the current block fills; finishing returns blocks to a free pool immediately.
- Fragmentation is thereby bounded to at most one partially-filled block per live sequence, and admission/eviction per iteration needs no compaction.
- **Block reuse / prefix caching:** filled blocks are indexed (a radix-tree structure in the V2 manager) so requests sharing a byte-identical prefix — the classic case is a long shared system prompt — reuse computed blocks instead of re-running prefill. Partial-block matches can be handled by copying the matched prefix into a fresh block. Reuse is on by default in recent versions, with the caveat in NVIDIA's own serving docs that multimodal requests are currently incompatible with it.
- **Sizing knob with a lesson in it:** the fraction of *remaining* GPU memory assigned to KV cache defaults to 0.9 in executor configuration. On an 80 GB datacentre card that aggression is rational; on a 6 GB card it would be a way to OOM politely. The parameter's existence — an explicit, pre-committed memory budget — is the transferable idea (§9), not its default value.
- KV-cache **dtype is a first-class choice**: FP16/BF16 by default, FP8 KV cache on hardware that supports it roughly halves cache memory and read bandwidth (§4).

### 3.3 Chunked prefill

Long prompts are split into chunks that consume only part of a step's token budget, so a single 30k-token prefill cannot stall every concurrently decoding request for a whole pass. Cost: slightly lower peak prefill throughput and more scheduler complexity. Notably, independent source-level comparison found chunked prefill **off by default** in TensorRT-LLM v1.2.1 while competitors default it on — a small, telling default: NVIDIA optimised for benchmark-shaped throughput first, interactive fairness when asked. *(Version-specific; verify before relying on it.)*

### 3.4 Executor / worker architecture — two generations

**Classic generation (C++).** The public surface was the **Executor API** (C++ header, with Python bindings): a client constructs an executor from an engine directory + model config, enqueues requests asynchronously, and polls or receives responses plus per-iteration statistics; cancellation and logits post-processing hooks are part of the API. Under it sat the batch manager (scheduling + KV-cache management) and the C++ GPT runtime driving the engine across GPUs via MPI ranks — tensor/pipeline parallelism degrees are properties of the "world" configuration. Triton's backend (§5) was a client of this executor, not a reimplementation.

**PyTorch generation.** The `LLM` class fronts a **PyExecutor** deliberately shaped to mirror the Executor interface, so the LLM API and server survive the backend swap. Per NVIDIA's PyTorch architecture overview, its parts are:

- **ModelEngine** — owns the model and performs one forward step; the concrete class wraps a PyTorch module whose hot paths call NVIDIA's custom kernels.
- **Scheduler** — two-stage: a *capacity* scheduler decides whether resources (above all KV blocks) can accommodate a request; a *micro-batch* scheduler picks which requests run this step. Both stages currently call C++ bindings, with Python-defined interfaces so scheduling policy is customisable.
- **ResourceManager / KVCacheManager** — per-request resources with an explicit lifecycle (prepare before the step, update after it, free at request end); the KV-cache manager is the crucial instance.
- **Decoder/sampler** — turns forward outputs into tokens; the PyTorch line offers its own sampler and an optional TRT-LLM sampler path, with some sampling features restricted when speculative decoders are active (documented limitation).

Two cross-cutting runtime techniques deserve explicit mention:

- **CUDA Graphs:** decode steps are captured into graphs for the common batch shapes and replayed, trading a padding-to-nearest-captured-shape waste for the removal of launch overhead. In the PyTorch line, graph capture at startup/warmup is part of where the old build-time tuning work went to live.
- **Overlap scheduling:** recent versions add an overlap scheduler (visible in the per-model feature matrix) that overlaps CPU-side scheduling/preparation with GPU execution — an admission that at high step rates the *host* becomes the bottleneck, a problem a single-user runner will meet at much smaller scale but in the same shape.

**Multi-GPU/multi-node** is foundational, not an add-on: tensor, pipeline and (for MoE) expert parallelism, custom all-reduce kernels, and MPI-coordinated workers run through both generations. Almost none of this transfers to a one-GPU personal runner except as a warning about where the codebase's complexity budget went.

---

## 4. Quantization and kernels

### 4.1 Precision support, by architecture (from the support matrix)

| Architecture | SM | Precisions listed |
|---|---|---|
| Hopper | SM90 | FP32, FP16, BF16, FP8, INT8, INT4 |
| Ada Lovelace | SM89 | FP32, FP16, BF16, FP8, INT8, INT4 |
| Ampere | SM80, SM86 | FP32, FP16, BF16, INT8, INT4 (FP8 not listed) |
| Blackwell | SM100+ | Adds FP4 / NVFP4 as the headline low-precision path (per current docs and model guides) |
| Turing | SM75 | **Not listed at all** — see §6 |

The matrix itself warns that FP8/INT8/INT4 support is not implemented for every model. Precision in TensorRT-LLM is a per-(model, hardware) fact, never a global promise.

### 4.2 Formats and where they come from

- **FP8 (W8A8, E4M3-centric):** the Hopper-and-later flagship. Weights and activations in FP8, executed on FP8 tensor cores, with per-tensor/per-channel scaling; NVIDIA positions it as near-lossless versus FP16 on tested workloads. FP8 **KV cache** is a separate, independently valuable switch.
- **NVFP4 / FP4:** the Blackwell flagship — 4-bit floating point with fine-grained scaling, used for the largest headline throughput claims on B200-class hardware. Irrelevant below Blackwell.
- **INT8 (SmoothQuant-style W8A8):** the Ampere-era low-precision path; activation outliers are smoothed into weights during calibration.
- **INT4 weight-only (AWQ and GPTQ, W4A16):** weights at 4 bits, activations at 16 bits; the "make a big model fit" option on Ampere/Ada. Both algorithms are supported as checkpoint formats; quality depends on the checkpoint, not the runtime.
- **Production path:** quantization is increasingly done *outside* the runner by NVIDIA's **Model Optimizer (ModelOpt)**, which calibrates a model once and exports a pre-quantized Hugging Face checkpoint that TensorRT-LLM (and, notably, vLLM/SGLang) load directly. In the PyTorch-backend world, "TensorRT-LLM quantization support" mostly means "ships the kernels to execute ModelOpt's formats fast."

### 4.3 Kernels

- **GEMM:** CUTLASS-based kernels (NVIDIA's own template library for linear algebra), including grouped/GEMM variants for MoE experts and fused expert dispatch in recent versions; low-precision GEMMs are where FP8/FP4 support is actually realised.
- **Attention:** historically a hand-written fused multi-head attention plugin (FlashAttention-like, with an XQA — cross/query attention — runner for decode in current sources); the PyTorch backend exposes **pluggable attention backends**: a reference "vanilla" backend, a FlashInfer backend, and NVIDIA's own TRT-LLM attention backend as default, which documents a superset of FlashInfer's features (in-flight batching + paged KV included). Attention backend is a constructor-level choice in the Torch argument set.
- **Fused elementwise chains:** normalisation, RoPE, activation+mul (e.g. SwiGLU-style MLPs) fused into surrounding kernels in both generations — by the graph compiler before, by hand-structured modules and `torch.compile` options now.
- **Communication:** custom all-reduce and, for disaggregated serving, a KV-cache transceiver with an NIXL backend (§5).

The honest summary: TensorRT-LLM's durable moat was never the engine file — it is this kernel library plus the people who tune it per architecture. That moat does not transfer to a Go runner except as design discipline (§9).

### 4.4 Speculative decoding

Support is broad but **backend- and version-fragmented**, which the dossier flags rather than smoothing over:

- **PyTorch backend (current line):** EAGLE-3, multi-token prediction (MTP — the built-in draft heads of DeepSeek-class models), separate draft-model speculation, and n-gram/prompt-lookup methods are documented as supported; recent pre-releases add further methods (PARD, DFlash, suffix-based) per independent source review.
- **Legacy-only:** Medusa and lookahead decoding were engine-backend features in the stable line and disappear with that backend. Any tutorial prescribing them is describing the old world.
- Speculative decoding composes with disaggregated serving in recent releases (EAGLE-3 + disagg is called out in release notes), and interacts with sampling restrictions (§3.4) and CUDA-graph padding — it is a system feature, not a flag you flip in isolation.

---

## 5. Serving surface

TensorRT-LLM is a runtime first; it offers three concentric serving surfaces:

1. **`trtllm-serve` (the direct server).** An OpenAI-compatible HTTP server started with a model id/path and parallelism flags. Documented endpoints: `/v1/models`, `/v1/completions`, `/v1/chat/completions`; newer doc trees add a Responses API and an embeddings subcommand for encoder-only models, plus health/metrics/version endpoints. Statistics endpoints for the PyTorch backend are marked beta in NVIDIA's own docs — the observability story lagged the backend migration. There is no meaningful built-in auth/TLS story in the CLI reference; it assumes a gateway in front, which tells you the intended deployment shape.
2. **Triton Inference Server backend.** The production-classic route: Triton provides request routing, model management, metrics and multi-model serving while the TensorRT-LLM backend (C++ implementation, `inflight_batcher_llm`; source now lives inside the TensorRT-LLM repo under `triton_backend/`) delegates batching to the executor. In the PyTorch era the same Triton packaging can serve Hugging Face models via the LLM API configuration with no engine compilation. Choose Triton when TensorRT-LLM is one model among several in an existing Triton fleet; otherwise it is a second system to operate for one model.
3. **Disaggregated serving (recent, verified in current docs).** Prefill ("context") and decode ("generation") run as **separate worker pools** with different parallelism strategies, coordinated by an orchestrating OpenAI-compatible front end; the KV cache produced by a context worker is transferred to a generation worker via a cache transceiver (NIXL backend in the documented configuration). Motivation, in NVIDIA's framing: prefill is compute-bound and decode is memory-bound, so co-locating them forces one hardware/parallelism compromise on two different problems and couples their latency distributions. Disaggregation is also integrated with NVIDIA's Dynamo platform in current positioning. This is a fleet feature — it presumes multiple GPUs and a network worth transferring KV over — and is noted here for completeness of the design-space map, not as a candidate import (§9).

Under all three sits the same executor/scheduler core (§3.4): the surfaces differ in operations, not in inference semantics. That layering — one engine, several front doors — is itself a stealable structural idea.

---

## 6. Hardware reality: where the design stops

### 6.1 What the support matrix actually says

From NVIDIA's TensorRT-LLM support matrix (live docs, read 2026-11-15):

- **Operating system:** Linux x86_64 or Linux aarch64. (A native-Windows beta existed in the engine era's launch period; it is not the documented present.)
- **GPU architectures supported:** Blackwell, Grace Hopper, Hopper, Ada Lovelace, Ampere. Full stop. The matrix adds, in substance: if an architecture is not listed, the team does not develop or test on it and support is limited to community support; older architectures may have additional limitations in newer releases.
- **Named datacentre parts** in the supported-hardware material: B200/GB200-class Blackwell, H100/H200/GH200 Hopper, L20/L40/L40S Ada, A100 Ampere. Consumer RTX cards are not named. A Jetson AGX Orin note (Ampere-class, via JetPack) is the only edge exception.
- **Software pins** in the matrix version read: container 25.06, TensorRT 10.11 — a reminder that the supported configuration is an NVIDIA-curated stack, not "any recent CUDA."

### 6.2 The corpus target: RTX 2060 Max-Q

The target card's facts: Turing architecture, TU106 chip, compute capability **7.5 (SM75)**, **6 GB** GDDR6 on a 192-bit bus (~264 GB/s), 65 W mobile part.

**Verdict, plainly: TensorRT-LLM is not an option on this card, by NVIDIA's own matrix.** Turing (SM75) is absent from the supported architecture list — not deprecated-with-warnings, absent — which under the matrix's own rule means undeveloped, untested, community-only. Three independent walls stand behind that absence:

1. **Precision wall.** The formats that make TensorRT-LLM worth its complexity assume later tensor cores: no FP8 path exists for Turing in the matrix (FP8 starts at Ada/Hopper-class support; Ampere itself is listed without it), no BF16 acceleration story, no FP4. What remains — FP16 and INT8/INT4 paths — was never the tuned centre of the project even on Ampere.
2. **Memory wall.** 6 GB must hold weights, KV cache, activations, CUDA graphs and workspace under a runtime whose KV sizing default takes 90% of *remaining* memory and whose reference models start at 7–8B. An INT4 7B's weights alone (~4 GB) leave a sliver for everything else; the datacentre configurations this software is tuned and tested against start at 40–80 GB.
3. **Stack wall.** The supported configuration is a pinned Linux container stack built for datacentre deployment. Even a heroic community port would be maintaining a fork of a fast-moving codebase against its vendor's direction — the opposite of a personal runner's economics.

Do not confuse this with the separate **TensorRT for RTX** product line, whose support matrix *does* include Turing (SM75) — that is a different SDK aimed at RTX application developers, not TensorRT-LLM. The similar names are a genuine trap; this dossier checked both matrices.

**What the 2060 should run instead** is other dossiers' business (GGUF-class runtimes are the proven fit); TensorRT-LLM's role for this corpus is purely as a design study. That is not a dismissal — §9 extracts what transfers.

---

## 7. Performance character

### 7.1 NVIDIA's reported numbers — with their context attached

Vendor claims, repeated as claims, each inseparable from its hardware/precision conditions:

- **"Over 40,000 tokens/second" for Llama 4 on B200 GPUs** (README news line, April 2025). Context: Blackwell flagship silicon, aggregate throughput framing, low-precision checkpoints; not a per-user or small-batch figure.
- **"1,000 tokens/second per user" barrier broken with Llama 4 Maverick on Blackwell** (NVIDIA developer blog, May 2025). Context: per-user rate under a serving configuration tuned for it, on B200-class hardware, with speculative decoding in the recipe family NVIDIA promotes for this result.
- **DeepSeek-R1 "world-record" inference on Blackwell** (March 2025 blog campaign) and a published best-practices benchmarking guide for it. Context: 671B-class MoE on multi-GPU Blackwell systems — a different sport from single-card serving.
- Historical launch-era claims (2023) centred on H100 FP8 versus prior stacks; they describe the engine era and should not be quoted against current versions.

The pattern across all of them: **headline numbers are H100/H200/B200 numbers**, at FP8 or FP4, at batch/concurrency regimes a personal runner never sees, often with speculative decoding enabled. None is false on its own terms; all are non-transferable without re-measurement.

### 7.2 Independent comparisons — what survives contact

- A controlled same-hardware comparison (single H100 SXM5 80 GB, Llama 3.3 70B FP8, TensorRT-LLM v1.2.0 *compiled engine* vs vLLM): TensorRT-LLM led throughput by **~13% at 50 concurrent requests (2,100 vs 1,850 tok/s)** and ~16% at 100 requests, with p95 time-to-first-token ~12% lower — and a **~28-minute engine build** before its first request versus ~62 s cold start for the load-and-go engine. Two lessons: the compiled-engine edge on identical datacentre hardware is real but **tens of percent, not multiples**; and that measurement belongs to the legacy path the vendor is now retiring, so it cannot be quoted as the PyTorch backend's margin. *(Secondary source, single study; treat magnitudes as indicative.)*
- The broader independent consensus across comparison write-ups read for this dossier converges on the same shape: on NVIDIA datacentre hardware TensorRT-LLM is typically the throughput/latency leader by roughly **10–35%** over generalist runtimes, with the gap widening at high concurrency and shrinking to single digits at low concurrency — paid for with the worst setup/operations burden of the group. No neutral, current, cross-engine benchmark suite exists that holds model, precision, hardware and latency targets constant across versions; every number in this space decays within a release or two.
- `trtllm-bench` is NVIDIA's own benchmarking harness for the runtime (throughput and latency modes against a served or offline configuration), supplemented by external load tools. Its existence matters for §9: the vendor treats *benchmarking as a shipped feature of the runner*, not an afterthought.

### 7.3 The recurring caveat, stated once and applied everywhere

Every performance figure in this section was produced on GPUs with 13–40× the target card's memory, 4–12× its memory bandwidth, and tensor-core generations the target does not have. The correct use of these numbers in our corpus is **ordinal** (which design choices buy how much, relative to what, on hardware that can express them), never **cardinal** (what our hardware will do).

---

## 8. Strengths / weaknesses

### Strengths

- **Kernel quality at the frontier.** First-party, per-architecture tuned attention/GEMM/MoE kernels, with new precisions (FP8, then FP4) landing here first because the same vendor designs the silicon.
- **A disciplined serving core.** In-flight batching, paged KV with prefix reuse, explicit token budgets, and a no-evict capacity policy form a coherent, production-proven scheduler design that survived a total backend replacement unchanged in outline.
- **Quantization as an ecosystem.** ModelOpt calibration → standard pre-quantized checkpoints → fast kernels is the most complete low-precision pipeline in the field.
- **Speculative decoding breadth** on the current backend (EAGLE-3, MTP, draft-model, n-gram) and its composition with disaggregated serving.
- **Fleet features that actually exist:** tensor/pipeline/expert parallelism, Triton integration, disaggregated prefill/decode, per-iteration executor statistics.
- **Apache-2.0 source** with development in the open on GitHub since March 2025 ("fully open-source" news line in the README).

### Weaknesses

- **Hardware absolutism.** NVIDIA-only, datacentre-first, and — per its own matrix — not even all NVIDIA: Turing and everything older is outside the fence (§6). No CPU, AMD, Intel or Apple path exists or is contemplated.
- **Operational weight.** Pinned container stacks, MPI multi-process workers, Triton as a second system, per-model feature matrices that must be checked feature-by-feature (chunked prefill, block reuse, speculative method, disagg — each varies by model architecture in NVIDIA's own tables).
- **Migration churn.** The project's centre moved (engine → PyTorch) within two years, invalidating a generation of tutorials, build scripts and operational knowledge; release-candidate cadence is high and breaking changes are routine. Pinning a version is not optional hygiene, it is survival.
- **Observability and polish lag the core.** PyTorch-backend serving statistics are self-described as beta; sampling feature coverage narrows under speculative decoding; defaults (e.g. chunked prefill off) favour benchmark shapes over interactive ones.
- **The personal-runner mismatch.** Everything about the design assumes a model is chosen once and served forever to many users. For one user swapping models conversationally, its historical costs were disqualifying and its current form offers no advantage over simpler PyTorch-ecosystem runtimes — while still refusing to run on the corpus's hardware at all.

---

## 9. Ideas to steal for a Go runner

Each idea is stated with its gain and its cost/risk. The through-line: TensorRT-LLM's *discipline* transfers even though its *artifacts* and *hardware* do not.

### 9.1 Steal: build-time (load-time) memory planning — the pre-sized arena

- **Idea.** Decide the memory map before the first request: weights + a KV arena sized from an explicit budget + fixed workspace, allocated once, never grown opportunistically. TensorRT-LLM did this at engine-build time; the PyTorch line still does it at startup via an explicit KV fraction of remaining memory. A Go runner should do it at **model-load time**: compute the arena from (VRAM actually free, model size, configured max context × concurrent sessions), allocate it once, and let the paged allocator live entirely inside it.
- **Gain.** OOM becomes a load-time refusal with a clear message instead of a mid-generation crash; fragmentation is structurally impossible outside the arena; capacity ("how many tokens of context can I hold?") becomes an arithmetic answer the UI can show honestly.
- **Cost/risk.** Wasted reservation if the budget is timid; complexity in measuring "actually free" VRAM across drivers. Mitigate with a conservative default fraction — explicitly *not* NVIDIA's 0.9 — and a user-visible override.

### 9.2 Steal: kernel autotune-at-install, as a bounded engine build

- **Idea.** A one-time, per-(model-family, GPU) micro-benchmark at install or first load: time the handful of kernel variants the runner actually ships (e.g. attention/GEMM paths per dtype) on the local card for the shapes a personal runner really serves (batch 1–4, realistic context lengths), cache the winners in a small local profile keyed by GPU model + driver + runner version.
- **Gain.** Recovers the *empirical* half of what `trtllm-build` did — choices measured on the user's exact silicon — in seconds-to-a-minute, without serialized artifacts, shape ceilings, or per-model builds. On a 6 GB Turing card where every kernel path is precious, measured selection beats heuristic selection.
- **Cost/risk.** Benchmark harness must be trustworthy (warmup, variance, thermal state on a laptop part); profile cache invalidation bugs would silently pin bad choices. Bound it hard: few variants, few shapes, total budget under a minute, always fall back to defaults, and log the chosen profile where the user can see and delete it.

### 9.3 Steal: in-flight batching discipline — even for one user

- **Idea.** Adopt the iteration-level loop and its accounting even at batch sizes of 1–4: rebuild the batch every step; budget each step in **tokens**, not just requests; admit/retire at step boundaries; prefer the guaranteed-no-evict admission rule (never start what the KV arena cannot finish).
- **Gain.** A personal runner still multiplexes — a chat reply, a background summariser, an embedding job — and the token-budget/no-evict discipline is what keeps a long generation from being strangled by a newly arrived prefill. It also gives clean per-iteration statistics almost for free, which the executor API treats as a first-class output.
- **Cost/risk.** Scheduler complexity is real even when small; the failure mode to avoid is importing the *concurrency machinery* (multi-process workers, MPI thinking) along with the *discipline*. Keep it one process, one GPU, boring data structures.

### 9.4 Steal, smaller: three supporting habits

- **Paged KV with prefix reuse, sized for the arena.** Fixed-size blocks + block-level sharing for repeated system prompts is directly applicable to a chat runner that resends the same persona/context every turn — likely the single largest free latency win available on small hardware. Cost: block bookkeeping and byte-exact prefix matching rules.
- **Benchmarking as a shipped feature.** A built-in bench mode (fixed prompts, reported TTFT/TPOT/throughput with full hardware+precision context printed beside every number) — the institutional habit behind `trtllm-bench` — keeps our own corpus honest. Cost: the discipline to never quote a number without its context line.
- **One core, several front doors.** TensorRT-LLM's layering (one executor; CLI server, Triton, disagg as surfaces) validates keeping the Go runner's inference core UI-agnostic, with the desktop app and any HTTP surface as replaceable shells. Cost: API discipline at the boundary from day one.

### 9.5 What NOT to import

- **Per-configuration artifacts.** No serialized "engines" keyed to (model, precision, GPU, shape envelope). The personal runner's unit stays the portable model file; any tuning output is a *cache* (§9.2) that can be deleted without consequence, never a required artifact.
- **Shape ceilings as refusals.** A request larger than the tuned profile must run slower, never fail for being unplanned. Rigidity was the engine model's fatal product flaw — NVIDIA's own retreat from it is the strongest evidence available.
- **Datacentre defaults.** 0.9-of-VRAM KV fractions, benchmark-first defaults (chunked prefill off), multi-process worker topologies, and pinned full-stack containers are answers to fleet questions we are not asking.
- **Precision maximalism.** FP8/FP4 recipes presume tensor cores the target lacks. On Turing-class hardware the honest low-precision story is the GGUF-style integer quantization family covered by sibling dossiers; importing NVIDIA's format zoo would buy nothing executable.
- **Disaggregated serving.** Splitting prefill and decode across machines is a solution to a multi-GPU fleet's interference problem. On one 6 GB card it is pure overhead wearing a datacentre costume.

---

## 10. Sources (accessed 2026-11-15)

**Primary — NVIDIA:**

1. TensorRT-LLM support matrix (live docs) — hardware architectures, OS, precision-by-SM table, container/TensorRT pins, "not listed = not developed/tested" rule. https://nvidia.github.io/TensorRT-LLM/reference/support-matrix.html
2. Migration guide: "TensorRT Backend Removed" (live docs) — PyTorch as sole backend; build/refit/prune and checkpoint conversion removed; `tensorrt` pip dependency dropped. https://nvidia.github.io/TensorRT-LLM/legacy/tensorrt-backend-removal.html
3. PyTorch backend architecture overview (v1.0.0rc4 docs) — `LLM` API, PyExecutor, ModelEngine, two-stage scheduler, ResourceManager/KVCacheManager. https://nvidia.github.io/TensorRT-LLM/1.0.0rc4/torch/arch_overview.html
4. PyTorch backend page (v1.0.0rc0 docs) — experimental status note, 0.17 availability, FP8/NVFP4 quantization via HF checkpoints, sampling notes. https://nvidia.github.io/TensorRT-LLM/1.0.0rc0/torch.html
5. Attention backends (features docs) — vanilla / FlashInfer / TRT-LLM attention backends, paged KV + in-flight support. https://nvidia.github.io/TensorRT-LLM/features/attention.html
6. Supported models + model-feature matrix (live docs) — per-model support for overlap scheduler, CUDA graphs, disaggregated serving, chunked prefill, speculative decoding, KV reuse. https://nvidia.github.io/TensorRT-LLM/models/supported-models.html
7. `trtllm-serve` documentation — OpenAI-compatible endpoints, disaggregated subcommands, beta statistics note. https://nvidia.github.io/TensorRT-LLM/commands/trtllm-serve/trtllm-serve.html
8. Disaggregated serving documentation — context/generation pools, orchestrator, NIXL KV transceiver config. https://nvidia.github.io/TensorRT-LLM/features/disagg-serving.html
9. Executor API (legacy docs) — C++ executor, enqueue/statistics/cancel surface, iteration-level batching definition. https://nvidia.github.io/TensorRT-LLM/legacy/advanced/executor.html
10. GitHub repository README (raw mirror read) — Apache-2.0 badge, release line 1.4.0rc0, Llama 4 / 40,000 tok/s on B200 news line, "fully open-source" March 2025 note. https://github.com/NVIDIA/TensorRT-LLM
11. NVIDIA developer blog, launch post (2023) — engine-era design: TensorRT compiler fusion/tactic selection, CUDA Graph compilation, attention/GEMM plugins, C++ runtime, Triton backend, Ampere/Ada/Hopper support as launched. https://developer.nvidia.com/blog/optimizing-inference-on-llms-with-tensorrt-llm-now-publicly-available/
12. Triton TensorRT-LLM backend documentation — backend location (`triton_backend/`), PyTorch-backend (LLM API) serving of HF models without engine compilation, MPI coordination. https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/tensorrtllm_backend/README.html
13. TensorRT SDK licence agreement (NVIDIA docs) — proprietary SDK terms, the licence boundary in §1. https://docs.nvidia.com/deeplearning/tensorrt/10.x.x/reference/sla.html
14. TensorRT for RTX support matrix + prerequisites (NVIDIA docs) — the *separate* RTX product that does list Turing SM75; checked to rule out name confusion in §6. https://docs.nvidia.com/deeplearning/tensorrt-rtx/v1.3/getting-started/support-matrix.html

**Secondary — independent, used for corroboration and benchmarks (magnitudes indicative, not canonical):**

15. Spheron, "vLLM vs TensorRT-LLM 2026" (benchmarks dated Aug–Nov 2026) — H100 SXM5, Llama 3.3 70B FP8, throughput/TTFT table, 28-min engine build vs ~62 s cold start. https://www.spheron.network/blog/vllm-vs-tensorrt-llm-2026/
16. Metarix, "vLLM vs SGLang vs TensorRT-LLM Compared" (accessed Nov 2026) — release-state tracking (stable v1.2.1 vs 1.3/1.4 RCs), hardware table, migration summary. https://metarix.io/vllm-vs-sglang-vs-tensorrt-llm
17. Belgavi, "TensorRT-LLM, in depth" (2026-09-30) — PyTorch runtime mechanics, scheduler token budgets, KV block reuse, 1.0-default / 1.2-removal timeline. https://aicassindra.com/blogs/gpu/gpu_tensorrt_llm.html
18. Belgavi, "In-Flight Batching" (2026-07-23) — packed inputs, block-paged KV mechanics, capacity policies. https://www.aicassindra.com/blogs/transformer_math/tm_inflight_batching.html
19. Residual Stream, "TensorRT-LLM: Compiling Inference Engines Ahead of Time" and "Comparing LLM Serving Architectures" (Oct 2026, source-level at v1.2.1) — what the build did (fusion/tuning), 32-token KV blocks, chunked-prefill default off, speculative-decoding backend fragmentation. https://residual-stream.lvtan71.workers.dev/posts/tensorrt-llm-explained/
20. TechPowerUp GPU database — RTX 2060 Max-Q: TU106, Turing, SM75/CUDA 7.5, 6 GB GDDR6, 192-bit, ~264 GB/s. https://www.techPowerUp.com/gpu-specs/geforce-rtx-2060-max-q.c3533
21. Aquanode TensorRT-LLM guide (2026) — supported-hardware naming (B200/H100/L40S/A100), README vendor-claim inventory. https://www.aquanode.io/blog/tensorrt-llm-guide

*Clean-room note: this dossier is written in the corpus's own words from the sources above. No documentation text is reproduced beyond short factual labels (endpoint paths, class/feature names, licence names); no code is included.*
