# OR-2 — ExLlamaV2: The Single-User Speed Specialist

**Dossier:** OR-2, Ollama Research Forge
**Subject:** ExLlamaV2 (turboderp / turboderp-org)
**Licence:** MIT — verified 2026-11-15 from the GitHub repository metadata, the `LICENSE` file listed in the repo root, and the PyPI package metadata, all of which state MIT.
**Languages / implementation:** Python (orchestration, model loading, generators, sampler, conversion tooling) with a PyTorch C++ extension (`exllamav2_ext`) written in C++ / CUDA for the performance-critical kernels; HIP/ROCm build variants existed experimentally (see §8). Distributed as source, as prebuilt wheels matched to Python + CUDA + PyTorch ABI, and as a JIT-compiled PyPI package that builds the extension on first use.
**Primary links:**
- Repository (current org): https://github.com/turboderp-org/exllamav2 — created 2023-08-30, 1,459 commits and 43 releases at time of access; README still also reachable via the older `turboderp/exllamav2` path which redirects / mirrors it.
- Successor: https://github.com/turboderp-org/exllamav3
- Recommended server: TabbyAPI — https://github.com/theroyallab/tabbyAPI/
- Single-user UI by the same author: ExUI — https://github.com/turboderp/exui
- Docs consulted in-repo: `README.md`, `doc/dynamic.md`, `doc/convert.md`, `doc/qcache_eval.md`

**As of:** 2026-11-15. All web sources accessed 2026-11-15 unless otherwise dated in §10.

**Status note that frames everything below:** The README at the head of the repository, as read on 2026-11-15, opens with a notice that the project is *archived for now* and that development continues on ExLlamaV3. ExLlamaV2 is therefore a finished design to study, not a moving target to chase. Its last PyPI release line visible at access was the 0.3.x series (0.3.2 wheel dated 2025-07-13 on PyPI); the in-repo dynamic-generator document was written against v0.1.4. Version numbers in this dossier are pinned to the document that states them.

**Essence.** ExLlamaV2 is an inference library for running large language models locally on modern consumer GPUs, built around one refusal: it will not compromise single-stream decode speed for generality. Where serving engines optimise aggregate throughput across many concurrent users, and where llama.cpp / GGUF optimise portability across CPU, Metal, Vulkan, ROCm and CUDA, ExLlamaV2 optimises the case of one person, one NVIDIA GPU (or a small multi-GPU split of one model), one conversation, waiting for the next token. Everything distinctive about it — a quantization format whose average bit-rate is a continuous dial rather than a menu, kernels co-designed with that format, a KV cache that can itself be quantized to 4 bits, and later a paged, dynamically batched generator that reuses prefix cache pages across jobs — follows from holding that single-user, low-latency, quantization-native brief and letting other briefs go.

---

## 2. Lineage & design intent: exllama → exllamav2

### 2.1 The V1 starting point

The original ExLlama (repository `turboderp/exllama`, early 2023) described itself, in its own README as retrieved 2026-11-15, as a standalone Python / C++ / CUDA implementation of Llama for use with 4-bit GPTQ weights, designed to be fast and memory-efficient on modern GPUs. The developer hardware named in that README is an RTX 4090 and an RTX 3090 Ti — consumer cards, not datacentre parts. Quantization itself was out of scope for V1: models arrived already GPTQ-quantized via external tooling such as AutoGPTQ or GPTQ-for-LLaMa, and ExLlama's job was purely to execute them well.

Three properties of V1 matter for understanding V2:

1. **Format follows someone else's quantizer.** V1 inherited GPTQ's fixed 4-bit world: group size (commonly 128), optional activation-order (`act-order` / `desc_act`) permutation, scales and zero-points per group. Its kernels had to be good at exactly that layout.
2. **Llama-first, then broadening.** V1 began as a Llama implementation and accreted other architectures. That origin left a Llama-shaped centre of gravity that V2's format work later exploited (see §3.5).
3. **Speed was already the identity.** Even in V1, the project was cited by other GPTQ tooling (for example AutoGPTQ's ExLlama backend) as the fast execution path for 4-bit models, inference-only, CUDA-only, 4-bit-only.

### 2.2 The V2 rewrite

ExLlamaV2 appeared as a preliminary release in mid-August 2023 — the V1 README's update log records a preliminary, initial and tentative release of ExLlamaV2 on 2023-08-12, and the V2 repository itself was created 2023-08-30. An archived snapshot of the V2 README from 2023-09-15 preserves the early self-description: almost all of the code was new, and the stated differences from V1 were, in substance:

- faster, better kernels;
- a cleaner and more versatile codebase;
- support for a new quant format (EXL2), alongside the same 4-bit GPTQ models V1 ran.

That short list is honest about the strategy. V2 was not a new product category; it was the same bet placed harder. By taking ownership of the quantization format as well as the kernels, the author could remove the constraint that had bounded V1 — the quantizer and the runtime could now be designed against each other. It also widened architecture coverage beyond the original Llama centre, to the range of Hugging Face decoder models its converter and loader came to support over the 0.0.x–0.3.x releases, including mixture-of-experts models (the converter docs discuss MoE calibration explicitly).

Subsequent V2 development added, in order of design significance:

- **Quantized KV caches** (FP8 and Q4 modes, evaluated in `doc/qcache_eval.md`; later Q8 and planned Q3/Q6 modes discussed in the dynamic-generator doc) — treating context memory as a second compressible budget, not a fixed FP16 tax.
- **Flash Attention integration**, and from v0.1.0, **paged attention via Flash Attention 2.5.7+**.
- **The dynamic generator** (v0.1.0+): dynamic/continuous batching, smart prompt caching, and KV-cache deduplication consolidated into one generator API, replacing the earlier base and streaming generators (see §4).
- **Speculative decoding support**, carried into the dynamic generator along with the earlier generators' sampling features (per the README's dynamic-generator summary).

The endpoint of the line is archival: with ExLlamaV3 (EXL3 quantization, based on QTIP) as the successor, V2/EXL2 is frozen. That is useful for a research corpus — the design can be assessed whole.

### 2.3 What "single-user, low-latency, quantization-native" forced

It is worth stating the counterfactuals explicitly, because they are the transferable lesson.

**Against the serving engines (vLLM, SGLang, TensorRT-LLM class).** A throughput-first engine accepts per-token kernel overhead, scheduler complexity, and memory reserved for many sequences, because its metric is tokens/second *summed over users* and requests/second under load. It will happily use a slightly slower attention kernel if paging that kernel's cache lets it fit two to four times as many concurrent sequences — the vLLM literature is explicit that paged attention's win is a batch-size lever, not a kernel-speed win. ExLlamaV2's metric is the inverse: latency and tokens/second *for the sequence the user is watching*. Consequences:

- The default configuration is batch size one. The dynamic generator's own doc notes that model and cache are initialised with an implicit batch size of one, and batching is something the generator manages opportunistically on top of that, not the assumption the memory layout is built around.
- There is no multi-tenancy machinery: no fair scheduling, no admission control, no per-user isolation, no production-server hardening. TabbyAPI, its own recommended server, describes itself as a hobby project for a small number of users, not meant for production servers — a limitation stated as a fact of the niche, not apologised for as a missing feature.
- Speculative decoding, prompt caching, and cache deduplication are all present, but each is justified by single-user experience (faster first token on the next turn of *your* chat, reuse of *your* system prompt) before any throughput argument.

