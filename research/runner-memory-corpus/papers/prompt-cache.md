# Prompt Cache — Prompt Cache: Modular Attention Reuse for Low-Latency Inference

## 1. Full citation

- **Title:** Prompt Cache: Modular Attention Reuse for Low-Latency Inference
- **Authors:** In Gim, Guojun Chen, Seung-seob Lee, Nikhil Sarda, Anurag Khandelwal, Lin Zhong
- **Affiliations (as listed in the paper):** Yale University; Google (Sarda)
- **Venue / year:** Proceedings of the 5th MLSys Conference (MLSys 2024), Santa Clara, CA, USA, 2024. arXiv v1 November 2023; v2 April 2024.
- **arXiv:** arXiv:2311.04934 [cs.CL] — https://arxiv.org/abs/2311.04934
- **Code (as reported in the paper):** https://github.com/yale-sys/prompt-cache

## 2. The problem it attacks

Time-to-first-token (TTFT) is dominated by prefill, and prefill cost grows quadratically with prompt length. Yet real prompts are assembled from recurring parts — the same system message, the same documents, the same templates — and conventional KV caching only reuses work *inside* one request. Every new request re-pays the full attention computation for segments the server has already processed many times, which is especially punishing for long-context document QA and for CPU / edge inference where attention is slow.

## 3. Core idea in our own words

Precompute the attention (KV) states of reusable text segments once, store them on the server, and splice them into later prompts instead of recomputing them. The reusable segments are made explicit: the author writes prompts in a small markup (Prompt Markup Language, PML) derived from a **schema**, and each declared segment is a **prompt module** with its own precomputed KV states.

The hard part is position. Attention states depend on where a segment sits, so naive splicing is invalid. Prompt Cache's answer is to assign each module a reserved range of position IDs in the schema and to exploit an empirical finding: models tolerate **discontinuous position IDs** — the position IDs of spliced-together modules do not need to be consecutive for the model to produce good output. At request time the server concatenates the cached KV tensors of the chosen modules (a memory copy, linear in size, instead of quadratic attention compute), computes only the uncached glue text with the correct relative position IDs, and then decodes normally. No model weights change.

Compared with prefix caching (vLLM / SGLang), reuse here is **modular, not positional**: a module can be reused wherever the schema places it, in different combinations and orders — at the price of requiring the author to declare the modules in advance.

## 4. Key design details a runner engineer needs

