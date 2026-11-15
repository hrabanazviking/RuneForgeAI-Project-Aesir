# SmoothQuant — Accurate and Efficient Post-Training Quantization for Large Language Models

## 1. Full citation

- **Authors:** Guangxuan Xiao, Ji Lin, Mickael Seznec, Hao Wu, Julien Demouth, Song Han
- **Title:** SmoothQuant: Accurate and Efficient Post-Training Quantization for Large Language Models
- **Venue / year:** Proceedings of the 40th International Conference on Machine Learning (ICML 2023), PMLR 202
- **arXiv:** arXiv:2211.10438 — submitted 18 November 2022, v7 29 March 2024 (the version read for this dossier, extended with Llama-2 / Falcon / Mistral / Mixtral results)
- **Link:** https://arxiv.org/abs/2211.10438
- **Code (as reported in the paper):** https://github.com/mit-han-lab/smoothquant

## 2. The problem as framed

SmoothQuant is the odd one out in this wave, deliberately: GPTQ, AWQ, and QuIP# are weight-only methods (W4A16 and below) that shrink *storage and weight bandwidth* but leave arithmetic in FP16. SmoothQuant asks the datacentre question — how to make the matrix multiplications themselves run in INT8 (W8A8), halving memory *and* using the INT8 tensor-core GEMMs that GPUs, CPUs, and DSPs already implement fast — without destroying the model.

The obstacle is not the weights. The paper's central empirical review, echoing LLM.int8(), is:

1. **Weights are easy to quantize.** Their distribution is comparatively flat and uniform; INT8 and even INT4 weight quantization was already known to cost little.
2. **Activations are hard, because of outliers.** Once models scale past roughly 6.7B parameters, a few activation channels carry magnitudes ~100× larger than typical values. With per-tensor (or per-token) quantization, the step size $\Delta = \max|\mathbf{X}| / 127$ is set by those outliers, so ordinary channels are left with only ~2–3 effective quantization levels out of 256 — the error is not noise spread evenly, it is the systematic crushing of every non-outlier channel.
3. **The outliers are structured, not random.** They persist in the *same few channels across all tokens*, while the variance *within* a channel across tokens is small. That persistence is the exploitable fact.

The two prior escapes both fail on efficiency or generality in the paper's framing: per-channel activation quantization preserves accuracy in simulation but cannot be implemented in INT8 GEMM kernels, because GEMM scaling may only be applied along the outer dimensions (token and output-channel), never along the inner (input-channel) dimension where it would be needed; and LLM.int8()'s mixed-precision decomposition — keep outlier activations in FP16, INT8 for the rest — preserves accuracy but pays a large latency overhead, frequently running *slower* than FP16. Naive W8A8 per-tensor quantization simply collapses: on OPT-175B the paper reports average zero-shot accuracy falling from 66.9% (FP16) to 35.5%, with WikiText perplexity exploding to 93,080.

So the diagnosis: the error lives in the *mismatch between one shared activation scale and a channel-wise outlier structure*, in a place the hardware forbids you from fixing directly at runtime.

## 3. Core mechanism in our own words

SmoothQuant fixes the problem *offline*, before quantization, by moving difficulty from the tensor that cannot bear it (activations) to the tensor that can (weights), using an identity the hardware never sees.

For a linear layer $\mathbf{Y} = \mathbf{X}\mathbf{W}$, insert a per-input-channel diagonal scaling and its inverse:

$$\mathbf{Y} = (\mathbf{X}\,\mathrm{diag}(\mathbf{s})^{-1}) \cdot (\mathrm{diag}(\mathbf{s})\,\mathbf{W}) = \hat{\mathbf{X}}\,\hat{\mathbf{W}}$$

In exact arithmetic nothing changes. In quantization arithmetic everything changes: dividing channel $j$ of the activations by $s_j$ shrinks that channel's range (outlier channels shrink the most, because $s_j$ is built from their statistics), while multiplying row $j$ of the weights by the same $s_j$ stretches the weight distribution in exactly the channels that were flat and easy to quantize. After the transformation, activations and weights are *both* smooth enough for plain INT8 quantization — and because $\mathrm{diag}(\mathbf{s})^{-1}$ can be folded into the preceding layer's parameters (or the preceding LayerNorm) offline, the runtime model contains only the smoothed tensors. There is no extra kernel, no mixed precision, and no per-channel activation scaling inside the GEMM. The deployed artifact is an ordinary W8A8 INT8 model runnable on off-the-shelf INT8 GEMM (the paper integrates with CUTLASS kernels via PyTorch and NVIDIA FasterTransformer).

