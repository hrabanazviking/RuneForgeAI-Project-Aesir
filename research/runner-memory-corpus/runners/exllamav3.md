# OR-2 (successor volume) — ExLlamaV3: The Trellis Generation

**Dossier:** OR-2 successor volume, Ollama Research Forge
**Subject:** ExLlamaV3 (turboderp-org)
**Predecessor dossier:** `exllamav2.md` (OR-2, banked 2026-11-15) — this volume is its direct successor and should be read against it. Where this dossier says "V2 did X", X is as recorded in that dossier unless a newer primary source is cited here.
**Licence:** MIT — verified 2026-11-15 from the GitHub repository metadata for `turboderp-org/exllamav3`, consistent with the predecessor volume and with secondary reporting of the GitHub API licence field. The QTIP reference implementation upstream is a separate project with its own licence (reported as GPLv3 by secondary sources); EXL3 as shipped in ExLlamaV3 is the author's own streamlined reimplementation under MIT. *[The QTIP upstream licence point is secondary-sourced; see §10 unverified list.]*
**Languages / implementation:** Python (orchestration, model loading, generator, sampler, conversion tooling) with a PyTorch C++ extension (`exllamav3_ext`, C++ / CUDA) plus a substantial body of Triton kernels (attention, cache and recurrent/linear-attention kernels are Triton, per the install notes in the README). Distributed as prebuilt wheels matched to Python + CUDA + PyTorch, as a PyPI package that JIT-compiles the extension on first import, and as source installable via `uv` with CUDA-flavour extras (`cu124`–`cu132`).
**Primary links:**
- Repository: https://github.com/turboderp-org/exllamav3 — created 2025-04-06 (per the campaign field-map sweep #3, banked 2026-11-15).
- Predecessor: https://github.com/turboderp-org/exllamav2 — its README now opens with the notice that the project is archived for now and development continues on ExLlamaV3 (not a GitHub public-archive flag).
- Recommended server: TabbyAPI — https://github.com/theroyallab/tabbyAPI/
- Format ancestor: QTIP, Cornell RelaxML — https://github.com/Cornell-RelaxML/qtip ; paper arXiv:2406.11235 (NeurIPS 2024 spotlight).

**As of:** 2026-11-15. All web sources accessed 2026-11-15 unless otherwise dated in §10.

**Version stamp — what was actually read.** The README, `doc/convert.md` and `doc/env_vars.md` were read from the `master` branch on 2026-11-15. The latest release that could be verified is **v1.6.6, dated 31 October 2026**, reported consistently by two independent secondary trackers (a release survey that cites the GitHub API, and a benchmark-site changelog that still listed 1.6.6 as current on 2026-11-13) and by the PyPI line (1.6.5 page read; 1.6.x series through October 2026). The GitHub release notes for v1.5.0 (2026-09-13) and the v1.6.5 note (2026-10-25) were read directly. Caution: the README's own wheel-install example still points at a v0.0.6 wheel — a stale example string, not the current version; the `pyproject.toml` version field was reported by one secondary source as a placeholder (0.0.1), so the release tags, not the package metadata, are the version authority. The 0.x → 1.0.0 → 1.6.x arc matters: v1.0.0 (reported July 2026) is described in release coverage as the first production release, removing the external FlashAttention-2 and xformers dependencies in favour of built-in kernels.

**Essence.** ExLlamaV3 keeps ExLlamaV2's founding refusal — no compromise of single-user, low-latency, quantization-native inference on consumer NVIDIA hardware — and rebuilds almost everything underneath it. The quantization format changes its mathematics entirely: EXL2's GPTQ-derived scalar rounding with a measured per-layer bit allocation is replaced by EXL3, a streamlined variant of QTIP in which weights are first rotated into an approximately Gaussian basis by Hadamard incoherence processing and then encoded as paths through a trellis, so that quality at 2 bits per weight and below — the regime where EXL2 degraded fastest — becomes the format's home ground. Around that new centre, three of V2's hard walls are deliberately breached: tensor parallelism and expert parallelism replace V2's layer-split-only multi-GPU story; CPU offloading of MoE experts (with AVX2/AVX-512 CPU kernels) breaks V2's VRAM-or-nothing rule for mixture-of-experts models specifically; and the KV cache widens from V2's FP16/8-bit/Q4 menu to a continuous 2–8 bit quantized, paged cache. What did not change is just as diagnostic: still a Python library, not a server; still TabbyAPI as the recommended front door; still CUDA-first with everything else experimental; still no dense-model CPU offload; still a hobby-scale, small-user serving story. V3 is best read as V2's design centre held constant while its format, its parallelism, and its escape valves were all renegotiated.

---

## 1. V2 → V3 at a glance: kept, changed, dropped

This table is the successor volume's contract with the predecessor dossier. Each row is expanded in the section noted.