- **Schema / PML:** a schema defines modules, their position-ID ranges (with gaps left between modules so glue text and parameterised arguments can be slotted in), and parameter slots (marked with unknown-token placeholders whose positions arguments later occupy). Prompts are derived from a schema; modules are populated (prefilled once) when the schema loads.
- **Serving flow:** parse prompt → look up modules → concatenate their cached KV tensors → compute KV only for uncached spans, using position IDs derived from neighbouring modules → decode as usual. Modules are used only to cut TTFT; per-token decode cost is unchanged.
- **Storage tiers:** modules can live in GPU memory (fastest, capacity-limited) or CPU memory (terabyte-scale, pays a host-to-device copy on use). The paper evaluates both and notes a combined tiered cache with replacement / prefetching as future work. Reported KV size: ~0.50 MB/token for Llama-7B and ~0.78 MB/token for Llama-13B (paper's Table 2) — module storage is not cheap and must be budgeted.
- **Architecture adaptations:** ~20 lines per model family in their prototype: RoPE models (Llama-2, Falcon) need a lookup table of rotation matrices indexed by (possibly discontinuous) position ID; ALiBi models (MPT) need the bias matrix built from the same IDs; learned-absolute-embedding models need no change.
- **Batch sharing:** prompts in a batch that use the same module should share one copy via pointer (the paper points to paged attention for this) rather than duplicating KV per request.
- **Implementation base:** prototype on HuggingFace Transformers / PyTorch, ~3K lines of Python, including a buffered concatenation operator to avoid PyTorch's allocate-on-concat behaviour.

## 5. Reported results — as reported, with context

All figures are the paper's own measurements; baseline is ordinary KV-cache inference in the same pipeline.

- **Headline (abstract):** TTFT improvement from **8× for GPU-based inference to 60× for CPU-based inference**, with output accuracy maintained and no model modification.
- **GPU detail (LongBench, Llama-7B class prompts averaging ~5K tokens):** TTFT reduction of **1.5×–3×** when modules are stored in CPU memory and **5×–10×** when stored in GPU memory, consistent across **RTX 4090, A40, and A100**.
- **CPU detail:** up to **70×** TTFT reduction on an **Intel i9-13900K (128 GB DDR5-5600)** system and up to **20×** on an **AMD Ryzen 9 7950X (128 GB DDR4-3600)** system; the authors attribute the gap largely to memory bandwidth. A concrete operating point given in the paper: on RTX 4090 with Llama-7B and 3K context, TTFT fell from ~900 ms to ~90 ms while decode stayed at ~32 ms/token for both systems.
- **Models / data:** Llama-2 (7B, 13B), CodeLlama, MPT-7B, Falcon-7B evaluated on the **LongBench** suite (21 datasets, 4K–10K contexts; documents declared as prompt modules, task instructions left uncached). Accuracy on LongBench tasks was comparable to baseline across models (F1 / Rouge-L / accuracy within noise, with a few per-dataset outliers in both directions in the paper's Table 1).
- **Scaling behaviour (as analysed in the paper):** the win grows with prompt length and model size because attention prefill is quadratic in both sequence length and hidden size, while module reuse costs only a linear memory copy.

## 6. Limitations / what it does not solve

- Modules must be **declared ahead of time** in a schema. Nothing is discovered automatically; ad-hoc user text gets no reuse. This is a programming-model commitment, not a transparent cache.
- Correctness rests on the discontinuous-position-ID behaviour, which is empirical, model-dependent, and (in the base design without extra "scaffolding") can cost accuracy on some tasks — the paper's own LongBench table shows per-dataset movement in both directions, and later work (SGLang's related-work section) reports larger drops for naive modular reuse. Treat per-model validation as mandatory.
- It only accelerates TTFT. Long generations are decode-bound and see no per-token gain.
- Storage cost per module is the full KV footprint of its tokens; a large module library needs eviction policy the paper leaves to future work.
- Prototype-grade: built on HF Transformers, not integrated with paged / continuously-batched production serving in the evaluated system.

## 7. Applicability

### (a) Ollama on a 6 GB consumer GPU running long character chats

- The character-chat prompt is already modular in practice: character card, system instructions, lorebook entries, and the user's persona are stable segments; only the latest exchange changes. Prompt Cache says: precompute those segments once per character, keep them (CPU RAM is plentiful next to a 6 GB GPU — the paper's CPU-memory tier still gave 1.5×–3× on GPU inference, and far more for CPU inference), and splice rather than re-prefill at every turn / restart.
- This is the one paper in the wave whose gains are *largest* on weak hardware: up to 60–70× TTFT claims are CPU numbers. For Ollama users running partially or fully on CPU, modular reuse of a long persona + lore prompt is the difference between a painful pause and an instant reply start.
- The discipline required is prompt structure: lore / character content must be assembled from stable, declared blocks with volatile text kept out of the blocks. Randomised or timestamped text inside a "module" silently destroys its reusability.
- Validation warning transfers directly: spliced position IDs are an approximation. For roleplay the failure mode is subtle quality drift, not a crash — A/B a character with and without module splicing before shipping it as a default.

### (b) Project Aesir (Mojo runner — sessions, prefix memory, hybrid SSM models)

- Prompt Cache is the complement to RadixAttention in Aesir's design space: radix handles *discovered* sharing (whatever prefixes happen to match); prompt modules handle *declared* sharing (persona, scenario, lore packs the application knows are reusable). Aesir should support both: declared modules get pinned storage and guaranteed position ranges; discovered prefixes get the opportunistic tree.
- The position-ID reservation scheme is directly reusable: Aesir's prompt assembler should allocate position ranges per module with deliberate gaps, so sessions can add / remove lore modules without invalidating every other module's cached state.
- For hybrid SSM models the module concept needs care: attention KV splices cleanly, but an SSM state is a function of the entire preceding sequence and cannot be spliced mid-stream. Declared modules for hybrid models are therefore only valid at sequence start (as a state checkpoint) unless Aesir defines an explicit state-composition rule — flag this as an open design question, not a solved port.
- Storage accounting from the paper (≈0.5 MB/token at 7B scale) should anchor Aesir's module-store budgeting on small devices.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2311.04934
- arXiv HTML (read for design + evaluation detail): https://arxiv.org/html/2311.04934v2
- MLSys proceedings PDF: https://proceedings.mlsys.org/paper_files/paper/2024/file/a66caa1703fe34705a4368c3014c1966-Paper-Conference.pdf
