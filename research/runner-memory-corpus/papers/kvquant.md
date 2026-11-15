# KVQuant — KVQuant: Towards 10 Million Context Length LLM Inference with KV Cache Quantization

## 1. Full citation

- **Title:** KVQuant: Towards 10 Million Context Length LLM Inference with KV Cache Quantization
- **Authors:** Coleman Hooper, Sehoon Kim, Hiva Mohammadzadeh, Michael W. Mahoney, Yakun Sophia Shao, Kurt Keutzer, Amir Gholami
- **Affiliations (as listed in the paper):** University of California, Berkeley; ICSI; LBNL
- **Venue / year:** Advances in Neural Information Processing Systems 37 (NeurIPS 2024), Vancouver, BC, Canada, December 2024 (arXiv record comment: "NeurIPS 2024")
- **arXiv:** arXiv:2401.18079 [cs.LG] — v1 31 January 2024; v6 28 May 2025 — https://arxiv.org/abs/2401.18079
- **Code (as reported in the paper):** https://github.com/SqueezeAILab/KVQuant

## 2. The problem it attacks

For long-context applications (document analysis, summarisation, retrieval over huge inputs) the KV cache — not the weights — becomes the dominant memory consumer, growing as 2 · layers · heads · head-dim · bytes · batch · length. Quantisation is the natural compression, but existing schemes fail below 4 bits: naive 3-bit and 2-bit quantisation destroys perplexity (in the paper's Table 1, uniform int3 on LLaMA-7B already degrades WikiText-2 perplexity from 5.68 to 10.87, and int2 explodes to 11779). KVQuant asks what combination of distribution-matching tricks makes *sub-4-bit* KV quantisation accurate — accurate enough that the memory arithmetic for million-token contexts closes.

## 3. Core idea in our own words

KVQuant is a stack of five mutually reinforcing fixes, each aimed at a measured failure mode. It shares KIVI's central asymmetry — **keys per-channel, values per-token** — and then goes further:

1. **Per-Channel Key Quantization.** Pre-RoPE keys have persistent outlier *channels* (large average magnitude in the same channels across tokens); values have no such fixed pattern. Grouping the scale/zero-point along the channel for keys (per-token for values) groups like magnitudes together. Alone, this switch is worth a **3.82 perplexity improvement on WikiText-2 for 3-bit LLaMA-7B** (paper, §3.1 / Appendix G).
2. **Pre-RoPE Key Quantization — the genuinely new move.** RoPE rotates each pair of key channels by a position-dependent angle, which *mixes* channel pairs differently at every position and thereby smears the clean per-channel outlier structure. Quantising keys *after* RoPE therefore quantises a scrambled distribution. KVQuant quantises keys **before** RoPE is applied, caches the pre-RoPE quantised keys, and applies RoPE on-the-fly after dequantisation inside a fused kernel. Worth **0.82 perplexity on WikiText-2 for 3-bit LLaMA-7B** (Appendix H). This is also the deepest kernel intrusion of any paper in this wave: the runner's cache can no longer store the post-RoPE keys every existing engine stores.
3. **Non-Uniform Quantization (nuqX).** With only 4–8 levels at 2–3 bits, *where* the levels sit matters as much as how many there are. KVQuant derives per-layer datatypes offline: a sensitivity-weighted k-means (weights from the diagonal Fisher information on a calibration set) places the non-uniform signposts where the distribution is dense *and* the model is sensitive. Each vector is normalised to [−1, 1] and rescaled per-channel/per-token at runtime, so one offline datatype serves online quantisation. Worth **0.29 perplexity vs 3-bit uniform on WikiText-2, LLaMA-7B** (Appendix I).
4. **Per-Vector Dense-and-Sparse Quantization.** Even matched distributions are skewed by a few extreme values that stretch the range. KVQuant extracts outliers **per vector** (per channel for keys, per token for values — a separate threshold at the same granularity as the scale factor) and stores them sparsely (CSR/CSC) in full precision, quantising only the well-behaved bulk. Removing just **1% of elements as outliers** is worth a further **0.19 perplexity** step in the paper's worked LLaMA-7B chain, landing within 0.07 of the FP16 baseline at 3 bits.
5. **Attention-Sink-Aware Quantization.** The first token attracts outsized attention (the attention sink) and is disproportionately sensitive to quantisation error; KVQuant simply keeps token 0 in FP16 and excludes it from calibration statistics. Cheap, and worth most at 2 bits.

Unlike KIVI, KVQuant is **not tuning-free**: key scales, outlier thresholds, and the nuq datatypes are calibrated offline (the paper's main runs use 16 calibration samples of 2K tokens from the WikiText-2 training set). Value scales and outlier thresholds, which cannot be calibrated offline because of outlier value tokens, are computed online per token, with threshold computation offloaded to CPU in the reference implementation.

## 4. Key design details a runner engineer needs

- **Naming:** `nuqX-Y%` = X-bit non-uniform datatype with Y% of elements held out as sparse FP16 outliers. Effective bit width is higher than X: at 32K context, nuq3-1% averages **3.33 bits** and nuq2-1% **2.33 bits** once scales and the sparse matrix are counted. Always compare on effective bits, not headline bits — KIVI-2's equivalent figure in the same tables is ~3.05 bits (group 32, residual 128).
- **Offline vs online split:** keys — offline-calibrated per-channel scales (the paper shows online per-channel scale updates are both expensive and unnecessary); values — online per-token scales and thresholds. A runner must support both paths simultaneously, in different kernels for K and V.
- **Storage formats:** dense part stored as X-bit indices into a per-layer lookup table of FP16 signposts; outliers as CSR or CSC sparse matrices (orientation chosen to suit appending new tokens). Dequantisation is a table lookup, not an affine rescale — kernels must be built for gather-from-LUT.
- **Kernels:** custom CUDA kernels perform quantise-on-append, the dense matvec against the LUT-dequantised cache, the sparse outlier matvec, and fused post-dequantisation RoPE for keys. Benchmarked on an **NVIDIA A6000** for LLaMA-2-7B-32K: at sequence length 16K, Key matvec 219.4 µs (FP16) → 126.3 µs (nuq4-1%); Value matvec 203.7 µs → 124.5 µs. The paper's abstract summarises this as **up to ~1.7× speedup vs FP16 matrix-vector multiplication for LLaMA-7B**. Decode is bandwidth-bound, so the speedup tracks the byte reduction minus LUT/sparse overhead.
- **Composes with weight quantisation:** combined with SqueezeLLM weight quantisation (w4/w3 dense-and-sparse), KV nuq4-1% adds only ~0.02 perplexity over the weight-quantised baseline on LLaMA-7B/13B (WikiText-2).

## 5. Reported results — as reported, with context

All figures are the paper's own measurements. Perplexity is teacher-forced WikiText-2 unless named otherwise.

- **Headline quality claim:** with 1% outliers held out, **4-bit: < 0.02 perplexity degradation and 3.7× cache-memory saving; 3-bit: < 0.1 degradation and 4.8× saving; 2-bit: < 0.5 degradation and 6.9× saving** — stated across the LLaMA, Llama-2, Llama-3, and Mistral families on both WikiText-2 and C4.
- **Table 1 detail (WikiText-2 perplexity / KV cache at 128K context):** LLaMA-7B FP16 baseline 5.68 / 64.0 GB → KVQuant-4bit 5.72, −4bit-1% 5.69 / 17.3 GB; −3bit 5.87, **−3bit-1% 5.75 / 13.3 GB**; −2bit 7.23, −2bit-1% 6.01 / 9.3 GB. LLaMA-65B FP16 3.53 / 320 GB → −3bit-1% 3.57 / 66.5 GB. Baselines at the same bits are far worse (e.g. LLaMA-7B int3 10.87, FlexGen-3bit 5.93, ATOM-3bit 6.17).
- **Retrieval, where KVQuant separates from KIVI:** passkey retrieval (50 samples per length) on LLaMA-2-7B-32K: nuq2-1% scores 1.00 / 1.00 / 0.98 / 1.00 / 1.00 at 2K/4K/8K/16K/32K, vs KIVI-2 (group 32, residual 128) at 0.76 / 0.72 / 0.72 / 0.68 / 0.70. The paper's explanation: KIVI's FP16 residual privileges the recent tail, while KVQuant represents all positions uniformly. On **RULER** (LLaMA-2-7B-32K, 32K max context): FP16 average 56.40 → KVQuant-3bit-1% 53.65 vs KIVI-2 39.78; KVQuant-2bit-1% 36.54. On **LongBench** (same model): FP16 31.96 → KVQuant-3bit-1% 31.21 vs KIVI-2 30.04.
- **The million-context claim, stated precisely:** the 2-bit configuration gives 8× KV compression, under which the paper's memory tables fit LLaMA-7B with **1M context on a single A100-80GB (≈64 GB of KV cache)** and **10M context on an 8-GPU system**; nuq4-1% (3.7×) fits LLaMA-65B at 32K on one A100, and nuq3 fits LLaMA-65B at 1M on 8 GPUs. These are capacity computations from the cache-size tables, backed by quality evaluation at up to 32K context — not end-to-end quality measurements at 1M tokens.
- **Kernel speed:** up to ~1.7× vs FP16 matvec (see §4 for the A6000 numbers behind the claim).

## 6. Limitations / what it does not solve

- **Calibration dependence.** The nuq datatypes, key scales, and thresholds are derived from calibration data (WikiText-2 samples in the paper). A model or domain far from the calibration distribution is an unmeasured risk, and every new model needs its calibration artefacts produced and shipped alongside it — an operational cost KIVI deliberately avoids.
- **2 bits is still lossy in absolute terms.** The "< 0.5 perplexity degradation at 2-bit" headline hides spread: LLaMA-7B nuq2-1% is +0.33 on WikiText-2 but the RULER average falls from 56.40 to 36.54. Retrieval-heavy and multi-needle tasks degrade far more than perplexity suggests. 3-bit-1% is the configuration the evidence actually supports as near-lossless.
- **Pre-RoPE caching is invasive.** It requires the attention kernel to dequantise → apply RoPE → score as one fused operation, and the cache format is incompatible with any engine (or prefix-cache store) that assumes post-RoPE keys. Persisted KV artefacts in KVQuant format cannot be consumed by a standard runner.
- **Complexity budget.** Five interacting mechanisms, two calibration pipelines, a sparse side-matrix, LUT dequantisation, and CPU-offloaded threshold computation is a large surface for a small team to implement and validate; each mechanism's individual gain (0.19–0.82 perplexity) is modest — the stack only pays off whole.
- Quality evaluation is perplexity-centric (WikiText-2/C4) plus LongBench/RULER/passkey at ≤32K; there is no chat-quality or long-generation evaluation comparable to KIVI's GSM8K/CoQA suite.

## 7. Applicability

### (a) Ollama on a 6 GB consumer GPU

- **Runtime policy in principle, research project in practice.** Like KIVI, KVQuant applies to an existing trained model without retraining — but unlike KIVI it additionally needs per-model calibration artefacts and a pre-RoPE cache path. For Ollama's world (arbitrary community GGUFs, no calibration pipeline), that makes full KVQuant a poor fit as a default and a plausible fit as an opt-in for a small set of first-class models that ship with calibration data.
- **What to steal without the stack:** (i) the sink rule — keep token 0 (in chat terms, protect the head of the system/character prompt) in FP16; it is nearly free and helps most exactly at the aggressive precisions a 6 GB card forces. (ii) The 1%-outlier lesson: at 3–4 bits, holding out a tiny sparse FP16 fraction buys more quality than an extra uniform bit. (iii) The honest operating point: on this evidence, **3-bit-class KV quantisation is the near-lossless floor; 2-bit is a capacity mode with named quality costs**, and a 6 GB chat product should default accordingly.
- The million-context headline is irrelevant at 6 GB (it is an A100 arithmetic result), but the same ratios are what turn a 6 GB card's ~1 GiB-per-8K FP16 cache (7B GQA worked example) into ~270 MB at effective 3.33 bits — the difference between 8K and ~24K usable context beside ~4.5 GB of weights.
- Retrieval warning for character chat: the RULER/passkey tables show quantisation error is *not* uniform across positions or tasks. A persona fact stated once, early, is exactly a passkey; if Ollama adopts aggressive KV quantisation for long chats, expect — and test for — precisely that failure before shipping it as "same quality, longer memory".

### (b) Project Aesir (Mojo runner — sessions, prefix memory, hybrid SSM models)

- **Pre-RoPE caching is a day-one architecture decision for Aesir.** If Aesir ever wants KVQuant-class quantisation, its cache format and attention kernels must store pre-RoPE keys and fuse RoPE after dequantisation from the start; bolting it onto a post-RoPE cache later means invalidating every persisted prefix block. Decide explicitly and record the decision — either way is defensible, indecision is not.
- The calibration-artefact model fits Aesir better than Ollama: Aesir controls its model catalogue, so shipping a per-model calibration bundle (nuq datatypes + key scales + thresholds, versioned with the model) is feasible where it is not for arbitrary GGUFs. Budget the calibration pipeline (Fisher estimation + per-layer k-means; the paper reports minutes per layer, parallelisable) as part of model onboarding.
- For prefix memory specifically: KVQuant blocks are *not portable* across runners (LUT + sparse + pre-RoPE format). Aesir's persisted session format should either commit to this format wholesale or store a dequantised interchange form at checkpoint time and re-quantise on load, accepting the cost. Do not let the on-disk format drift into existence by accident.
- The sensitivity-weighted datatype idea generalises beyond KV: Aesir's weight-quantisation work can reuse the same Fisher-weighted k-means machinery, amortising the implementation across both problems.
- Evaluation discipline: adopt the paper's own correction to perplexity-only reporting — any Aesir KV-quantisation claim must be paired with a retrieval benchmark (passkey/RULER-style) at the longest supported context, because that is where this paper shows the damage hides.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2401.18079
- arXiv HTML (read for method + evaluation detail): https://arxiv.org/html/2401.18079v6
- NeurIPS 2024 proceedings PDF (author copy): https://people.eecs.berkeley.edu/~ysshao/assets/papers/kvquant-neurips2024.pdf