**Choosing $\mathbf{s}$: the migration factor α.** Pushing *all* difficulty onto the weights ($s_j = \max|\mathbf{X}_j|$, equalizing every activation channel) just relocates the collapse — the migrated outlier channels then wreck weight quantization; pushing none leaves activations unquantizable. SmoothQuant splits the difficulty with one hyperparameter, the migration strength $\alpha$:

$$s_j = \frac{\max(|\mathbf{X}_j|)^{\alpha}}{\max(|\mathbf{W}_j|)^{1-\alpha}}$$

$\alpha = 0.5$ divides the dynamic range geometrically evenly between activation and weight, and the paper finds it a general sweet spot for OPT and BLOOM (ablation on OPT-175B: accuracy holds for $\alpha$ in roughly 0.4–0.6 and degrades outside it). Models whose activations are more pathological get more migration: $\alpha = 0.75$ for GLM-130B in the original experiments; the v7 extension uses $\alpha = 0.85$–0.9 for Llama-2, 0.6–0.8 for Falcon/Mistral/Mixtral, chosen by a quick grid search. The channel statistics $\max|\mathbf{X}_j|$ are estimated once from calibration data — 512 random sentences from the Pile pre-training corpus in the paper's setup — and the same smoothed model is then used for all downstream tasks.

**Scope of application.** Smoothing is applied to the inputs of the compute-heavy operators — the linear layers in attention and feed-forward blocks, and the batched matmuls (BMMs) in attention — which are quantized W8A8. Lightweight elementwise operations (Softmax, LayerNorm, ReLU) stay in FP16. The paper defines three efficiency levels, O1 (per-tensor weights, per-token dynamic activations) through O3 (per-tensor weights, per-tensor *static* activations — the fastest, since no runtime scale computation is needed), all of which preserve accuracy in its OPT-175B evaluation, which is itself a result: after smoothing, even the coarsest, most hardware-friendly quantization scheme works.

SmoothQuant is training-free throughout: no gradients, no reconstruction loop, no fine-tuning.

## 4. Reported results — as reported, with context

All figures are the paper's own. Hardware for the speed/memory results is NVIDIA A100-80GB unless stated; the serving integration is FasterTransformer unless stated.

**Accuracy — the collapse that doesn't happen.** OPT-175B, seven zero-shot tasks (average accuracy) + WikiText perplexity:
- FP16: 66.9% average, PPL 10.99
- Naive W8A8: 35.5%, PPL 93,080 — destroyed
- ZeroQuant: 35.8%, PPL 84,648 — destroyed
- Outlier Suppression: 36.0%, PPL 96,151 — destroyed
- LLM.int8() (mixed precision): 66.7%, PPL 11.10 — accurate, but see latency below
- SmoothQuant O1/O2/O3: 66.5% / 66.4% / 66.8%, PPL 11.11 / 11.14 / 11.17 — accurate at every efficiency level, including fully static per-tensor

Across the three largest open models of the time (average accuracy, task sets differ per model as noted in the paper): OPT-175B FP16 71.6% → SmoothQuant-O3 71.1%; BLOOM-176B 68.2% → 67.4% (O1/O2: 68.3% / 68.4%); GLM-130B 73.8% → O1 73.7%, O3 72.8% — while naive W8A8 scores 32.3% / 64.2% / 26.9% respectively. Instruction-tuned OPT-IML-30B: FP16 WikiText 14.26 → SmoothQuant-O3 14.37, where W8A8 and ZeroQuant collapse (576.53 / 455.12).

**Later-model extension (v7), WikiText2 perplexity, W8A8 SmoothQuant vs FP16:** LLaMA-7B/13B/30B/65B: 11.51→11.56, 10.05→10.08, 7.53→7.56, 6.17→6.20 (sequence length 512, $\alpha$ per the LLaMA setup). Llama-2-7B/13B/70B: 5.474→5.515, 4.950→4.929, 3.320→3.359. Mistral-7B: 5.253→5.277. Mixtral-8x7B: 3.842→3.893. Falcon-40B: 5.228→5.255. The pattern is uniform: W8A8 costs a few hundredths of a perplexity point once smoothing is applied.

