# GPTQ — Accurate Post-Training Quantization for Generative Pre-trained Transformers

## 1. Full citation

- **Authors:** Elias Frantar, Saleh Ashkboos, Torsten Hoefler, Dan Alistarh
- **Title:** GPTQ: Accurate Post-Training Quantization for Generative Pre-trained Transformers
- **Venue / year:** International Conference on Learning Representations (ICLR 2023)
- **arXiv:** arXiv:2210.17323 — submitted 31 October 2022, v2 22 March 2023
- **Link:** https://arxiv.org/abs/2210.17323
- **Code (as reported in the paper):** https://github.com/IST-DASLab/gptq

## 2. The problem as framed

A 175-billion-parameter model in FP16 occupies about 326 GiB in the paper's accounting. It does not fit on one high-end GPU, so even inference requires a multi-GPU deployment. Retraining or quantization-aware training at that scale is prohibitively expensive, so the practical question is one-shot post-training quantization (PTQ): compress a finished model, using only a small calibration set and a few hours of compute, with no task-specific retraining.

Naive round-to-nearest (RTN) — round every weight independently to the nearest level on a fixed grid — is the only prior method that scaled trivially to 175B, and it works at 8 bits. At 4 bits it already loses material accuracy on large OPT models, and at 3 bits it collapses completely (see §4). GPTQ's diagnosis is that RTN treats each weight's rounding error as if it were final. In a linear layer the output error is not the sum of independent weight errors: it is the error propagated through the layer inputs, $\|\mathbf{W}\mathbf{X} - \hat{\mathbf{W}}\mathbf{X}\|_2^2$. Once one weight in a row is rounded, the still-unquantized weights in that same row can be *moved* to compensate, because they multiply correlated inputs. RTN never uses that freedom. The error therefore lives in the interaction between rounding decisions and the second-order structure of the layer inputs — the Hessian $\mathbf{H} = 2\mathbf{X}\mathbf{X}^\top$ — not in any single weight in isolation.

Prior accurate PTQ methods that did exploit this structure (AdaRound, BRECQ, and especially Optimal Brain Quantization, OBQ, the direct predecessor) could not scale: OBQ's greedy order and per-weight inverse-Hessian updates cost $O(d_{row} \cdot d_{col}^3)$ for a $d_{row} \times d_{col}$ layer, roughly an hour for a 25M-parameter ResNet-50 and infeasible at billions of parameters.

## 3. Core mechanism in our own words

GPTQ quantizes one layer at a time, solving the layer-wise reconstruction problem above, row by row in parallel but column by column in a fixed order. Three ideas make the OBQ/OBS (Optimal Brain Surgeon) lineage fast and stable enough for 175B models:

**Error compensation with second-order information.** When a column is quantized, the quantization error for that column is distributed over all not-yet-quantized columns, weighted by the inverse Hessian. Concretely, if quantizing weight $w_q$ incurs error $w_q - \mathrm{quant}(w_q)$, the remaining weights receive the update $\boldsymbol{\delta}_F = -\frac{w_q - \mathrm{quant}(w_q)}{[\mathbf{H}_F^{-1}]_{qq}} \cdot (\mathbf{H}_F^{-1})_{:,q}$. Weights whose inputs are strongly correlated with the quantized weight's input absorb more of the correction. This is greedy-optimal for the quadratic layer objective at each step.

**Fixed order instead of greedy order.** OBQ re-picks, at every step, the weight with the smallest incremental error. GPTQ's first insight is empirical: on large, heavily parameterized layers, quantizing in an arbitrary fixed order — the same column order for every row — loses almost nothing versus the greedy order, because a weight quantized late has fewer compensators left but also tends to have been adjusted many times already. Fixing the order means the set of remaining weights, and hence $\mathbf{H}_F^{-1}$, is identical for all rows, so the inverse-Hessian update is done once per column instead of once per weight. That alone cuts the complexity by a factor of $\min(d_{row}, d_{col})$ — orders of magnitude at LLM layer sizes.