**Against the portability engines (llama.cpp / Ollama class).** A portability-first engine must keep kernels expressible on every backend and must handle the model-does-not-fit case gracefully, layer by layer, across the PCIe bus. ExLlamaV2 refuses both:

- One vendor's hardware is targeted deeply (NVIDIA CUDA, tensor-core and memory-bandwidth behaviour on consumer GeForce cards) rather than five vendors' hardware adequately.
- The model must fit in VRAM (single GPU, or split across multiple GPUs — see §5). There is no CPU layer-offload path comparable to llama.cpp's `-ngl` partial offload. If it does not fit, the answer the design gives is not "run it slower" but "quantize it to a lower average bit-rate until it does fit" — which is precisely why the format in §3 exists.

**Quantization-native, not quantization-tolerant.** Many runtimes accept quantized weights as an input option. ExLlamaV2 treats the quantized representation as the primary representation: the converter, the on-disk layout, the dequantization path, and the GEMV kernels are one design. FP16/BF16 models can be loaded (front-ends list them), but nobody's reason to choose this engine is to run unquantized weights; the speed and memory story only exists in the quantized regime.

---

## 3. The EXL2 format

### 3.1 What EXL2 is, in one paragraph

EXL2 is a weight-only, post-training quantization format and method, native to ExLlamaV2, stored in Hugging Face-style model directories (safetensors weights plus config), in which different parts of the same model are quantized at different bit-widths drawn from {2, 3, 4, 5, 6, 8} bits, so that the *average* bits per weight (bpw) across the model can be any value between 2 and 8 — 4.65 bpw, 3.0 bpw, 2.55 bpw are all ordinary EXL2 artefacts, and Hugging Face repositories for EXL2 models are conventionally named by that average. The method that chooses the per-layer assignment is GPTQ-derived (see §3.4) and calibration-driven (see §3.3).

### 3.2 Mixed precision at two granularities

The README's EXL2 section, as read 2026-11-15, states the two levels of mixing plainly, paraphrased here:

1. **Across layers / matrices.** Different linear layers in the model can carry different bit-widths. Sensitive matrices keep more bits; robust matrices give bits up.
2. **Within a layer.** A single linear layer can itself be split, with more important columns quantized at a higher bit-width and the remainder lower — described in the README as akin to sparse quantization. The mechanism that makes this affordable is the same column-remapping (activation-order) trick that already let ExLlama execute act-order GPTQ models efficiently, so mixing formats inside a kernel invocation costs little to nothing in performance, per the author's account.

The `lm_head` (output) layer is handled as its own decision: the converter exposes a separate head-bit-width option (default 6 bits, which in practice yields a mixed assignment averaging about 6.3 bpw for that layer; the useful choices are noted as 6 and 8).

This two-level mixing is the core format idea. A fixed-menu format can only spend its bit budget uniformly or by coarse layer-type rules. EXL2 spends it where measured error says it buys the most.

### 3.3 Calibration and measurement: the two-pass converter

The converter (`convert.py`, documented in `doc/convert.md`) works in two passes:

**Pass 1 — measurement.** The model is effectively quantized many times over (the docs say about twelve times over, on a reduced calibration sample) to measure, per module/layer, how quantization error responds to each candidate setting. Defaults documented: measurement rows 16, measurement length 2,048 tokens. The result is saved as `measurement.json` and can be reused (`-m` / `-om` options) so that quantizing the same base model at several bit-rates does not repeat the expensive pass.

**Pass 2 — solve and quantize.** Given a target average bit-rate (`-b`, a float), the converter searches for the combination of per-layer settings that (in the README's formulation) minimises the *maximum* quantization error over the entire model while meeting the target average; the convert doc's notes describe the solving step in complementary terms as minimising the product of measured per-layer errors within the bits budget, and warn that this step can appear to pause — the search implementation is acknowledged to be inefficient. The distinction between the two phrasings (minimax vs. product) is not resolved further in the docs read; what is unambiguous is the shape of the problem: a global, error-measured allocation under an average-bits constraint, not a per-layer independent rounding. *[Reader note: treat "minimise the worst layer" as the README's headline characterisation and the product formulation as the solver's working objective as documented; the dossier does not claim they are identical.]*

**Calibration data.** Quantization proper uses a larger calibration set: defaults documented are 100 rows × 2,048 tokens, supplied as a Parquet file (`-c`), concatenated and truncated to the required token count. If none is supplied, a built-in dataset with a deliberately broad mix of data types is used, specifically to avoid overfitting the quant to one mode, language, or style — a failure mode the docs call out as most dangerous at low bit-rates. RoPE scaling settings used at calibration time must match the model's training/fine-tuning configuration, or calibration will be wrong for long-context models (the docs give DeepSeek-Coder's scale factor of 4 as the cautionary example).

**Cost of conversion.** Documented hardware for conversion is substantial: roughly 64 GB system RAM and 24 GB VRAM for a 70B model; about 16 GB RAM and 8 GB VRAM for a 7B. The deciding factor is model *width* (hidden size), not depth. Conversion is resumable from the working directory, and the converter reports a calibration perplexity for the quantized model as a sanity check (values around 30+ signal a poor quant; values in the thousands signal catastrophic failure, per the docs).

**MoE caveat.** For mixture-of-experts models, experts rarely triggered during calibration forward passes receive little calibration data (the docs warn when an expert sees under 10% coverage). GPTQ-style quantization of MoE models is flagged in the docs themselves as very new, with the impact of thin expert calibration not yet certain at time of writing.

### 3.4 GPTQ lineage, in brief

GPTQ (Frantar, Ashkboos, Hoefler & Alistarh, arXiv:2210.17323, submitted 2022-10-31, ICLR 2023) is a one-shot, weight-only post-training quantization method built on approximate second-order (Hessian) information, descended from Optimal Brain Quantization. In design terms: working layer by layer, it quantizes weights column by column and *compensates* for each rounding error by adjusting the not-yet-quantized weights in the same row, using inverse-Hessian information estimated from calibration activations. That compensation is what let GPTQ compress models to 3–4 bits per weight with negligible accuracy loss at scales (175B parameters in about four GPU hours) where naive round-to-nearest collapses.

EXL2's relationship to GPTQ, as stated in the V2 README, is that it is *based on the same optimization method as GPTQ*. The inheritance is the error-compensating, calibration-conditioned rounding machinery and the grouped-quantization layout (scales per group of weights; GPTQ models in V1/V2 conventionally use group size 128). The departure is everything in §3.2–§3.3: GPTQ as originally published and commonly distributed picks one bit-width for the model (typically 4); EXL2 turns bit-width into a per-layer, and even per-column-group, variable and adds a measurement pass plus a global allocator on top of the GPTQ core to decide it. A plain GPTQ checkpoint remains loadable by ExLlamaV2 — backwards compatibility with the V1 world was kept — but a GPTQ checkpoint cannot express an EXL2 mixed assignment, and an EXL2 checkpoint is not a GPTQ checkpoint.

### 3.5 Why this differs from GGUF's fixed quant types