| Dimension | Verdict | Summary (§) |
|---|---|---|
| Single-user, low-latency, consumer-GPU design centre | **Kept** | Same brief, same TabbyAPI pairing, same "hobby project for a small number of users" server disclaimer (§2, §7) |
| Batch-1-first decode priority | **Kept, with a widened second front** | Decode still leads (release tables report decode at S=1), but prefill, MoE throughput and multi-GPU work now receive first-class kernel investment V2 never made (§6) |
| Continuous average bit-rate (target bpw as a float) | **Kept** | `-b` is still a float; fractional artefacts (3.75 bpw, 3.05 bpw, 2.05 bpw) are the norm in release notes (§3) |
| Quantization mathematics | **Changed fundamentally** | GPTQ-style scalar rounding → QTIP trellis-coded quantization with incoherence processing and LDLQ error feedback (§3) |
| Usable bit-rate floor | **Changed** | V2's practical floor was ~2.5 bpw; V3 publishes coherent 1.6 bpw-class artefacts and 2.05 bpw release-tested MoE quants (§3, §6) |
| Calibration/conversion shape | **Changed** | V2's two-pass measure-then-solve converter → V3's single-step converter: Hessians computed on the fly, fused Viterbi trellis encoding, resumable checkpoints; 250 × 2,048 calibration defaults (§3) |
| Per-layer bit allocation | **Kept in spirit, mechanised differently** | Budgeted allocation survives, joined by explicit per-tensor YAML recipes, an `-hq` promotion for attention/shared-expert layers, and per-expert MoE Hessians (§3) |
| Within-layer column mixing (EXL2's sparse-style trick) | **Dropped as a mechanism** | Superseded: trellis coding mixes information *across* weights by construction, so the act-order column trick has no analogue and none is needed (§3) |
| GPTQ checkpoint compatibility | **Dropped (unverified edge)** | Neither V3's nor TabbyAPI's current docs list GPTQ or EXL2 as loadable; TabbyAPI's current line is EXL3 + FP16/BF16 only (§8, §10) |
| EXL2 checkpoint compatibility | **Not documented — treat as dropped** | Third-party posts claim EXL2 loads; no primary source read confirms it (§10) |
| KV cache | **Changed and widened** | FP16 / 8-bit / Q4 menu → 2–8 bit quantized cache, still paged, with staged-dequantization prefill paths and online cache quantization in the built-in attention kernel (§4) |
| Paged attention substrate | **Changed** | V2 stood on Flash Attention 2.5.7+ paged attention; v1.0.0 removed the FA2/xformers dependencies — attention, cache and recurrent kernels are now built-in (Triton + CUDA), FA2 demoted to an optional A/B backend (§4) |
| Dynamic/continuous batching, speculative decoding | **Kept** | Both are headline README features again; speculative decoding is substantially expanded (draft models, MTP heads, n-gram drafting, hybrid drafting) (§4) |
| Prefix / prompt caching | **Kept, less documented** | A v1.6.5 release note fixes a tokenizer regression "causing prompt caching to fail sometimes" — proof the machinery lives in V3 — but no V3 equivalent of V2's `doc/dynamic.md` deduplication exposition was found (§4, §10) |
| Multi-GPU | **Changed fundamentally** | Layer split (`gpu_split`/autosplit) only → flexible tensor parallelism (native PCIe backend or NCCL/NVLink backend, POSIX shared-memory transport) plus expert parallelism, alongside retained layer split (§5) |
| CPU offload | **Changed — the wall is breached for MoE only** | V2: none. V3: routed MoE experts can run on CPU from system RAM (AVX2/AVX-512), hot experts stream to GPU at prefill; dense models still must fit in VRAM (§5) |
| Model architecture breadth | **Changed** | Far wider registry (90+ HF architectures per secondary index), including multimodal, hybrid linear-attention (GDN/KDA), MLA and MTP models that did not exist in V2's world (§4) |
| ROCm | **Changed: from traces to preliminary** | v1.6.0 added preliminary ROCm (ROCm 10, gfx1100+ per release coverage); env-var doc now carries first-class CUDA/ROCm default differences. Still not an equal path (§8) |
| LoRA | **Unclear** | An older README snapshot listed LoRA under "What's missing?"; secondary summaries now list LoRA adapters as supported. Not verified in the current README read (§10) |
| Tensor naming / portability | **Improved (secondary-sourced)** | EXL3 reportedly retains more of the original HF tensor structure than EXL2's Llama-normalised layout (§3, §10) |

---

## 2. Lineage & design intent: what the rewrite was for

### 2.1 The handover

The V2 repository was created 2023-08-30; the V3 repository was created 2025-04-06 — roughly nineteen months later, while V2 was still shipping (its last PyPI line, 0.3.x, ran into mid-2025 per the predecessor dossier). V3 therefore began as a parallel development line, not an emergency replacement, and the archival notice on V2's README ("archived for now; development continues on ExLlamaV3") marks the moment the parallel line became the line. The version arc visible in releases — a long 0.0.x development series, v1.0.0 as the self-described production release (July 2026 in release coverage), then rapid 1.4–1.6 series through October 2026 with 70+ tracked releases — is the profile of a ground-up rewrite that took over a year to reach parity-plus, then accelerated.

### 2.2 Why a new format forced a new engine

The predecessor dossier's central finding about V2 was that format and kernel were one design: EXL2's mixed scalar bit-widths were only free because the act-order remapping already reordered columns inside the GEMV kernel. EXL3 breaks that coupling deliberately. A trellis-coded weight is not a packed scalar with a scale; it is an index path whose decoded values are produced procedurally from trellis state (§3). Every part of V2 that touched weights — converter, loader layout, GEMV/GEMM kernels, the int8 path, MoE expert handling, CPU offload eligibility (which requires a specific codebook, §5) — had to be rebuilt around that representation. That, more than any feature list, explains why this is ExLlamaV3 and not ExLlamaV2 0.4. *[Interpretation, marked as such: the docs present EXL3 as the headline change and the rewrite as its vehicle; the causal framing is this dossier's.]*

### 2.3 The design centre: held, with two honest widenings

**Held.** The README's first line still defines the product as an inference library for running local LLMs on modern consumer GPUs. TabbyAPI is still "the official and recommended backend server", and TabbyAPI still disclaims production use in the same terms the predecessor dossier recorded for the V2 pairing. The release-note benchmark tables still lead with decode at sequence batch S=1 alongside 4k prefill — the single-stream number is still the number the project chooses to be judged by.

**Widening 1 — parallelism as a consumer feature.** V2's multi-GPU story was a memory trick: split one model across cards so it fits. V3's README advertises "flexible tensor-parallel and expert-parallel inference for consumer hardware setups" as a headline feature, with a backend choice documented in the TabbyAPI layer (native transport recommended for PCIe, NCCL for NVLink) and POSIX shared memory as the tensor-parallel transport. On two- and four-card consumer rigs — exactly the hardware the local community actually accumulated during the V2 years — tensor parallelism converts spare cards into *speed*, not just capacity. That is a genuine shift in what multi-GPU is *for*.

**Widening 2 — the MoE exception to VRAM-or-nothing.** The era's defining models became sparse: hundreds of routed experts, a handful active per token. For such models the all-weights-in-VRAM rule wastes the card on experts that fire rarely. V3's CPU expert offload (§5) is scoped precisely to that shape and to nothing else — dense models keep V2's rule. The design centre bent where the workload's mathematics said it should, and nowhere else. That selectivity is itself the continuity: this is still an engine that refuses generality it cannot make fast.

### 2.4 What V3 declined to become

No first-party server product (TabbyAPI remains a separate project). No production multi-tenancy story. No Vulkan or Metal line — one secondary analysis notes Vulkan is not merely unimplemented but absent from any roadmap it could find, while ROCm sits on the author's own list and has since landed in preliminary form. No GGUF support (TabbyAPI's world explicitly leaves GGUF to a sister llama.cpp-based project). The library-not-product layering of V2 is intact.

---

## 3. The EXL3 format

### 3.1 What EXL3 is, in one paragraph

EXL3 is a weight-only, post-training quantization format and method, native to ExLlamaV3, stored as safetensors in a Hugging Face-style model directory, in which each linear layer's weights are (a) transformed by randomized Hadamard incoherence processing so the matrix behaves statistically like i.i.d. Gaussian noise, (b) error-feedback quantized column-by-column under a Hessian-aware LDLQ decomposition inherited from the QuIP lineage, and (c) encoded not as independent scalar codes but as a *trellis path*: a stateful sequence in which each step's bits both select a reconstruction value from a procedural codebook and determine the next state, found by a Viterbi search over the whole sequence. The user still supplies one number — a target average bits-per-weight, a float — and the converter still allocates that budget across layers; the per-layer rates are drawn from a 1–8 bit range (the README and conversion docs frame practical targets as 2–8, with sub-2 artefacts published). The headline result, stated by the project and corroborated by independent measurement (§6), is usable quality at average rates — 2.5, 2.0, even ~1.6 bpw on large models — where scalar formats, EXL2 included, fall apart.

### 3.2 The three mechanisms, and why each exists

**Incoherence processing (the rotation).** Outliers are the enemy of low-bit quantization: a few huge weights force the scale up and crush everything else. The QuIP-family answer, kept by QTIP and EXL3, is to multiply the weight matrix (and, inversely, the incoming activations at runtime) by randomized Hadamard transforms with random sign flips. A Hadamard transform is cheap (a butterfly of adds/subtracts, O(n log n), no stored matrix) and it smears any single large coordinate's energy across all coordinates, making the transformed matrix's entries closely approximate a Gaussian distribution. Quantizers are at their theoretical best on Gaussian sources — so instead of designing a quantizer for the weights you have, you rotate the weights into the distribution your quantizer is optimal for. At inference the rotation is not undone as a separate step: the runtime folds the input-side transform into the linear's prologue and the output-side inverse into its epilogue, and V3's current kernels go further, folding both Hadamard transforms into the weight-reconstruction kernel's epilogue on long prefill chunks so the standalone transform launches disappear entirely (documented in `doc/env_vars.md` as previously ~14% of long-chunk prefill GPU time).

**LDLQ error feedback (the rounding discipline).** As in GPTQ — EXL2's ancestor — quantization proceeds column by column, and each column's rounding error is pushed forward onto the not-yet-quantized columns, weighted by inverse-Hessian (activation second-moment) information gathered in calibration passes. EXL3 inherits this through QTIP's use of the QuIP# BlockLDLQ framework. The V3 converter computes Hessians on the fly during its single pass (README), supports per-tensor scaled Hessian factorisation by default, and — in its advanced options — two-sided LDLQ using precomputed output-side Hessians, with output-channel scales chosen so residual error lands in the channels the model's output depends on least. The GPTQ bloodline is therefore still present in V3, but demoted: it is now the error-accounting scaffold around the trellis encoder, not the encoder itself.

**Trellis-coded quantization (the encoding).** This is the break. Scalar quantization (GPTQ, EXL2, GGUF's block quantizers) rounds each weight, or each small group, independently: K bits buy at most 2^K reconstruction levels per weight, full stop. Vector quantization (QuIP#'s lattice codebooks, AQLM) buys better packing by coding small vectors jointly, but its cost grows exponentially in vector dimension, capping dimensions at single digits. Trellis-coded quantization, a 1980s channel-coding construction QTIP imported, codes a long *sequence* jointly at linear cost: the encoder walks a finite-state graph (the trellis; 2^L states for log-state-size L), and at each step the emitted bits choose among a subset (coset) of reconstruction values determined by the current state, while also moving the state. Because the decoder's effective alphabet is state-dependent, the code achieves distortion close to high-dimensional vector quantization while the search (Viterbi dynamic programming, keeping the cheapest path per state) and the decode both scale linearly in sequence length — QTIP quantizes blocks of weights as single sequences of dimension in the hundreds. EXL3's converter runs this search in a fused Viterbi kernel, over 16×16 weight tiles in the documented implementation structure.

**The bitshift trellis and procedural codebooks (why it is fast, not just good).** Naive trellis decoding would need a stored codebook lookup per step — memory traffic that would eat the bandwidth win quantization exists to create. QTIP's hardware move, which EXL3 adopts, is the *bitshift trellis*: the next state is obtained by shifting the emitted bits into the state register, so no state table is stored, and the reconstruction values themselves are *computed* from the state by a few integer instructions (the code families QTIP names 1MAD, 3INST and hybrid codes; EXL3's converter exposes codebook choices named `mul1` — the default, and required by the int8 GEMV and CPU-offload fast paths — `mcg`, and `3inst`). Decode thus trades a handful of register ALU ops per weight for zero codebook memory reads. On a bandwidth-bound decode step that trade is exactly right; §6 returns to its cost on the compute side.

