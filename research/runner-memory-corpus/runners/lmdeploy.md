# OR-2 — LMDeploy (TurboMind + PyTorch Backends)

**Name:** LMDeploy — a toolkit for compressing, deploying and serving large language models (LLMs) and vision-language models (VLMs)
**Licence:** Apache License 2.0 — verified in the project README / PyPI listing and in third-party catalogues, all stating the same licence, accessed 2026-11-15
**Languages:** Python (package, serving layer, PyTorch engine, `lite` quantisation toolkit); C++ / CUDA (TurboMind engine core, exposed to Python through pybind-style bindings); Triton kernels in the PyTorch engine path
**Links:**
- Repository: `github.com/InternLM/lmdeploy`
- Documentation: `lmdeploy.readthedocs.io`
- Package: PyPI `lmdeploy` (release line seen during research: v0.12.3 on PyPI in April 2026 notices, v0.18.0 listed as latest in a November 2026 catalogue snapshot — version numbering moves fast; pin a version in any real deployment)
**As of:** 2026-11-15
**Authors / stewardship:** Developed by the MMRazor and MMDeploy teams under the InternLM organisation (Shanghai AI Laboratory ecosystem)

**Essence.** LMDeploy is the Chinese-ecosystem production runner that most directly competes with vLLM and TensorRT-LLM, but it arrives from a different engineering culture: its fast engine, TurboMind, is written C++-first for throughput, while a second, pure-Python PyTorch engine exists in the same package for breadth and experimentation. Around those two engines the project bundles the whole path from checkpoint to service — offline AWQ/GPTQ quantisation with its own calibration tooling (`lmdeploy lite`), blocked KV-cache management, online INT4/INT8 KV quantisation, prefix caching, tensor parallelism, and an OpenAI-compatible HTTP server plus an in-process pipeline API. Its headline bets are persistent batching, AWQ-first W4A16 weight quantisation, and the claim that the two compose: quantise the weights, quantise the KV cache, and reuse prefixes, all at once.

---

## 2. Two backends, two philosophies

LMDeploy does not have one engine with two modes. It has two engines that share a serving layer, a model registry philosophy, and config types (`TurbomindEngineConfig` vs `PytorchEngineConfig`), and it auto-selects between them when the user does not specify one: if TurboMind is importable and its supported-architecture check passes for the checkpoint, TurboMind is chosen; otherwise the system falls back to the PyTorch engine. That fallback is silent enough that production guides warn operators to assert the backend from the startup log — a planned TurboMind deployment can quietly become a PyTorch deployment with different speed and different quantisation options.

### TurboMind — the fast path

- **Implementation.** C++ core with CUDA kernels, bound into Python. The request orchestration, batching loop, KV management and the low-precision GEMM paths live below the Python layer, so the per-step hot path does not pay Python dispatch costs in the way a Python-first scheduler does.
- **Heritage — stated honestly.** The project's own architecture document says TurboMind is *based on NVIDIA's FasterTransformer*. That is the documented relationship: a fork-and-refocus, not a clean-room engine and not TensorRT-LLM. The LLaMA-family implementation was adapted from FasterTransformer's GPT-NeoX model code, then substantially reworked — a CUTLASS-based fused multi-head attention (FMHA) for context decoding that tolerates mismatched query/key lengths, indirect buffer pointers so attention can follow non-contiguous KV blocks, a new synchronisation scheme for tensor-parallel workers, and INT8 KV support added for batch-size headroom. Conversely, many FasterTransformer capabilities were deliberately dropped because the objective narrowed to conversational LLM serving: the architecture note lists prefix prompts, beam search, context embeddings, sparse GEMM and the GPT/T5/other model families among the removals. Calling TurboMind "TensorRT-adjacent" is fair only in the genealogical sense — it descends from the same NVIDIA FasterTransformer lineage that also fed TensorRT-LLM — but LMDeploy does not present TurboMind as TensorRT, does not require a TensorRT compilation step, and maintains its own kernel tree (`src/turbomind/kernels`). Any stronger claim of TensorRT equivalence would be speculation.
- **Scope.** A curated set of architectures with hand-optimised paths: the Llama family, InternLM / InternLM2 / 2.5 / 3, Qwen lines including MoE variants, Mistral, Baichuan, DeepSeek families including V2/V3-class MoE, GLM, Phi, Gemma and others, plus a subset of VLMs with native vision-tower integration. New architectures land here later than in the PyTorch engine, if at all.
- **Parallelism.** Tensor parallelism inside the engine, with host-side barriers guarding NCCL calls (the architecture note records a fix for an NCCL hang when multiple TP instances shared a process).

### The PyTorch backend — the portable path

- **Implementation.** Written entirely / predominantly in Python on PyTorch, introduced publicly in January 2024 explicitly to lower the barrier for developers and enable rapid experimentation with new features. Custom kernels exist (Triton, CUDA-graph capture — a September 2024 note credits CUDA graphs with a 1.3× gain on Llama3-8B), but the control plane is Python.
- **Scope.** 40+ model architectures through a registry mapping Hugging Face architecture names to LMDeploy model classes. This is where new models arrive first: DeepSeek-V2, CogVLM2, Mini-InternVL, LLaVA-Next and Mono-InternVL were all announced as PyTorch-engine additions in 2024. It is also the *only* path for non-NVIDIA hardware (see §7) and for some newer features — e.g. TurboQuant KV compression (§4–5) is currently PyTorch-engine-only.
- **Structure (from the PyTorch architecture document, v0.2.4-era, concepts still reflected in current code layout).** An `Engine` loop running in a sub-thread: a request manager receives requests, a `Scheduler` decides which sequences participate in the current step and allocates block resources for them, a model agent swaps caches in/out per the scheduler's plan and runs the patched model, and the scheduler updates request status from the results. A separate cache engine performs host↔device page swaps. S-LoRA-style multi-adapter serving is supported in this design.