**Lazy batch updates.** A direct implementation is memory-bandwidth-bound: each single-column step would touch the whole weight and Hessian matrices for a handful of FLOPs. GPTQ processes columns in blocks (block size $B = 128$ in the paper's algorithm). Inside a block, updates are applied only within the block; only when the block is finished is the accumulated error propagated to all remaining columns in one large matrix operation. The arithmetic is the same; the GPU utilization is not.

**Cholesky reformulation for numerical stability.** Repeatedly updating $\mathbf{H}^{-1}$ by the OBQ elimination formula accumulates error until the matrix can become indefinite, at which point updates point in wrong directions and a layer's quantization can fail arbitrarily badly. The paper reports this is near-certain in at least a few layers once models exceed a few billion parameters, and that simple dampening (adding $\lambda \mathbf{I}$, with $\lambda$ set to 1% of the average diagonal of $\mathbf{H}$) is not enough at that scale. GPTQ instead observes that the algorithm only ever needs one row of each successive $\mathbf{H}_{F}^{-1}$, and that the sequence of those rows is, up to a diagonal scaling, exactly a Cholesky decomposition of the initial inverse Hessian. It therefore precomputes the Cholesky factor once, with a numerically robust kernel, plus the same mild dampening, and reads all needed information from it. Stability and a further speedup come from the same move.

Calibration and grid, as reported: 128 random segments of 2,048 tokens from the C4 training set, no task-specific data; standard uniform per-row asymmetric quantization on a min-max grid in the main experiments, with optional grouping (independent grids for consecutive groups of weights) as an add-on. Quantization proceeds block by block through the network, feeding each block the inputs produced by the already-quantized earlier blocks, so later layers are calibrated against the errors earlier layers actually introduce. Embeddings and the output layer are kept in FP16 in the headline 175B inference setup.

GPTQ is weight-only: activations stay in FP16, and the paper is explicit that its speedups come from reduced memory movement, not from cheaper arithmetic — there is no mainstream hardware support assumed for mixed FP16×INT4 multiplication.

## 4. Reported results — as reported, with context

All figures below are the paper's own, on the hardware and models stated. Perplexity is WikiText2 unless otherwise noted; lower is better.

**Quantization cost.** On a single NVIDIA A100 (80 GB): OPT-175B in 4.2 hours, BLOOM-176B in 3.8 hours; OPT-13B in 20.9 minutes, OPT-30B in 44.9 minutes. The abstract rounds this to "approximately four GPU hours" for a 175B model.

**4-bit accuracy — near-lossless at scale, where RTN is not.** OPT-175B: FP16 8.34 → GPTQ-4bit 8.37 (a loss of 0.03) versus RTN-4bit 10.54 (a loss of 2.20, worse than the 10× smaller FP16 OPT-13B at 10.13). BLOOM-176B: FP16 8.11 → GPTQ-4bit 8.21 versus RTN 8.37. Across the 175B models and WikiText2/PTB/C4, the paper summarizes 4-bit GPTQ as within ≤0.25 perplexity of FP16.

**3-bit accuracy — the regime RTN cannot enter.** OPT-175B: GPTQ-3bit 8.68 versus RTN-3bit ~7.3×10³ (total collapse). BLOOM-176B: GPTQ-3bit 8.64 versus RTN 571. The paper's summary for the two 175B models at 3 bits is a loss of only 0.3–0.6 perplexity points for more than 5× compression. Smaller models degrade more: OPT-6.7B goes 10.86 (FP16) → 11.39 (4-bit) → 14.86 (3-bit); OPT-1.3B goes 14.63 → 15.47 → 20.97. Larger models quantize more easily — a recurring, decision-relevant pattern.

**Grouping helps, at a small true-bitrate cost.** For 175B models at nominal 3 bits, group size 1024 (≈0.02 extra bits/weight) and group size 128 (≈0.15 extra bits/weight) each improve perplexity further, ending 0.1–0.3 points off the uncompressed accuracy in the paper's accounting.

**Extreme regime — 2-bit and ternary, grouped only.** At ≈2.2 bits effective (2-bit, group size 128) the perplexity increase on the largest models is already under 1.5 points; at ≈2.6 bits effective (group size 32) it drops to 0.6–0.7 points — only slightly worse than vanilla 3-bit in the paper's comparison. With group size 8, ternary (−1, 0, +1) quantization reaches 9.20 WikiText2 perplexity on OPT-175B, under a 1-point drop. These are presented as an encouraging first step, not as a general recommendation.

**End-to-end inference speedup, in its original kernel context.** The paper's bespoke kernel dequantizes weights on the fly inside a quantized-matrix × FP16-vector product, exploiting the fact that single-token generation is memory-bandwidth-bound. For OPT-175B generation (batch size 1, sequences of length 128): on A100, 230 ms/token FP16 (5 GPUs) → 71 ms/token at 3 bits (1 GPU), ≈3.25×; on A6000, 589 ms/token FP16 (8 GPUs) → 130 ms/token at 3 bits (2 GPUs), ≈4.5×. The 3-bit 175B model plus a 2,048-token KV cache (≈63 GB + ≈9 GB) fits on a single 80 GB A100, versus 5×80 GB for FP16 and 3×80 GB for the 8-bit LLM.int8() baseline cited. The speedup claim is therefore inseparable from that custom kernel and that memory-bound decode setting; GPTQ the *algorithm* by itself guarantees the size, not the speed.

## 5. What it changed in practice

GPTQ established the template that almost all later weight-only PTQ follows: calibrate on a small generic set, quantize layer by layer against a Hessian-weighted reconstruction objective, compensate errors into unquantized weights, and ship a grouped low-bit format plus a dequantizing kernel. "GPTQ" consequently names both an algorithm and, in the ecosystem, a family of checkpoint formats (grouped INT4/INT3 weights with scales and zero-points, typically group size 128) consumed by vLLM, ExLlamaV2, LMDeploy, TensorRT-LLM, and Hugging Face / AutoGPTQ-derived tooling, as documented in this corpus's runner dossiers. A practitioner downloading a "GPTQ" model is usually downloading the format and kernel contract, produced by some implementation of this method or a descendant, not necessarily the original IST-DASLab code.

It also set the honest baseline for the field: 4-bit weight-only quantization of large models can be near-lossless; 3-bit is viable at large scale and fragile at small scale; 2-bit needs grouping and tolerance for visible loss. Every later method in this wave is measured against those claims — AWQ by beating GPTQ's perplexity at INT3/INT4 on Llama models while avoiding reconstruction, QuIP# by beating it decisively at 2 bits.

## 6. Applicability

### (a) Ollama on a 6 GB card — which formats to prefer, and why

GPTQ is an *offline* method: Ollama does not run GPTQ at load time; it consumes checkpoints that someone else quantized. The actionable content is format preference per bit-width.

- **At 4 bits, GPTQ-format checkpoints are a safe default** for the 7B–13B class that actually fits a 6 GB card beside a KV cache — provided the runner's kernel path for that format is mature. The paper's evidence is strongest exactly here: near-FP16 perplexity at scale, with grouping at 128 as the standard configuration. On a 6 GB card the binding constraint is usually not the last 0.1 perplexity but whether weights + KV cache + activations fit without spilling; a 4-bit grouped format is the balanced point.
- **At 3 bits, prefer GPTQ (or AWQ) over any RTN/naive 3-bit checkpoint, and expect model-size dependence.** The paper's own numbers warn that a 3-bit small model loses far more than a 3-bit large model. For a 6 GB card this cuts against intuition: shrinking a small model to 3 bits to make it fit can cost more quality than choosing a natively smaller model at 4 bits. Treat 3-bit as a considered trade, validated per model, not a free upgrade.
- **At 2 bits, vanilla GPTQ is not the recommendation.** The paper's 2-bit results require small groups (raising the true bitrate to ≈2.2–2.6 bits) and still lose 0.6–1.5 perplexity on 175B models; on 7B-class models the loss would be larger. Sub-2-bit and 2-bit needs belong to the QuIP#/AQLM lineage (§ see quip-sharp.md), or to GGUF's IQ-family design space, not to plain GPTQ.
- **Kernel reality check:** GPTQ-format speed depends entirely on the runner's dequantize-and-multiply kernel for that exact packing. A format that is accurate but served by a slow fallback kernel can be slower than a slightly larger format with a fast kernel. For the improved-Ollama design, GPTQ support is a kernel commitment, not just a file parser.

### (b) Aesir's compression school — what a home-grown quantizer must implement or measure

GPTQ is the minimum bar a home-grown GGUF quantizer must clear to be taken seriously, and the most directly implementable of the four methods in this wave:

- **Implement the Hessian-weighted objective, not weight-space MSE.** The quantizer must accumulate $\mathbf{H} = 2\mathbf{X}\mathbf{X}^\top$ (damped) per layer from calibration activations and grade candidate roundings by output error $\mathrm{tr}((\hat{\mathbf{W}}-\mathbf{W})\mathbf{H}(\hat{\mathbf{W}}-\mathbf{W})^\top)$, not by $\|\hat{\mathbf{W}}-\mathbf{W}\|$. A quantizer that minimizes weight error alone is RTN with extra steps.
- **Implement error compensation.** After each column (or block) is rounded, propagate its error into the unrounded remainder via the inverse-Hessian/Cholesky factor. Without compensation there is no reason to expect GPTQ-class results at 3–4 bits.
- **Copy the numerical discipline, not just the math.** Precompute the Cholesky factor of the damped inverse Hessian once; do not iteratively update a full inverse. Dampen at ~1% of the mean diagonal as a starting point and log any layer where the factor fails — that log is a faithfulness signal, not an inconvenience.
- **Calibration discipline.** Use a small, generic, held-out-from-evaluation calibration set (the paper: 128 × 2,048 tokens of C4), quantize sequentially through the network feeding quantized-block outputs forward, and never tune on the grading set. Aesir's faithfulness protocol — grade packed against original on data the quantizer did not calibrate on — is exactly the guard against the overfitting failure mode later papers attribute to reconstruction-heavy methods.
- **Grade by bit-width and by model size separately.** Report perplexity delta *and* teacher-forced logit/rank agreement against the FP16 original, per bit-width, per model size. The paper's central empirical lesson — larger models tolerate fewer bits — must be re-measured for Aesir's target models, not assumed.
- **Account true bitrate.** Group scales and zero-points are real bits. Report effective bits/weight including all per-group metadata, as the paper does for its grouped 2-bit figures (≈2.2 / ≈2.6 bits), so format comparisons stay honest.

## 7. Cross-links

- **ExLlamaV2 dossier** (`runners/exllamav2.md`): ExLlamaV2 is one of the principal consumers of GPTQ-format checkpoints, and its continuous / mixed bit-rate provisioning is the runner-side answer to the question GPTQ leaves open — given that quality falls non-uniformly across layers and model sizes, allocate bits where they buy the most faithfulness instead of fixing one bit-width for the whole model.
- **Aesir ideas dossier** (`aesir/aesir-ideas-for-ollama.md`): GPTQ is the reference algorithm for Aesir's compression school — the first quantizer to implement, and the baseline every Aesir-written quantizer must beat at equal true bitrate before more exotic machinery (incoherence processing, lattice codebooks) is justified.
- **KV wave (KIVI / KVQuant dossiers, `papers/kivi.md`, `papers/kvquant.md`):** the weight/KV symmetry — GPTQ shows weights tolerate 4 bits and, with compensation, 3 bits, because weight error can be redistributed across correlated inputs; the KV wave shows cache error is governed by outlier geometry along the channel/token axes. Both waves converge on the same principle: *where* the error lives, and what structure can absorb it, matters more than the raw bit count.

## 8. Sources

- Frantar et al., GPTQ, arXiv:2210.17323 — abstract page and HTML full text (v2). https://arxiv.org/abs/2210.17323 ; https://arxiv.org/html/2210.17323v2
- Date accessed: **2026-11-15** for all sources in this dossier.