### 3.3 EXL3 vs EXL2: the provisioning picture changes

The predecessor dossier showed EXL2's provisioning logic: the continuous bpw dial existed so a model could be shrunk until it fit VRAM, and its cost was quality that fell off steeply below ~3 bpw, because scalar rounding's distortion grows brutally as levels per weight drop to 8, 4, 2. EXL3 keeps the dial and changes what the dial *buys*:

| Dimension | EXL2 (per predecessor dossier) | EXL3 (this dossier) |
|---|---|---|
| User input | Target average bpw (float, 2–8) | Same: `-b` float; worked examples at 3.75 and 4.00 bpw; release-tested artefacts at 3.05, 2.05 bpw |
| Head / special layers | `lm_head` separately, default ~6 bpw mixed | Same pattern, generalised: `--head_bits` (int 1–8, default 6), plus separate integer rates for MTP layers (default 4), vision tower (default 6 or 16 by architecture), token embeddings (default 16 = unquantized, quantizable to 1–8, decodable from RAM or streamed from disk), and n-gram embedding tables |
| Per-layer allocation | Measured two-pass solve minimising worst-layer/product error | Budgeted allocation retained; additionally: full per-tensor YAML recipes (wildcard-matched, coverage-checked before calibration) from the self-calibration optimizer, and `-hq` promotion raising the floor of attention/shared-expert layers at a documented cost of ~0.05–0.10 bpw on MoE models |
| Calibration | 100 × 2,048 tokens default; separate ~12× measurement pass (16 × 2,048), reusable `measurement.json` | 250 × 2,048 tokens default; **no separate measurement pass** — Hessians computed on the fly in a single-step conversion; custom calibration accepted as packed token rows (safetensors) instead of the bundled corpus mix |
| MoE calibration | Docs warned thin expert coverage was uncharted | Per-expert Hessians are a first-class option (`--moe_affinity_eps`, typical 0.01): each expert is calibrated on the inputs its router actually sends it, with an epsilon floor keeping the global distribution in play |
| Conversion cost | Documented up to ~64 GB RAM / 24 GB VRAM for 70B; multi-hour class | README: a couple of minutes for smaller models to a few hours for 70B+ on a single high-end consumer GPU; conversion is checkpointed (120 s default interval) and *explicitly* resumable (`-r`) — the convert doc notes this reverses V2's implicit-resume behaviour; trellis encoding parallelises across multiple GPUs (`-d`, autotuned ratios), which V2's converter did not offer |
| Quality floor | Author demo: 70B at 2.55 bpw, coherent at 2k context | Project claim (README, via secondary quotation): 70B coherent at ~1.6 bpw with the head at 3 bpw, fitting under 16 GB with a 4k cache; independent perplexity data (§6) shows 3.0 bpw EXL3 matching a ~4.86 bpw GGUF K-quant on the same 30B MoE model |
| Failure shape at the floor | Scalar distortion: perplexity climbs, then incoherence | Trellis distortion grows more gracefully — the format's published KLD curve (README's own Llama 3.1 8B chart) is the project's chosen self-portrait — but see the embedding caveat in §3.4 |

The provisioning consequence for a capacity planner is the single most important practical difference between the volumes: **under EXL2, bpw was a fit dial with a quality cliff near the bottom; under EXL3, the bottom of the dial moved down by roughly a bit per weight at equal quality.** A model class that needed ~3.5–4 bpw to be trustworthy under scalar allocation is a ~2.5–3 bpw artefact under EXL3, which is a 25–35% VRAM saving on weights at the same quality — or, read the other way, the next model size up becomes single-card feasible. Any capacity table written for the fork from EXL2-era numbers is now pessimistic by about that margin, *provided* the model is run through a trellis-class quantizer (§9).

### 3.4 The fine print the headline hides

- **Embeddings are outside the bpw headline.** Independent EXL3-vs-GGUF measurement (Gemma-4 12B, §6) found the EXL3 4.00 bpw artefact's *quantized weights* notably smaller and closer to BF16 than GGUF Q4_K_M — but once its high-precision (default 16-bit) embedding table was included, total file size was nearly identical to a GGUF Q5_K_M. The converter's `--embed_bits` option (with GPU decode, RAM residency or disk streaming of the table) exists precisely to close this gap, but the default provisioning number a user downloads is *weights bpw + a full-precision embedding table*. Provision on total file/VRAM, never on the bpw label alone.
- **Codebook choice is a capability switch, not a quality knob.** Only the default `mul1` codebook qualifies a model for the fused int8 GEMV path and for CPU expert offload; the convert doc states there is no reason to pick another codebook except testing. Artefacts converted with `mcg`/`3inst` silently forfeit fast paths.
- **HF structure retention.** A secondary format survey reports EXL3 retains more of the original Hugging Face tensor structure than EXL2, whose Llama-normalised internal renaming made artefacts hard to reuse elsewhere. If true, EXL3 artefacts are less of a dead end than EXL2's were. *[Secondary-sourced; not verified against the format spec in this pass — §10.]*
- **An in-repo format writeup exists.** Secondary analysis references an `exl3.md` format document shipped with the repo. It was not retrieved in this pass; the format internals above rest on the QTIP paper, the convert doc, and the env-vars doc. *[§10.]*

### 3.5 QTIP lineage, stated precisely

QTIP (Tseng, Sun, Hou & De Sa, Cornell RelaxML; arXiv:2406.11235; NeurIPS 2024 spotlight) introduced trellis-coded quantization to LLM weight compression: incoherence processing from QuIP# (random Hadamard transform), BlockLDLQ error feedback from the QuIP line, and the bitshift trellis with compute-based codes to make TCQ decode at GEMV speed. Its paper's claim — that TCQ's linear cost lets it quantize at effective dimensions above 100 where vector quantization stalls below 10, closing most of the gap to an optimal 2-bit quantizer — is the theoretical basis for EXL3's low-rate quality. EXL3 is described by its own README as a *streamlined variant* of QTIP: the streamlining, as far as public docs establish it, consists of the single-codebook-family design centred on `mul1`, the fused Viterbi conversion kernel, on-the-fly Hessians, and kernel layouts co-designed with ExLlamaV3's GEMM/GEMV and tensor-core tiling (16×16 tiles, Marlin-influenced per secondary analysis) rather than with a research codebase. The QTIP reference repo's licence does not govern EXL3; ExLlamaV3 is MIT (§ header).

---

## 4. Architecture

### 4.1 Shape of the system

The layering is V2's, kept: a library, not a server.

