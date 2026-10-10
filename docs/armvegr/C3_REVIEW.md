# MÍMISBRUNNR Campaign C3 Review — ARMVEGR CPU Pipeline Verdict

**Date:** 2026-10-10
**Campaign:** C3 — Loaders, Tokenizer, KV Cache (H041–H060)
**Reviewer:** Yrsa Freydisdottir (replacement worker 69eddd77)
**Scope:** `armvegr/` pure-Mojo CPU inference substrate

## Per-Component Table

| Component | Slice(s) | Test Coverage | Worst Measured Error | Evidence Path |
|-----------|----------|---------------|----------------------|---------------|
| GGUFSeer ARM64 port | H041 | 6-file corpus, v2+v3, 8 dtypes; byte-identical x86_64 vs ARM64 | 0 bytes diff | `data/armvegr/gguf_port_diff.txt` (empty) |
| GGUF tensor loader | H042 | 68 tensors byte-identical across arches; 1.1GB sparse GGUF at 320 KiB RSS; 3 corrupt files fail closed | 0 bytes diff (sha256 49391f64… both) | `data/armvegr/gguf_loader_xcheck.txt` |
| safetensors parser | H043 | 5 real files match Python; 6 adversarial headers fail closed | 0 bytes diff | `data/armvegr/safetensors_xcheck.txt` |
| safetensors loader | H044 | 65536-pattern BF16 exhaustive bit-exact both arches; 18-tensor checksums identical | 0 bits diff (3f8e1497…) | `tests/h044_bf16_exhaust.mojo` |
| Weight layout planner | H045 | 6-tensor model; packed vs naive max err 0.0; byte-identical plan JSON | 0.0 | `tests/c3_h045_layout.mojo` |
| BPE tokenizer | H046 | 50/50 exact vs tiktoken 0.14.0; 1000/1000 round-trip both arches | 0 mismatches | `data/armvegr/gpt2_bpe.bin` |
| SentencePiece tokenizer | H047 | 200/200 exact vs sentencepiece 0.2.2; 300/300 round-trip both arches | 0 mismatches | `data/armvegr/tinyllama_tokenizer.model` |
| Differential suite | H048 | 3000 assertions (750+750 encode, 1500 round-trip) | 0 failures | `prof/armvegr/test_tokenizers.py` (H048-ALL-PASS) |
| Tokenizer configs | H049 | 3 families (gpt2, llama, mistral); fail-closed on unknown | 0 failures | `data/armvegr/model_tokenizer_configs.json` |
| KV cache | H050–H052 | 256 steps cache-vs-recompute max err 1.06e-4; sliding window correct; 4/4 OOB fail-closed | 1.06e-4 ≤ 1e-3 | `tests/c3_h051_kvcheck.mojo` |
| Sampler | H053–H057 | Greedy/temp/top-k/top-p/rep-penalty; 2000 draws no leaks; PRNG fixed | 0 failures | `tests/c3_h053_sampler.mojo` |
| CPU smoke test | H058 | 20 tokens, crash detection, perf JSON | 0.053s wall | `prof/armvegr/test_cpu_smoke.py` (H058-ALL-PASS) |
| Q6_K dequant | H059 (partial) | Matches Python reference implementation | <1e-4 vs Python | `armvegr/quant.mojo` (`q6k_to_fp16`) |
| TinyLlama inference | H059 | **BLOCKED** — output incoherent (see below) | N/A | `armvegr/infer.mojo`, `tests/c3_h059_infer.mojo` |

## H059 Blocker Detail

**Goal:** Load TinyLlama-1.1B-Chat-v1.0 Q4_0 GGUF, generate coherent text.

**What was built:**
- `armvegr/infer.mojo`: `TinyLlama` struct (loads + dequantizes all 201 tensors to FP16) + `Inference` struct (decode loop: embedding → 22× [RMSNorm → GQA attention with RoPE → residual → RMSNorm → SwiGLU FFN → residual] → final norm → LM head → sampler).
- Q6_K support in `armvegr/quant.mojo` and `armvegr/gguf_loader.mojo` (required for `output.weight`, dtype 14).
- `tests/c3_h059_infer.mojo`: driver with chat prompt.