### Why maintain both?

In our reading, three reasons, all documented in the project's own framing:

1. **Performance ceiling vs coverage floor.** A C++ engine can squeeze dispatch overhead and fuse kernels in ways a Python engine cannot, but every new architecture costs C++ work. The Python engine guarantees that a model the lab cares about can be served *today*, even if slowly.
2. **Hardware reach.** TurboMind is CUDA-only by construction. Every non-NVIDIA target — Huawei Ascend, AMD ROCm, Cambricon MLU, MetaX Maca — is reachable only through the PyTorch engine's pluggable backend layer (`dlinfer`). Without the second engine, LMDeploy would be an NVIDIA-only project.
3. **Feature prototyping.** New ideas (graph mode on Ascend, TurboQuant, new VLM shapes) are proven in Python first. Some later migrate to TurboMind; some, like TurboQuant so far, stay PyTorch-only. The dual structure is therefore also a staging pipeline.

The cost of the pattern is real and visible: two schedulers, two KV implementations with differently named knobs (`cache_block_seq_len` vs `block_size`), feature matrices that differ by engine, and the silent-fallback hazard above. LMDeploy accepts that cost as the price of not choosing between speed and breadth.

---

## 3. Scheduling: persistent batch, request lifecycle, preemption

### Persistent batch = continuous batching, independently named

TurboMind's scheduler is called **persistent batch**. The architecture document is explicit that this is the same idea other projects call continuous batching, and explains the name: the feature was developed concurrently, and the team modelled conversational inference as a single batch whose lifetime spans the entire serving process.

Mechanics, in our own words:

- The batch is a fixed pool of pre-configured **slots** (bounded by configuration and by KV memory).
- A request **joins** when a slot is free; it **leaves** the moment its generation finishes, and the slot is immediately reusable. Admission and eviction happen at step granularity, not at request granularity — a short request never waits for the longest request in its cohort.
- The batch **grows and shrinks** dynamically to avoid wasted compute on padding or empty slots.
- On a **conversation cache hit** (see §4), history tokens do not need to be re-decoded; generation of the new turn's tokens starts directly from the retained KV.