1. **Extension + kernels** (`exllamav3_ext` C++/CUDA, plus Triton kernels): EXL3 GEMM/GEMV family, MoE kernels, attention, cache operations, sampling. The v1.0.0 removal of the FlashAttention-2 and xformers dependencies means the attention/cache/recurrent kernel set is now the project's own — a structural change from V2, whose paged path stood on an external Flash Attention version (§4.4).
2. **Python model layer**: architecture registry (the README's support table lists roughly sixty model families, many multimodal), config, safetensors loading with autosplit measuring, tokenizer, cache classes, tensor-parallel runtime.
3. **Generator**: continuous/dynamic batching over a paged cache, speculative decoding, multimodal inputs — the README's generation line reads "Continuous, dynamic batching, speculative decoding, multimodal support", i.e. V2's dynamic-generator feature set carried forward as the baseline, not the headline.
4. **Servers/UIs remain other projects**: TabbyAPI (recommended, OpenAI-compatible), plus a Hugging Face Transformers integration example shipped in-repo — a small but real widening of V2's integration surface.

Architecture breadth deserves one precise note: the registry now spans hybrid and non-classic designs that postdate V2 — gated-delta-net / linear-attention layers (Qwen3-Next/3.5, Kimi Linear, GLM KDA), MLA compressed-attention models (DeepSeek V3/V4 class), multi-token-prediction heads, per-layer-embedding (n-gram table) models, and recurrent/state-space hybrids (Nemotron-H). The env-vars document is dominated by these families' kernels (GDN, MLA, DSA sparse attention, hyper-connections). V2's world was decoder-transformer-shaped; V3's engine core has become a small zoo of layer types sharing one cache and generator. That breadth is the main *architectural* (as opposed to format) difference between the volumes.

### 4.2 Scheduling and batching model

**What is verified.** Continuous (dynamic) batching is a headline feature, implemented over the paged cache exactly in V2's lineage: the env-vars doc's graphed decode path patches "input/output/position/block-table pointers" per replay, which only makes sense against a block-table (paged) cache organisation, and TabbyAPI's documentation describes parallel batching via paged attention requiring Ampere or newer. Jobs carry a *job slot* identity in the graphed-path design (graphs are built per cache layer, job slot and shape), indicating the generator still thinks in discrete concurrent jobs sharing one cache pool, as V2's did.

**Speculative decoding is where the scheduling investment went.** Where V2 listed speculative decoding as a retained feature, V3's release history shows a drafting ecosystem: separate draft models; MTP (multi-token-prediction) heads as drafters; recurrent draft models (GDN/KDA/Mamba-class, with reduced flat VRAM overhead for their state in v1.6.1); a hybrid drafting mode combining a draft model with a long n-gram lookup (v1.6.1); DFlash2 drafters under tensor parallelism (v1.6.2); and improved speculative decoding for MoE models (v1.5.0). The graphed decode paths are explicitly built for q_len up to 16 — i.e. whole draft-verification blocks execute as single captured graphs. For the fork's purposes: V3 treats "propose several tokens cheaply, verify in one pass" as a primary decode accelerator alongside raw GEMV speed, which is a scheduling-level admission that at EXL3's low bit-rates the bottleneck is shifting from bytes-read toward per-step fixed costs (§6).

**What is not verified.** No V3 document equivalent to V2's `doc/dynamic.md` was found in this pass: page size (V2: 256 tokens), defragmentation policy, job-queue admission rules, and per-job sampler object shape are **unverified for V3** (§10). TabbyAPI's config exposes `cache_size` in tokens (sample configs use multiples of 256, consistent with — but not proof of — V2's page size surviving).

### 4.3 KV cache design

Four facts are primary-verified, and together they describe a cache that widened on every axis V2 had:

1. **Range: 2–8 bit quantization.** The README's quantization line pairs EXL3 with "2–8 bit cache quantization" — V2's menu was FP16 / 8-bit / Q4 (with Q3/Q6 merely planned in its docs). V3 makes cache precision a near-continuous dial in the same spirit as weight bpw, configurable per K and V in the server layer (TabbyAPI `cache_mode` values such as Q8 or split "8,8"-style settings appear in community configs; the engine-level per-tensor split is **partially verified**, §10). Independent measurement on a 27B model found 8-bit cache effectively free in KL terms (<0.00012 shift) while 4-bit cache carried a real, weight-rate-dependent cost in EXL3 (+0.0002 at 2–2.5 bpw rising to ~+0.0033 at 6–8 bpw) — a subtler interaction than V2's qcache eval reported, and a warning against assuming cache and weight quantization errors simply add.
2. **Paged organisation retained.** Block tables, per-sequence page windows, and a fixed staging window denominated in pages (default 256 pages = 64k tokens per sequence in the staging path) are all documented in the env-vars doc.
3. **Staged dequantization for prefill.** Quantized caches feed attention three ways, switchable at runtime: direct (kernels dequantize fused into their loads; lowest memory; prefill pays ~5–25% on the attention kernel because each KV tile is re-expanded per query block), staged (default: prefill chunks ≥256 tokens dequantize the referenced window once into a shared FP16 scratch, bringing quantized-cache prefill within ~1–3% of FP16; decode always reads packed directly), and full staging (legacy debug path). This is a more sophisticated answer to the quantized-cache attention tax than anything in V2's docs, and it is directly stealable (§9).
4. **Online cache quantization in the attention kernel.** The v1.0.0-era attention kernel is described in release coverage as supporting online cache quantization (quantize-on-append inside the attention path) plus dual input for sliding-window layers and attention sinks. The graphed decode path fuses the whole block — projections, head norm + RoPE, *cache append*, flash-decoding attention, output projection — into one captured CUDA graph, so cache writes are part of the per-token graph, not a separate pass.

**Recurrent-state caches.** Hybrid models add a second cache species V2 never had: GDN/KDA/Mamba layers carry recurrent state rather than KV, and the release notes track VRAM overhead reductions for exactly that state in drafting configurations. A fork targeting modern hybrid architectures must budget state caches separately from KV pages. *[Design note, marked as inference from release-note evidence.]*

### 4.4 Attention

V2: Flash Attention as kernel and as paging substrate, version-pinned (2.5.7+). V3: built-in Triton paged prefill and flash-decoding kernels are the default dispatch; FlashAttention-2 survives only as an optional dependency behind a preference switch whose doc states the built-in kernels "match or beat FA2 across supported hardware and cover more cases (quantized caches, head dims > 256, attention sinks)". Turing (sm_75) gets special paths (an SDPA-based prefill route and a dedicated PTX kernel for 256-wide heads) because Triton emits no tensor-core instructions there — evidence the project still spends effort on older consumer cards, as V2 did. MLA layers get their own prefill strategy choice (up-projected MHA form at ~2.8× fewer FLOPs per query–past pair vs. absorbed form). Attention is no longer a dependency; it is a subsystem. The portability cost is the mirror image: the paged/quantized cache features now live or die with the project's own kernel maintenance, and the ROCm defaults in the env-vars doc already diverge per-kernel (§8).

### 4.5 Session and prefix handling — the fork's core interest, answered carefully

What can be stated from primary or release sources:

- **Prompt caching exists in V3.** The v1.6.5 release note (2026-10-25) fixes "a tokenizer regression from 1.6.4 causing prompt caching to fail sometimes" — a bug of that shape is only possible if token-level prompt caching is a live, exercised feature of the current line.
- **The paged substrate that makes prefix sharing cheap is present** (§4.2–4.3): block tables and job slots are the same primitives V2's deduplication was built on.
- **TabbyAPI exposes cache provisioning, not cache policy**: `cache_size` (tokens, default 4,096 in the sample config — a notorious trap for agent workloads, since effective context defaults to the cache size) and `cache_mode` are the user-facing knobs found.

What **cannot** be verified from the sources read (§10): whether V3 retains V2's specific machinery in the same form — page-level deduplication across *concurrent* jobs (many questions over one shared document), retention of recently finished jobs' pages for cross-turn reuse, and any explicit session object in the generator API. No V3 dynamic-generator document was located, and the README does not mention deduplication or prefix sharing. The honest summary for the fork: **prefix reuse: present (release-note grade). V2-style cross-job page deduplication: unverified — do not assume parity; this is the single largest documentation regression relative to V2**, whose `doc/dynamic.md` specified its cache-sharing semantics in unusual detail. A follow-up pass should read the V3 generator/cache source structure (public, MIT) at the architecture level to close this gap before any fork design leans on it.

### 4.6 Sampler surface

Partially verified from the env-vars doc: V3's sampler collapses eligible stacks into fused kernels at construction — stacks ending in greedy or temperature/min-P/top-K/top-P/Gumbel steps, optionally preceded by repetition/presence/frequency penalties, run as a few logit-space kernels instead of a sort-based pipeline, with documented tie-breaking and seed-equivalence semantics versus the reference path. That is a materially more engineered sampler than V2's settings object as the predecessor dossier could verify it, and the seed-semantics documentation is a direct answer to the determinism caveat the V2 dossier recorded from front-end docs. The full per-job settings surface remains **unverified** at the same level as V2's (§10) — the docs still demonstrate a subset; the code remains the authority.

---

## 5. Memory management

### 5.1 The provisioning equation, V3 form

Steady-state VRAM = EXL3 weights (at target bpw, **plus** head at its own rate, **plus** embeddings at theirs — §3.4) + paged KV/state cache (tokens × per-token bytes at the chosen 2–8 bit cache mode) + fixed overheads the project has been actively shrinking (v1.6.1/1.6.2: reduced flat overhead for recurrent drafting and for GDN/KDA/MLA layers) + the FP16 staging scratch for quantized-cache prefill (a fixed, load-time-budgeted allocation: pages × page size × KV heads × head dim × 2 tensors, counted by the autosplit measuring pass). Weights and cache remain distinct allocations with distinct knobs, as in V2; what changed is that both are now dials with useful range below the points where V2's versions stopped working.

### 5.2 Multi-GPU: from split to parallel

Three distinct modes now exist where V2 had one:

1. **Layer split (kept).** `gpu_split` / autosplit distributes layers across cards' VRAM pools; the TabbyAPI layer documents an autosplit reserve (~96 MB per GPU in one secondary reading; 1–3 GB in a practitioner's config for desktop-shared cards). This remains the mode CPU MoE offload requires.
2. **Tensor parallelism (new).** Weights of individual layers are sharded across ranks and partial results combined per layer, over a native POSIX shared-memory transport (recommended for PCIe) or NCCL (recommended for NVLink). Env-var evidence shows the graphed fast paths *decline* under TP for some module types (the single-graph attention block falls back to regular dispatch under TP) — TP buys capacity/speed at the price of some decode-path fusion. Tensor parallelism was extended to most models, including Gemma 4, by v1.0.0 per release coverage.
3. **Expert parallelism (new).** MoE experts are distributed across devices — the natural complement to CPU offload: hot experts on GPUs, spread by device; cold experts on CPU (§5.3). Shared experts get special placement (whole on one rank under TP, entering the all-reduce from that rank only, per the env-vars doc).

### 5.3 CPU offload: the MoE-only breach of the VRAM wall

Mechanics, from the env-vars doc (the fullest primary source): the `-mcl`/`--moe_cpu_offload` setting runs the routed experts of the first N block-sparse MoE layers on CPU, weights resident in system RAM. Constraints: layer-split mode only (not TP); `mul1`-codebook experts only; K ≤ 8 routed experts; uniform per-expert biases. A spawned worker process per model component (main / draft / MTP) owns its expert weights and a job ring in pinned shared memory; the parent's forward pass never blocks on the CPU. During prefill, hot experts additionally *stream* their weights to the GPU and run there while the CPU works the remaining tail, with the streaming threshold autotuned against measured pinned→device bandwidth (a chipset x4 link demands a much hotter expert than a CPU-direct x16 link). CPU kernels use AVX2 and AVX-512. v1.5.0 added an experimental zero-copy pinned-arena mode (Linux only) and measured, for a 125B-class MoE at 80% CPU offload, decode in the ~60 t/s range on high-end consumer cards with a Threadripper host — and roughly 10 t/s on an 8-core AVX2 host for a dense-ish MoE case, which honestly bounds the trick: the CPU tail is only as fast as the CPU.

TabbyAPI exposes two granularities: whole layers on CPU, or a split-experts count (keep the N coldest experts per layer in RAM, hot experts in VRAM, placement adjusted while running — per practitioner reporting, secondary-sourced). Embeddings join the offload story separately: a quantized embedding table can live in system RAM or stream from disk.

**What is still not supported:** CPU offload of dense weights. Every secondary source read agrees, and nothing in the primary docs contradicts it: a dense model larger than aggregate VRAM at its lowest acceptable bpw does not run. V2's rule survives for the dense case — but the models the community most wants to oversize are now MoE, and for those the rule is gone.

### 5.4 System RAM and disk

System RAM graduates from V2's conversion-and-staging role to a steady-state inference tier (CPU experts, RAM-resident embeddings, pinned staging rings), and disk becomes a third tier for embedding/n-gram tables (streamed). The practical floor for the flagship MoE-offload use case in practitioner reports is ~40–64 GB RAM. Conversion working directory still needs room for a full copy of the output model, and conversion checkpoints live there too.

---

## 6. Kernels: where the speed lives now

### 6.1 The workload shape, revisited

V2's kernel logic was one sentence: batch-1 decode is bandwidth-bound, so bytes-per-token is destiny. V3 keeps that sentence and adds a corollary forced by its own format: **at 2 bpw, bytes-per-token halves again — and the trellis decode that produces the weights costs real ALU work per weight.** EXL3 decode is therefore a deliberate trade of compute (a few integer ops per weight, in registers, from the bitshift trellis) for bandwidth (half the bytes of a 4-bit scalar format). On Ada/Ampere tensor-core cards with bandwidth to spare relative to their integer throughput at these shapes, the project's own assessment (via secondary quotation of the README) is that the 4 bpw kernel sits at roughly memory-bound latency on sm_89, with Ampere "not yet at peak". The corollary for the fork: below ~3 bpw, kernel quality stops being only a bandwidth question and becomes a joint bandwidth×decode-compute question — a genuinely new kernel-design regime compared with EXL2 (§9).

### 6.2 The kernel families

- **EXL3 GEMV (small-m)**: QTIP-style fp16 GEMV dispatched by shape heuristic from the main GEMM entry; weight extraction by shuffle or shared-memory staging per bitrate.
- **Fused int8 GEMV (mul1 only)**: one cooperative launch covering input Hadamard, activation quantization, dp4a GEMV and output Hadamard, with an error-feedback residual mode giving ~15–16-bit effective activation precision at slight cost. This is the int8-activation path — note V3 quantizes *activations* on this path, something EXL2 never did (V2's format was strictly weight-only with floating-point activations).
- **Reconstruct-then-GEMM prefill (hgemm)**: long inputs reconstruct weights to the original basis (both Hadamards folded into the reconstruction kernel's epilogue, §3.2) and run a conventional GEMM on raw inputs; below ~1k rows the rotated-basis pipeline (input Hadamard → GEMM → output Hadamard) is kept. Prefill is engineered as its own regime with its own crossover points — more prefill investment than V2's docs ever showed.
- **Graphed decode blocks**: whole attention/MLA/GDN/DSA blocks captured as single CUDA graphs per shape, patched by pointer at replay, removing effectively all Python host time from the attention block; documented as worth a few percent at decode generally and most on host-bound setups (small models, fast GPUs, contended CPUs) — the same small-model fixed-cost wall the predecessor dossier inferred from V2's TinyLlama numbers, now attacked head-on and in writing.
- **MoE kernels**: fused expert kernels with row tiling, a ticket scheduler (v1.0.0 coverage), batched reconstruct tiers for streamed experts, and the CPU AVX2/AVX-512 expert path (§5.3).
- **Triton attention/cache/recurrent kernels** (§4.4), plus vendored Flash Linear Attention chunked prefill kernels for GDN-family layers.
- **Fused sampler kernels** (§4.6).

### 6.3 Reported numbers, with hardware context

All numbers are *reported*, not re-measured. Provenance is stated per row; treat the classes differently.

**Project release-note table (v1.5.0, primary; 4k prefill and decode at S=1, before → after the release):** dense 27B at 4.00 bpw — decode 54.6 t/s (RTX 4090), 78.6 t/s (RTX 5090), 48.7 t/s (3090 Ti), prefill up to 4,651 t/s (5090). gpt-oss-20b at 3.00 bpw — decode 242.7 t/s (4090), 303.3 t/s (RTX Pro 6000). MoE cases: Gemma4-26B-A3B at 3.10 bpw decoding ~182–202 t/s across 4090/5090/Pro 6000; GLM-class MoE at 2.05 bpw decoding ~94 t/s on Pro 6000. CPU-offload cases are tabulated in §5.3. The honest reading: at comparable bpw these decode figures sit in the same class as V2's author table (e.g. V2's 7B at 4.0 bpw, 211 t/s on a 4090) scaled by model size — **V3's win is not a decode-speed revolution at equal bpw; it is that the bpw can be much lower at equal quality, and prefill/MoE/parallel cases improved by double-digit percentages per release.**

**Independent measurement (Atomic Chat, RTX 5090, ExLlamaV3 1.4.9 + TabbyAPI vs llama.cpp, Gemma-4 12B, batch 1, 16k FP16 cache, no speculative/prefix help):** EXL3 processed a 2,048-token prompt up to ~2.5× faster than the GGUF stack, while llama.cpp *decoded* 15–21% faster in the two file-size-matched pairs. Quality: EXL3 4.00 bpw mean KLD 0.0248 at 5.79 GiB of quantized weights vs GGUF Q4_K_M's 0.0398 at 6.62 GiB (totals near-equal once embeddings counted, §3.4). Also recorded there: EXL3's current `mul1` codebook improved both KLD and decode throughput over the legacy `mcg` build at similar prefill. This is the most decision-relevant independent result found: **on current hardware, V3's stack leads on prefill and quality-per-weight-byte, and can trail llama.cpp on raw decode** — a materially different competitive picture from V2's era, when the predecessor dossier could record a consistent ~1.5× decode lead over GGUF on the same card.

**Community/HF-reported perplexity (via secondary analysis):** Qwen3-30B-A3B — EXL3 3.0 bpw at Wiki perplexity 9.18 (10.8 GB VRAM) vs the same model's Q4_K_M-class GGUF at ~4.86 bpw within 0.14 perplexity; EXL3 2.5 bpw degraded but coherent. Directionally consistent with the KLD result above.

**Unusable numbers, recorded as such:** several SEO-class pages publish round ExLlamaV3 speed tables (e.g. "8B at 180 t/s") with no methodology; this dossier does not cite them as evidence.

---

## 7. Ecosystem position

The fan-out shape is V2's, with the centre of gravity moved:

- **TabbyAPI** remains the official server and has completed its own migration: its ExLlamaV2 backend was removed on 2026-07-14 (per secondary reporting of its commit history), its current tree carries only the exllamav3 backend plus embeddings, and its sample config lists supported model types as EXL3 ("highly recommended") and FP16/BF16. It pins specific exllamav3 versions (1.6.2 in late-October practitioner reporting) and ships rolling `main` with no tagged releases of its own. Its licence is AGPL-3.0 (secondary-reported) — the server's copyleft does not touch the MIT engine, but a fork bundling TabbyAPI code would inherit it; the predecessor dossier did not record this and it matters for any reuse decision.
- **Hugging Face distribution**: the author publishes an EXL3 model collection (linked from the README) with one branch/revision per bitrate (e.g. a `4.0bpw` revision; MoE artefacts with compound revisions encoding expert bpw, head bits and n-gram bits). Community quantizers named in the current README's shout-outs (ArtusDev, MikeRoz, MetaphoricalCode, Ready.Art, isogen) succeed V2's LoneStriker/bartowski EXL2 ecosystem — the quantizer-publisher pattern survived the format change intact.
- **Transformers integration** ships as an in-repo example — a door V2 never opened.
- **ExUI** (V2's single-user UI by the author) has no V3 successor found in this pass; the chat example script in-repo is the author's own front end now. *[Absence noted, not proof of non-existence — §10.]*
- **text-generation-webui / SillyTavern**: SillyTavern still reaches this stack through TabbyAPI; oobabooga's V3 loader state was not verified in this pass (§10). The roleplay/chat demand side that the predecessor dossier identified as the stack's home market remains its home market, now joined by a visibly growing coding-agent clientele (multiple 2026 guides run TabbyAPI+EXL3 behind Cline/Continue/Aider-class clients, drawn by exactly the VRAM-efficiency and long-context-cache properties in §4–§5).

What is still absent: Ollama/LM Studio integration, a first-party server product, cloud serving deployments. The ecosystem remains a library with a fan-out — but the fan-out now includes agent tooling, which is a new centre of demand the fork should note.

---

## 8. Strengths / weaknesses

### Strengths (stated precisely)

1. **Quality per bit at low bit-rates, by a new mechanism.** Trellis coding + incoherence processing moves the usable floor from ~2.5 bpw (EXL2) to ~1.6–2 bpw on large models, with independent KLD/perplexity corroboration at 3–4 bpw (§3, §6). This is the strongest quality-per-VRAM-byte position available on consumer NVIDIA hardware in the sources read.
2. **The continuous dial survived the revolution.** Provisioning logic from V2 (dial bpw to fit) still works, now over a wider useful range and with finer special-layer controls (head/MTP/vision/embedding/n-gram rates, per-tensor recipes).
3. **Conversion got cheaper and more honest.** Single-step, on-the-fly Hessians, fused Viterbi, multi-GPU encoding, explicit checkpoint/resume, per-expert MoE calibration — every V2 converter pain point named in the predecessor dossier has a documented answer.
4. **A complete, widened memory story**: weights (EXL3 dial) + cache (2–8 bit, paged, staged prefill) + parallelism (split / TP / EP) + a scoped CPU tier for MoE experts and embeddings. Each budget is separately tunable, as in V2, but each now has more range.
5. **Prefill and host-overhead engineering.** Reconstruct-then-GEMM crossovers, graph-captured decode blocks, fused sampler — the project now attacks the fixed costs that dominate small-model and long-prompt experience, not just decode bandwidth.
6. **Architecture breadth** including hybrid/MLA/MTP/multimodal models, with per-family kernel work documented to an unusual depth (the env-vars doc runs to ~2,000 lines).
7. **MIT licence, active development** (weekly-class releases through October 2026), and a public format lineage (QTIP/QuIP# papers) that a clean-room implementer can study legally and completely.

### Weaknesses (stated precisely)

1. **Still effectively NVIDIA-first.** CUDA is the reference path; ROCm is preliminary (v1.6.0: ROCm 10, gfx1100+ per release coverage) with per-kernel default divergences and at least one documented deadlock workaround in the GEMM autotuner; no Metal/Vulkan/CPU-dense path exists. EXL3 artefacts are unreadable by other engines in practice — one secondary analysis notes the only route on AMD today is dequantizing back to FP16 in host RAM for a different engine. Format lock-in is *worse* than EXL2's in one respect: the trellis representation is further from every other format's layout.
2. **Dense VRAM wall stands.** No dense CPU offload (§5.3). The 6 GB-class and small-card segment still belongs to offload-capable engines for dense models.
3. **Decode leadership is no longer uncontested.** The best independent stack comparison found llama.cpp decoding 15–21% faster at matched file sizes on an RTX 5090, with V3 ahead on prefill (§6.3). V2's clean "fastest decode, full stop" claim cannot be repeated for V3 on current evidence.
4. **Documentation regressed where the fork most needs it.** V2 shipped a detailed dynamic-generator/cache-sharing document; no V3 equivalent was found, leaving cross-job prefix deduplication and session semantics unverified (§4.5) — for a project of this maturity, the generator's public contract is under-documented relative to its kernel surface (which is documented exhaustively).
5. **Operational sharp edges.** TabbyAPI's 4,096-token default cache silently caps context; codebook choice silently gates fast paths (§3.4); the README's install example still shows a 0.0.6 wheel against a 1.6.6 current release; version metadata is inconsistent across PyPI/pyproject/release tags. None are deep, all are user-facing.
6. **Toolchain weight, unchanged.** Python + PyTorch + CUDA-version-matched wheels or a JIT build with a full toolchain — the opposite of a single-binary runner, as in V2.
7. **Embedding-table accounting.** Default 16-bit embeddings mean headline bpw understates artefact size (§3.4); comparisons that ignore this mislead by up to a full quant tier on embedding-heavy models.
8. **Sampler/generator API surface still code-first.** As with V2, the exhaustive settings surface is not documented in prose (§4.6).

---

## 9. IDEAS TO STEAL for a Go 6 GB runner

*Framing as in the predecessor volume: the target is an improved Ollama-class runner in Go with a **6 GB** usable budget. "Gain"/"cost" are this dossier's engineering estimates — speculation, marked as such — not measurements. Design transfers only, re-implemented clean-room; the QTIP and QuIP# papers are the lawful study texts for the mathematics.*

### 9.1 Trellis-class quantization as the low-end quantizer (the headline steal)

**Steal:** A trellis-coded (or, as a stepping stone, lattice/vector-coded with incoherence rotation) quantizer for the sub-3.5 bpw tiers of the fork's format, replacing scalar block rounding there. Keep scalar K-quant-style tiers at ≥4 bpw where they are already good and cheap to decode; deploy trellis coding exactly where EXL3 proves it wins: 1.6–3 bpw. The non-negotiable companion piece is the Hadamard incoherence rotation — the evidence across QuIP#, QTIP and EXL3 is that rotation + error-feedback rounding carries most of the quality, with trellis memory adding the margin on top (one independent trellis-format study apportions most of its gain over a plain codebook to rotation and LDLQ-style feedback, and most of its margin over an already-trellis rival to the trellis itself).

**Expected gain (estimate):** At 6 GB, this is the difference between a 7–8B model at a degraded ~3 bpw scalar quant and the same model at a trustworthy ~2.5 bpw trellis quant *with gigabytes left for cache* — or a 13–14B-class model becoming a 6 GB artefact at all. Roughly one bit per weight of quality-equivalent compression versus scalar allocation (§3.3).

**Cost / risk:** The highest of any steal here. The decoder is compute-bearing (§6.1): on the small/older cards a 6 GB budget implies, trellis decode ALU could eat the bandwidth win — EXL3's own Ampere caveats are the warning. The encoder needs a Viterbi search (conversion-time cost, server-side if artefacts are pre-published). Gate it exactly as the predecessor dossier gated within-layer mixing: prototype the decode kernel on the target card class first; if decode t/s at 2.5 bpw trellis does not beat 3.5 bpw scalar on the *same* card, drop it and keep §9.2.

### 9.2 Rotation + error-feedback as a format upgrade even without the trellis

**Steal:** If §9.1 fails its gate, steal its substrate alone: add randomized-Hadamard incoherence processing and Hessian-weighted error-feedback rounding (LDLQ/GPTQ-class) to the fork's existing scalar quantizer, with the rotations folded into the linear kernel's prologue/epilogue as EXL3 folds them into reconstruction. This is a quantizer-side change with a modest kernel-side cost, and it is where most of the measured quality lives.

**Expected gain (estimate):** A substantial fraction of the sub-4 bpw quality gap at a fraction of §9.1's risk; also improves the *existing* tiers' low end.

**Cost / risk:** Calibration pipeline must produce Hessians per model (server-side, publishable as part of the artefact pipeline); runtime must apply inverse rotation to activations — a bandwidth-light butterfly, but a new kernel obligation on every backend the fork supports (the cross-platform law makes this a per-backend cost, unlike CUDA-only ExLlama).

### 9.3 Cache precision as a continuous 2–8 bit dial, with staged prefill

**Steal:** V3's cache settlement (§4.3) wholesale as policy: (a) cache bits as a dial, defaulting to 8, offering 4 for long context, with the measured interaction warning attached (4-bit cache costs more KL on high-bpw weights than on low-bpw ones — price it per model, don't global-default it); (b) the *staged prefill* pattern — dequantize the referenced cache window once into a bounded FP16 scratch for prefill, always read packed on decode — which caps the quantized-cache attention tax at ~1–3% for the price of one fixed scratch allocation that the loader budgets explicitly.

**Expected gain (estimate):** On 6 GB, an 8-bit default cache halves the FP16 cache tax (~0.5 GB at 8k context on a GQA 8B) for measured-zero quality cost; the staging pattern removes the standard objection to quantized caches (prefill slowdown) at fixed, known memory cost.

**Cost / risk:** Quantized-cache attention kernels per backend; the staging scratch must be in the loader's budget arithmetic from day one or it becomes an OOM surprise on exactly the small cards it serves.

### 9.4 Graph the decode block; fuse the sampler

**Steal:** V3's fixed-cost programme (§6.2): capture the whole per-token decode block (projections → norm/RoPE → cache append → attention → output projection) as one replayable graph per shape, and collapse sampler stacks into fused logit-space kernels with *documented seed semantics*. In Go terms: the per-token host path should approach zero allocations and zero per-layer launches, and sampling should never sort a vocabulary it can threshold.

**Expected gain (estimate):** A few percent on large models, and the difference between usable and sluggish on the small models a 6 GB runner mostly serves — V3's docs state the graphed path's largest gains are precisely on host-bound setups (small/hybrid models, fast GPUs, contended CPUs), which is a description of the fork's target machines.

**Cost / risk:** CUDA-graph-style capture is backend-specific (Metal/Vulkan equivalents differ); budget it as a per-backend optimisation with an eager fallback that is *the same arithmetic*, as V3 does. Seed-semantics documentation is cheap and should be stolen even if the kernels are not.

### 9.5 MoE-scoped CPU offload with hot-expert streaming

**Steal:** The shape of V3's breach (§5.3), not its code: for MoE models only, place the coldest experts in system RAM under a worker that never blocks the GPU forward pass, and *stream hot experts to the GPU during prefill* behind a bandwidth-probed threshold. The two-granularity exposure (whole layers, or N coldest experts per layer) is the right user-facing shape.

**Expected gain (estimate):** On a 6 GB card with 32–64 GB system RAM, this is the only mechanism in either dossier that makes 30B–125B-class sparse models addressable at all; decode rates will be CPU-bound and modest (V3's own tables: ~10 t/s on 8 AVX2 cores in the worst shown case, ~60 t/s on a high-end host) — a capability tier, not a speed tier.

**Cost / risk:** High implementation complexity (pinned shared-memory job rings, per-component workers); strictly MoE-shaped — do not let it metastasise into a general dense offload, which is llama.cpp's home ground and a different engineering programme. AVX2/AVX-512 divergence and ARM (Pi-class) absence must be designed for under the cross-platform law.

### 9.6 Tensor parallelism for consumer multi-GPU, honestly labelled

**Steal, conditionally:** If the fork ever serves the two-card desktop segment, V3's settlement — native shared-memory transport for PCIe, NCCL-class transport for NVLink, and *documented fallback* of fused decode paths under TP — is the reference design for doing TP without pretending it is free.

**Expected gain (estimate):** Converts a second consumer card from capacity (layer split) into speed for models that already fit on one card.

**Cost / risk:** Out of scope for the 6 GB single-card target; record as a deferred steal. The lesson that transfers immediately is the labelling: publish which fast paths TP disables.

### 9.7 Per-tensor recipes + self-calibration as the publishing pipeline

**Steal:** The converter's publishing surface (§3.3): per-tensor YAML bitrate recipes with wildcard matching and pre-flight coverage checks, generated by a self-calibration optimizer, plus separate first-class rates for head/MTP/vision/embedding/n-gram components. For a registry-based runner this maps to: publish the recipe *with* the artefact, so a quant is auditable and reproducible, and let advanced users re-solve at a different target bpw from the published recipe + sensitivities instead of re-running calibration (the evolution of the predecessor dossier's §9.2 proposal, now with an existence proof).

**Expected gain (estimate):** Artefact auditability and a denser bpw ladder at near-zero marginal registry cost.

**Cost / risk:** Low–moderate; mostly pipeline discipline.

### 9.8 What NOT to steal

- **The documentation regression.** Do not ship a generator whose prefix/session semantics live only in source. V2's `doc/dynamic.md` was the better practice; the fork should specify its cache-sharing contract in prose, versioned with the API (§4.5).
- **Silent capability gating.** Codebook-gated fast paths and default-capped context are the kind of invisible behaviour that generates user distrust; every gated path in the fork should be discoverable from the artefact's own metadata.
- **Format exclusivity, again.** EXL3 deepened lock-in (§8). Borrow the mathematics (papers are public; the method is publishable knowledge), keep the fork's artefacts in an open, documented layout.

---

## 10. Sources with dates accessed

All sources accessed **2026-11-15** unless a different date is stated. Primary sources carry the load-bearing claims; secondary sources are marked.

**Primary**

1. ExLlamaV3 README, `master` branch, via raw.githubusercontent.com/turboderp-org/exllamav3 — self-description, feature lines (EXL3/QTIP, 2–8 bit cache quantization, tensor/expert parallelism, CPU MoE offload with AVX2/AVX-512, continuous dynamic batching, speculative decoding, multimodal), TabbyAPI recommendation, install routes (wheels, PyPI JIT, `uv` CUDA-flavour extras, torch ≥2.6.0 / CUDA ≥12.4), architecture-support table, conversion summary (single-step, on-the-fly Hessians, fused Viterbi kernel, minutes-to-hours conversion times), HF EXL3 collection and community quantizers, acknowledgements (QTIP, Marlin, FlashAttention, vendored Flash Linear Attention).
2. ExLlamaV3 `doc/convert.md` — full converter surface: `-b` float target, `--head_bits` (default 6), `--mtp_bits` (4), `--vision_bits`, `--embed_bits` (default 16; 256-wide rotated trellis-coded groups; RAM/disk-streamed decode), `--ngram_bits`, `-hq` promotion (+0.05–0.10 bpw on MoE), `--moe_affinity_eps` per-expert Hessians (typical 0.01; 262,144 sampled rows), per-tensor YAML recipes with coverage checks, calibration defaults (250 × 2,048) and custom packed-token calibration files, codebooks (`mul1` default / `mcg` / `3inst`; mul1 required for int8 GEMV and CPU offload), two-sided LDLQ and output-scale options, checkpointing (120 s) and explicit `-r` resume (noted as reversing V2 behaviour), multi-GPU trellis encoding (`-d`, autotuned ratios).
3. ExLlamaV3 `doc/env_vars.md` (~2,000 lines; read in part, attention/GEMM/sampler/CPU-offload sections in full) — CUDA/ROCm default divergences; graph-captured decode blocks (attention/MLA/GDN/DSA; q_len ≤ 16; block-table pointer patching; TP fallback); quantized-cache staging modes (direct / staged ~1–3% of FP16 / full) and staging window (256 pages = 64k tokens); FA2 as optional non-default backend; Turing SDPA/fa75 paths; EXL3 GEMV heuristics; fused int8 GEMV (mul1, error-feedback residual mode); reconstruct-then-GEMM prefill crossover (~1k rows; folded Hadamards worth ~14% of long-chunk prefill); fused sampler semantics; CPU MoE offload mechanics (`-mcl`, mul1/K≤8/layer-split constraints, pinned shared-memory worker rings, hot-expert streaming with bandwidth-probed thresholds).
4. GitHub release notes: v1.5.0 (2026-09-13) — MoE prefill/decode speedups with full hardware-labelled tables, zero-copy pinned arena (Linux), speculative decoding for MoE; v1.6.5 (2026-10-25, via release mirror) — prompt-caching tokenizer-regression fix. v1.6.6 (2026-10-31) as latest release via secondary trackers citing the GitHub API (see Secondary 8–9).
5. Tseng, Sun, Hou & De Sa, "QTIP: Quantization with Trellises and Incoherence Processing", arXiv:2406.11235 (NeurIPS 2024) — TCQ, bitshift trellis, compute-based codes (1MAD/3INST/hybrid), incoherence processing, BlockLDLQ integration, high-dimensional (>100) quantization claim. Read via the paper's abstract/summary pages and the authors' project writeup (together.ai blog, Cornell RelaxML) rather than the full PDF in this pass. *[Partial-read flag: §10 unverified list.]*
6. ExLlamaV2 README (current) — archival notice and handover to ExLlamaV3; predecessor dossier OR-2 (`exllamav2.md`) for all V2-side claims.

**Secondary (corroboration / context / attributed numbers)**

7. Atomic Chat, "EXL3 vs GGUF: Quality, Speed and VRAM" and "LLM Quantization Explained" (accessed 2026-11-15) — independent RTX 5090 stack benchmark (ExLlamaV3 1.4.9): KLD and size tables, prefill up to ~2.5× vs llama.cpp decode 15–21% faster, mul1-vs-mcg improvement, embedding-inclusive totals, EXL3 HF-structure-retention note.
8. dev.to survey, "ExLlamaV3 and TabbyAPI — the pair that ships today" (fetched 2026-11-11 by its author; accessed 2026-11-15) — v1.6.6/2026-10-31 via GitHub API, TabbyAPI V2-backend removal (2026-07-14), TP backend guidance (native/PCIe, NCCL/NVLink), POSIX shared-memory note, EXL2-loadability non-documentation.
9. quantized.uk data changelog (updated 2026-11-15) — ExLlamaV3 1.6.6 still current 2026-11-13; runlocalai.co release pulse — v1.6.0 preliminary ROCm (ROCm 10, gfx1100+), v1.6.1 recurrent drafting + hybrid n-gram drafting, v1.6.2 faster CPU offload + DFlash2 under TP, v1.5.4 embedding quantization + disk streaming.
10. Release coverage of v1.0.0 (July 2026) — FA2/xformers dependency removal, MoE ticket scheduler, online cache quantization in the new attention kernel, TP extended to most models, INT8 GEMV introduction.
11. zolotukhin.ai, "EXL3's 1.6 bpw trellis quantization has no path to RDNA4 yet" (May 2026) — 1.6 bpw 70B claim as quoted from the then-current README, older "What's missing?" list (LoRA, ROCm), Marlin tile heritage, CUDA share of codebase. *Dated snapshot: its "missing" list predates the ROCm landing and is used here only as historical evidence.*
12. DeepWiki index of turboderp-org/exllamav3 (generated 2026-11-03) — module structure corroboration (EXL3 quant module, cache module, TP export, 90+ architectures).
13. Practitioner guides (aicoderscope.com TabbyAPI guide, Sep 2026; dev.to Qwen3.8-Flash-Next guide, Oct 2026) — TabbyAPI `cache_size` 4,096 default and `cache_mode` usage, `cpu_moe_split_experts` behaviour, pinned exllamav3 versions, AGPL-3.0 TabbyAPI licence. Community-grade evidence; used only where flagged.
14. Medium summary of a LocalLLaMA KV-quantization study (Qwen3.8 27B, accessed 2026-11-15) — 8-bit cache KL ≈ 0; EXL3 4-bit cache KL penalty varying with weight bpw. Single-author benchmark; used as directional evidence only.

**Unverifiable / unresolved items (declared):**
- **Cross-job prefix deduplication and session semantics in V3** (§4.5): prompt caching is release-note-verified; V2-style page-level deduplication across concurrent jobs, retention of finished jobs' pages, page size, defragmentation policy, and the generator's job/sampler object shape have no V3 prose source found in this pass.
- **EXL2 (and GPTQ) loadability in V3**: claimed by third-party posts, documented by neither V3 nor TabbyAPI current docs; TabbyAPI's documented set is EXL3 + FP16/BF16.
- **LoRA support status**: older README snapshot lists it as missing; secondary summaries list adapters as supported; the current README read neither advertises nor disclaims it.
- **QTIP full-paper details** beyond abstract/summary level (exact trellis parameters per bitrate as adopted by EXL3, e.g. state size L and tile geometry per K) and the in-repo `exl3.md` format writeup: referenced by secondary sources, not retrieved in this pass. EXL3's exact per-bitrate trellis parameters are therefore **not asserted** in this dossier.
- **QTIP reference-repo licence (GPLv3)** as it bears on clean-room study: secondary-sourced only; the operative fact (ExLlamaV3 itself is MIT) is verified.
- **EXL3 HF tensor-structure retention** (§3.4): single secondary survey.
- **Per-K/per-V cache-mode split** at engine level: server configs suggest it; engine docs read do not state it.
- **TabbyAPI AGPL-3.0 licence and V2-backend removal date**: secondary-sourced (multiple, consistent).
- **ExUI's V3 status** and **text-generation-webui's V3 loader**: not verified in this pass.
- **Repo creation date (2025-04-06)** is taken from the campaign field-map sweep #3 as instructed, not re-verified against the GitHub API in this pass.

*End of dossier OR-2 successor volume. Clean-room note: this dossier was written from the public sources listed above, in the author's own words; no source text is reproduced beyond short factual labels (names, version numbers, parameter/flag names, and benchmark figures with attribution), and no code is included.*