**Speed and memory — in the INT8-kernel context where the claim lives.**
- Context stage, PyTorch implementation, single A100: up to **1.51× speedup** (OPT-30B, sequence length 256) and up to **1.96× memory saving** versus FP16; LLM.int8() is slower than FP16 in most of these cases.
- Context stage, FasterTransformer: up to **1.56× speedup** on OPT-13B/30B single-GPU; for OPT-66B and OPT-175B, similar or better latency using *half* the GPUs (1 instead of 2; 4 instead of 8). Memory footprint almost halved.
- Decoding stage: up to **1.42×** per-token speedup (OPT-30B, batch 16, sequence 512: 2,488 ms → 1,753 ms) with roughly halved memory; the abstract's headline is up to 1.56× speedup and 2× memory reduction overall.
- **Scale demonstration:** MT-NLG 530B quantized W8A8 with negligible accuracy loss (average of LAMBADA/HellaSwag/PIQA/WinoGrande: FP16 73.1% → INT8 73.1%) and served on **8×A100-80GB (one node) instead of 16 GPUs**, at similar latency (e.g. sequence 512: 838 ms FP16 on 16 GPUs vs 839 ms INT8 on 8).

The speed claims must be read with their mechanism: they exist because W8A8 lets the *arithmetic itself* run on INT8 tensor cores. They do not transfer to hardware or kernels without fast INT8 GEMM, and they are context/prefill-heavy — decode gains (≤1.42×) are smaller than prefill gains, because single-token decode is bandwidth-bound and W8A8 only halves weight bytes, where W4A16 quarters them.

## 5. What it changed in practice

SmoothQuant created the W8A8 serving lineage. Before it, "INT8 LLM serving" effectively meant LLM.int8()'s accurate-but-slow mixed precision; after it, the standard datacentre recipe became: smooth offline, quantize everything to INT8, run stock INT8 GEMMs. That recipe — and the per-channel smoothing transformation itself, often combined with GPTQ/AWQ-style weight treatment in later pipelines — is embodied in FasterTransformer / TensorRT-LLM-class serving and in the W8A8 model configurations offered by mainstream serving stacks, as documented in this corpus's runner dossiers. Its conceptual export is even broader than its format: *equivalent transformation before quantization* — change the parameterization, not the function, so the quantizer's job becomes easy — is the move AWQ's scaling, OmniQuant's learned transformations, and QuIP#'s incoherence processing all generalize in different directions.

For this wave's canon, SmoothQuant is also the boundary marker: it proves 8-bit *activation* quantization is a solved problem (with smoothing), which is precisely why the rest of the wave can treat activations as FP16 and fight exclusively over weight bits below 8. The hard frontier moved to W4/W3/W2 weights and, separately, to the KV cache — not to W8A8.

## 6. Applicability

### (a) Ollama on a 6 GB card — which formats to prefer, and why

