# KIVI — KIVI: A Tuning-Free Asymmetric 2bit Quantization for KV Cache

## 1. Full citation

- **Title:** KIVI: A Tuning-Free Asymmetric 2bit Quantization for KV Cache
- **Authors:** Zirui Liu, Jiayi Yuan, Hongye Jin, Shaochen Zhong, Zhaozhuo Xu, Vladimir Braverman, Beidi Chen, Xia Hu
- **Venue / year:** Proceedings of the 41st International Conference on Machine Learning (ICML 2024), PMLR 235:32332–32344
- **arXiv:** arXiv:2402.02750 [cs.CL] — v1 5 February 2024; v2 25 July 2024 — https://arxiv.org/abs/2402.02750
- **Code (as reported in the paper):** https://github.com/jy-yuan/KIVI

## 2. The problem it attacks

Batching many requests is how serving cost per request falls, but the KV cache grows with batch size × context length until it is the memory *and* bandwidth bottleneck: the paper's scale examples are ~3 TB of KV cache for 540B PaLM at batch 512 × 2048 tokens, and 1.2 TB for OPT-175B at batch 512 × 512 prompt × 32 generated tokens. Quantising the cache to fewer bits is the obvious lever, yet prior work had mostly applied vanilla 4-bit round-to-nearest per-token quantisation, and nobody had systematically studied *the element distribution* of the KV cache to learn what actually breaks at 2 bits. KIVI is that distribution study, plus the quantisation scheme the study dictates.

## 3. Core idea in our own words

Keys and values have opposite outlier geometry, so they must be quantised along opposite axes:

- **Keys: a few fixed channels are always huge.** In the key cache, a small set of channels carries very large magnitudes for essentially every token (the same outlier-channel phenomenon known from activation quantisation). If you quantise **per-token** (one scale/zero-point shared across all channels of one token), those outlier channels stretch the range for the whole token and crush every normal channel into a couple of levels. If you quantise **per-channel** (group elements *along the token dimension within one channel*, one scale per channel-group), each outlier channel gets its own range and the error is confined inside that channel. Measured on Llama-2-13B at 2 bits, per-token key quantisation gives ~5× larger attention-score error than per-channel (relative Frobenius error 47.00 vs 9.60; key reconstruction error 13.67 vs 4.55).
- **Values: no channel pattern — but values are a mixer.** The value cache shows no fixed outlier channels, and on reconstruction error alone per-channel and per-token look similar (3.73 vs 4.57). The deciding fact is how values are *used*: the attention output is a sparse weighted sum over tokens' value vectors. Per-token quantisation confines each token's error to that token, so the few heavily-attended tokens keep their accuracy and the errors of ignored tokens never enter the output. Per-channel quantisation smears error across tokens. Measured attention-output error: per-token 3.55 vs per-channel 49.89 — roughly 14× worse the wrong way round.

The fake-quantisation ablation (Llama-2-13B, group size 32, CoQA exact-match / TruthfulQA BLEU) makes the asymmetry brutal: 16-bit scores 66.37 / 29.53; 2-bit (K per-channel, V per-token) scores 63.53 / 28.60; 2-bit (K per-token, V per-token) falls to 52.93 / 24.98; and *any* configuration with V per-channel collapses to ~2.8 / ~0.3–0.7. The axis choice, not the bit count, is what kills you.

KIVI is the deployable form of that finding: asymmetric 2-bit (or 4-bit) group quantisation, **tuning-free** — no calibration data, no fine-tuning, plug-and-play on an existing model.

## 4. Key design details a runner engineer needs