GGUF (llama.cpp's format) offers a *menu*: named quant types (the Q4_K_M family and its siblings, IQ variants, etc.), each a fixed recipe. The K-quant recipes do use mixed precision, but the mixing is *prescribed by the recipe* — fixed rules about which tensor types get which bit-width, optionally informed by an importance matrix (`imatrix`) if the quantizer runs one. The user chooses a point on the menu; the file's average bit-rate is whatever that recipe produces.

EXL2 inverts the control flow:

| Dimension | GGUF approach | EXL2 approach |
|---|---|---|
| User's input | Pick a named recipe (e.g. a K-quant variant) | Pick a number: target average bpw (float, 2–8) |
| Where mixing is decided | In the format's fixed recipe, by tensor type | Per model, per layer, per column group, by measured error on calibration data |
| Calibration role | Optional (`imatrix` improves some quants) | Mandatory and central: measurement pass drives allocation |
| Fit-to-hardware workflow | Try recipes until one fits the card | Dial bpw down/up until the artefact fits the card exactly |
| Portability of artefact | Self-contained single file, runs across llama.cpp's many backends | HF directory layout, tied to ExLlamaV2's kernels and its Llama-normalised internal tensor expectations (secondary sources note EXL2 renames tensors so models present internally in a Llama-like form, which is one reason reuse outside the ExLlama line is poor) |

The practical consequence the README itself demonstrates: a Llama 2 70B at 2.55 bpw running (coherently, in the author's tests, at 2,048-token context) on a single 24 GB GPU, and 13B models at 2.65 bpw inside 8 GB. Neither artefact corresponds to any integer-bit format. The continuous dial is not a cosmetic feature; it is the mechanism by which "must fit in VRAM, no offload" (§2.3) becomes a workable rule instead of a frequent dead end. The price is that every (model, bpw) pair is its own conversion job with its own calibration cost — there is no cheap transcode from one bpw to another, only a re-solve reusing the saved measurement.

### 3.6 What EXL2 does not quantize

EXL2 is weight quantization. Activations remain in floating point at inference, and the KV cache is a *separate* compression axis with its own modes (§4.3, §5). Conflating the two budgets is the most common accounting error in this space; ExLlamaV2's design keeps them visibly separate, which a future runner should copy in its own bookkeeping even if it copies nothing else.

---

## 4. Architecture

### 4.1 Shape of the system

ExLlamaV2 is a library, not a server. The stack, bottom to top:

1. **CUDA extension** (`exllamav2_ext`): quantized linear (GEMV/GEMM) kernels, attention support, cache operations, sampling support — compiled as a PyTorch C++ extension, either ahead of time (prebuilt wheel) or just-in-time on first import.
2. **Python model layer**: config, model loading (including multi-GPU autosplit), tokenizer wrapper, cache classes.
3. **Generators**: originally a base generator and a streaming generator; from v0.1.0, the **dynamic generator** consolidates their inference, sampling, and speculative-decoding features into one API (the one exception documented: FP8 cache mode was not carried into the dynamic generator, on the grounds that Q4 cache mode performs better anyway).
4. **Servers / UIs are other people's layers**: TabbyAPI (FastAPI, OpenAI-compatible API) as the recommended server, ExUI as the author's own single-user web UI, and loaders inside general front-ends (§7). The library ships examples, including a console chat script, but its surface is a Python API.

This layering is itself a design statement: the engine does not own HTTP, sessions, or chat templating policy. Ollama made the opposite choice (engine + daemon + API + registry as one product); §9 returns to what each choice costs.

### 4.2 Dynamic batching: the v0.1.0 generator in design terms

The dynamic-generator document (`doc/dynamic.md`, written against v0.1.4) is the best primary source in the repo for how modern ExLlamaV2 actually schedules work, and it is unusually candid about the alternatives it rejected. Summary in our own words:

**The problem with static batching.** Earlier generators used left-padding to batch uneven sequences into a rectangular tensor against a pre-allocated cache. Padding wastes cache space, and attention implementations either cannot consume left-padded batches (Flash Attention, at the time) or waste compute attending to pad tokens that are then masked away. Right-padding avoids the mask but forces the batch to start at the shortest sequence's length, wasting early steps. Flash Attention's unpadded mode helps attention itself but requires the whole cache to be reshaped every time any sequence grows by a token.

**Paged attention as the enabler.** From Flash Attention 2.5.7, paged attention is available: the KV cache is indexed through a block table, so a sequence's cache pages need not be contiguous and sequences can grow by allocating a new page rather than by moving data. ExLlamaV2's page size is fixed at 256 tokens in the documented implementation. Wasted space per sequence is at most the tail of its final page.

**Continuous (dynamic) batching on top of paging.** The generator runs a job queue. It starts as many jobs as fit in the cache; when a job finishes, its pages are freed and the next queued job — whether queued at the start or added mid-run — takes the space, filling whatever gaps fragmentation has opened, because the block table imposes no contiguity requirement. Defragmentation is deliberately conservative: only unreferenced pages are defragmented, and only when the queue is empty, so housekeeping never stalls live generation. The author notes the terminology himself: what ExLlamaV2 calls the *dynamic* generator is what the serving literature usually calls *continuous batching*, with a hybrid flavour.

**Why this matters for a single-user engine.** The canonical use is not fifty strangers; it is one user (or one evaluation harness) with many related prompts: the doc's own examples generate 100 completions from the same prompt seed and run the repo's MMLU / HumanEval harnesses by queueing thousands of jobs and collecting results as each completes. Batch size becomes an emergent property of cache capacity ("it may run at batch 100, or hold at batch 17 if that is all that fits") rather than a configuration the caller must get right. The caller-facing API collapses accordingly: pass a string, get a string; pass a list of strings, get a list of strings; or enqueue jobs explicitly and drive an `iterate()` loop (or its `asyncio` variant, `ExLlamaV2DynamicJobAsync`) for streaming, per-job identifiers, logits, and token probabilities.

### 4.3 KV cache handling

Four mechanisms deserve separation, because later runners often implement one and claim the others:

1. **Sizing as a token budget.** The cache is created with a maximum sequence length that functions as a *total token capacity* under the dynamic generator: the documented example creates a 65,536-token cache for a model whose per-sequence limit is 8k, yielding room for (for example) eight full-length sequences or sixty-four 1k sequences. Cache capacity, not batch size, is the resource the user provisions.
2. **Quantized cache modes.** Alongside the standard FP16 cache, ExLlamaV2 provides an 8-bit cache class and a Q4 cache class (`ExLlamaV2Cache_Q4` and siblings), with Q8 positioned in the docs as more accurate at a footprint similar to FP8, and Q3/Q6 modes described as planned at the time of the dynamic-generator doc. The Q4 mode uses Hadamard rotations on keys/values in its improved form. The author's own evaluation (`doc/qcache_eval.md`) reports, on The Pile perplexity samples and HumanEval: both Q4 and FP8 caches add very little loss versus FP16; Q4 is, counter-intuitively, *more* accurate than FP8 in those tests; and HumanEval differences for Q4 are within the margin of error. For a chat runner the implication is direct: cache bits are usually better spent as *weight* bits (raise bpw) or as *context length* than hoarded as FP16 cache.
3. **Deduplication (prefix sharing).** Because sequences reference cache pages through the block table, multiple sequences can reference the *same* pages. When a new job's prompt prefix already exists in cache — the long-system-prompt case, or many questions over one shared document — the job references the existing pages instead of re-prefilling them, saving both prefill time and VRAM. The doc's worked example fans one short story out into many independent questions, each reduced to shared-prefix pages plus a unique tail.
4. **Prompt caching across jobs.** Reuse is not limited to concurrently active jobs. The generator avoids overwriting recently used pages, so a follow-up job sharing a prefix with a recently *finished* job can still reuse its cache. In chat terms: successive turns reuse the whole prior context (as the old streaming generator already did), and alternating between two conversations need not evict either, if the cache is large enough to hold both.

### 4.4 Flash Attention usage

Flash Attention is used in two distinct roles, and the dossier keeps them distinct because the project's history does:

- **As an attention kernel** for prefill and decode, reducing attention's memory traffic by tiling in fast on-chip memory rather than materialising the full attention matrix — the standard Flash Attention benefit, most valuable at long context.
- **As the paging substrate**: the v0.1.0+ paged-attention support is explicitly tied to Flash Attention 2.5.7+ in the README. Paging, dynamic batching, deduplication, and prompt caching in §4.2–§4.3 all stand on this dependency. Before that version, ExLlamaV2 used Flash Attention without the paged cache organisation, and its generators used the padding strategies described above.

A portability consequence follows: the paged path inherits Flash Attention's hardware and precision constraints (NVIDIA, and in practice modern architectures; the FP8 cache mode's absence from the dynamic generator is one visible seam).

### 4.5 Generator / sampler surface

What the primary docs verify about the sampling and generation surface:

- **Sampler settings object** (`ExLlamaV2Sampler.Settings`), applicable per-job or shared across a batch, with per-job lists supported. Fields explicitly exercised in the primary docs include `temperature`, `top_p`, and `token_repetition_penalty`; a `greedy()` preset constructor is used in the README's streaming example. The full settings object is broader than the three fields the docs happen to demonstrate — front-end integrations expose the conventional family (temperature, top-k, top-p, min-p class filters, repetition/frequency/presence penalties) — but this dossier only asserts as primary-verified the fields named above and marks the wider family as front-end-observed. *[Unverifiable from primary docs read: the exhaustive field list of `ExLlamaV2Sampler.Settings` in the final 0.3.x release; the repo's code, not its docs, is the authority, and code was not audited line-by-line for this dossier.]*
- **Stop conditions** as token IDs and/or strings; **banned strings** in the async job API (and, by extension of the same job model, banned tokens).
- **Streaming** both synchronously (job + `iterate()` loop returning result dicts with text chunks, metrics, and optionally logits/probabilities) and via `asyncio`.
- **Speculative decoding**, listed in the README as a feature of the previous generators that the dynamic generator retains.
- **Determinism caveat**: text-generation-webui's parameter documentation notes that ExLlama v1/v2 loaders are not deterministic with respect to the UI seed setting — sampling randomness is not seed-controlled the way llama.cpp's is in that integration. Worth recording for anyone designing eval harnesses on top of it.