**Bugs found and fixed:**
1. `fp16_from_bits` flushed subnormals to zero; Q6_K scales can be subnormal (e.g., bits=851 → 5e-5). Fixed to handle subnormals correctly. Verified: Mojo Q6_K matches Python dequant (<1e-4).
2. Driver forwarded last prompt token twice (prefill + decode both processed it). Fixed.
3. `rope_fp16` called with `theta=10000.0` instead of `ln_theta=log(10000.0)≈9.21`. Fixed.

**Components verified:**
- Q6_K dequant matches Python reference (first 10 values: [-0.01379, -0.02597, 0.00324, …] both).
- `gemv_fp16` correct on known case ([[1,2,3],[4,5,6]] @ [1,1,1] = [6,15]).
- `rope_fp16` correct in isolation (pos=1: y0≈-0.301, y1≈1.381 as expected).
- All 201 tensors load with correct sizes (e.g., `token_embd.weight` 65,536,000; `output.weight` 65,536,000).
- Tokenizer correct: "Hello" → [15043] → "Hello"; 15043 decodes to "Hello".

**Observed failure:**
- Prompt "Hello" (1 token) → greedy next token 28633 ("nederbörd", logit 14.35). Expected: " world", ",", "!", or similar.
- Chat prompt (35 tokens) → 20 tokens of Cyrillic/Latin fragments ("ограограmulticolesseur…"), not coherent English.
- Logit distribution is peaked (entropy 4.73 vs uniform 10.37) but peak is wrong token.
- 1-layer ablation still garbage; embedding→norm→head bypass also garbage (but bypass is not a valid test).

**Root cause:** Not isolated. Suspects (in order): (a) weight matrix layout/transpose misunderstanding for Q/K/V/O projections; (b) subtle RoPE application error (e.g., wrong head_dim indexing); (c) attention mask/scale error; (d) corrupted model file. Requires differential debugging against a reference implementation (e.g., llama.cpp or transformers) with intermediate activation comparison.

**Honest assessment:** Per the fail-closed law, H059 cannot be marked complete. The scaffolding is real and the fixed bugs were genuine, but coherent generation is not achieved.

## L2 / L3 / L9 Confirmation

- **L2 (no Python in shipped path):** CONFIRMED. All shipped code under `armvegr/` is pure Mojo. Python appears only in `prof/` (H048, H058) and `tests/` drivers, per the authorized "Python TESTS ONLY" law. `git log --name-only` shows no `.py` files under `armvegr/`.
- **L3 (no HEF involved anywhere):** CONFIRMED. C3 is CPU-only; no Hailo Encoding Format files, no HEF-related code paths. `grep -ri "hef" armvegr/` returns nothing.
- **L9 (zero `cuda_*` edits across C2–C3):** CONFIRMED. `git log --oneline --name-only main` filtered for `cuda_*` shows zero commits touching CUDA modules in the C3 range (H041–H060). The only non-additive edit was the two authorized `gguf.mojo` touchpoints (Finding A).

## C3 VERDICT: REMEDIATION REQUIRED

**Verdict:** **F1-CORE-NOT-READY** — Campaign C3 is **NOT** complete.

**Rationale:** H041–H058 are complete and verified (all green, both arches where applicable). H059 is blocked: the TinyLlama inference pipeline does not produce coherent output despite genuine bug fixes and component verification. The F1 milestone ("coherent text on the pure-Mojo CPU path") is not achieved.

**Named remediation slices:**
- **H059R1 — Differential debug vs reference:** Implement a NumPy/Python reference for 1 transformer layer using the dequantized weights; compare intermediate activations (post-QKV, post-RoPE, post-attention, post-FFN) to isolate the divergence. (Estimated: 1 slice)
- **H059R2 — Fix and verify coherence:** Apply the fix from H059R1; re-run H059 acceptance (3 prompts, ≥50 tokens each, rubric ≥6/6). If the model file is corrupted, re-download and re-verify SHA-256. (Estimated: 1 slice)
- **H059R3 — Mimir cross-check:** Run the coherent generation on Mimir (ARM64) to confirm portability. (Estimated: 1 slice)

**What IS ready:** The loader substrate (H041–H045), tokenizers (H046–H049), KV-cache (H050–H052), sampler (H053–H057), and smoke test (H058) are solid, tested, and portable. The Q6_K dequantizer is correct. The inference scaffolding (`armvegr/infer.mojo`) is structurally sound and will support the remediation.

**Recommendation:** Execute H059R1–R3 before declaring F1 complete. Do not proceed to C4 (Hailo driver) until the CPU pipeline demonstrably generates coherent text, as C4 builds on the F1 core.