- **The streaming problem and the residual cache.** Per-token value quantisation streams naturally (quantise each new token on arrival, append). Per-channel key quantisation does not: a channel group's scale is computed over a group of *tokens*, which arrive one at a time. KIVI's solution is a split cache: a **grouped** part, quantised in groups of G tokens, plus a **residual** part holding the most recent R tokens in full FP16. New K/V land in the residual; when the residual fills, its oldest block is quantised and appended to the grouped part. Defaults in the paper: **group size G = 32, residual length R = 128** (the efficiency run also tests R = 32).
- **The residual is not overhead, it is load-bearing.** Fake 2-bit quantisation of *everything* (no residual) drops Llama-2-7B GSM8K exact-match to 5.76; KIVI-2 with its FP16 residual window scores 12.74 against a 13.50 FP16 baseline. Recent tokens are exactly the ones local reasoning attends to hardest; keeping a short FP16 sliding window is what makes 2 bits survivable on hard generation tasks. Effective window: ~R/2 for keys, R for values by the paper's accounting.
- **Attention is computed in two tiles.** Scores against the grouped part use a mixed-precision matmul (Q_MatMul) that fuses dequantisation into the matmul at tile level (CUDA); scores against the FP16 residual use the ordinary path; the two score blocks are concatenated before softmax. Group quantisation itself is a Triton kernel. Prefill passes the *exact* K/V to the next layer — only the retained cache is quantised — so quantisation error does not compound through prefill layers.
- **Hyperparameter sensitivity (paper's ablation, Llama-2-13B GSM8K):** group size 32 → 20.77, 64 → 21.00, 128 → 17.29 (large groups hurt). Residual length shows no monotone pattern across {32, 64, 96, 128} but must not be tiny.
- **Composes with weight-only quantisation** (the paper states full compatibility) and, conceptually, with eviction and paging — it changes the *precision* of what is stored, not *which* tokens are stored. All tokens are retained.

## 5. Reported results — as reported, with context

All figures are the paper's own measurements.

- **Headline efficiency (Llama-2-7B, single NVIDIA A100-80GB, ShareGPT-derived workload, mean prompt 161 tokens / mean generation 338 tokens, batch grown until OOM):** KIVI-2 uses **2.6× less peak memory including model weights** than the FP16 baseline, enables up to **4× larger batch size**, and delivers **2.35×–3.47× throughput**. The authors note the gain grows with longer contexts; at chat-length prompts the KV cache is a smaller share of memory, so expect the low end or less.
- **Generation quality, LM-Eval tasks (exact-match for CoQA/GSM8K, BLEU for TruthfulQA):**
  - Llama-2-7B: 16-bit CoQA 63.88 / TruthfulQA 30.76 / GSM8K 13.50 → KIVI-2 63.05 / 33.95 / 12.74; KIVI-4 63.78 / 30.80 / 13.80.
  - Llama-2-13B: 16-bit 66.37 / 29.53 / 22.67 → KIVI-2 66.23 / 29.84 / 20.77.
  - Mistral-7B: 16-bit GSM8K 38.36 → KIVI-2 36.01.
  - **Falcon-7B is the exception:** 16-bit GSM8K 4.55 → KIVI-2 3.41, and the paper states 4-bit KIVI is needed to hold Falcon's accuracy. Falcon uses multi-query attention (a single KV head), so its cache is already head-compressed and has less redundancy left to squeeze.
- **LongBench (8-task subset: Qasper, QMSum, MultiNews, TREC, TriviaQA, SAMSum, LCC, RepoBench-P; max length 4096, 8192 for Mistral):** Llama-2-7B average 44.52 (16-bit) vs 44.27 (KIVI-2) vs 44.59 (KIVI-4); Llama-2-13B 44.85 vs 44.69; Mistral-7B 46.58 vs 45.85. Needle-in-a-haystack retrieval is reported as retained at 2 bits for Llama-3-8B-Instruct and Mistral-7B-Instruct-v0.2 (appendix figures).

## 6. Limitations / what it does not solve

- It compresses bytes per token, not token count: memory still grows linearly with context and batch. For a single long chat (batch 1), the win is longer context in the same memory, not the batch/throughput headline, which is a batched-serving result.
- The FP16 residual (up to 128 tokens × K and V × every layer) is a fixed tax that matters at very short contexts — at a 512-token context a quarter of the cache is unquantised by design.
- Falcon/MQA result is the warning label: the more a model's cache is already architecturally compressed (MQA, aggressive GQA), the less headroom 2-bit quantisation has, and the paper's own fix is to fall back to 4 bits.
- Evaluation ceiling: LongBench runs are capped at 4096 tokens for most models (8192 Mistral); nothing in the paper validates 2-bit caches at 32K+ contexts, where grouped per-channel scales must survive far more diverse token populations.
- The implementation is HuggingFace-Transformers-based research code with custom Triton/CUDA kernels; the paper lists further fusion of the quantisation step itself as future work, i.e. prefill/decode quantisation overhead is real in the reference implementation.

## 7. Applicability

### (a) Ollama on a 6 GB consumer GPU

- **This is a runtime policy, fully retrofittable.** KIVI needs no training, no calibration set, and no change to the model file: any existing GGUF model can in principle be served with a KIVI-style cache. What it needs is runner support — grouped per-channel key quantisation, per-token value quantisation, an FP16 residual window, and a fused dequantise-in-attention kernel. That is a llama.cpp-class engineering project, not a flag flip: Ollama's existing KV-cache precision options are uniform schemes, not this asymmetric grouped design, so do not mistake "KV quantisation exists" for "KIVI exists".
- **Why it matters at 6 GB, in arithmetic** (worked example, not a paper figure): a 7B-class GQA model with 32 layers, 8 KV heads, head-dim 128 stores 2 × 32 × 8 × 128 × 2 bytes = 128 KiB of FP16 KV per token — 1 GiB per 8K tokens of chat. A KIVI-2-style cache cuts the grouped portion ~8×, bringing an 8K context's cache to roughly 150–200 MB including the FP16 residual and scales. On a 6 GB card where weights already take ~4–5 GB, that is the difference between an 8K chat fitting beside the weights and not fitting at all.
- **Chat-specific caution:** the paper's own GSM8K result is the relevant warning for roleplay too — the FP16 residual window is doing real work for local coherence. Any Ollama-side implementation that drops the residual to save the last megabytes will land on the fake-quantisation numbers (GSM8K 5.76 vs 13.50), not the KIVI numbers. Keep R ≈ 128.
- KIVI composes with eviction (SnapKV/PyramidKV) and with StreamingLLM-style pinning: quantise what you keep. Combined, they multiply — fewer tokens, each cheaper.

### (b) Project Aesir (Mojo runner — sessions, prefix memory, hybrid SSM models)

- Aesir should adopt the asymmetry as a *format decision*, not a runtime afterthought: the cache block format should natively be "keys grouped per-channel, values per-token, newest block(s) FP16". Retrofitting per-channel grouping onto a cache laid out per-token is a rewrite; designing the block layout around it from the start is free.
- The residual window maps cleanly onto Aesir's session model: the FP16 residual is the live tail of the session; when a session is checkpointed to prefix memory / disk, its tail quantises into grouped blocks. That gives a natural two-tier persistence format (hot FP16 tail, cold 2-bit body) with the paper's quality evidence behind the split.
- Kernel requirement to record: the fused dequantise-in-matmul tile path (Q_MatMul analogue) must exist in Aesir's attention kernels for both the grouped and residual tiles, with scores concatenated pre-softmax. In Mojo this is one kernel with two tile sources — design it that way rather than materialising dequantised K/V.
- For hybrid SSM models, MLA-style thinking does not apply (no KV in SSM layers), but attention layers benefit identically; note the Falcon lesson — hybrids whose attention layers already use few KV heads should default to 4-bit cache quantisation, with 2-bit as an opt-in validated per model.
- Evaluation discipline: report any Aesir cache-quantisation mode the KIVI way — named generation benchmarks (a reasoning task like GSM8K is the canary) at 16-bit vs the quantised mode, never perplexity alone.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2402.02750
- arXiv HTML (read for method + evaluation detail): https://arxiv.org/html/2402.02750v2
- ICML 2024 proceedings (PMLR): https://proceedings.mlr.press/v235/liu24bz.html