- **W8A8 is usually the wrong trade at 6 GB, and SmoothQuant's own numbers show why.** W8A8 halves weight memory; W4A16 quarters it. On a 6 GB card, a 7B model at W8A8 (~7 GB of weights) does not fit at all, while at W4A16 (~3.5–4 GB) it fits beside a useful KV cache. SmoothQuant's prize — INT8 arithmetic speed — matters most in compute-bound prefill on datacentre GPUs; single-user decode on a consumer card is bandwidth-bound, where fewer weight *bits* beat faster *arithmetic*. Prefer 4-bit weight-only formats (GPTQ/AWQ/GGUF Q4-class) as the default; treat W8A8 as a quality reference point, not a deployment target.
- **The exception is quality headroom, not speed.** If a specific model is known to degrade badly below 8-bit weights and the card can hold it (small models, ~3B class and under), a SmoothQuant-lineage W8A8 artifact will be essentially indistinguishable from FP16 (the paper's deltas are ~0.03–0.05 perplexity). That is a legitimate choice for a small, quality-critical model.
- **Do not expect Ollama/GGUF to "be" SmoothQuant.** GGUF quantization is weight-centric with its own activation handling; SmoothQuant W8A8 artifacts live in the INT8-GEMM serving ecosystem (TensorRT-LLM and kin). For the improved-Ollama design, SmoothQuant's transferable asset is not a file format but the smoothing *technique* (see §6b) and a caution: if a future Ollama targets hardware with fast INT8/INT4 arithmetic (NPUs, newer tensor cores), the W8A8 analysis — smooth first, then quantize activations — is the proven way to use it.
- **Bit-width error behaviour, placed in the wave's map:** at 8 bits, with smoothing, error is negligible for both weights and activations; at 4 bits weight-only, error is small and method-dependent; at 3 bits, method decides viability; at 2 bits, only incoherence/vector-quantization methods survive. SmoothQuant anchors the top of that ladder — it defines what "lossless" looks like, against which every lower-bit claim in this wave should be graded.

### (b) Aesir's compression school — what a home-grown quantizer must implement or measure

- **Equivalent transformation is a first-class tool in the quantizer's kit.** Before reaching for finer groups or more bits, an Aesir quantizer should ask SmoothQuant's question: can a per-channel diagonal rescaling — folded into the preceding layer, zero runtime cost — make this tensor's distribution easier to quantize? This applies inside GGUF weight quantization too: smoothing the *weight* distribution via activation statistics is the shared root of SmoothQuant and AWQ, and Aesir should implement the statistic collection once and reuse it for both.
- **Measure the outlier structure before choosing anything.** The paper's method falls out of three measurements (weights flat, activations outlier-dominated, outliers channel-persistent). Aesir's school should institutionalize that order of operations: for every new model family, profile per-channel activation maxima and weight ranges, publish the profile with the quantized artifact, and let the profile — not habit — choose α-like parameters, group sizes, and bit allocation.
- **α is a graded hyperparameter, not a constant.** The paper's ablation (sweet spot ~0.4–0.6 for OPT, higher for harder models) and its per-family α values in v7 (0.6–0.9) teach the same lesson: expose the migration/smoothing strength, grid-search it on calibration data, and record the chosen value and the grading curve in the artifact's provenance. A quantizer with a magic constant baked in will silently fail on the next model family.
- **Static-calibration risk must be graded.** SmoothQuant-O3's small BLOOM regression (68.2% → 67.4%) is attributed by the authors to mismatch between statically collected statistics and evaluation-time activations. Any Aesir mode that bakes activation statistics into an artifact (smoothing factors, static scales) must be graded on out-of-calibration data, per the faithfulness protocol — the failure mode is known, named, and measurable.
- **Know which bottleneck you are relieving.** SmoothQuant relieves compute and halves bandwidth; GPTQ/AWQ relieve bandwidth ~4× and leave compute alone. Aesir's compression school should state, for each quantizer it writes, which regime (prefill/compute-bound vs decode/bandwidth-bound, per target hardware) its numbers were measured in — importing a datacentre W8A8 speedup claim into a decode-bound consumer context is exactly the category error this dossier exists to prevent.

## 7. Cross-links

- **ExLlamaV2 dossier** (`runners/exllamav2.md`): the contrast case — ExLlamaV2's continuous bit-rate provisioning optimizes the weight-only axis (how many bits, where) for bandwidth-bound local inference, while SmoothQuant optimizes the W8A8 axis for compute-bound serving. Together they map the two different optima a runner must choose between based on its hardware and batch regime.
- **Aesir ideas dossier** (`aesir/aesir-ideas-for-ollama.md`): SmoothQuant contributes the compression school's "transform before you quantize" principle and its calibration-statistics discipline; it is also the reference for any future Aesir work on NPU/INT8-arithmetic targets, where W8A8 — not W4A16 — is the native regime.
- **KV wave (KIVI / KVQuant dossiers, `papers/kivi.md`, `papers/kvquant.md`):** the weight/KV symmetry in its sharpest form — SmoothQuant proves persistent channel outliers are the enemy of activation quantization and defeats them by rescaling channels offline; KIVI proves the same persistent channel outliers govern the key cache and defeats them by quantizing along the channel axis. Same distribution pathology, two different structural fixes, chosen by what the respective hardware allows.

## 8. Sources

- Xiao et al., SmoothQuant, arXiv:2211.10438 — abstract page and HTML full text (v7). https://arxiv.org/abs/2211.10438 ; https://arxiv.org/html/2211.10438v7
- Date accessed: **2026-11-15** for all sources in this dossier.
