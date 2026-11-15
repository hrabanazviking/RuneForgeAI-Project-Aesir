# OR-2 — llama.cpp / ggml: The Gravity Well of Local Inference

| Field | Value |
|---|---|
| Projects | **llama.cpp** (application / inference engine) and **ggml** (tensor library) |
| Organisation | ggml-org (formerly ggerganov personal repos; moved to ggml-org) |
| Repositories | https://github.com/ggml-org/llama.cpp · https://github.com/ggml-org/ggml |
| Licence | **MIT** for both projects (verified on both GitHub repo sidebars and LICENSE files, accessed 2026-11-15) |
| Languages | Plain C / C++ core with no required runtime dependencies; Python only for conversion tooling (`convert_hf_to_gguf.py`, `gguf-py`); backend shaders/kernels in CUDA C, Metal Shading Language, GLSL/SPIR-V (Vulkan), SYCL, etc. |
| Snapshot | llama.cpp master commit `6d3568e` (≈12,408 commits, ≈135k stars), ggml master commit `417a024` (≈5,315 commits), both as fetched 2026-11-15. The project releases continuously under `bNNNN` build numbers; any flag default cited here must be re-checked with `--help` on the exact build in hand. |
| Dossier date | As of **2026-11-15** |
| Clean-room note | This dossier describes architecture, behaviour and design ideas in our own words. No source code is reproduced. Flag names, type names and file-format field names are short factual labels. |

**Essence.** llama.cpp is the reason local LLM inference exists as a mass practice. It began in March 2023 as a one-evening port of Meta's LLaMA to dependency-free C/C++, and became the portable substrate almost every local runner — Ollama, LM Studio, Jan, KoboldCpp and dozens of bindings — either embeds, forks, or (in Ollama's current design) launches as a subprocess. Underneath it, ggml is a small, austere tensor library: define a computation graph, hand it to a pluggable backend, execute it with zero allocations in the hot path. Everything distinctive about the ecosystem — the GGUF single-file format, block quantization down to ~1.5 bits per weight, CPU+GPU hybrid execution of models larger than VRAM, operation on everything from a Raspberry Pi to a multi-GPU server — follows from those two decisions: *no dependencies, and never assume the hardware*. For our improved-Ollama work, llama.cpp is therefore not one option among many. It is the incumbent physics. Any design we propose either rides it, consciously diverges from it, or pays to reimplement it.

---

## 1. Architecture: ggml below, llama.cpp above

### 1.1 The three-layer stack

The cleanest mental model, confirmed across the READMEs, the server developer docs and independent deep-dives read for this dossier, is three layers:

1. **ggml — the tensor engine.** Owns tensors, types (including every quantized block format), the computation-graph representation, memory allocation for graphs, and the backend abstraction. It knows nothing about transformers, tokenizers or chat.
2. **libllama — the model logic.** Lives in llama.cpp's `src/` and public C API in `include/llama.h`. It reads GGUF metadata and builds the correct architecture (Llama, Mistral, Qwen, Gemma, Phi, Falcon, Mamba/RWKV hybrids and many more — new architectures typically land here first, often within days of a model release), owns model loading, the KV / recurrent / hybrid memory subsystem, batching (`llama_batch`), context creation (`llama_context`) and the sampler chain.
3. **Tools — the application layer.** `llama-cli` (interactive/one-shot), `llama-server` (also exposed as `llama serve`; HTTP server with OpenAI-compatible and Anthropic-compatible routes plus a built-in web UI), `llama-bench`, `llama-perplexity`, `llama-quantize`, `llama-imatrix`, embedding / reranking / speculative example tools, and the newer router mode that can load/unload several models in one server process. Bindings (Python, Go, Rust, Node, etc.) wrap layer 2, not ggml directly.

The llama.cpp repo vendors its own copy of ggml under `ggml/`; the standalone ggml repo is the upstream library also used by whisper.cpp and other ggml-family projects. The ggml README explicitly directs core ggml contributions through the llama.cpp repo, because that is where CI coverage and review attention live. In practice: **llama.cpp is the development head; ggml-the-repo is the library extraction.** Anyone tracking behaviour should read llama.cpp first.

### 1.2 ggml: tensors, graphs, define-then-execute

ggml's execution model is *define-then-execute*, not eager:

- User code creates tensors inside a `ggml_context` (an arena; tensors are metadata + a data pointer or buffer assignment, not owning allocations in the PyTorch sense).
- Calling an operation (matrix multiply, add, RoPE, softmax, RMS-norm, … — roughly 80–95 ops depending on snapshot) does **not** compute anything. It creates a result tensor node recording the op and its source tensors.
- `ggml_build_forward_expand` walks the source pointers depth-first to assemble a `ggml_cgraph`: leaf nodes (no op) are inputs/weights; op nodes execute in dependency order.
- A graph allocator (`ggml_gallocr`) statically analyses tensor lifetimes in the graph and reuses buffers for tensors whose lifetimes do not overlap, minimising the compute-buffer footprint.
- Execution happens only when the graph is handed to a backend: `ggml_backend_graph_compute` for a single device, or the scheduler (below) for several.

Two stated ggml design properties matter downstream:

- **Zero memory allocations during runtime** (ggml README). Graph arenas and backend buffers are reserved up front (the scheduler even offers a reserve pass sized from a worst-case "measure graph"). This is why llama.cpp's memory use is predictable and why its failure mode under pressure is a clean allocation failure at context creation rather than creeping fragmentation — the opposite trade from a general Python runtime.
- **Autograd exists but is vestigial for inference.** ggml carries forward/backward graph support and simple optimizers (Adam, L-BFGS) from its origins as a general ML library. llama.cpp uses only the forward path. Do not mistake ggml for a training framework.

### 1.3 The backend abstraction and scheduler

A backend is an opaque device handle (`ggml_backend_t`) with a vtable: allocate/free buffers, copy tensors (synchronous and asynchronous), execute a graph, optionally pre-plan a graph, record/wait events for cross-backend synchronisation, and answer `supports_op` / `supports_buft` capability queries. A registry discovers backends; they can be built in or compiled as shared libraries and loaded dynamically (`GGML_BACKEND_DL`).