Both engines batch at step level in current versions: prefill (all prompt tokens in parallel, writing K/V into blocks) followed by decode (one token per sequence per step, appending to the sequence's last block and allocating a new block when it fills). Production-oriented write-ups of LMDeploy note the standard consequence: throughput comes from keeping the batch full, while tail latency is governed by how often a long prefill stalls the decoders sharing the step. LMDeploy's feature list also names **dynamic split & fuse** among its throughput techniques — in context, the splitting/fusing of long and short work so prefill and decode work can be composed into efficient kernel launches — and current documentation/catalogues list chunked-prefill-style behaviour, speculative decoding, structured output and context parallelism among the serving features. *[Speculation flag: the exact current chunking policy and its defaults were not pinned down from a primary LMDeploy scheduling document during this research; treat "chunked prefill exists" as catalogue-supported and its tuning as unverified.]*

### Request lifecycle

Through the OpenAI-compatible server, the lifecycle is:

1. Client posts to `/v1/chat/completions` (or `/v1/completions`); the server applies the model's chat template to produce a token sequence.
2. The engine's scheduler admits the sequence when enough free KV blocks exist to hold its prompt (subject to `session_len`, the cap on prompt + output tokens for one sequence).
3. Prefill executes; decode proceeds step-by-step inside the persistent/step-level batch, streaming tokens back through a callback to the API layer.
4. On finish (EOS, length cap, stop condition), the sequence's blocks return to the pool and its slot is freed for the next waiting request.

In the PyTorch engine the same lifecycle is expressed as the Engine → Scheduler → ModelAgent loop described in §2, with the scheduler owning admission, block allocation and post-step status updates.

### Preemption behaviour

LMDeploy documents preemption less prominently than vLLM does, and the two engines differ:

- **TurboMind (original design).** The KV manager is an LRU pool (see §4). When a new sequence needs space and no slot is free, the least-recently-used sequence is evicted; its KV is discarded but its token IDs are retained in compact form, so a later return of the same conversation is a cache *miss* that re-decodes from token IDs rather than a loss of the conversation. Eviction is thus a recompute-on-return policy, transparent to the user.
- **PyTorch engine.** The scheduler/cache-engine design supports swapping pages between host and device memory and evicting unused blocks to sustain larger batches and longer sessions. Independent production analysis describes the user-visible behaviour when the block pool exhausts mid-decode as: some sequences are stopped and later recomputed or resumed, surfacing as latency spikes rather than errors. *[Marked as secondary-source characterisation: the primary PyTorch scheduler document confirms block eviction and host-device swapping; the precise victim-selection and recompute-vs-swap decision per version was not fully specified in the primary pages read.]*

What is clear across both: there is no documented priority/preemption API exposed to API-server clients — preemption is an internal memory-pressure response, not a user-controlled scheduling class.

---

## 4. KV cache & memory

### Blocked KV in both engines

Both engines divide KV memory into fixed-size **blocks** — the same paging idea as vLLM's PagedAttention, independently implemented:

- Default block size: **64 tokens** per block in current documentation/analysis (`cache_block_seq_len` for TurboMind, `block_size` for the PyTorch engine).
- Each sequence owns a block table; blocks need not be contiguous, which keeps fragmentation low and lets a finished sequence return all its blocks at once.
- The pool size is governed by **`cache_max_entry_count`**, default **0.8** — meaning 80% of the GPU memory *remaining after weights load* becomes KV cache (not 80% of total memory; the distinction is a recurring operator confusion). Lowering it is the standard remedy for startup OOM on shared GPUs.

A worked sizing from independent analysis (Llama-3-8B: 32 layers, 8 KV heads, head-dim 128 → 128 KiB of FP16 KV per token; 8 MiB per 64-token block) on a 24 GB card (L4-class, ~22 GiB usable) makes the interaction concrete: FP16 weights (~15 GiB) leave room for ~32,800 resident KV tokens; AWQ 4-bit weights (~5.5 GiB) raise that to ~101,000 tokens; AWQ plus INT8 KV roughly doubles it again to ~200,000 tokens. The lesson the analysis draws — and we endorse it — is that on memory-constrained cards, weight quantisation matters for concurrency mostly *because* it frees memory for KV, not only because decode reads fewer bytes.

### TurboMind's original KV manager: a cache of KV caches

The early TurboMind design (still conceptually distinctive) treated the KV manager as an LRU **cache of whole-conversation KV caches**, not merely a block allocator:

- All KV device memory is pre-allocated by the manager into slots, each sized for one sequence's KV; the allocation chunk size is configurable between pre-allocated and on-demand policies.
- A fetch for a conversation already resident is a **hit**: its history KV is returned directly and no context decoding runs — this is the mechanism behind multi-round chat remembering its history without reprocessing, also surfaced in the README as "interactive inference mode."
- A fetch with no free slot **evicts the LRU sequence** to token IDs (see §3); a later fetch for it is a miss that re-decodes.
- The design goal, in the document's own framing, is that from the user's side the system behaves as if device memory were unbounded for conversation history.

Current TurboMind releases layer the blocked allocator and prefix caching (below) on top of this lineage; the LRU conversation-cache framing remains the clearest statement of TurboMind's original conversational-serving intent.

### KV cache quantisation

Since **v0.4.0**, LMDeploy supports **online** KV quantisation (the earlier offline method was removed):

- **Schemes:** INT8 (`quant_policy=8`) and INT4 (`quant_policy=4`).
- **Method:** Asymmetric quantisation, applied **per-head, per-token**, computed online at write time — **no calibration data or offline step required**.
- **Effect on capacity:** INT8 halves KV bytes (≈2× blocks); INT4 quarters them (≈4× blocks) versus FP16.
- **Accuracy (project's OpenCompass evaluations):** INT8 described as essentially lossless across the evaluated 7B-class models (Llama-2-7B-Chat, InternLM2-Chat-7B, InternLM2.5-Chat-7B, Qwen1.5-7B-Chat on CEval/MMLU/TriviaQA/GSM8K/RACE); INT4 shows small but consistent losses, largest on knowledge/reasoning sets. Independent guidance concurs: INT8 KV is the safe default; INT4 KV should be validated specifically on long-context retrieval and exact-copy tasks, where degraded key precision shows first.
- **Hardware for KV quant:** Documented for NVIDIA Volta (sm70, V100) and above — Turing (sm75), Ampere (sm80/sm86), Ada Lovelace (sm89), Hopper (sm90).
- **PyTorch-engine extensions:** The PyTorch engine additionally accepts FP8 KV policies (values 16 / 17 for FP8 E4M3 / E5M2 in secondary-source reporting of current code) — *[flag: confirm the numeric policy values against the exact release in use; the INT4/INT8 values 4/8 are primary-documented, the FP8 values were seen in secondary analysis only]*.
- **TurboQuant (newer, PyTorch-only).** LMDeploy now also implements KV compression based on Google Research's TurboQuant: keys compressed to 4 bits via a PolarQuant-style rotation + Lloyd-Max codebook plus a 1-bit QJL residual sign (QJL4), values to 2-bit MSE — average ≈3 bits per element, claimed ~5× KV memory reduction. Project benchmark on an **H200, Qwen3-30B-A3B-Base, ShareGPT, concurrency 64, 5,000 requests**: output throughput 2,186.7 → 2,027.0 tok/s (−7.3%), mean TTFT 1.139 s → 1.235 s (+8.4%) — i.e. a deliberate memory-for-speed trade. Limitations as documented: PyTorch engine only, no MLA architectures, no speculative decoding, head dimension must be a power of two.

### Prefix caching

- **Automatic Prefix Caching** is a first-class TurboMind configuration (`enable_prefix_caching`, **off by default** in the configurations surveyed).
- When enabled, blocks whose token content matches a previous request's prefix are reused instead of recomputed: shared system prompts, few-shot blocks and multi-turn histories skip most of their prefill and time-to-first-token falls.
- Matching is **block-granular** (whole 64-token blocks of identical tokens), so a prefix that diverges early yields little reuse; the operational advice is to place stable text first and per-request text last.
- The README stresses **composability**: KV quantisation, AWQ weights and Automatic Prefix Caching are supported *simultaneously* — a combination not every engine guarantees.

---

## 5. Quantisation: the `lite` toolkit

Quantisation is not an afterthought bolted onto the server; it is one of the toolkit's three pillars, implemented in the `lmdeploy lite` sub-tooling with its own calibration pipeline.

### AWQ-first W4A16 — the specialisation

- **What it is.** Activation-aware Weight Quantisation: weights stored as **4-bit integers**, activations kept at 16-bit (W4A16). Weights are grouped (default **group size 128**) with a scale per group; salient weight channels — identified from activation statistics — are scaled up before quantisation to protect them, which is AWQ's core trick for keeping 4-bit quality.
- **Tooling.** A single command produces the checkpoint: `lmdeploy lite auto_awq <model> --work-dir <out>`, with documented defaults of calibration dataset `ptb`, **128 calibration samples**, **sequence length 2048**, `--w-bits 4`, `--w-group-size 128`. An optional scale-search pass (`--search-scale`) re-tunes scale ratios when accuracy degrades. Evaluation of the result is via OpenCompass integration.
- **Serving.** TurboMind runs AWQ checkpoints natively (`--model-format awq`) with INT4 kernels that work on the packed weights in the decode path. The project also ships ready-to-use 4-bit models on Hugging Face Hub (since August 2023) so users can skip calibrating common models themselves.
- **GPTQ asymmetry — an honest detail.** TurboMind can *serve* 4-bit models quantised by either AWQ or GPTQ, but LMDeploy's own quantisation module only *produces* AWQ. GPTQ checkpoints must be created elsewhere (a `gptq` API exists in the lite tree per code indexes, but the W4A16 document's statement governs: production tooling is AWQ-only). This asymmetry is exactly what "AWQ-first" means in practice.
- **Hardware for INT4 weight inference (documented):** V100 (sm70), Turing/T4 (sm75), Ampere incl. A100/A10/A30/A16 and 30-series (sm80/sm86), Ada Lovelace (sm89). Hopper INT4 weight support was *not* listed in the W4A16 document version read — *[flag: this may reflect document age rather than current kernels; MXFP4 on Hopper-class parts is separately documented, see below]*.
- **Claimed effect:** 4-bit inference up to **2.4× faster than FP16** (project headline figure; see §8 for context and scepticism).

### W8A8: SmoothQuant, INT8 and FP8

- **SmoothQuant path.** The lite toolkit also provides `smooth_quant`, implementing W8A8 quantisation: both weights *and* activations to 8-bit, by migrating activation outlier difficulty into the weights via per-channel scales. In the PyTorch engine this is realised by converting linear and RMSNorm layers to quantised versions.
- **FP8 state.** FP8 is supported as a W8A8 dtype variant — **E4M3 and E5M2** — targeting hardware with native FP8 tensor cores: **Hopper (H100-class) and Ada Lovelace (L40S-class)** per the quantisation indexes. FP8 may be selected inside the SmoothQuant flow or used standalone in the PyTorch CUDA/Triton backends. LMDeploy does not present FP8 as its headline (AWQ occupies that slot); it is the modern-hardware option inside the 8-bit family.
- **Ascend note.** The same lite commands (`auto_awq`, `smooth_quant`) are documented on Huawei Ascend (Atlas 800T A2, `--device npu`), plus offline INT8 KV quantisation on Ascend in eager mode — quantisation tooling is part of the portability story, not CUDA-only.

### KV quantisation

Covered in §4: online, calibration-free, INT4/INT8 (plus PyTorch-engine FP8 policies and TurboQuant). Note the clean division of labour: *weight* quantisation is offline and calibration-driven; *KV* quantisation is online and data-free. An operator can therefore enable INT8 KV on any FP16/AWQ deployment with one flag and no preparation, while AWQ requires a deliberate quantise-then-serve step.

### Newer low-precision work

- **MXFP4.** TurboMind added MXFP4 support for OpenAI's gpt-oss models; a September 2025 release note states MXFP4 works on NVIDIA GPUs *starting from V100* (emulated/unpacked paths on older parts, native FP4 on Blackwell) and claims **1.5× vLLM throughput on H800** for gpt-oss. Treat the multiplier as a vendor figure (see §8).
- **llm-compressor interop.** Current catalogues list support for consuming checkpoints produced by vLLM's `llm-compressor` ecosystem, widening the supply of pre-quantised models beyond LMDeploy's own lite output.

### The calibration story, summarised

AWQ quality lives or dies on calibration representativeness. LMDeploy's defaults (PTB, 128×2048) are sane generic starting points, but independent production guidance is blunt: calibrating on generic web text and then serving code, maths or another language loses more quality than the headline perplexity deltas suggest; calibrate on samples of real traffic and evaluate on the real task set. The toolkit makes calibration *easy* (one command, search-scale rescue pass); it cannot make calibration *representative* — that remains the operator's job.

---

## 6. Serving surface

- **OpenAI-compatible API server.** `lmdeploy serve api_server <model>` (default port commonly 23333 in LMDeploy examples). Documented OpenAI-compatible endpoints: **`/v1/chat/completions`**, **`/v1/completions`**, **`/v1/models`**, plus an LMDeploy-specific **`/v1/chat/interactive`** for stateful interactive inference that reuses conversation KV. Any OpenAI client library works by pointing its base URL at the server. Current serving documentation/catalogues additionally list: tool/function calling, reasoning-output handling, Anthropic-compatible endpoints, LoRA serving, structured output, speculative decoding, and Prometheus-style production metrics (secondary/catalogue sources report `/metrics` with KV-usage and waiting-request gauges — *[flag: metric names seen in third-party guides, not verified against a primary metrics document]*).
- **Pipeline API (offline / in-process).** `from lmdeploy import pipeline` with an engine config object; the same call shape serves LLMs and VLMs, supports batched list input, streaming, and generation configs. This is the embedding path for applications that want the engine inside their own Python process rather than behind HTTP.
- **CLI chat.** `lmdeploy chat <model>` for interactive terminal use, with the interactive KV-reuse mode for multi-turn sessions.
- **Distribution.** A request-distribution service for multi-model, multi-machine, multi-GPU deployments is part of the project's stated feature set (since January 2024), and prefill/decode disaggregation is available through integrations (DLSlime is named in third-party deployment guides) rather than as a single built-in flag — *[flag: disaggregation maturity is integration-dependent; verify per release]*.
- **Model hubs.** Checkpoints load from Hugging Face, ModelScope, or openMind Hub (selected via environment), reflecting the project's Chinese-ecosystem roots alongside global distribution.

### Vision-language breadth

VL support is unusually broad for a throughput-focused stack, and is a genuine differentiator:

- **Families (documented across releases):** InternVL full series (v1.1–v1.5, InternVL2, 2.5, 3, 3.5; 1B–241B class range in registry summaries), InternLM-XComposer2 / 2.5, LLaVA / LLaVA-Next, Qwen-VL / Qwen2-VL lines, CogVLM / CogVLM2, MiniCPM-V, Mini-InternVL, Mono-InternVL, DeepSeek-VL, Phi-3-Vision-class and Gemini-style small VLMs among others.
- **Architecture.** A dedicated VL subsystem: an image encoder component preprocesses inputs (InternVL uses dynamic aspect-ratio tiling into patches), extracts vision embeddings, and wraps them for either engine (`wrap_for_turbomind` / `wrap_for_pytorch`). A registry maps HF architectures to vision-model implementations, so new VLMs are added as registry entries.
- **Engine split mirrors the LLM split:** TurboMind covers a curated VLM subset with native vision-tower integration; the PyTorch engine covers the wider set, including video/audio-adjacent multimodal inputs in registry descriptions.
- **Quantised VLMs.** 4-bit weight-only quantisation and inference for VLMs (InternVL v1.5, LLaVA, XComposer2 named at announcement, May 2024) — VL quantisation is not universal among runners.
- **Ecosystem signal:** LMDeploy was integrated into ModelScope Swift as the default VLM inference accelerator (August 2024), suggesting its VL path is used well beyond the InternLM team's own models.

---

## 7. Hardware: NVIDIA-first reality

- **NVIDIA (primary).** TurboMind is CUDA-only and is the performance reference. Documented quantisation/inference coverage spans Volta (V100, sm70) through Hopper (H100/H200, sm90), with Blackwell-class parts addressed by the MXFP4/FP4 work in 2025 releases. Tensor parallelism assumes fast interconnect (NVLink-class) for its all-reduce pattern; multi-GPU single-node serving is a documented, first-class configuration.
- **Huawei Ascend (real, PyTorch-only).** Supported devices as documented: **Atlas 800T A3, Atlas 800T A2, Atlas 300I Duo**, via the PyTorch engine with `device_type="ascend"` / `--device ascend`, built on `torch-npu` and the `dlinfer-ascend` backend. Graph mode and eager mode support varies by device (A3 currently Qwen-series eager-only; 300I Duo graph-only, FP16-only in the documented limitations). Official container images are published for Ascend. A September 2024 note credits graph mode on Ascend with doubling inference speed, and an October 2024 note records PyTorch-engine Ascend support as a shipped feature — this is a maintained port, not a stub.
- **AMD ROCm (present, PyTorch-only, thinly documented).** The multi-platform index lists AMD as device type `rocm` under the PyTorch engine, depending on ROCm-enabled PyTorch + Triton. No TurboMind path exists for AMD, and no AMD-specific performance claims were found in the primary material read. Honest grading: **supported in the backend matrix, unproven as a performance platform** — an AMD user gets the portable engine, not the fast engine. *[This is the single most important hardware caveat for readers comparing LMDeploy with ROCm-mature stacks.]*
- **Other accelerators (PyTorch / dlinfer).** Cambricon MLU (`camb`, via `dlinfer-camb`) and MetaX Maca appear in the same pluggable-backend table, each with its own OpsBackend subclass adapting platform quirks.
- **CPU / edge.** No CPU-first or Apple-Silicon story was found in the material read; LMDeploy is a GPU/NPU server stack. Absence here is a finding, not an oversight: do not plan LMDeploy for laptop-class or CPU-only deployment.

The pattern is consistent: **one fast CUDA engine + one portable engine whose backend layer absorbs every other vendor.** Portability breadth is genuine (five platform families), but performance depth outside NVIDIA + Ascend is undocumented.

---

## 8. Performance character — numbers with context, read critically

All numbers below carry their hardware and provenance. LMDeploy's own figures are vendor benchmarks; independent figures are labelled as such. None were re-run for this dossier.

### Project (vendor) claims

| Claim | Context as stated by the project | Reading |
|---|---|---|
| Up to **1.8× higher request throughput than vLLM** | Project headline (README), attributed jointly to persistent batching, blocked KV, dynamic split & fuse, TP and CUDA kernels. No single canonical hardware/model pairing is attached to the headline itself. | A best-case ("up to") figure across the project's benchmark suite, not an expectation for arbitrary workloads. Directionally supported by independent tests on quantised models (below); not supported as a universal multiplier. |
| **2.4× faster 4-bit inference vs FP16** | Project headline for W4A16 AWQ inference. | Plausible for bandwidth-bound decode at small/medium batch (¼ the weight bytes per step); the gain necessarily shrinks as batch grows and workloads become compute-bound, where dequantisation overhead is pure cost. Treat as a low-batch decode figure. |
| KV INT8 / INT4: **+27–28% / +39% RPS** (Llama-2-Chat-7B/13B); **+5% / +7%** (InternLM2-Chat-7B) | Project KV-quant document: `profile_throughput.py`, TP1, KV ratio 0.8–0.9, batch 128–256, 10,000 prompts. Hardware not named in the table as read. | The spread between models is itself the lesson: KV quant gains depend on how KV-bound the workload is. InternLM2-7B's single-digit gains warn against quoting the Llama-2 numbers generally. |
| MXFP4 gpt-oss: **1.5× vLLM on H800** | September 2025 release note (TurboMind MXFP4, GPUs from V100). | Single-model-family, vendor-measured, on the quantisation path TurboMind is most specialised for. Credible as a specialisation signal; not a general engine comparison. |
| TurboQuant: **~5× KV reduction for −7.3% throughput** | H200, Qwen3-30B-A3B-Base, ShareGPT, concurrency 64, 5,000 requests (full table in §4). | Unusually honest vendor reporting — a *slowdown* published alongside the memory win. Raises confidence in the project's other tables slightly. |

### Independent / third-party comparisons

- **H100, Llama-3.1-8B (aggregated comparison, PremAI, 2026):** LMDeploy ≈ **16,100 tok/s**, SGLang ≈ 16,200 tok/s, vLLM ≈ 12,500 tok/s — i.e. LMDeploy and SGLang clustered ~29% above vLLM on that setup, with LMDeploy credited with the lowest time-to-first-token across concurrency levels and best-in-class quantised serving. *[Secondary aggregation of 13+ engines; methodology not fully auditable from the summary — use for shape, not for procurement.]*
- **H100 SXM5, InternLM2.5-7B, 50 concurrent requests (Spheron deployment guide, 2026, labelled "directional"):** TurboMind ≈ **1,980 tok/s** vs vLLM ≈ 1,850 tok/s vs TensorRT-LLM ≈ 2,100 tok/s. On the project's *own* model family, the three engines sit within ~13% of each other — a useful corrective to the 1.8× headline.
- **A100 80 GB, Llama-3-70B, AWQ 4-bit, 100 concurrent users (same aggregated comparison):** LMDeploy ≈ **700 tok/s** with the lowest TTFT among tested engines; the salient point is feasibility — a 70B model serving from a single 80 GB card via INT4 — more than the raw rate.
- **A40 48 GB, Llama-3-8B-Instruct FP16, 100 concurrent users, Alpaca-derived diverse prompts (single-author Medium benchmark, Dec 2025):** LMDeploy **2,023 tok/s** vs SGLang 1,638 tok/s (+37% claimed by the author; arithmetic gives ~+23% on tokens — *[the author's percentage does not match their own token figures; we report the raw tok/s and flag the discrepancy]*), P99 latency 4.8 s for LMDeploy, GPU utilisation pinned at 100% with only ~21.6% MFU — a reminder that even the winning engine leaves most FLOPs unused on bandwidth-bound decode. Single-author, custom harness: indicative only.
- **GPT-OSS 120B MXFP4 (Spheron table, sourced from LMDeploy's published H800/H100-class benchmarks):** H100 SXM5 ≈ 1,950 vs ~1,300 tok/s (vLLM); H200 ≈ 2,600 vs ~1,750; B200 ≈ 4,200 vs ~2,800 — a consistent ~1.5× ratio across three GPUs, which is either a robust specialisation or a consistently reproduced vendor setup; independent replication was not found.

### Critical reading of the persistent-batch throughput story

1. **Persistent batching itself is not a differentiator anymore.** Every serious runner (vLLM, SGLang, TensorRT-LLM) does iteration-level batching; Orca established the technique in 2022. LMDeploy developed its version concurrently and named it differently, but a 2026 buyer should not pay a premium for the *existence* of continuous batching — only for the *quality of its implementation* (dispatch overhead, kernel fusion, block management), which is where TurboMind's C++ core plausibly earns real, smaller gains.
2. **The gains concentrate where TurboMind specialises:** AWQ INT4 and MXFP4 decode, InternLM-family models, and latency (TTFT) under concurrency. The closer a workload sits to that centre, the more of the headline survives; FP16 serving of a non-InternLM model at high batch is where independent numbers show near-parity with peers.
3. **Throughput headlines omit the knee.** Independent production guidance for LMDeploy itself stresses sizing by the p99-latency knee, not peak tok/s, because block-pool exhaustion (eviction/recompute) degrades tails before it degrades averages. Any capacity plan built on the 1.8× figure without a tail-latency test on real traffic shape is built on sand.

**Bottom line on performance:** TurboMind is credibly among the fastest open engines — top-tier on H100-class hardware in independent aggregations, and plausibly *the* fastest on its AWQ/MXFP4 home turf — but the honest multiplier over a well-tuned vLLM on generic FP16/BF16 serving is closer to 1.0–1.3× than 1.8×, with the vendor figure reserved for favourable quantised configurations.

---

## 9. Strengths / weaknesses

### Strengths

- **C++ hot path.** TurboMind removes Python from the per-step loop; dispatch overhead, batching and INT4 GEMM dispatch are native. This is a structural advantage that Python-first engines must work around with graphs and compiled schedulers.
- **Quantisation as a product, not a flag.** Owned AWQ calibration tooling, pre-quantised Hub models, W8A8/SmoothQuant/FP8 paths, online KV quant, TurboQuant — plus the guarantee that AWQ + KV quant + prefix caching compose. Few stacks cover weights, activations *and* KV with first-party tooling.
- **Conversational-serving heritage.** The LRU cache-of-KV-caches design and interactive endpoint show a system designed from the start for multi-turn chat, not retrofitted to it.
- **VL breadth with quantisation.** Wide VLM coverage *including* 4-bit VLM inference, and adoption as a default VLM accelerator in the ModelScope ecosystem.
- **Portability via the second engine.** Five platform families through one backend abstraction; a maintained Ascend port with its own quantisation support.
- **Apache-2.0 throughout**, with no licence split between engines or tooling found in the material read.

### Weaknesses

- **Two engines, two truths.** Divergent feature matrices, knob names and defaults; silent fallback from TurboMind to PyTorch can invalidate a capacity plan without an error.
- **NVIDIA gravity.** The fast engine is CUDA-only. AMD support exists on paper in the portable engine with no published performance character; CPU/edge is out of scope entirely.
- **Documentation/version velocity.** Flags, defaults (e.g. the meaning of the KV ratio across releases) and policy values shift between releases; multiple documentation vintages (v0.2.4-era architecture pages alongside current ones) remain live and can mislead. Pinning a version and recording the full launch command is mandatory hygiene.
- **Benchmark opacity at the headline level.** The 1.8× figure travels without its hardware/model pairing; per-feature tables are better (the KV-quant and TurboQuant tables name settings and, for TurboQuant, full hardware), but the marketing number is the one that propagates.
- **Preemption/scheduling documentation is thin** compared with vLLM's: victim selection, recompute-vs-swap policy and any fairness guarantees are not specified in the primary pages read, forcing operators to learn tail behaviour empirically.
- **AWQ calibration burden is real.** The one-command flow hides a genuine quality risk (calibration/traffic mismatch) that only shows up on task-level evaluation, not perplexity spot-checks.
- **Ecosystem gravity outside China is weaker** than vLLM/SGLang: fewer independent benchmarks, fewer third-party deployment guides, and several load-bearing details (FP8 KV policy values, metrics names, disaggregation maturity) were only findable in secondary sources during this research.

---

## 10. Ideas to steal for a Go runner

Written for Yrsa's improved-Ollama-in-Go project. Each idea states the gain and the cost/risk honestly.

### 10.1 Persistent batch as the execution model for a resident-session runner

**The idea.** Do not model the Go runner as "load model → run one request → return." Model it as TurboMind does: a **permanently running batch loop** owned by a resident daemon, with a fixed set of slots; sessions join and leave at step granularity; a session's KV survives between turns in an LRU-managed pool, so turn *n+1* of a conversation starts decoding immediately from retained history instead of re-prefilling the transcript.

**Gain.** This is the single highest-leverage architectural transplant for an Ollama-class runner, whose natural workload is exactly TurboMind's home case: one user, long multi-turn conversations, repeated returns to the same session. It converts Ollama's current per-request framing into a session-resident framing: near-zero re-prefill cost across turns, natural streaming, and graceful behaviour when a second client (a tool, a subagent) interleaves requests — they share the loop instead of queueing behind whole generations. In Go specifically, the loop maps cleanly onto a single scheduler goroutine owning slot state, with channels for admission/results — no locks on the hot path if ownership is kept single-threaded by design.

**Cost / risk.** You inherit the scheduler as a permanent subsystem: admission control, `session_len`-style caps, block accounting and an eviction policy must all be designed up front, and tail-latency bugs (one long prefill stalling all decodes) become *your* bugs. The LRU-to-token-IDs eviction trick also requires a fast re-prefill path to be tolerable. Mitigation: ship the loop with exactly two policies first — FIFO admission, LRU session eviction — and resist adding priority classes until real traffic demands them. LMDeploy's thin preemption documentation is the cautionary tale: document the policies you *do* ship, precisely.

### 10.2 AWQ-first as a quantisation specialisation bet

**The idea.** Instead of supporting every quantisation format shallowly, pick **one weight format as the flagship** — the LMDeploy bet is W4A16 AWQ (group-128, per-group scales, activation-aware protection of salient channels) — and invest disproportionately in (a) a fused INT4 decode kernel that consumes packed weights directly, (b) first-party calibration tooling with sane defaults (128 samples × 2048 tokens) and a scale-search rescue pass, and (c) a small library of pre-quantised, quality-gated checkpoints for the models users actually run. Other formats (GPTQ checkpoints, FP8) are *served* if cheap, but not *produced* and not optimised.

**Gain.** Specialisation is what makes TurboMind's numbers real: one packed layout means one kernel family to tune, one calibration story to document, one quality bar to defend. For a Go runner targeting consumer GPUs, W4A16 is the right centre of gravity — decode there is bandwidth-bound, so 4-bit weights buy both fit and speed, and the freed memory converts directly into KV capacity (§4's worked example: ~3× resident tokens from AWQ alone on a 24 GB card). A Go implementation also gains a distribution advantage: a single blessed format keeps the model library coherent instead of fragmenting across GGUF-style quant zoos.

**Cost / risk.** You are betting against format pluralism: users holding GPTQ/GGUF/FP8 checkpoints get a converter or a refusal, and conversion tooling becomes critical infrastructure. Calibration quality is a reputational risk — a badly calibrated flagship checkpoint makes the *runner* look bad — so the bet obliges you to run task-level evaluations (OpenCompass-style) per shipped checkpoint, not just perplexity. Finally, W4A16's speed advantage decays at high batch (compute-bound, dequant-dominated); if the Go runner's future is multi-tenant serving rather than resident personal serving, an FP8 W8A8 path would need to become the second specialisation sooner than LMDeploy needed it.

### 10.3 Two-backend discipline: fast path + portable path as an organisational pattern

**The idea.** Structure the Go project as LMDeploy structures LMDeploy: **one narrow, heavily optimised fast engine** for the dominant hardware (in our case: the accelerators the fleet actually owns) with a curated model list, and **one deliberately simple portable engine** (pure Go + a standard tensor backend) that supports every model shape and every secondary platform, selected automatically with an explicit, logged fallback. New architectures land in the portable engine first; promotion to the fast engine is an explicit optimisation decision. The serving API, session model and quantisation artefacts are shared, so the engines differ only below the scheduler line.

**Gain.** This pattern resolves the otherwise paralysing tension in a small-team runner project: you never have to choose between "fast for the models that matter" and "works for the model released yesterday." It also creates a built-in correctness oracle — the portable engine is the reference implementation against which fast-engine outputs are diffed — and a built-in portability story for ARM/Pi-class targets (the portable engine is the ARM engine on day one, exactly as LMDeploy's PyTorch engine is its Ascend/ROCm engine). Organisationally, it gives contributors a low-barrier entry point (portable engine, readable code) without diluting the fast path.

**Cost / risk.** LMDeploy's own failure modes are the price list: divergent feature matrices, silent-fallback confusion, and doubled scheduler/KV surface to test. The disciplines that keep it survivable, stolen along with the pattern: (1) **one shared config type with engine-specific sections**, never two CLIs; (2) **the fallback is loud** — startup prints the active engine in the first log line and the API's `/models`-style response reports it, so no deployment can mistake which engine it got; (3) **a conformance suite runs the same request battery against both engines in CI**, so divergence is a test failure, not a user discovery; (4) promotion criteria are written down (a model enters the fast engine when it passes the battery within a stated tolerance at a stated speed gain). Without those four rules, two backends decay into two products.

### 10.4 Smaller steals (one line each)

- **Online, calibration-free KV quantisation as a flag, not a project:** INT8 KV (per-head, per-token, asymmetric) is the cheapest concurrency a runner can buy — in Go, a quantised-KV block type behind the same block-table interface gets the 2× resident-token win without touching the weight path.
- **`cache_max_entry_count` semantics:** size the KV pool as a *fraction of memory remaining after weights load*, not of total memory — it self-adjusts across model sizes and prevents the classic "pool sized for the 7B starves the 70B" bug.
- **Composability as a tested guarantee:** LMDeploy promises AWQ + KV-quant + prefix caching *simultaneously*; steal the promise as a test matrix (every quant combination × prefix caching on/off) rather than as a feature list.
- **Publish a negative result with the feature:** TurboQuant's vendor table includes its own slowdown. A runner project that publishes its trade-offs in the same table as its wins earns the trust that makes its win-numbers believable.

---

## 11. Sources

All sources accessed 2026-11-15. Primary = project-owned; secondary = independent or third-party.

**Primary**

1. LMDeploy project README / PyPI listing (`pypi.org/project/lmdeploy`) — licence (Apache-2.0), two-engine framing, 1.8× throughput and composability claims, release notes incl. PyTorch engine introduction (2024-01), Ascend support (2024-09), CUDA-graph gain (2024-09), MXFP4 1.5× on H800 (2025-09). Accessed via search index and PyPI snapshots, 2026-11-15.
2. *Architecture of TurboMind*, LMDeploy documentation (v0.7.0.post3 vintage, read in full) — FasterTransformer basis, persistent batch definition, KV cache manager LRU design, FMHA/indirect-pointer/INT8-KV implementation notes, dropped FasterTransformer features. `lmdeploy.readthedocs.io/en/v0.7.0.post3/inference/turbomind.html`, accessed 2026-11-15.
3. *INT4/INT8 KV Cache*, LMDeploy documentation (latest, read in full) — online per-head/per-token asymmetric quantisation since v0.4.0, `quant_policy` values 4/8/42, OpenCompass accuracy tables, RPS tables (Llama-2-7B/13B, InternLM2-7B), TurboQuant design, H200/Qwen3-30B-A3B benchmark and limitations. `lmdeploy.readthedocs.io/en/latest/quantization/kv_quant.html`, accessed 2026-11-15.
4. *AWQ/GPTQ (W4A16)*, LMDeploy documentation (v0.6.5 vintage) — TurboMind serves AWQ+GPTQ but the quantisation module produces AWQ only; `auto_awq` command and defaults (ptb, 128 samples, seqlen 2048, w-bits 4, group 128); documented INT4 GPU list. Accessed 2026-11-15.
5. *OpenAI Compatible Server*, LMDeploy documentation — `api_server` launch, `/v1/chat/completions`, `/v1/completions`, `/v1/models`, `/v1/chat/interactive`. Accessed 2026-11-15.
6. *Architecture of lmdeploy.pytorch* (v0.2.4 vintage) — Engine/Scheduler/ModelAgent/cache-engine loop, block allocation and eviction, host-device page swaps, S-LoRA note. Accessed via search index, 2026-11-15.
7. *Get Started with Huawei Ascend*, LMDeploy documentation (latest, read in full) — Atlas 800T A3/A2 and 300I Duo support, PyTorch-engine-only usage, graph/eager limitations, Ascend `auto_awq` / `smooth_quant` / INT8 KV support. Accessed 2026-11-15.

**Secondary**

8. DeepWiki index of InternLM/lmdeploy (generated from the repository; crawled Oct 2026) — dual-engine comparison and backend auto-selection, quantisation technique matrix (W4A16 AWQ, W8A8 SmoothQuant incl. FP8 E4M3/E5M2 on Hopper/Ada, GPTQ, KV INT4/8), multi-platform table (CUDA / Ascend via dlinfer / ROCm / Cambricon / Maca), VLM subsystem and registry, supported-model registries. Accessed 2026-11-15.
9. Belgavi, S. — *LMDeploy, in depth: TurboMind, blocked KV cache sizing, AWQ and KV quantization, and serving it in production* (aicassindra.com, 2026-10-05; flags checked against Oct 2026 docs; read in full) — 64-token blocks, `cache_max_entry_count` semantics, Llama-3-8B worked KV sizing on 24 GB, prefix-caching behaviour and defaults, preemption-as-latency-spikes characterisation, production failure modes. Accessed 2026-11-15.
10. *vLLM vs SGLang vs LMDeploy: Fastest LLM Inference Engine in 2026?* (premai.io, 2026) — aggregated H100 Llama-3.1-8B throughputs (~16,100 tok/s LMDeploy), A100 70B AWQ figure, TTFT characterisation. Accessed via search index, 2026-11-15.
11. *Deploy LMDeploy on GPU Cloud: TurboMind Inference for InternLM, Qwen3, and DeepSeek* (spheron.network, 2026) — H100 SXM5 InternLM2.5-7B directional comparison (1,980 / 1,850 / 2,100 tok/s), GPT-OSS MXFP4 table across H100/H200/B200, C++-vs-Python dispatch analysis. Accessed via search index, 2026-11-15.
12. Kairo, Y. — *I Pitted SGLang Against LMDeploy on an NVIDIA A40* (Medium, 2025-12-14) — single-author A40 Llama-3-8B FP16 benchmark (2,023 vs 1,638 tok/s; author's percentage inconsistent with raw figures, flagged in §8). Accessed via search index, 2026-11-15.
13. *How to Run LMDeploy on RunPod* (runpod.io, updated 2026-09-13) — production flags, KV-ratio tuning, TP guidance for DeepSeek-V3-class AWQ, metrics names as reported by a third-party operator guide. Accessed via search index, 2026-11-15.
14. EveryDev.ai LMDeploy catalogue entry (updated Nov 2026) — licence confirmation, v0.18.0 latest-release listing, serving-feature catalogue (tool calling, Anthropic-compatible endpoints, LoRA, structured output, speculative decoding). Accessed 2026-11-15.

**Unverifiable / flagged in-line:** exact current chunked-prefill policy and defaults; PyTorch-engine FP8 KV numeric policy values (16/17, secondary only); `/metrics` gauge names (third-party guide only); prefill/decode disaggregation maturity (integration-dependent); Hopper INT4 *weight* kernel listing (absent from the W4A16 document vintage read; MXFP4 on Hopper is separately documented). No live LMDeploy instance was run for this dossier; all performance figures are reported, not reproduced.