The design character of the surface is *job-oriented*: a job carries its prompt (as token IDs at the low level), its own sampler settings, its own stop conditions, and a user-supplied identifier that rides back with every result chunk. That is a chat-runner-friendly shape — one conversation turn, one branch, one eval item are all the same object — arrived at from an inference library rather than from an HTTP API backwards.

---

## 5. Memory management

### 5.1 Model loading

Models load from a Hugging Face-style directory: config, tokenizer files, and safetensors shards (EXL2, GPTQ, or full-precision weights). Loading flows through a config object and a model object, with the cache created separately and sized by the caller (see §4.3) — weights and cache are distinct allocations with distinct knobs, and `lazy` cache creation is supported so allocation can be deferred. The documented dynamic-generator example loads with `load_autosplit` (see §5.2) and progress reporting.

Practical loading frictions recorded in the primary README: prebuilt wheels must match platform, Python version, CUDA version, *and* PyTorch version (the Torch extension ABI breaks across PyTorch releases); the JIT/PyPI route avoids wheel-matching by compiling on first use and caching the build under `~/.cache/torch_extensions`, at the cost of a first-run build and a working toolchain (CUDA Toolkit plus gcc on Linux or Visual Studio Build Tools on Windows).

### 5.2 What fits where: the VRAM-only rule and multi-GPU split

The governing rule, stated in §2.3 and corroborated by every integration guide read: **the model's weights must fit entirely in GPU memory.** The escape valves, in the order the design intends them to be used:

1. **Lower the average bit-rate.** The continuous EXL2 dial (§3) exists for this. Author-reported fits from the README (hardware: single 24 GB GPU; context as noted; treat as author tests, not independent benchmarks): Llama 2 70B at 2.55 bpw with 2,048-token context on 24 GB; 13B at 2.65 bpw within 8 GB (with the caveat that those particular 13B models lacked GQA, effectively limiting context to 2,048). The author adds, drily, that in either case the model is unlikely to fit *alongside a desktop environment* in that budget.
2. **Quantize the cache.** FP16 → 8-bit → Q4 cache modes (§4.3) shrink the second budget so more of the card can go to weights or context.
3. **Split across multiple GPUs.** `gpu_split` / autosplit loading distributes the model across several GPUs (the CLI examples use `--gpu_split auto`). This is *model splitting across VRAM pools*, not CPU offload: aggregate VRAM must still hold the weights. It is also not tensor-parallel serving in the vLLM sense; it is one model, one user, more memory (with the usual interconnect cost when layers span cards — secondary benchmark write-ups note the sharp speed fall when work spills beyond VRAM, which in this design means it simply does not spill; it does not run).

**What is not supported:** partial CPU/RAM layer offload of the llama.cpp kind. SillyTavern's own API-connection documentation warns TabbyAPI/ExLlamaV2 is not recommended for low-VRAM users precisely because there is no CPU offloading. Independent comparisons concur: for a model that exceeds VRAM at the lowest usable bit-rate, llama.cpp is the fallback, not a slower mode of ExLlamaV2. *[Speculation, marked: this reads as a deliberate kernel-design consequence, not an oversight — a fused dequant-GEMV tuned for VRAM-resident weights gains little from a PCIe-fed variant, and the author chose the EXL2 dial as the fit mechanism instead. The docs state the absence; the motive is inference.]*

Indicative weight footprints (arithmetic, not benchmarks): weights ≈ parameters × bpw / 8 bytes, plus scales/metadata and the `lm_head` at its higher rate, plus cache (§4.3) and activations. Hence a 7B at 4.0 bpw is roughly 3.5 GB of weights before overhead — consistent with the README's 7B-class speeds being measured comfortably on 24 GB cards with room for large caches, and with third-party measured runs such as Llama 3.1 8B at 4.65 bpw occupying about 5.4 GB total on an RTX 4090 (see §6.3).

### 5.3 Cache sizing as user-visible policy

Because cache capacity is provisioned in tokens and pages are 256 tokens, the user's real controls are: total cache tokens, cache precision mode, and the model's own per-sequence maximum (extendable via RoPE scaling config, with the calibration caveats of §3.3). The generator then treats that pool as shared, deduplicated, prefix-cached workspace (§4.3). There is no per-request cache reservation API in the documented surface — another single-user tell: contention policy is unnecessary when contention is one person's jobs.

### 5.4 System RAM