On top sits the **multi-backend scheduler** (`ggml_backend_sched_t`, up to 16 backends in current sources as summarised by DeepWiki's code reading). Given one graph and an ordered list of backends/buffer types, it:

1. **Splits** the graph into contiguous sub-graphs, assigning each op to a backend — preferring the backend where its input tensors already live, respecting explicit tensor-placement decisions made by libllama (this is where layer offload enters; §5), and falling back to CPU for ops a GPU backend does not support.
2. **Inserts copies** where a split boundary crosses devices, and can pipeline those copies (multiple graph copies so the copy for batch N+1 overlaps compute for batch N, coordinated by backend events).
3. **Allocates** each split's intermediates through the graph allocator, per device.

The consequence is the signature llama.cpp behaviour: *one model graph, executed partly on GPU and partly on CPU, with the seam invisible to the model code.* The model builder declares where tensors should live; the scheduler handles the rest, including quiet CPU fallback for unsupported ops. That fallback is a portability blessing and a performance trap — an op silently running on CPU in the middle of a GPU graph forces synchronisation and copies, and is a classic cause of "GPU is slower than expected" reports (see §7).

### 1.4 Backend roster

From the llama.cpp README backend table (accessed 2026-11-15), condensed to the roster that matters plus the long tail:

| Backend | Targets | Notes for our work |
|---|---|---|
| **CPU** (built-in ggml-cpu) | x86 (AVX, AVX2, AVX-512, AMX), ARM (NEON, Accelerate framework hooks, SVE/SME), RISC-V (RVV and related extensions), PowerPC (VSX), s390x, LoongArch, Wasm | Always present; the reference implementation and universal fallback. Hand-vectorised per ISA. Thread count is a first-class tuning knob, separately for generation and for batch/prompt processing. |
| **CUDA** | NVIDIA GPUs | The most optimised GPU path: custom kernels including fused dequantise-matmul (MMQ/MMVQ families) and Flash Attention. Default choice on NVIDIA. |
| **HIP** | AMD GPUs (ROCm) | CUDA code path compiled through HIP. Fastest AMD path *when the card is on ROCm's support list*; coverage gaps on older/consumer cards are the recurring pain point. |
| **Vulkan** | Any Vulkan-capable GPU (AMD, Intel, NVIDIA, mobile) | The portability GPU backend: no vendor stack required, works on Windows without ROCm/CUDA installs. Usually behind CUDA/HIP at peak, ahead of them in "it runs at all". Shaders compiled to SPIR-V. |
| **Metal** | Apple Silicon | First-class citizen since the project's first weeks. The unified-memory showcase (§5.4). Flash Attention supported. |
| **SYCL** | Intel GPUs (Arc, Xe, Data Center) | Intel's oneAPI path. Also received sparse Flash Attention work in recent ggml releases. |
| Long tail (README) | BLAS / BLIS (CPU matmul libraries), CANN (Huawei Ascend NPU), Hexagon (Snapdragon NPU), OpenCL (Adreno), MUSA (Moore Threads), ZenDNN (AMD CPU), IBM zDNN, WebGPU (browser), RPC, VirtGPU, OpenVINO (in progress, Intel CPU/GPU/NPU) | RPC deserves a note: it lets a graph span ggml servers on *other machines* — llama.cpp's only native distributed story, and a research curiosity rather than a serving feature. |

**How backends are chosen and blended.** Selection is at three levels. (a) *Build time:* CMake options decide which backends are compiled or made loadable. Prebuilt release binaries ship per-backend flavours. (b) *Startup:* the registry enumerates devices (`--list-devices`); `--device` restricts which devices libllama may offload to; `--main-gpu` picks the primary device under row splitting. (c) *Per-op, at run time:* the scheduler assignment described above. Blending is therefore not "pick one backend" but "declare tensor placement, let the scheduler route ops": weights pinned to a GPU pull their matmuls there; the KV cache follows the layer that owns it unless told otherwise (`--no-kv-offload`); embeddings, sampling helpers or an unsupported op may still execute on CPU. A single inference routinely uses two backends (GPU + CPU) even in "full GPU offload" configurations, for orchestration and edge ops.

---

## 2. The GGUF format

### 2.1 What the file is

GGUF (specification in `ggml/docs/gguf.md`, version 3 current) is a binary, single-file container designed around three stated goals that explain every layout choice: **single-file deployment** (everything needed to load the model is in the file), **mmap compatibility** (load by mapping, not parsing-and-copying), and **extensibility** (new information must not break old readers). It succeeds GGML/GGMF/GGJT; the decisive change from GGJT was replacing a positional, untyped hyperparameter list with typed key–value metadata.

Layout, in order:

1. **Header:** 4-byte magic (`GGUF`), uint32 version, uint64 tensor count, uint64 metadata-pair count. Little-endian by default; v3 adds big-endian support (with the spec's own caveat that endianness is not self-describing in the file).
2. **Metadata:** that many typed key–value pairs. Keys are hierarchical ASCII strings (`lower_snake_case` segments joined by `.`, max 65535 bytes). Values are strongly typed: integers (8–64 bit, signed/unsigned), floats (32/64), bool, UTF-8 strings (length-prefixed, not NUL-terminated), and arrays of any of those, nestable.
3. **Tensor directory:** per tensor — name (≤64 bytes), dimension count (≤4), dimensions, `ggml_type` code, and a byte offset into the data region.
4. **Tensor data:** raw tensor bytes, each tensor's offset aligned to `general.alignment` (default **32 bytes** if the key is absent). Alignment + offsets are what make zero-copy mmap loading possible: a reader can point a tensor directly at the mapped page range.

Standardised metadata carries, in practice:

- **Identity/provenance:** `general.architecture` (required; e.g. `llama`, `qwen3`, `falcon`, `mamba`), `general.name`, `general.file_type` (the majority tensor type), `general.quantization_version`, source/base-model lineage keys, licence as an SPDX expression.
- **Architecture hyperparameters**, namespaced per architecture: e.g. `[arch].context_length` (training context), `[arch].embedding_length`, `[arch].block_count`, `[arch].feed_forward_length`, attention head counts (including separate KV head count — the GQA parameter that drives KV size), RoPE parameters, normalisation epsilons. The loader builds the model from these keys; there is no separate config file.
- **Tokenizer:** the `tokenizer.ggml.*` family — model kind (BPE/SPM/etc.), the full token list, merges, BOS/EOS and special-token IDs, pre-tokenizer identifier. A GGUF is runnable without any external tokenizer files.
- **Chat template:** `tokenizer.chat_template` — a Jinja template string stored in the file. llama-server renders prompts through its Jinja engine using this template unless overridden (`--chat-template`, `--jinja`/`--no-jinja`). This single key is why "the same model" can behave differently across quant publishers: whoever converted the file chose the template baked into it.
- **Sidecars by filename convention:** the (human-oriented, explicitly not perfectly parseable) naming scheme encodes base name, size label, fine-tune, version and encoding; prefixes mark auxiliary files — `mmproj-` for a multimodal projector, `mtp-` for Multi-Token Prediction draft heads — and suffixes mark LoRA adapters, vocab-only files, and sharding (`-00003-of-00009`) for models split across files.

**Design judgement.** GGUF's strength is that it is a *deployment* format, not an interchange format: it optimises for "map this file and run" at the cost of carrying inference-shaped, pre-quantised tensors rather than a canonical training checkpoint. Its weakness is the mirror image: trust and safety live entirely in the reader. The parser runs before any sandboxing, and 2026 saw disclosed GGUF-parser vulnerabilities (e.g. CVE-2026-27940 and related heap-overflow reports noted in secondary coverage read for this dossier) — an improved runner must treat untrusted GGUFs as untrusted input, because llama.cpp historically treated them as trusted local files. *[Speculation flag: severity and patch status of individual CVEs were not verified against the upstream security advisories for this dossier; verify before relying on this point.]*

### 2.2 Quantization: the design ideas

GGUF itself defines no compression; it *hosts* tensor types defined by ggml (`enum ggml_type` in the spec mirrors `ggml.h`, and gains values over time — F32/F16/BF16, the Q/IQ/TQ families below, MXFP4, NVFP4, FP8 E4M3, and plain integer types). Every tensor in a file may use a different type. The families:

**(a) Legacy block quants (Q4_0, Q4_1, Q5_0, Q5_1, Q8_0, Q8_1).** The original scheme: independent blocks of **32 weights**. Each block stores small integer codes plus one fp16 scale (`w = d·q`, "type-0"); the `_1` variants add a minimum (`w = d·q + b`, "type-1", affine). Q4_0 costs 18 bytes per 32 weights = **4.5 bits/weight**; Q8_0 ≈ 8.5 bpw and is near-lossless. Simple, fast to decode, and still the speed reference on some hardware — but one scale per 32 weights handles outlier-heavy distributions poorly, which is why the later families exist. Q8_0 remains important beyond weights: it is the workhorse KV-cache quant (§3.3).

**(b) K-quants (Q2_K … Q6_K).** Introduced mid-2023 (PR #1684 in the historical numbering). The idea is *hierarchical scaling*: weights are grouped into **super-blocks of 256**, subdivided into sub-blocks (8×32 or 16×16 depending on type). Each sub-block gets its own scale (and, for type-1 formats, a minimum) — and crucially those sub-block scales are *themselves quantised* (to 4, 6 or 8 bits) against fp16 super-block scale/min values. Two levels of scale metadata buy much better fidelity per bit than the flat legacy scheme. Nominal costs: Q2_K 2.625 bpw, Q3_K 3.4375, Q4_K 4.5, Q5_K 5.5, Q6_K 6.5625.

The second K-quant idea is that **a file type is a recipe, not a tensor type.** `Q4_K` is a tensor type; `Q4_K_M` is a per-tensor assignment policy: most tensors at Q4_K, but the tensors empirically most sensitive — classically half of `attn_v` and `ffn_down` (the down-projection), and the output/token-embedding in many recipes — promoted to Q6_K; `_S` keeps everything uniform, `_L` promotes more. Measured on Llama 3.1 8B in llama-quantize's own documentation (via secondary compilations read for this dossier): Q4_K_M lands at ≈**4.89 bpw effective** (not 4.5), Q5_K_M ≈5.7, Q3_K_M ≈3.9–4.0. This mixed-precision-by-tensor-role insight — *sensitivity is structured, not uniform* — is the single most transferable quantisation idea in the project, and it is why Q4_K_M became the ecosystem default (both llama.cpp's `-hf` download default and Ollama's pull default): near-Q5 quality at near-Q4 size. Perplexity deltas quoted in the original K-quant work (LLaMA-7B, WikiText): F16 5.9066 → Q6_K 5.9110, Q4_K_M 5.9601, Q2_K 6.7764. Treat all perplexity numbers as model+dataset-specific illustrations, not constants.

**(c) I-quants / IQ line (IQ1_S/M, IQ2_XXS/XS/S, IQ3_XXS/S/M, IQ4_NL, IQ4_XS) and ternaries (TQ1_0, TQ2_0).** Below ~4 bpw, scalar rounding collapses; the IQ family switches strategy to **codebooks**: weights are encoded as indices into small sets of jointly-chosen values — e.g. a 256-point 8-dimensional lattice grid for the IQ2_XXS class, or a fixed 16-entry non-uniform value table for IQ4_NL (whose levels are placed where weight distributions actually concentrate, rather than uniformly). IQ1_S reaches ≈1.56 bpw; IQ2_XXS ≈2.06 bpw. These formats are inseparable from the **importance matrix (imatrix)**: a calibration pass (`llama-imatrix`) runs the full-precision model over sample text and accumulates, per input channel, the mean squared activation ⟨a²⟩. The quantiser then minimises an activation-weighted error — roughly, the squared error of each dot product the next layer will actually see, (Σ(qⱼ−wⱼ)aⱼ)² — spending its scarce codebook fidelity where activations are large and rounding aggressively where they are near zero. The imatrix is a build-time artefact only; it is **not** stored in the shipped GGUF. Consequences: (i) IQ quality depends on calibration data representativeness — an imatrix built on generic web text is a prior about what matters, and can misfire for narrow domains; (ii) IQ decode can be *slower* than K-quants on hardware lacking the SIMD paths its table lookups want (one secondary source measured IQ4_XS ≈8% slower than Q4_K_M on an RTX 3090, and much worse on old Pascal cards — hardware context essential, treat as indicative only); (iii) at 4-bit, IQ4_XS buys roughly 400 MB saved on an 8B model versus Q4_K_M at comparable perplexity — the win grows as bit-width shrinks.

**(d) Newer microscaling formats (MXFP4, NVFP4, FP8 E4M3).** Recent ggml adds OCP-style microscaling types (small blocks sharing an exponent scale) driven by models natively released in those formats (e.g. gpt-oss in MXFP4). Design significance: ggml is absorbing vendor-native low-precision formats rather than forcing everything through its own quantiser — the format zoo will keep growing, and a runner must version its type support explicitly.


## 3. KV cache and context in llama.cpp

### 3.1 Cache layout

For transformer models the cache is, per layer, per token, per KV head: a key vector and a value vector, each of head dimension. The modern implementation (`llama_kv_cache`, with a `llama_memory_i` abstraction that also covers recurrent state for Mamba/RWKV and hybrid models) allocates **two large tensors per layer — one K, one V** — in buffers on the devices owning those layers. Sequences ("streams" in unified-KV terminology) occupy cell ranges inside those tensors; a token is identified by its sequence id + position, not by being the Nth element of a private array. This cell-based, position-addressed design is what makes prefix reuse, shifting and per-slot management expressible as small operations (remove a position range, shift a range by a delta, copy a range) rather than copying whole tensors.

Memory cost per token (transformer, f16 cache) is exact arithmetic:

```
bytes/token = 2 (K and V) × n_layers × n_kv_heads × head_dim × bytes_per_element
```

Worked example read in the server-era deep-dives and independently re-derivable from GGUF metadata: Llama 3.1 8B — 32 layers, 8 KV heads (grouped-query attention), head_dim 128, f16 (2 bytes) → 2×32×8×128×2 = **131,072 bytes = 128 KiB per token**. A 32,768-token context therefore costs **4 GiB of KV cache alone**, on top of ≈4.9 GB of Q4_K_M weights. A 6 GB GPU cannot hold both at 32k context; it can at roughly 8k (1 GiB KV + 4.9 GB weights ≈ 6 GB before compute buffers — uncomfortably tight; see §8.2). This formula, not file size, is the binding constraint for long-context single-user work.

### 3.2 What happens when a sequence overflows n_ctx — verified behaviour

**This is the load-bearing finding of §3, and the answer is split between two code paths, which is itself a hazard.**

- **llama-server (the serving path) — default is to *stop*, not discard.** The server README (master, accessed 2026-11-15) lists `--context-shift, --no-context-shift` as "whether to use context shift on infinite text generation (default: disabled)". Independent deep-dives confirmed the same: if prompt + generated output exceeds the slot's context, the default behaviour is to stop generation rather than silently discarding history; context shifting is opt-in. When enabled, shifting implements the classic rule: keep the first `n_keep` tokens (the initial prompt — settable via `--keep N`; `-1` keeps all, 0 keeps none), discard `n_discard` tokens immediately after them, and shift the surviving KV entries down by that amount (`llama_memory_seq_rm` then `llama_memory_seq_add`/shift in current sources; the older `llama_kv_cache_seq_rm`/`seq_shift` names still appear in older code and secondary write-ups). RoPE positions of the survivors are re-based to their new positions. **Nothing in this mechanism is semantic: it keeps a token *count* from the start of the sequence. Whatever lives in the discarded middle — including a character definition, safety instruction or conversation fact placed there — is gone, silently, and the model continues as if it never existed.**
- **llama-cli / completion loops — shifting is the historical default.** The CLI's generation loop has long performed exactly the same keep-prefix / discard-middle / shift operation automatically when the context fills (this is visible in the passkey example and the `n_keep`/`n_discard` logic in old `examples/passkey` and `main` sources). Do not generalise CLI behaviour to the server, or vice versa: the two tools differ in default.
- **Newer server machinery around shifting:** a unified KV buffer shared across slots (`--kv-unified`, default enabled only when the slot count is automatic; `--kv-unified-per-slot N` to size it explicitly); `--cache-reuse N` (default 0 = off) which reuses *non-identical* prefixes by shifting KV chunks instead of recomputing them, with N the minimum chunk size; per-slot context **checkpoints** (`--ctx-checkpoints`, default 32 per slot, min spacing `--checkpoint-min-step`, default 8192 tokens) that let the server rewind a slot to an earlier checkpoint rather than re-processing; and `--cache-ram` (default 8192 MiB) bounding a RAM cache of idle slots' prompt state, with `--cache-idle-slots` (default enabled) saving idle slots into it and clearing them when unified KV is in use. These are all recent (2025–2026) additions and move fast; the `--help` of the running build is authoritative.

**What llama.cpp's shifting is, in one sentence:** a *positional, prefix-preserving, middle-discarding* eviction policy. It is optimised for "the system prompt is at the front and short" and for "keep generating forever without crashing". It is **not** a memory policy in the character sense at all.

### 3.3 KV cache quantization

Separate from weight quantization, the *cache itself* can be stored in a lower-precision type, set independently for K and V: `-ctk, --cache-type-k` and `-ctv, --cache-type-v`, allowed values `f32, f16, bf16, f8_e4m3, q8_0, q4_0, q4_1, iq4_nl, q5_0, q5_1`, **default f16 on both** (server README, accessed 2026-11-15). The draft model has its own pair (`--spec-draft-type-k/-v`, defaults f16).

Worked effect on the §3.1 example: switching K and V from f16 to `q8_0` (≈34 bytes per 32 elements, vs 64 bytes f16) cuts the 32k-context cache from 4 GiB to ≈**2.1 GiB**. `q4_0` roughly halves it again, with a corresponding quality risk: KV quantization errors compound across a long generation in a way weight errors do not, because each decoded token's attention reads the *quantised* history of every earlier token.

**Important caveat, stated in two independent sources read for this dossier:** quantised KV (especially for the V cache) is tied to **Flash Attention** being active; the commonly quoted form is that Ollama's own FAQ exposes `OLLAMA_KV_CACHE_TYPE` with f16 default and applies quantised K/V when Flash Attention is enabled, and llama.cpp-side guides present `-fa` as the prerequisite for KV quantization. The exact coupling (which cache types require FA on which backend) varies by build and backend; verify on the build in hand before promising it. It is *not* safe to treat `-ctk q8_0` as an unconditional free memory win.

### 3.4 Session save / restore — three different mechanisms, do not conflate them

| Mechanism | How it works | Limits |
|---|---|---|
| **CLI prompt cache** — `llama-cli --prompt-cache <file>` (plus `--prompt-cache-all` to also persist generated tokens, `--prompt-cache-ro` for read-only loading) | On first run, after processing the prompt, the library writes the full inference state (KV cache + associated tokens) to the file via the state-save API. On later runs with the same file, it loads that state instead of re-processing the prompt. | Tied to the same model and context size; restoring does **not** guarantee identical subsequent tokens even with a fixed seed (documented in the old CLI README). State is a binary blob keyed to the build's internal format — treat as non-portable across versions. It is a *file*, not a session record: it stores tokens + KV, not the rendered chat history, sampler state or server-side bookkeeping. |
| **Server slot save/restore** — start with `--slot-save-path <dir>`; then `POST /slots/{id}?action=save` with `{"filename": "x.bin"}`, `?action=restore`, `?action=erase` | The slot's live KV state is serialised to a file in that directory and can be restored into a (fresh) server. A measured community run (Nov 2026, Debian 13 VM, 6 vCPUs, no GPU, llama.cpp commit `29c720e`, Qwen3-1.7B, 7,289-token system prompt): cold prompt 160.7 s; restore 2.14 s with the page cache dropped; file 836 MB (≈114,700 bytes/saved token); a second model (Qwen3.5-2B) produced 171 MB for the same token count, showing file size is strongly architecture- and cache-type-dependent. Another community measurement: 5k-token chat, 9.9 s cold re-prefill vs 1.4 s restore (≈7×). | Disabled by default — without `--slot-save-path` the endpoints return HTTP 501. Restore requires the **same model and same slot count** (`-np`); `-c` may differ if the saved tokens fit. Restore failure returns the same generic HTTP 400 for every cause (missing file included) — callers must treat failure as "run cold". **No auto-persistence exists**: upstream declined automatic session persistence (discussion #17107 per secondary reporting), so the caller must drive save/restore explicitly. Files are large (full KV, roughly cache-size per token × tokens) and contain the conversation's KV state — a privacy surface in multi-user deployments (a 2026 preprint reported cross-client slot-state recovery in a controlled experiment; it is a preprint, not a CVE, and it depended on `--slot-save-path` being enabled and slots being shared — but it shows the *design* has no per-user isolation boundary on saved slots). |
| **Server in-memory prompt caching** — `--cache-prompt` (default enabled) + `--cache-reuse` | Within a running server, a new request whose prompt shares a prefix with the slot's previous prompt skips re-processing the shared tokens (`tokens_cached` reported in the response; `tokens_evaluated` is the remainder). | Reuse is prefix-exact only: a changed timestamp, session id, RAG block or system-prompt edit near the front destroys the shared span and forces full re-prefill. Without `--cache-reuse`, even a *trimmed* history (oldest turns dropped) breaks reuse because the prefix no longer matches; `--cache-reuse N` recovers some of this by shifting. This is the mechanism that makes multi-turn chat cheap *only if* the prompt is rendered identically turn after turn — a design constraint that falls directly on whoever builds the chat template. |

**Design judgement.** llama.cpp has *three* persistence stories, each invented for a different era (CLI single-run resume, in-memory slot reuse, explicit slot files), and none of them is a *session* in the product sense: none stores the conversation, the model identity + quant, the sampler settings, or a validity check beyond "the model matches". That gap is precisely where an improved Ollama should build — see §8. Also note the asymmetry that matters for us: **restore is fast because it is a file read, not compute** (2.14 s vs 160.7 s in the measured case); the economics of session persistence are therefore dominated by disk and by *when* you choose to save, not by compute.

---

## 4. Scheduling and batching

### 4.1 llama-server's slot system

`llama-server` is a **single process** multiplexing N concurrent sequences through one shared `llama_context`. Each sequence occupies a **slot** (`server_slot`, internally a `llama_seq_id` in the KV cache) holding its own prompt, sampler state, performance counters and KV range, while all slots share the model weights. The slot count is `--parallel / -np` (default `-1` = auto; the auto value is derived from the context and memory fit, not a fixed number). Requests arriving while all slots are busy **queue** until a slot frees; there is no built-in admission priority documented as stable behaviour — treat queueing as FIFO and verify per build.

Context is a **server-wide budget, not a per-slot budget**, and this is the most commonly misread flag in the project: `-c / --ctx-size N` sizes the KV pool (0 = the model's training context). How that pool is divided depends on the KV mode (§3.2): with the legacy per-slot division, N slots each get roughly `N_ctx / N_slots`; with the unified buffer (`--kv-unified`, default-on only when the slot count is automatic) the pool is shared and slots draw from it dynamically — but explicitly setting `-np 4 -c 16384` without `-kvu` has been observed to leave each slot at 4,096 tokens. **Read the effective per-slot context from `/props` and `/slots` after startup; never trust arithmetic alone.** The server also gained a router mode (`--models-dir`, `--models-max` default 4, `--models-memory-margin`) that loads/unloads several models in one process with an LRU policy — a different axis of concurrency from slots.

### 4.2 Continuous batching, and the two batch sizes

Continuous (dynamic) batching is **enabled by default** (`-cb, --cont-batching`, default: enabled, server README). New sequences join the in-flight batch between decode steps instead of waiting for a batch to drain; each decode step is one forward pass advancing *every* busy slot by one token, and each slot's logits are then sampled independently. Prompt processing and generation are deliberately separated:

- **Logical batch** `-b, --batch-size` (default 2048): the maximum total tokens the scheduler will consider in one logical step — the ceiling on how much prompt can be processed plus how many sequences decode together.
- **Physical micro-batch** `-ub, --ubatch-size` (default 512): the largest chunk actually handed to the backend in one call. A long prompt is split into several ubatches; the scheduler can interleave decode work between them.

The split exists because prompt processing (prefill) is **compute-bound** — many tokens share each weight read, so it wants big matmuls (GEMM) — while token generation (decode) is **memory-bandwidth-bound** — one token per sequence per step, each step re-reading the whole weight set, so the bottleneck is moving weights, not arithmetic. Tuning `-b`/`-ub` is therefore tuning the prefill/decode balance: a large `-b` with a small `-ub` lets a long prompt prefill in pieces without starving in-flight decodes; a large `-ub` maximises prefill throughput on a quiet server. The server's other performance-relevant scheduler facts: prompt processing uses a separate thread count (`-tb, --threads-batch`, defaulting to the generation thread count `-t`), and NUMA options (`--numa distribute|isolate|numactl`) exist for multi-socket machines.

**What llama.cpp's "continuous batching" is *not*.** It is not vLLM-style iteration-level scheduling over a paged KV pool with prefix-aware reuse across requests, and it is not a multi-process engine: tokenization, detokenization, HTTP handling and the scheduler all live in one process, and the slot count is a fixed, pre-allocated resource. For 1–8 concurrent sequences this is an excellent design. Beyond that, the fixed slot grid and per-slot KV reservation become the ceiling (see §7).

### 4.3 Speculative decoding, built in

Speculative decoding is a first-class, documented server feature (`--spec-type`, default `none`). The mechanism, in design terms: a cheap draft proposes K candidate tokens; the target model verifies all K in **one** forward pass, accepts the prefix it agrees with, and replaces the first disagreement with its own token. When acceptance is high, several tokens emerge per target-model pass — the only known way to beat the memory-bandwidth decode wall without changing the output distribution (for the probabilistic sampling variant, the output distribution is preserved by construction; greedy drafting is exact only for greedy decoding).

The current `--spec-type` vocabulary (server README, master, accessed 2026-11-15):

| Type | Idea |
|---|---|
| `draft-simple` | A separate small draft model (`--spec-draft-model, -md`, with its own layer offload `--spec-draft-ngl`/`-ngld`, own KV cache types, own ubatch). **Constraint: the draft must share the target's tokenizer/vocabulary** — cross-family drafting collapses acceptance. Typical draft: same-family 0.5–1.5B for an 8–32B target; draft size is a memory cost (a 0.5B Q4 model is ~0.4 GB) plus its own KV. |
| `draft-mtp` | Multi-Token Prediction heads built into (or shipped as a sidecar to) the target model — the model predicts several future tokens itself, no second model file. Needs an MTP-capable model (e.g. Qwen 3 MTP sidecars). |
| `draft-eagle3` | EAGLE-3 draft head: a trained draft head for a specific target family. Higher acceptance than a generic small model, at the cost of a family-specific artefact. |
| `draft-dflash`, `draft-dflash2`, `draft-dspark`, `draft-lilicorr` | Newer/experimental draft mechanisms in the 2026 codebase (names as listed in the README; treat as fast-moving — check the build's `--help` and changelog before designing against any of them). |
| `ngram-simple`, `ngram-map-k`, `ngram-map-k4v`, `ngram-mod`, `ngram-cache` | **No second model at all**: the draft is a lookup into n-grams seen in the current context (or a static/dynamic lookup cache on disk, `--lookup-cache-static/dynamic`). Particularly effective for repetitive text — code, structured output, repeated boilerplate — where the future literally resembles the past. A self-speculative variant reusing the model's own generation history was introduced for coding workloads (PR #18471 in secondary reporting). |

Tuning knobs that matter: `--spec-draft-n-max` (draft tokens per round; documented default **3**; community practice 4–8, with diminishing returns and rising VRAM pressure past ~8), `--spec-draft-n-min`, `--spec-draft-p-min` (early-abort when draft confidence is low), `--spec-draft-sampling {greedy,probabilistic}`, and `--spec-default` for a canned configuration. The old `--draft-max`/`--draft-min` flags have been **removed** (the README says so explicitly); tutorials still using them will fail.

**Limitation to verify per build.** Multiple 2026 guides report that speculative decoding in llama-server requires **single-slot operation** (`--parallel 1`); one states the server will silently ignore speculative decoding otherwise. This was not confirmed in the current server README text read for this dossier (the README lists the flags without restating the restriction), so treat it as *reported, version-dependent, and mandatory to verify on the exact build* — and as a design fact with large consequences either way: if true, speculation and multi-user concurrency are mutually exclusive in llama-server, and an improved Ollama must choose per deployment (or per model) which it wants.

Expected gains, honestly: the original speculative-decoding paper (Leviathan et al., arXiv:2211.17192) reported 2–3× on T5-XXL, batch 1, one TPU-v4 — narrow conditions. Local community reports cluster around 1.5–2.6× for well-matched same-family pairs on consumer GPUs, and near-zero (or negative, once draft overhead is counted) for cross-family or low-acceptance pairs. **Acceptance rate is the whole game; everything else is plumbing.**


## 5. Memory management

### 5.1 mmap loading and mlock

Model loading is controlled by `--load-mode` (default `auto`):

- `auto` — mmap, unless a device in use does not support it.
- `mmap` — memory-map the GGUF. The file's aligned tensor layout (§2.1) lets the OS page weights in on demand and share pages between processes mapping the same file. Startup is fast; pages can be evicted under memory pressure, which trades latency stability for low resident commitment. This is the default behaviour most users experience.
- `mlock` — force the OS to keep the model resident in RAM (mlock / VirtualLock). Nothing pages out; latency is stable; the full model commits physical memory whether or not it is hot. For dedicated, long-lived servers.
- `mmap+mlock` — both: map for layout/sharing, lock for residency.
- `dio` — DirectIO where available, bypassing the page cache.

`--lazy-mode` (default `auto`) refines this for very large tensors (e.g. per-layer embeddings): `on` reads rows on demand from the mapped file instead of keeping them resident; `auto` does so only for tensors over 4 GiB. The older CLI exposed the same ideas as separate `--mmap` / `--mlock` flags; the consolidated `--load-mode` is the current surface.

### 5.2 Tensor offload: -ngl layer splitting, and the finer tools

The headline knob is `-ngl, --gpu-layers, --n-gpu-layers N` — the maximum number of layers to store in VRAM, accepting a number, `auto` or `all` (**default: `auto`** in current builds; it was 0 in early versions, which is why old tutorials insist on setting it manually). Counting detail worth knowing: libllama counts each transformer block plus the output layer, so a 40-block model reports "offloaded 41/41 layers". Values above the layer count cap out (the folklore `-ngl 99` / `999` = "all" still works for that reason).

What actually moves: an offloaded layer's **weights go to VRAM, and so does that layer's share of the KV cache** (the cache is allocated per layer on the device holding the layer) unless `--no-kv-offload` (`-nkvo`) forces the whole cache to system RAM. Each device also receives a compute buffer sized at context creation — the one memory cost not derivable from the model file. Layers left behind, plus the embedding table, stay in system RAM; the scheduler routes each op to the device holding its weights, paying host↔device copies at the seam.

The finer-grained controls, all present in the current README, are where an improved runner can differentiate:

- `--override-tensor <pattern>=<buffer type>` — per-tensor placement overrides (e.g. pin one hot tensor to GPU while its layer stays on CPU).
- `--cpu-moe` / `--n-cpu-moe N` — keep MoE expert weights (all layers / first N) on CPU; experts are sparsely activated, so this is often the cheapest way to fit a large MoE. `--moe-cache-mib` adds a GPU cache for host-resident experts.
- `--n-cpu-ffn N` — keep dense FFN weights of the first N layers on CPU.
- Multi-GPU: `--split-mode {none,layer,row,tensor}` (default `layer` — pipeline-split layers + KV across GPUs, proportions by free memory or `--tensor-split`; `row` — parallel row split; `tensor` — experimental full tensor split) and `--main-gpu`.
- `--device` / `--list-devices` to constrain the offload target set.

### 5.3 How memory is estimated — and the --fit system

Three components, in order of predictability:

1. **Weights ≈ GGUF file size** (the file is the weights, plus metadata). Exactly knowable before load.
2. **KV cache = the §3.1 formula × context × cache-type factor**, summed over the layers actually holding cache on each device. Exactly knowable from GGUF metadata before load.
3. **Compute buffers + backend context overhead** — sized at context creation, logged at startup ("compute buffer size" in the load log), *not* derivable from the file. Budget 1–2 GB headroom on a discrete GPU as community practice; the honest answer is to read the log line from a trial load.

Since build b7410 (per secondary reporting of PR #16653), **`--fit` is on by default**: for any argument the user left unset, llama.cpp adjusts it to fit free device memory. It starts from "all layers on GPU at full trained context", and if that leaves less than the `--fit-target` margin (default **1024 MiB** per device), it first shrinks the context (never below `--fit-ctx`, default 4096), and only then moves layers back to system RAM (for MoE models, expert weights first). The companion tool `llama-fit-params` prints the flags `--fit` would choose, so a runner can pin them explicitly. **Design significance:** upstream llama.cpp has already absorbed the "guess a safe configuration" job that Ollama's scheduler historically owned. An improved Ollama that still hard-codes conservative defaults without consulting `--fit` is duplicating a worse version of an upstream feature.

### 5.4 Unified-memory behaviour

On Apple Silicon (and other unified-memory systems), CPU and GPU share one physical memory pool. mmap'd weights are not copied into a separate VRAM; Metal tensors can reference the same pages, and "offload" is about *where compute runs*, not about duplicating the model. Practical consequences: the weights+KV budgeting of §5.3 becomes a single-pool budget (no separate VRAM wall); CPU fallback for an unsupported op costs a synchronisation, not a bus transfer; and the machine's total RAM, not a card size, is the model-size ceiling — which is why 32–64 GB Macs run models that no 16 GB discrete card can. The same logic applies, more weakly, to integrated GPUs on x86 APUs via Vulkan/SYCL. A runner that reports "VRAM" as if it were always a discrete quantity will mislead on exactly the hardware where llama.cpp is strongest.

---

## 6. Kernels: where the speed lives

Decode is memory-bandwidth-bound and prefill is compute-bound (§4.2), so the kernels split into two families with opposite shapes:

- **Decode (batch ≈ 1 per sequence): matrix–vector work.** The hot op is a *fused dequantise-and-multiply* kernel: read quantised weights, dequantise on the fly in registers/shared memory, multiply by the activation vector — never materialising the fp16 weight matrix. ggml names these families MMVQ (quantised mat-vec) and MMQ (quantised mat-mat) on CUDA; the CPU equivalents are hand-vectorised dot-product kernels per type and per ISA (AVX2/AVX-512/AMX on x86, NEON/SVE on ARM, RVV on RISC-V); Metal and Vulkan have their own shader equivalents. **This is why quantization speeds up decode at all:** at batch 1, tokens/second is essentially (memory bandwidth) ÷ (bytes of weights read per token), so a 4.5 bpw model is not "a bit smaller" — it is roughly 3.5× less data to stream per token than fp16, and its decode ceiling is roughly 3.5× higher on the same memory system. Kernel quality per (type × backend) pair is uneven — newer IQ types and newer backends routinely lag the Q4_K × CUDA/Metal reference path — and is the main source of "same model, wildly different speed" reports.
- **Prefill / batched decode: matrix–matrix work.** Larger tiles, tensor-core-friendly layouts on CUDA (and cooperative-matrix paths on Vulkan, e.g. int8 coopmat on AMD RDNA3/4 in recent ggml releases), weight *repacking* at load time (`--repack`, default enabled) to match the kernel's preferred layout. Prefill throughput scales with FLOPS; this is where datacentre GPUs pull away and where llama.cpp's general-purpose kernels most visibly trail model-specialised stacks.
- **Attention: Flash Attention.** llama.cpp implements Flash-Attention-style tiled attention (never materialising the full N×N score matrix; attention memory linear rather than quadratic in sequence length) on **CUDA, Metal and Vulkan**, with SYCL receiving (sparse) Flash Attention work in recent ggml releases; `-fa, --flash-attn [on|off|auto]` defaults to **`auto`** (on where the backend supports it, silently off on CPU-only hosts). It is also the gateway feature for quantised V-cache (§3.3). CPU attention remains a conventional (well-vectorised) implementation. Sliding-window-attention models can use a full-size SWA cache via `--swa-full` at a memory cost.
- **Everything else** — RoPE, RMS-norm, softmax, activations, sampling — is individually small but collectively significant at long context; several of these ops are the ones most likely to fall back to CPU on a young backend (§1.3), which is why backend *maturity* (op coverage) matters as much as backend *peak*.

**Design judgement.** llama.cpp's kernel strategy is *breadth-first*: a correct, decent kernel for every (op × type × backend) combination, with deep optimisation concentrated on the highest-traffic combinations. The cost is a long tail of mediocre combinations; the benefit is that a new model or a new chip works on day one at 70% speed instead of not working at all. Any improved runner inherits this trade wholesale the moment it builds on ggml.

---

## 7. Strengths and weaknesses — honest, evidence-tied

### 7.1 Strengths

- **Portability without a runtime.** One C/C++ codebase, no Python, no driver-stack assumptions beyond the chosen backend, running on laptops, phones, Pis, browsers (WebGPU) and servers. No competitor matches the hardware breadth (15+ backends in the README table).
- **GGUF + quantization as an ecosystem standard.** Single-file models, a mature quantisation ladder from ~8.5 bpw down to ~1.5 bpw with honest quality gradations (§2.2), and day-one support for new architectures. The model *supply* is the moat.
- **Predictable memory.** Zero-allocation runtime, exact KV arithmetic, mmap/mlock control, per-layer/per-tensor offload, and now `--fit`. For a single user on a known machine, no engine is easier to reason about.
- **Hybrid execution.** Running a model larger than VRAM by splitting layers (or just MoE experts) across GPU+CPU is a llama.cpp signature that pure-GPU servers simply do not offer.
- **A real server in the box.** OpenAI- and Anthropic-compatible APIs, continuous batching, slot save/restore, speculative decoding, grammar-constrained output, embeddings/reranking, a router mode — `llama-server` alone covers most single-node serving needs.
- **Licence and governance.** MIT, community-driven, extremely active (8,000+ releases/builds in the repo's history; the counter on the repo page read 2026-11-15 shows continuous b-numbered builds). *[Context note: secondary sources report ggml.ai joined Hugging Face in February 2026 with a stated commitment to keep llama.cpp open and community-driven; not verified against a primary announcement for this dossier.]*

### 7.2 Weaknesses

- **Concurrency ceiling.** Fixed slots, pre-divided or simply-shared KV, single-process scheduling. Community benchmarks consistently show the same shape: at 1 request llama.cpp/Ollama and vLLM are within ~10% of each other (e.g. Llama 3.1 8B on an RTX 4090: ~65 tok/s llama.cpp vs ~71 tok/s vLLM-FP16 in one early-2026 compilation — different precisions, so read as "same ballpark", not a ranking); at 8 concurrent requests vLLM leads ~2.3×; at 50, ~6×; at stress concurrency, 10–20× claims recur across sources. The *shape* is robust across every source read; the exact ratios are not (models, quants and GPUs differ per report).
- **No paged KV.** vLLM's PagedAttention stores KV in fixed-size non-contiguous blocks (OS-paging analogy), cutting KV waste from the 60–80% fragmentation range claimed for naive contiguous allocation to under ~4%, and making prefix sharing across requests natural. llama.cpp's cell/range design (§3.1) is more flexible than a naive per-request array but is not a paged allocator: slot KV is still effectively reserved against the pool, and cross-request prefix sharing exists only via the in-slot prompt cache and `--cache-reuse`, not as a global radix/prefix tree (SGLang's RadixAttention is the other reference point here, with up to ~5–6× reported gains on prefix-heavy workloads).
- **Defaults archaeology.** Flag defaults have changed repeatedly (`-ngl`: 0 → all → auto-fit; `-fa` in `llama-bench`: off → auto as late as build b9437, May 2026; server port: 8080 → 9931; `--draft-max` removed). Any wrapper, tutorial or config file older than a few months is suspect. This is a *process* weakness: the project's velocity is its documentation's decay rate.
- **Silent fallbacks and silent discards.** CPU fallback for unsupported ops (§1.3) and middle-discarding context shift (§3.2) both fail *quietly*: the run continues, slower or amnesiac, with no user-visible signal by default. For an engine this is defensible; for a product built on it, it is not.
- **Security posture assumes a trusted local user.** Unauthenticated-by-default server, slot files with no per-user isolation (§3.4), a GGUF parser that has had disclosed vulnerabilities, and a security policy that explicitly places multi-tenant isolation on the operator. llama-server must not be exposed beyond loopback without an authenticating proxy in front of it.
- **Kernel long tail.** §6: breadth-first optimisation means the (type × backend) combination a given user needs may be the slow one, with no workaround except choosing a different quant or backend.

### 7.3 Versus Ollama's use of it — and what Ollama's history teaches

Ollama's relationship to llama.cpp changed fundamentally during the period covered by the sources read, and the dossier must state it as of late 2026, not as of the 2023–2024 folklore ("Ollama is a Go wrapper that vendors a llama.cpp fork"):

- **2023–mid-2025:** Ollama vendored/forked llama.cpp (the `llama.cpp` runner, CGO-linked), adding its Go daemon, model registry, Modelfile system and conservative defaults. Version lag behind upstream and fork drift were recurring community complaints.
- **May 2025:** Ollama announced its own engine built directly on ggml (bypassing libllama) for new multimodal models, citing upstream churn/stability. Secondary post-mortems report this reintroduced bugs upstream had fixed (structured output, vision, missing tensor-type support) — treat the bug list as contested commentary, but the *direction* (fork → drift → pain) is corroborated by what happened next.
- **May 2026 (PR #16031, merged 2026-05-29):** Ollama **removed** its vendored ggml backend, CGO runner and Go model implementations, making upstream **`llama-server` (built via CMake FetchContent, pinned in a `LLAMA_CPP_VERSION` file — `b11232` at the time one source read it) the sole inference engine for GGUF models**, invoked as a subprocess. A temporary `llama/compat/` layer translates already-published Ollama GGUFs whose metadata/layout upstream cannot load directly. On Apple Silicon, Ollama separately moved to **MLX** as the default runtime for supported architectures (previewed in 0.19, March 2026; default in 0.40) — so "Ollama = llama.cpp" is now platform-conditional: llama-server for GGUF elsewhere, MLX on Macs.
- **Consequences for us.** (i) The performance question "llama.cpp vs Ollama" has largely collapsed: on the same GGUF, same quant, same context and same upstream build, they run the same maths; residual differences are *defaults and scheduling policy* (Ollama's daemon, keep-alive, context defaults, parallel settings), not kernels. Claims of "llama.cpp 1.8× faster than Ollama" in older/community benchmarks measure default-configuration differences (and, pre-2026, fork lag), not engine differences — any dossier or decision citing them must date them. (ii) The durable lesson is about **fork economics**: maintaining a private ggml/libllama fork cost Ollama a year and ended in re-convergence on upstream as a subprocess. Our improved Ollama should treat "subprocess + pinned upstream + thin translation layer" as the proven integration pattern, and any urge to patch the engine as a cost centre to be justified per patch. (iii) The remaining differentiation surface is exactly the product layer Ollama still owns: model management, defaults policy, session handling, and the API — which is where §8 aims.

### 7.4 Versus vLLM-class servers, in one paragraph

vLLM (and SGLang) assume a datacentre GPU, many concurrent requests, and throughput as the metric: paged KV, iteration-level scheduling, a pre-allocated KV pool claiming ~90% of VRAM by default (`--gpu-memory-utilization` 0.90–0.92 depending on version/source), CUDA-graph and model-specialised kernels, safetensors/AWQ/GPTQ/FP8 model supply. llama.cpp assumes arbitrary hardware, one user, latency and *ability to run at all* as the metrics: GGUF quants, hybrid offload, mmap, conservative allocation (weights + actual context only). Neither is a failed version of the other. For Volmarr's single-user, character-driven, consumer-GPU use, llama.cpp's assumptions are the correct ones; vLLM's are correct at ~10+ concurrent strangers. An improved Ollama should steal vLLM *ideas* (§8) without importing its *assumptions*.

---

## 8. Ideas to steal for our improved-Ollama work

Each idea states the upstream mechanism, the change we would make, the expected gain, and the cost/risk. Gains are labelled **[measured]** (a number from a source read for this dossier), **[derived]** (arithmetic from verified formulas), or **[speculative]** (engineering judgement, no measurement).

### 8.1 Real sessions: promote slot files into versioned session objects

**Steal:** the slot save/restore primitive (§3.4) — serialised KV + tokens, restore-as-file-read economics.
**Change:** wrap it in a session record that llama.cpp does not provide: model identity (GGUF hash + quant + upstream build), context size and cache types used, the full rendered prompt / chat history, sampler settings, a checksum, and a validity check on restore that *fails loudly* instead of upstream's generic 400. Save policy becomes a product decision (save on idle, save on turn boundary, keep last-K) rather than a manual API call. Namespace saved state per conversation with access control — upstream has none (§7.2).
**Expected gain:** **[measured]** restore ≈2.1 s vs ≈161 s cold prefill for a 7.3k-token prompt on a CPU-only VM; ≈7× on a 5k-token chat in a second measurement. On GPU hardware the absolute numbers shrink but the ratio (file read vs compute) still favours restore for long system prompts / character definitions. Time-to-first-token for a returning conversation becomes near-constant.
**Cost/risk:** disk — sessions are KV-sized (the measured 7.3k-token session was 836 MB for one small model; a 32k-context 8B session at f16 cache is ~4 GiB by §3.1 arithmetic). Requires an eviction policy, quantised-cache sessions (save in q8_0 to halve size, §8.2), and discipline about *not* saving speculatively for short chats where cold prefill is already fast. Privacy: a session file *is* the conversation, in recoverable form; it must be treated as user data, not cache.

### 8.2 An anchor law for context management — where we must *diverge* from llama.cpp

**Upstream behaviour (verified, §3.2):** server context shifting is **off by default** (overflow = generation stops); when enabled — and in the CLI by default — shifting keeps the first `n_keep` tokens and discards a chunk of the *middle*. Protection is purely positional and purely at the *front* of the sequence.
**Why that violates our law:** our character-anchor requirement is that the character definition / system anchor **must not be shiftable-out, ever**. llama.cpp's policy fails that requirement in three distinct ways: (1) if the anchor is longer than `n_keep`, its tail is in the discard zone; (2) if the anchor (or any part of the character state) sits anywhere other than the very front — appended persona blocks, mid-conversation re-anchoring, a character prompt placed at the *end* of the assembled context as our Voxta work requires — the middle-discard treats it as expendable history; (3) the discard is **silent** — no signal reaches the user or the character layer that the model's memory of who it is talking to has been cut.
**Change:** implement eviction at *our* layer, above the engine: (a) the anchor is a separately-managed segment, re-asserted/pinned by construction — it is never part of the evictable token stream; in llama.cpp terms, `n_keep` is set to cover the *entire* anchor segment and the anchor is guaranteed to occupy exactly that prefix (if our design needs the anchor at the end of the prompt for attention reasons, we maintain *two* copies of the guarantee: a pinned prefix copy for the engine's sake, or we disable engine shifting entirely and do our own history compaction); (b) eviction discards oldest *conversation turns* (whole user/assistant pairs), never partial turns and never anchor-adjacent tokens; (c) every eviction/compaction event is logged and surfaced — the character layer should be able to know its memory was trimmed; (d) prefer **summarise-then-evict** (compress dropped turns into a short recap inserted after the anchor) over upstream's raw discard, accepting the extra prefill cost of the recap.
**Expected gain:** **[speculative, but it is a correctness property, not a speed claim]** the failure mode "the character quietly forgot who she is mid-conversation" becomes structurally impossible rather than merely unlikely. This is the single most important divergence in this dossier: llama.cpp's shifting is a *generation-continuation* feature; ours must be a *memory-integrity* feature.
**Cost/risk:** disabling engine shifting means overflow must be handled by our compaction *before* the context fills (headroom monitoring, earlier intervention); summarisation costs a generation pass; pinning a large anchor permanently taxes every context (a 7k-token anchor in an 8k window leaves almost nothing — anchor size discipline becomes a product constraint, and §8.1's session restore is what makes a large pinned anchor affordable).

### 8.3 KV quantization as the default on small GPUs — the 6 GB worked case

**Steal:** independent K/V cache types (§3.3) + Flash Attention.
**Change:** on ≤8 GB GPUs, default to `-fa auto -ctk q8_0 -ctv q8_0` (with a per-model quality escape hatch to f16), instead of upstream's f16 default or Ollama's historically conservative posture.
**Expected gain: [derived]** Llama-3.1-8B-class model (32 layers, 8 KV heads, head_dim 128), Q4_K_M weights ≈4.9 GB, on a **6 GB GPU**: f16 KV costs 128 KiB/token → the ~1 GB left after weights buys under ~8k context *before* compute buffers — in practice the fit system (§5.3) will spill layers to CPU instead. q8_0 KV costs ~64 KiB/token → the same headroom buys roughly **double the context at full GPU offload**, or the same context with materially more headroom for compute buffers and a draft model (§8.4). At 32k context the saving is 4 GiB → ~2.1 GiB **[measured formula, §3.1/§3.3]**. q4_0 V (with q8_0 K — K is empirically the more sensitive of the two) is the aggressive variant for 4 GB cards.
**Cost/risk:** quality — KV quantisation error compounds over long generations (§3.3); it must be validated per model family with perplexity + long-generation spot checks, not assumed. Availability — the Flash Attention prerequisite (§3.3 caveat) means some backends/models cannot take the win; the runner must detect and fall back, loudly. Interaction — quantised KV also halves session-file size (§8.1), a compounding benefit; conversely, changing cache type invalidates saved sessions (another reason sessions need the §8.1 validity record).

### 8.4 Speculative decoding tuned for single-user chat

**Steal:** the full `--spec-type` menu (§4.3), but deployed where it actually pays: **batch-1, single-user, latency-bound chat** — the exact regime where decode is bandwidth-bound and spare compute is idle.
**Change:** (a) default candidate: **n-gram speculation** (`ngram-simple`/`ngram-cache`) for character chat — no second model, no extra VRAM, and character dialogue is unusually repetitive in the favourable way (names, forms of address, recurring phrases, structured scene markers), which is precisely what n-gram lookup exploits; (b) where VRAM headroom exists after §8.3, a same-family small draft (`draft-simple`, 0.5–1B, `--spec-draft-n-max` 4–5) for general text; (c) MTP (`draft-mtp`) opportunistically when the chosen model ships MTP heads — free drafting with no extra model to manage; (d) expose acceptance rate in the UI/logs — it is the only honest signal of whether speculation is helping *this* conversation.
**Expected gain:** **[measured ranges, §4.3]** 1.5–2.6× decode speed for well-matched draft-model pairs in community reports; n-gram gains are workload-dependent and unmeasured for character chat specifically — **[speculative]** expect the high end on repetitive/structured stretches and ~1.0× (no harm beyond lookup cost) on novel prose. Even 1.3× on decode is a large *felt* improvement in chat, where decode is ~all of the wait.
**Cost/risk:** the reported `--parallel 1` restriction (§4.3) means speculation is a single-user feature — the scheduler must disable it cleanly when a second slot is in use, not silently. Draft-model VRAM (mitigated by §8.3). Wrong-family drafts actively hurt; the runner must only auto-pair drafts it has verified share the target's tokenizer. Greedy-vs-probabilistic sampling semantics must be pinned per deployment (§4.3) or output reproducibility claims become false.

### 8.5 Consult --fit, don't reinvent it — and expose what it decided

**Steal:** the `--fit` auto-configuration and `llama-fit-params` (§5.3).
**Change:** our runner asks the engine (or replicates its logic via a trial `llama-fit-params` run) for the fitted configuration instead of shipping its own static defaults table; it then *shows the user* the fitted values (layers offloaded, context chosen, cache types) and lets them pin overrides. This directly attacks llama.cpp's "silent fallback" weakness (§7.2) at the product layer: the engine may guess, but the product must confess.
**Expected gain: [speculative]** eliminates the largest class of "why is it slow / why did my context shrink" support mysteries; converts upstream's hidden heuristics into a visible, correctable contract.
**Cost/risk:** `--fit` behaviour changes between builds (it is young — b7410-era); pin the upstream build (as Ollama now does, §7.3) and snapshot-test the fitted outputs per upgrade.

### 8.6 Prompt-rendering discipline as a caching feature

**Steal:** in-slot prompt caching + `--cache-reuse` (§3.4).
**Change:** treat byte-identical prefix rendering as a *requirement* on our chat-template layer: no timestamps, session ids or volatile metadata ahead of (or inside) the stable prefix; history trimming done in whole turns at a `--cache-reuse`-compatible granularity; slot-prompt-similarity routing if we ever run multiple slots. Combined with §8.2, the rule becomes: *anchor first, byte-stable; history after, turn-aligned; volatility last.*
**Expected gain: [derived from §3.4 mechanics]** in multi-turn chat, per-turn prefill collapses from O(full history) to O(new turn) — for a 7k-token accumulated history with a 200-token new turn, that is the difference between re-processing ~7,200 tokens and ~200, every turn, for free.
**Cost/risk:** template rigidity — any feature that wants per-turn prompt variation (dynamic retrieval, rotating instructions) must be placed *after* the stable prefix or it silently destroys the cache (and, per §7.2, nothing will tell us). Add a `tokens_cached` regression check to our own telemetry: if it trends to zero, the template broke.

### 8.7 What *not* to steal

- **Do not fork ggml/libllama.** Ollama's 2025–2026 detour (§7.3) is the controlled experiment; subprocess + pinned build + compat translation is the proven pattern.
- **Do not copy the fixed-slot scheduler as our concurrency story** if multi-user serving ever becomes a goal; that road leads to vLLM/SGLang territory (paged KV, prefix trees) and should be entered deliberately, with those engines, not by stretching slots.
- **Do not expose llama-server directly** beyond loopback (§7.2): our API layer must authenticate and isolate sessions that upstream leaves open.

---

## 9. Conflicts, gaps and unverified points

- **Speculative decoding × parallel slots:** the `--parallel 1` requirement is asserted by multiple secondary guides but not stated in the current server README text read. *Unverified against source.* Verify on the target build before shipping §8.4.
- **KV-quantization × Flash Attention coupling:** stated as a prerequisite in Ollama's FAQ (via secondary quotation) and in llama.cpp guides; the exact per-backend/per-type matrix was not read from primary source. *Partially verified.*
- **Ollama engine history (§7.3):** the PR #16031 account, dates and the MLX transition come from secondary reporting (BetterClaw, Stribog, Dev.to comparisons) consistent across three independent sources, but the PR itself was not opened for this dossier. *Corroborated, not primary-verified.*
- **GGUF parser CVEs (§2.1):** existence reported in secondary coverage; individual CVE severity/patch status *not verified* against upstream advisories.
- **ggml.ai / Hugging Face (§7.1):** reported by secondary sources (Feb 2026); *not verified* against a primary announcement.
- **All throughput ratios (§7.2):** benchmark compilations disagree in detail (different models, precisions, GPUs); only the *shape* (parity at 1 request, multi-fold vLLM lead at high concurrency) is consistent across every source. No first-party benchmark was run for this dossier.
- **Flag defaults** are stated as of master on 2026-11-15 and *will* drift; the dossier flags the historically unstable ones (`-ngl`, `-fa`, port, draft flags) explicitly.

---

## 10. Sources

All accessed **2026-11-15** unless a different read date is noted in the source itself. Primary sources first.

**Primary (upstream)**
1. llama.cpp repository and README — backends table, description, build/release state. https://github.com/ggml-org/llama.cpp
2. ggml repository and README — tensor library description, zero-allocation and quantization claims. https://github.com/ggml-org/ggml
3. GGUF specification, `ggml/docs/gguf.md` — file layout, metadata typing, standardised keys, `ggml_type` enumeration, alignment. https://github.com/ggml-org/ggml/blob/master/docs/gguf.md
4. llama-server README, `tools/server/README.md` (master) — all flag defaults cited: `-c`, `-b` (2048), `-ub` (512), `-np` (-1 auto), `-cb` (enabled), `--context-shift` (disabled), `-ctk`/`-ctv` (f16; allowed values), `--load-mode`, `-ngl` (auto), `--fit`/`--fit-target` (1024)/`--fit-ctx` (4096), `--kv-unified` (auto-conditional), `--cache-prompt` (enabled), `--cache-reuse` (0), `--cache-ram` (8192), `--ctx-checkpoints` (32), `--slot-save-path` (disabled), `--spec-type` vocabulary, removed `--draft-*` flags, slot save/restore/erase endpoints. https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md

**Secondary (analysis, measurements, history) — used for measurements, comparisons and post-2024 history; load-bearing engine facts above rest on the primary sources**
5. Belgavi, "llama.cpp, in depth" and "GGUF File Format: Layout, K-Quants, imatrix" (aicassindra.com, Oct 2026; flags checked by the author against the server README on 2026-10-02) — request walk-through, KV arithmetic (Llama 3.1 8B, 128 KiB/token, q8_0 ≈2.1 GiB at 32k), unified-KV division caveat, context-shift default-off confirmation.
6. MyAIHardware, "GGUF Quantization Formats: K-Quants and I-Quants Explained" (read Oct–Nov 2026) — super-block structure, bpw table, PR #1684 (merged 2023-06-05) perplexity figures, IQ codebook descriptions.
7. gpu.nz, "GGUF explained" (data as of 2026-10-19; primary-checked by its author 2026-10-20) — Q4_K_M recipe detail (half of attn_v/ffn_down + output at Q6_K; 4.84–4.89 bpw), Ollama/llama.cpp Q4_K_M download defaults.
8. Big Iron guides: "llama.cpp server for multiple users" (2026-06-15) — slot/queue behaviour, per-slot context division; "llama-server Slot Save and Restore" (2026-11-03) — measured save/restore run (Qwen3-1.7B, commit `29c720e`, 7,289-token prompt, 160.7 s cold / 2.14 s restore / 836 MB file), 501-without-path and generic-400 behaviours.
9. Intelligibberish, "Local LLM Prompt Caching" (Oct 2026) — `--cache-prompt`/`--cache-reuse` semantics, `tokens_cached`, KV-type lists, Ollama FAQ KV statement.
10. Tokios docs, "Optimize llama.cpp for speed and memory" — mmap vs mlock practice, flash-attention description, per-layer memory budgeting example.
11. OpenRelay, "--n-gpu-layers in llama.cpp" (2026-10-04; build b11390) — layer counting (blocks + output), `--fit` history (b7410, PR #16653), split modes, KV-follows-layer allocation.
12. Glukhov, "Speculative Decoding" (Nov 2026) and Aliteq, "Speculative Decoding for Local LLMs" (read Oct 2026; docs read 2026-10-03) — `--spec-type` usage, `--spec-draft-n-max` default 3, reported `--parallel 1` requirement, paper figures (arXiv:2211.17192, T5-XXL, TPU-v4, 2–3×).
13. AI-TLDR / SesameDisk / Zolotukhin (imatrix explainers, 2026) — imatrix construction (⟨a²⟩ per channel, PR #4861), IQ-vs-K behaviour, IQ4_XS size/speed deltas (RTX 3090 context).
14. DeepWiki code readings (ggml-org/ggml, llama.cpp, forks; Apr–Oct 2026) — ggml graph/backend/scheduler internals, `ggml_gallocr`, KV-cache class structure, quantize pipeline file/line references. Used for structure, not for behavioural claims.
15. Ollama-history and comparison sources: BetterClaw, "Ollama vs LM Studio vs llama.cpp" (checked 2026-10-27); Stribog, "One Engine, Two Wrappers" (PR #16031 text, `LLAMA_CPP_VERSION` b11232, `llama/compat/`); Dev.to, "llama.cpp vs Ollama" (2026); SleepingRobots, "Friends Don't Let Friends Use Ollama" (polemical — used only for the fork-history timeline, not for its benchmark claims).
16. vLLM comparison sources: InsiderLLM, "llama.cpp vs Ollama vs vLLM: One User vs Many" (2026); SGON.AI on-premise guide (2026-04-03); BestTechGuidePro benchmarks (2026-09) — concurrency throughput shape, PagedAttention waste figures, `gpu_memory_utilization` defaults. Ratios treated as indicative (§9).
17. RunAIHome, "NVMe KV Cache Offloading" (2026-07-29) — slot-save community measurement (5k tokens, 9.9 s vs 1.4 s), auto-persistence feature-request history (#17107, #18244 as reported).
18. Svjatoslav / CLI session notes and old `examples/main` READMEs (via cnb.cool mirrors) — `--prompt-cache`, `--prompt-cache-all`, `--prompt-cache-ro` semantics and the non-determinism caveat.

*End of dossier OR-2.*