System RAM matters at two moments: conversion (§3.3: up to ~64 GB for 70B) and initial weight loading/staging. At inference steady state, the design intends the working set to be VRAM-resident; a slow CPU is noted in the README's performance section as a possible bottleneck (tokenization, sampling, orchestration remain Python/CPU work around the kernels), but system RAM is not part of the inference memory hierarchy the way it is in offload-capable engines.

---

## 6. Kernels: where the speed lives

### 6.1 The workload shape: decode is a memory problem

Autoregressive decode at batch size one is, arithmetically, a streaming problem: each generated token requires reading (nearly) every weight in the model exactly once, while performing only about two floating-point operations per weight (a vector–matrix product, GEMV, per layer). The ceiling on tokens/second is therefore set by memory bandwidth divided by bytes-per-token — i.e., by model size *at its quantized bit-rate* — long before it is set by FLOPs. Prefill is the opposite regime (many tokens at once, GEMM, compute-bound), and §6.3 keeps the two separate.

Every kernel decision in ExLlamaV2 reads correctly once that is fixed in mind:

- **Fused dequantization + matvec.** The quantized linear kernels dequantize weights on the fly, inside the kernel that consumes them, rather than materialising an FP16 copy of the weight matrix (which would double memory traffic and halve effective capacity). The kernel's job is to turn packed 2/3/4/5/6/8-bit weights, their group scales, and the act-order permutation into arithmetic at full bandwidth. This is the "quant GEMV kernel" family the assignment names, and it is where the project's hand-written CUDA concentrates.
- **Mixed-format execution at no premium.** Because the act-order remapping already reorders columns, a layer whose column groups carry *different* bit-widths can be executed by the same kernel structure with, per the author, little to no performance impact (§3.2). Without that property, EXL2's within-layer mixing would be a quality feature bought with speed — the opposite of this project's trade. Format and kernel were, again, designed together.
- **Bypassing generic framework layers.** The extension calls its own CUDA kernels directly for the hot path rather than composing PyTorch operators, minimising per-launch and per-op overhead — overhead that is invisible at batch 64 and decisive at batch 1, where kernel-launch and Python-side costs are a visible fraction of a ~5 ms token step.
- **Attention and cache kernels matched to the cache modes**, including the quantized-cache paths (Q4 cache with Hadamard-rotated keys/values) and Flash Attention for the attention computation itself (§4.4).

### 6.2 Why batch-1 decode is its home turf

Three compounding reasons:

1. **Bandwidth is the whole game, and quantization is a bandwidth multiplier.** Halving average bpw roughly halves bytes read per token and therefore roughly doubles the decode ceiling, until non-weight costs dominate. The README's own table shows the gradient on one model (Llama 2 7B, RTX 4090): 257 t/s at 3.0 bpw, 211 t/s at 4.0 bpw, 179 t/s at 5.0 bpw. No serving engine can exploit this as single-mindedly, because at large batch the bottleneck migrates to compute, where low-bit weight-only quantization helps far less.
2. **Consumer cards are bandwidth-rich for their price but capacity-poor.** A 24 GB RTX 4090 offers roughly 1,008 GB/s of memory bandwidth. An engine that wastes none of the capacity on FP16 weights, FP16 cache, or padding — EXL2 dial + Q4 cache + paged allocation — converts that bandwidth directly into either speed (smaller model, faster) or capability (larger model, fits at all).
3. **Latency overheads are minimised where they are proportionally largest.** Single-user decode issues many small kernels back-to-back; per-token fixed costs (scheduler, sampling, Python orchestration) directly cap t/s for small models — visible in the TinyLlama 1.1B figures (§6.3), which sit far below the naive bandwidth ceiling for exactly this reason. *[Interpretation, marked as such: the docs note slow CPUs as a bottleneck; attributing the small-model shortfall specifically to launch/orchestration overhead is standard analysis of this workload, not a quote.]*

### 6.3 Reported numbers, with hardware context

All numbers below are *reported*, not re-measured for this dossier. Hardware, model, and mode are stated with each, per quality law.

**Author's table (README, accessed 2026-11-15; RTX 3090 Ti and RTX 4090; generation speed):**

| Model | Mode | 3090 Ti | 4090 |
|---|---|---:|---:|
| Llama 7B | GPTQ, group 128, no act-order | 181 t/s | 205 t/s |
| Llama 13B | GPTQ, group 128, no act-order | 110 t/s | 114 t/s |
| Llama 33B | GPTQ, group 128, act-order | 44 t/s | 48 t/s |
| OpenLlama 3B | GPTQ, group 128, act-order | 259 t/s | 296 t/s |
| CodeLlama 34B | EXL2 4.0 bpw | 44 t/s | 50 t/s |
| Llama 2 7B | EXL2 3.0 / 4.0 / 5.0 bpw | 217 / 185 / 164 t/s | 257 / 211 / 179 t/s |
| Llama 2 70B | EXL2 2.5 bpw | 33 t/s | 38 t/s |
| TinyLlama 1.1B | EXL2 3.0 / 4.0 bpw | 656 / 602 t/s | 770 / 700 t/s |

An earlier archived README snapshot (2023-09-15) shows the V1→V2 comparison on the same cards (e.g. Llama 7B GPTQ: V1 173 t/s → V2 195 t/s on a 4090), i.e. the rewrite's kernel gains on identical GPTQ artefacts were on the order of 10–30% in those early tests, before EXL2-specific gains.

**Independent / third-party reports (treat with more caution):**

- A measured-benchmark collection (quantized.uk, accessed 2026-11-15; methodology stated as batch-1, 128-token prompt, 128 generated tokens, 4,096 context, with a bandwidth-ceiling sanity check) records Llama 3.1 8B at EXL2 4.65 bpw on ExLlamaV2 at **235 t/s on an RTX 4090 (5.4 GB VRAM)** and **175 t/s on an RTX 3090 (5.4 GB)** — consistent with the author's 7B-class figures once model and bpw differences are allowed for.
- A comparison article (insiderllm.com, updated 2026-11-04) aggregating oobabooga-community testing reports Llama 2 13B on an RTX 3090 at ~57 t/s (EXL2 4.25 bpw) and ~64 t/s (GPTQ 4-bit) versus ~31 t/s for llama.cpp GGUF Q4_K_M with full GPU offload, and prompt-processing around 14,000 t/s for an 8B on an RTX 4090, roughly 2–2.5× llama.cpp with Flash Attention in that test. These are secondary aggregations of community numbers, *not* controlled benchmarks; the dossier records them as evidence of the *direction and rough magnitude* (ExLlamaV2 ahead on NVIDIA, same-hardware, VRAM-resident comparisons) that the ecosystem consistently reports, not as precise figures to engineer against.

**Prefill vs decode honesty:** the large prompt-processing figure above and the decode table measure different regimes (§6.1). Any future citation of "ExLlamaV2 speed" without stating which regime, which card, which bpw, and which context length should be treated as unverified.

---

## 7. Ecosystem position

ExLlamaV2's deployment evidence is best read as: *wherever one NVIDIA user wanted the fastest possible local chat or roleplay and was willing to live inside its format, this is what they ran.* The integrations named in the primary README, as read 2026-11-15:

- **TabbyAPI** (theroyallab) — the official and recommended backend server. FastAPI-based, OpenAI-compatible API, with Hugging Face model downloading, embedding-model support, and Jinja2 chat-template support. It is the bridge that made ExLlamaV2 addressable by the wider chat-front-end world. (Note for currency: TabbyAPI's own current README, per secondary reporting at access time, now centres its ExLlamaV3 backend — the V2 pairing is the historical and still-documented one in V2's README.)
- **ExUI** (turboderp) — the author's own minimal, standalone, single-user web UI serving an ExLlamaV2 instance directly, with chat and notebook modes. The purest expression of the intended use: no server product, just a window onto the library.
- **text-generation-webui** (oobabooga) — supports ExLlamaV2 through two loaders, `exllamav2` (native) and `exllamav2_HF` (Hugging Face-integrated variant with a wider feature/sampler surface). For several years this was the most common way casual users encountered EXL2 models, and its loader options (GPU split, max sequence length, cache mode flags) document what end users actually tuned.
- **lollms-webui** — supports ExLlamaV2 through its exllamav2 binding (named in the README's integration list).
- **SillyTavern** — not a host of the engine, but the demand side: SillyTavern connects to TabbyAPI as its ExLlamaV2 route (its docs describe TabbyAPI as a lightweight ExLlamaV2-based API with streaming, supporting EXL2, GPTQ and FP16 models, with an official extension for loading/unloading models from inside SillyTavern), and to text-generation-webui as another route. The roleplay community's preference for this stack — TabbyAPI + ExLlamaV2 behind SillyTavern — is the strongest deployment evidence for the single-user thesis: that workload is one user, one long-lived character conversation, latency-sensitive, sampler-sensitive, and NVIDIA-desktop-based.
- **KoboldCpp-adjacent world — a precision note.** KoboldCpp itself is a llama.cpp-based, GGUF engine; it does *not* embed or serve ExLlamaV2, and this dossier does not claim otherwise. The adjacency is sociological, not technical: KoboldCpp and the TabbyAPI/ExLlamaV2 stack compete for the *same* creative-writing/roleplay user, fronted by the *same* SillyTavern client, divided largely by format (GGUF vs EXL2) and by whether the user's model fits VRAM with speed to spare (ExLlamaV2's ground) or needs CPU offload and maximal portability (KoboldCpp's ground). Any "ideas to steal" analysis that treats them as one codebase would be wrong; treating them as one *market* is correct.
- **Model distribution**: EXL2 artefacts were distributed at scale on Hugging Face by the author (`turboderp`) and by community quantizers the README itself names — LoneStriker and bartowski — typically with the average bpw in the repository name and multiple bpw variants per model. The existence of a quantizer-publisher ecosystem around a single-author engine is itself evidence about where the format's value was perceived to lie.

What is absent is also position: no Ollama registry support, no LM Studio integration, no first-party OpenAI-server product from the engine author, no cloud/serving deployments of note. The ecosystem is a fan-out of community servers and UIs around a library — the inverse of Ollama's integrated product shape.

---

## 8. Strengths / weaknesses

### Strengths (stated precisely)

1. **Fastest-in-class single-stream decode on NVIDIA consumer hardware**, by consistent author and third-party reporting (§6.3), when the model fits in VRAM. The margin over GGUF/llama.cpp on the same card is routinely reported in the 1.5× class for generation.
2. **Exact-fit quantization.** The continuous bpw dial (§3) converts "does it fit?" from a lottery over a fixed menu into a solvable equation, enabling otherwise-impossible single-card runs (70B on 24 GB at 2.55 bpw, author's test).
3. **Quality per bit at low bit-rates**, from calibration-measured allocation: bits are spent where measured error says they matter, including within-layer column mixing — the regime (sub-4 bpw) where fixed recipes degrade fastest.
4. **A complete memory story**: weights (EXL2 dial) + cache (FP16/8-bit/Q4 modes with published quality evals) + allocation (paged, deduplicated, prefix-cached) are all first-class, separately tunable budgets.
5. **A job-oriented generator API** (§4.5) that makes single, batched, streamed, and async generation the same abstraction, with per-job sampler settings — unusually well-shaped for chat and eval workloads.
6. **MIT licence, small surface, hackable library form.** No server lock-in; embeddable in any Python front-end.
7. **GPTQ backwards compatibility**: the V1 artefact world kept working.

### Weaknesses (stated precisely)

1. **NVIDIA-only in practice.** The documented install path requires the CUDA Toolkit; the README names no other backend. Historical nuance: a preliminary ROCm port was noted in September 2023 and ROCm wheel-build workflows exist in the repo, and some downstream projects compiled ROCm variants — but no primary document read for this dossier presents ROCm as a supported, equivalent path, and secondary sources uniformly treat the engine as CUDA-only (no Metal, no Vulkan, no CPU inference path, no Apple Silicon, no ARM in practice). For engineering purposes: **one vendor, one API.** *[Marked as the dossier's assessment from conflicting/partial sources; the safe claim is "CUDA-first with experimental ROCm traces", the practical claim is "NVIDIA-only".]*
2. **No CPU offload; hard VRAM wall.** Models larger than aggregate VRAM at the lowest acceptable bpw simply do not run (§5.2). This excludes the entire "big model, small card, patience" segment that llama.cpp/KoboldCpp serve.
3. **Format lock-in.** EXL2 artefacts run (in practice) only on ExLlamaV2/V3-line kernels; the layout's internal Llama-normalisation further discourages reuse. Every model × bpw pair is a separate, calibration-costly conversion (§3.3), and conversion itself demands serious hardware (up to 64 GB RAM / 24 GB VRAM for 70B). GGUF's single-file portability is the direct counterexample.
4. **No serving ambitions — by design, with real costs.** Dynamic batching notwithstanding, there is no multi-tenant scheduling, auth, isolation, or production-server story; the recommended server disclaims production use. Anyone needing concurrent users should, and does, choose vLLM-class engines.
5. **Python + PyTorch + CUDA toolchain weight.** Install friction (wheel/ABI matching, first-use JIT compilation, Visual Studio/gcc requirements) is the opposite of a single-binary runner's; it selects for technical users.
6. **Sampler determinism / seed control gaps** in common integrations (§4.5), and a sampler surface whose full extent is documented in code rather than prose.
7. **Project finality.** Archived in favour of ExLlamaV3: no new architectures, kernels, or fixes should be expected on the V2 line. EXL2 artefacts and knowledge transfer; the codebase is a reference design now, not a dependency to build a future on. *[Currency note: statements about TabbyAPI's migration to a V3 backend come from secondary reporting at access time (2026-11-15) and were not re-verified against TabbyAPI's live repo for this dossier.]*

---

## 9. IDEAS TO STEAL for a Go 6 GB runner

*Framing for this section: the hypothetical target is an improved Ollama-class runner, implemented in Go, whose defining constraint is a **6 GB** usable budget (a small consumer GPU, or a tightly capped allocation on a shared card). Every idea below is assessed against that constraint. "Gain" and "cost/risk" are engineering estimates by this dossier — speculation, marked as such throughout — not measurements. Nothing here proposes copying code; these are design transfers, re-implemented clean-room.*

### 9.1 Continuous bit-rate thinking vs. the fixed quant menu

**Steal:** Treat average bits-per-weight as a *continuous provisioning variable*, not a catalogue choice. At model-load (or model-pull) time, compute the artefact that fits the *actual* free budget: `target_bpw ≈ (budget − cache_reserve − runtime_reserve) × 8 / parameters`. Even if the underlying Go runner keeps a small set of block quantizers (e.g. 2/3/4/5/6/8-bit block kernels), it can *mix* them per layer to hit a non-integer average — which is all EXL2 does at the format level.

**Expected gain (estimate):** The difference between "the 4-bit artefact is 200 MB too big, fall back to the 3-bit artefact and lose quality everywhere" and "a 3.8 bpw artefact that fits exactly". On a 6 GB budget this is not marginal: for a 7–8B model, the menu gap between adjacent fixed quants is roughly 0.4–0.9 GB — a large fraction of the whole budget. Exact-fit also frees a *known* remainder for cache, instead of whatever a menu item happens to leave.

**Cost / risk:** Model distribution gets harder — Ollama's registry model (named tags, shared layers, instant pulls) assumes a finite artefact set. Mitigations: quantize-on-pull on the user's machine (slow, needs calibration — see §9.2), or publish a denser bpw ladder (e.g. every 0.25 bpw) and accept registry growth. Kernel risk is low if mixing is per-layer; per-column mixing (§9.4) is the expensive version.

### 9.2 Calibration-driven quant choice

**Steal:** EXL2's measurement pass (§3.3) as a *principle*: never allocate bits by layer-type folklore ("attention matters, MLP doesn't") when a cheap measurement on representative data can allocate them by observed error. A Go runner cannot ship a full GPTQ pipeline casually, but it can ship: (a) a small built-in, deliberately mixed calibration set (EXL2's anti-overfitting lesson — broad mix, or low-bpw quants overfit to one mode); (b) a per-layer sensitivity table *precomputed per model at publish time* and shipped as metadata, so the client-side allocator in §9.1 is just solving a knapsack against published sensitivities — no on-device measurement pass needed.

**Expected gain (estimate):** Most of EXL2's quality-per-bit advantage at sub-4 bpw, where a 6 GB runner will live for 7B+ models, without paying conversion cost on user hardware. Precomputed sensitivity metadata is a few KB per model.

**Cost / risk:** Publishing pipeline must run the measurement pass per model (server-side cost, EXL2-documented at up to 64 GB RAM / 24 GB VRAM for 70B-class — budget it). Sensitivity measured on one calibration mix may mislead for specialised (code-only, non-English) deployments; ship the calibration-mix description with the metadata so the limitation is visible. Risk of false precision: mark sensitivity-derived quants with their calibration perplexity, as EXL2's converter does.

### 9.3 Batch-1-first kernel priorities

**Steal:** The kernel programme, in priority order, for a chat runner: (1) a fused dequantize + GEMV path for the single-token decode step, per supported block quantizer, tuned for bandwidth on the *small* cards the 6 GB budget implies (their bandwidth, not a 4090's, is the design point); (2) dequantization that never materialises a full FP16 weight copy; (3) ruthless per-token fixed-cost discipline — in Go terms, no per-token allocations, no per-token syscalls, sampler and detokenizer off the critical path or overlapped. Treat prefill (GEMM) as the second kernel family, optimised after decode is right, because chat UX is decode-dominated after the first screenful.

**Expected gain (estimate):** This is the largest single speed lever available: decode t/s scales almost linearly with bytes-not-read and with fixed-costs-removed at batch 1 (§6.1–§6.2). A runner that is merely "GGUF-compatible speeds" versus one that is batch-1-tuned is the difference users describe as sluggish vs. snappy, on identical artefacts.

**Cost / risk:** Go-specific: the hot kernels will not be Go — they will be GPU kernels reached via cgo or a backend library, which taxes Go's build simplicity and cross-compilation story (a standing cross-platform law for this user's projects makes that tax real: Windows / Linux x86-64 / Linux ARM must all keep working). Scope the steal honestly: batch-1-first is a *prioritisation* discipline that applies even when the kernels come from an underlying engine (llama.cpp-class); it tells you which configurations to default to, which to benchmark in CI (batch-1 decode on a 6 GB card as a release gate), and which optimisations to refuse (any that buy batch throughput with batch-1 latency).

### 9.4 Within-layer mixed precision (the second-order steal)

**Steal, later:** EXL2's within-layer column mixing (§3.2) — important columns at higher bits inside the same matrix. In Go-runner terms this is a v2 feature: first ship per-layer mixing (§9.1), then per-column-group mixing for the most sensitive layers only (embeddings-adjacent and final layers are the usual candidates — to be confirmed by the §9.2 measurements, not by folklore).

**Expected gain (estimate):** A further quality increment at fixed average bpw, concentrated at very low bpw (≤3.5) where per-layer mixing alone runs out of granularity.

**Cost / risk:** Kernel complexity jumps — the GEMV must handle heterogeneous column groups without losing the fused-dequant property, and EXL2 only got this cheaply because its act-order remapping already reordered columns. If the Go runner's kernel substrate lacks an equivalent permutation trick, this steal can *cost* speed. Gate it on a prototype measurement; be willing to drop it.

### 9.5 Quantized KV cache as a default, not an option

**Steal:** ExLlamaV2's cache modes and, more importantly, its published evidence (§4.3): ship Q8-class cache as the default and Q4-class cache as the long-context mode on a 6 GB budget, with FP16 cache available but not default. Reinvest the saved bytes automatically: the loader should offer the user the trade explicitly ("Q4 cache frees ~X MB → +N bpw on weights, or +M tokens of context") rather than hiding it in flags.

**Expected gain (estimate):** Cache at FP16 for a GQA 8B at 8k context is on the order of 1 GB — a sixth of the entire budget. Q4 cache cuts that to roughly a quarter, at a quality cost the primary source's own evals found within noise on HumanEval and minimal on perplexity. On 6 GB, this is the difference between 4k and 16k usable context at the same weight quality.

**Cost / risk:** Quantized-cache attention kernels are real work, and Q4-cache quality at *very* long context and on attention-heavy retrieval tasks is less proven than at the evaluated scales — default to Q8, make Q4 opt-in per model with the eval numbers attached. Hadamard-rotation tricks (as in the improved Q4 cache) may be needed to reach the published quality; budget the R&D.

### 9.6 Paged cache + prefix deduplication, sized for one user

**Steal:** The dynamic generator's cache organisation (§4.2–§4.3), scaled down: page the KV cache (256-token pages are a reasonable starting granularity), let multiple sequences *reference shared prefix pages* (system prompt, character card, RAG preamble), and retain recently finished conversations' pages for instant resume (prompt caching). A Go chat runner serving one user with several named conversations gets most of vLLM's paging benefit with none of its multi-tenancy machinery: no scheduler fairness, no preemption policy — just a page table, reference counts, and an LRU that only evicts unreferenced pages when space is needed. Defragment only when idle, exactly as the dynamic generator does.

**Expected gain (estimate):** Time-to-first-token on turn *n* of a chat collapses to prefilling only the new turn, when the prefix is resident; switching between two live conversations stops costing a full re-prefill; parallel sampling (best-of-*n*, branching) shares the prompt's pages instead of duplicating them. These are the interactions a single user actually feels, dozens of times a day.

**Cost / risk:** Page-table indirection makes the attention kernel's job harder (this is the known paged-attention kernel tax — the vLLM literature puts an early paged kernel ~20–26% slower than its non-paged equivalent, repaid by capacity; at batch 1 with one user the repayment is thinner). Prototype against the simple contiguous cache and keep whichever wins on the target card. Complexity risk in Go: reference-counted GPU buffers plus async generation is a classic leak/use-after-free site — needs a strict ownership model and soak tests.

### 9.7 The job as the API unit

**Steal:** The generator/sampler surface shape (§4.5): one `Job` value carrying prompt, sampler settings, stop conditions, banned strings, and a caller-supplied identifier, submittable singly, in lists, or streamed via an async iterator, with the runtime — not the caller — deciding how jobs share the cache and batch. In Go this maps naturally onto a channel-returning API with per-job contexts for cancellation. Per-job sampler settings (rather than per-server or per-model settings) are the detail to copy exactly: branching a conversation at a different temperature should not require reloading anything.

**Expected gain (estimate):** API ergonomics and correctness rather than raw speed: front-ends (chat UI, eval harness, agent loop) all become the same client shape, and features like parallel branches and eval sweeps stop being special cases.

**Cost / risk:** Low. Main risk is over-generalising into a serving framework — hold the single-user line: the job queue exists to share one person's cache pages, not to schedule a fleet.

### 9.8 What NOT to steal

- **The VRAM-or-nothing rule.** On a 6 GB budget it would exclude most interesting models. Steal the *dial* (§9.1) that made the rule survivable, keep Ollama-class graceful degradation (partial offload) as the floor beneath the dial's lowest setting.
- **The toolchain.** Python/PyTorch/CUDA-extension installation friction is antithetical to a Go single-binary runner; nothing in the speed story requires it — the kernels do.
- **Format exclusivity.** EXL2's lock-in was affordable for a single-author library; a runner with a registry should keep its artefacts in an open, documented layout (GGUF-compatible or a published superset), even when borrowing EXL2's allocation mathematics wholesale.

---

## 10. Sources with dates accessed

All sources accessed **2026-11-15** unless a different publication/snapshot date is stated. Primary sources (the project's own documents) are listed first and carry the dossier's load-bearing claims; secondary sources are marked and were used for corroboration, ecosystem context, and clearly-attributed third-party numbers only.

**Primary**

1. ExLlamaV2 README, `master` branch, via raw.githubusercontent.com/turboderp/exllamav2 and via github.com/turboderp-org/exllamav2 — essence, archival notice, TabbyAPI recommendation, v0.1.0 paged-attention and dynamic-generator notes, performance table (RTX 3090 Ti / RTX 4090), install methods, EXL2 description, integration list (TabbyAPI, ExUI, text-generation-webui, lollms-webui), community quantizers (LoneStriker, bartowski).
2. ExLlamaV2 `doc/dynamic.md` (written against v0.1.4) — static vs. continuous batching analysis, Flash Attention 2.5.7 paged attention, 256-token pages, job queue, defragmentation policy, deduplication, prompt caching, cache-as-token-budget example (65,536-token cache, Llama 3 8B), Q4/FP8/Q8 cache-mode notes, sampler-settings example (temperature, top_p, token_repetition_penalty), job/streaming/async API.
3. ExLlamaV2 `doc/convert.md` — converter arguments, two-pass measurement/quantize flow, calibration defaults (100 × 2,048; measurement 16 × 2,048), built-in calibration dataset rationale, `measurement.json` reuse, head-bit-width option, MoE calibration warning, calibration-perplexity sanity thresholds, conversion hardware requirements (~64 GB RAM / 24 GB VRAM for 70B; ~16 GB / 8 GB for 7B).
4. ExLlamaV2 `doc/qcache_eval.md` — Q4 vs. FP8 vs. FP16 cache perplexity (The Pile) and HumanEval results, Hadamard-rotation note, long-context summarisation comparison.
5. ExLlama (V1) README, via raw.githubusercontent.com/turboderp/exllama — V1 self-description (4-bit GPTQ, Llama, RTX 4090 / 3090 Ti development hardware), 2023-08-12 preliminary ExLlamaV2 release note.
6. Archived ExLlamaV2 README snapshot, 2023-09-15 (Internet Archive capture of the GitHub repo) — early V1-vs-V2 differences (faster kernels, cleaner codebase, EXL2), early comparative performance table, preliminary ROCm note (2023-09-13).
7. GitHub repository metadata for turboderp-org/exllamav2 (accessed via the GitHub repo page) — MIT licence, creation 2023-08-30, commit/release counts.
8. PyPI package page for `exllamav2` — MIT licence, maintainer, release history (0.3.2 wheel dated 2025-07-13; 0.2.x line through 2025).
9. Frantar, Ashkboos, Hoefler & Alistarh, "GPTQ: Accurate Post-Training Quantization for Generative Pre-trained Transformers", arXiv:2210.17323 (submitted 2022-10-31; ICLR 2023) — GPTQ method, second-order error compensation, 3–4 bit results at 175B scale.

**Secondary (corroboration / context / attributed numbers)**

10. TabbyAPI README (theroyallab/tabbyAPI) and SillyTavern documentation (API connections; TabbyAPI page) — TabbyAPI's role, self-description as a small-user hobby server, SillyTavern integration, "no CPU offloading / not recommended for low VRAM" warning.
11. text-generation-webui parameter documentation (via GitHub wiki mirror) — ExLlama v1/v2 seed-determinism caveat; loader context.
12. quantized.uk, "LLM benchmarks: measured tok/s and VRAM" — batch-1 measured runs incl. Llama 3.1 8B EXL2 4.65 bpw at 235 t/s (RTX 4090) / 175 t/s (RTX 3090), 5.4 GB VRAM; methodology as stated on the page.
13. insiderllm.com, "ExLlamaV2 vs llama.cpp Speed" (updated 2026-11-04) — aggregated community comparisons (13B on RTX 3090; 8B prompt processing on RTX 4090); used only as directional, secondary evidence.
14. Format-comparison surveys (local-llm.net GGUF/GPTQ/AWQ/EXL2 comparison, April 2026; MarkTechPost format explainer, 2026; Aquanode EXL2 glossary entry) — EXL2 per-layer/column-level allocation summaries, GGUF K-quant contrast, EXL2 tensor-normalisation lock-in note.
15. RunLocalAI tool review of ExLlamaV2 (verified 2026-11-08) and the ExLlamaV3/TabbyAPI survey on dev.to (November 2026) — archival/successor status, single-stream design-goal characterisation, TabbyAPI backend-migration reporting (flagged in-text as not independently re-verified).

**Unverifiable / unresolved items (declared):**
- The exhaustive `ExLlamaV2Sampler.Settings` field list for the final 0.3.x release (docs demonstrate a subset; code not audited line-by-line).
- The precise status and quality of ROCm support across V2's life (primary traces are preliminary/experimental; secondary sources conflict between "exists" and "effectively CUDA-only" — §8 states the assessment and its basis).
- The README's "minimises the maximum error" vs. the convert doc's "minimises the product of errors" formulations of the EXL2 solver objective (§3.3) — both are the project's own words in different documents; the dossier reports both rather than resolving them.
- TabbyAPI's current (2026-11-15) backend defaults with respect to ExLlamaV2 vs. ExLlamaV3, beyond secondary reporting.

*End of dossier OR-2. Clean-room note: this dossier was written from public sources listed above, in the author's own words; no source text is reproduced beyond short factual labels (names, version numbers, parameter names, and benchmark figures with attribution), and no code is included.*
