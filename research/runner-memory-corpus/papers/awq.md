# AWQ — Activation-aware Weight Quantization for LLM Compression and Acceleration

## 1. Full citation

- **Authors:** Ji Lin, Jiaming Tang, Haotian Tang, Shang Yang, Wei-Ming Chen, Wei-Chen Wang, Guangxuan Xiao, Xingyu Dang, Chuang Gan, Song Han
- **Title:** AWQ: Activation-aware Weight Quantization for LLM Compression and Acceleration (paper title in proceedings form: *AWQ: Activation-aware Weight Quantization for On-Device LLM Compression and Acceleration*)
- **Venue / year:** Proceedings of the 7th Conference on Machine Learning and Systems (MLSys 2024), Santa Clara, CA, USA — Best Paper Award (as stated in the paper)
- **arXiv:** arXiv:2306.00978 — submitted 1 June 2023; the version read for this dossier is v5 (proceedings version); arXiv listing current version v6, revised 25 April 2026 per the abstract page
- **Link:** https://arxiv.org/abs/2306.00978
- **Code (as reported in the paper):** https://github.com/mit-han-lab/llm-awq

## 2. The problem as framed

AWQ targets on-device inference: running an LLM locally on edge hardware to cut cloud cost and protect privacy, where model size and memory bandwidth — not datacentre throughput — are the binding constraints. In single-batch generation, decoding is memory-bound (the paper's roofline analysis on an RTX 4090 puts FP16 generation at arithmetic intensity ≈1 against a machine balance of ≈165 FLOPs/byte), and weight traffic dominates activation traffic by orders of magnitude. Weight-only low-bit quantization (W4A16) therefore attacks the right bottleneck: it shrinks the bytes that must be streamed for every generated token.

Naive RTN weight quantization at 3–4 bits loses too much, and the obvious refinement — identify the important weights and keep just those in FP16 — is hardware-hostile: a mixed-precision model with a scattered 1% in FP16 breaks the uniform, grouped integer format that fast kernels need. GPTQ, the closest prior work, recovers accuracy by second-order reconstruction, but AWQ's framing faults it on a different axis: reconstruction *overfits the calibration set*, distorting features on out-of-distribution domains and modalities — a serious defect for generalist, instruction-tuned, and multi-modal models, which are exactly the models people deploy on device.

AWQ's diagnosis of where the error lives is specific and testable: **a tiny fraction of weight channels — on the order of 0.1–1% — are salient, and they are salient because of the activations they multiply, not because of their own magnitude.** A weight channel fed by consistently large activation magnitudes contributes disproportionately to the output; quantizing it coarsely injects error multiplied by those large activations. Selecting "important" weights by weight magnitude or $L_2$ norm performs no better than random in the paper's ablation. Selecting by activation magnitude transforms the result.

## 3. Core mechanism in our own words

AWQ is weight-only, grouped quantization (group size 128 throughout, unless otherwise stated) with one additional, offline step before rounding: a per-input-channel scaling that protects salient channels *inside* a uniform integer format, with no mixed precision and no backpropagation or reconstruction.

**Step 1 — find saliency from activations.** Run a small calibration set (the paper uses a small set from the Pile, deliberately not task-specific) through the FP16 model and record, per input channel, the average activation magnitude $\mathbf{s_X}$. Channels with large $\mathbf{s_X}$ mark the salient weight channels. The motivating ablation (INT3-g128, WikiText perplexity): keeping just 1% of channels in FP16, chosen by activation, takes OPT-6.7B from RTN's 23.54 to 11.39 (FP16 baseline 10.86) and OPT-1.3B from 119.00 to 16.91 (FP16 14.62); the same fraction chosen by weight magnitude or at random barely moves the result.

**Step 2 — protect by scaling, not by sparing.** For a salient weight $w$ multiplied by activation $x$, consider the equivalent computation $Q(w \cdot s) \cdot (x / s)$ with $s > 1$. The paper's error analysis shows the relative quantization error of that weight scales as $(\Delta'/\Delta) \cdot (1/s)$, where $\Delta$ is the group's quantization step. Because scaling *one* channel rarely changes the group's maximum, $\Delta' \approx \Delta$ for most groups, so the salient channel's relative error falls by roughly $1/s$ — it effectively gets finer resolution — while the cost is a modest increase in error for non-salient channels in groups whose $\Delta$ does grow. Empirically on OPT-6.7B (INT3): scaling the 1% salient channels by $s=2$ improves perplexity from 23.54 ($s=1$, i.e. RTN) to 11.92; $s=4$ overshoots (12.36), because 21.2% of groups then see an increased $\Delta$.

**Step 3 — search one exponent per layer, not one scale per channel by hand.** AWQ parameterizes the whole per-channel scale vector as $\mathbf{s} = \mathbf{s_X}^{\alpha}$, with a single hyperparameter $\alpha \in [0,1]$ balancing protection of salient channels against harm to the rest ($\alpha = 0$: no scaling; $\alpha = 1$: most aggressive in this family). For each layer, $\alpha$ is chosen by a fast grid search (grid size 20 in the paper's setup) minimizing the layer output error $\| Q(\mathbf{W}\,\mathrm{diag}(\mathbf{s}))\,(\mathrm{diag}(\mathbf{s})^{-1}\mathbf{X}) - \mathbf{W}\mathbf{X} \|$ on the calibration activations. Weight clipping to minimize quantization MSE is applied on top. The inverse activation scaling $\mathrm{diag}(\mathbf{s})^{-1}$ is fused into the preceding operator offline, so at runtime there is no extra scaling pass and no mixed-precision storage: the deployed artifact is ordinary grouped INT4/INT3 weights whose values were pre-conditioned to quantize well.

That is the whole method, and its restraint is the point: because AWQ only *measures* average activation magnitudes and searches one scalar per layer, it has very little capacity to overfit the calibration set — the property the paper leans on for its instruction-tuned and multi-modal results, and for needing (per its Figure 8) roughly 10× less calibration data than GPTQ to reach good perplexity on OPT-6.7B INT3-g128, with far smaller degradation when calibration and evaluation distributions differ (AWQ +0.5–0.6 perplexity cross-distribution versus GPTQ +2.3–4.9 in that experiment).

**TinyChat, the companion system.** The paper pairs AWQ with TinyChat, an inference framework for 4-bit on-device LLM/VLM deployment: on-the-fly dequantization fused into the matmul kernels, platform-aware (SIMD-aware) weight packing — e.g. interleaved packing so a 128-bit NEON register's 32 INT4 weights unpack in 3 SIMD instructions — and aggressive kernel fusion (LayerNorm, QKV projection, KV-cache update). TinyChat is evidence for the format, not part of the quantization algorithm, but its numbers (§4) are how the paper proves W4A16's theoretical bandwidth saving converts to wall-clock speed on edge hardware.

## 4. Reported results — as reported, with context

All figures are the paper's own. Perplexity is WikiText2, lower is better; quantization is grouped, group size 128, unless stated.

**Headline perplexity — LLaMA / Llama-2, INT4-g128 and INT3-g128 (Table 4 of the paper).**

| Model | FP16 | INT4: RTN / GPTQ / AWQ | INT3: RTN / GPTQ / AWQ |
|---|---|---|---|
| Llama-2-7B | 5.47 | 5.73 / 5.69 / **5.60** | 6.66 / 6.43 / **6.24** |
| Llama-2-13B | 4.88 | 4.98 / 4.98 / **4.97** | 5.52 / 5.48 / **5.32** |
| Llama-2-70B | 3.32 | 3.46 / 3.42 / **3.41** | 3.98 / 3.88 / **3.74** |
| LLaMA-7B | 5.68 | 5.96 / 6.22 / **5.78** | 7.01 / 8.81 / **6.35** |
| LLaMA-65B | 3.53 | 3.67 / 3.66 / **3.62** | 4.24 / 4.17 / **3.95** |

AWQ beats RTN and GPTQ (with and without the reordering trick) at both bit-widths across the family in this table, with the margin growing at INT3 — the regime where method, not bit count, decides usability. Note the honest context: at INT4 all three methods are close to FP16; at INT3 the gaps open.

**The saliency ablation (INT3-g128).** OPT-6.7B: FP16 10.86 → RTN 23.54 → AWQ 11.39, matching the impractical "keep 1% in FP16 (by activation)" oracle at 11.39. OPT-13B: 10.13 → 46.04 → 10.56. The paper's Figure 2 makes the same point on a single bar: OPT-6.7B INT3-g128 perplexity 43.2 for plain quantization in that illustration, 13.0 with activation-chosen FP16 protection — AWQ's scaling recovers most of that gap without the mixed precision.

**Beyond base language models — where GPTQ degrades and AWQ, as reported, does not.**
- *Instruction-tuned:* INT3-g128 Vicuna-7B/13B evaluated by the GPT-4 comparison protocol against their FP16 counterparts — AWQ wins more comparisons than RTN and GPTQ at both sizes (paper Figure 5).
- *Code and math at INT4-g128:* CodeLlama-7B-Instruct on MBPP: FP16 pass@1 38.53 → RTN 37.51, GPTQ 31.97, AWQ 40.64. Llama-2 on GSM8K: 7B FP16 13.87 → AWQ 13.57 (GPTQ 12.13); 70B FP16 56.41 → AWQ 56.40 (GPTQ 56.03).
- *Multi-modal (first VLM low-bit study claimed):* OpenFlamingo-9B on COCO captioning, INT4-g128, 32-shot CIDEr degradation versus FP16: RTN −4.57, GPTQ −6.72, AWQ −1.17; at INT3-g128: RTN −16.91, GPTQ −16.93, AWQ −7.23. VILA-7B/13B at INT4-g128 is reported as essentially lossless across 11 visual-language benchmarks.
- *Newer architectures:* Mistral-7B-Instruct-v0.2 / Mixtral-8x7B-Instruct (WikiText2): FP16 4.14 / 5.94 → INT4-g128 4.30 / 6.05 → INT3-g128 4.83 / 6.52 (AWQ).

**Extreme low bit, combined with GPTQ.** In the paper's INT2-g64 OPT experiment (its Table 9), AWQ's scaling is *orthogonal* to GPTQ's compensation: applying AWQ-style scaling before GPTQ further closes the gap at 2 bits. AWQ alone is not presented as a 2-bit method — an important boundary for §6.

**TinyChat speed, in its original context.** More than 3× speedup over the Hugging Face FP16 implementation on desktop and mobile GPUs (paper's summary: 3.2–3.3× average across models; up to 3.9× on an RTX 4090 and 3.5× on Jetson Orin in the detailed figures); Llama-2-13B running interactively (~30 tokens/s as reported for the laptop case) on a laptop RTX 4070 with 8 GB; Llama-2-70B deployed on a single Jetson Orin with 64 GB. These are TinyChat-system numbers against an HF FP16 baseline — not a claim that any AWQ checkpoint in any runner runs 3× faster.

## 5. What it changed in practice

AWQ made "activation-aware" a standard design axis: after AWQ, a weight quantizer that looks only at weights is understood to be missing the main signal. Its practical footprint is as a named format and method across the serving ecosystem — the paper itself lists adoption by Hugging Face Transformers, NVIDIA TensorRT-LLM, vLLM, LMDeploy, FastChat, Intel Neural Compressor, Microsoft DirectML, Google Vertex AI, Amazon SageMaker, and AMD tooling — and AWQ checkpoints (grouped INT4, group size 128, with pre-applied scales) are a first-class citizen in vLLM, ExLlamaV2, and LMDeploy alongside GPTQ checkpoints, as documented in this corpus's runner dossiers. For a downloader, "AWQ" versus "GPTQ" at the same bit-width is a real choice with a real evidence base: comparable at 4 bits, AWQ ahead at 3 bits and on instruction-tuned / multi-modal models in the paper's measurements.

It also changed the calibration conversation. GPTQ proved a small calibration set suffices; AWQ showed *what you extract from it* determines generalization — a per-channel mean magnitude is a low-capacity statistic that transfers, while full reconstruction can memorize. That lesson generalizes well beyond AWQ itself (see §6b).

## 6. Applicability

### (a) Ollama on a 6 GB card — which formats to prefer, and why

- **At 4 bits, AWQ and GPTQ checkpoints are both sound; prefer AWQ when the specific model offers both and the runner's AWQ kernel is mature**, on the strength of the paper's consistent (if small at INT4) perplexity edge and its stronger instruction-tuned results — chat models are the 6 GB use case, and instruction tuning is precisely where AWQ's generalization claim was tested. If only one format has a fast kernel path in the runner at hand, that kernel fact outweighs the paper margin.
- **At 3 bits, prefer AWQ over GPTQ and strongly over RTN.** The LLaMA-7B INT3 row (RTN 7.01, GPTQ 8.81, GPTQ-with-reorder 6.53, AWQ 6.35 against FP16 5.68) is the single most decision-relevant table in the paper for a memory-starved user: at 3 bits the *method* is worth more than a bit-width step at 4 bits is worth between methods. A 3-bit AWQ 13B-class model is a legitimate way to spend 6 GB; a 3-bit RTN model is not.
- **At 2 bits, AWQ alone is not the answer.** The paper only reaches INT2 by *combining* AWQ scaling with GPTQ compensation, on OPT models, as a research result. Production sub-3-bit choices belong to the QuIP#/AQLM lineage and GGUF's IQ family (see quip-sharp.md).
- **On-device framing transfers directly.** TinyChat's analysis — decode is memory-bound, weight traffic dominates, W4A16 raises arithmetic intensity ~4× — is the same physics on a 6 GB consumer card as on a Jetson. The runner-side requirement is identical too: fused on-the-fly dequantization and sane weight packing, or the format's bandwidth saving never becomes tokens/second.

### (b) Aesir's compression school — what a home-grown quantizer must implement or measure

- **Measure activation statistics, always.** Any Aesir quantizer must, at minimum, collect per-input-channel average activation magnitudes over its calibration set and use them — for saliency-aware scaling (AWQ), for Hessian construction (GPTQ, where $\mathbf{H} = 2\mathbf{X}\mathbf{X}^\top$ encodes the same information at higher capacity), or for both. A weight-only statistic (max, norm) is proven by AWQ's ablation to be near-worthless as an importance signal.
- **Prefer low-capacity calibration statistics when generalization matters, and prove it.** Aesir's grading protocol should include AWQ's own stress test: calibrate on one distribution, grade on another, and report the cross-distribution delta. A quantizer whose faithfulness collapses off-distribution has memorized its calibration set; AWQ's +0.5–0.6 versus GPTQ's +2.3–4.9 (OPT-6.7B INT3, paper Figure 8) is the shape of evidence to demand, re-measured on Aesir's models.
- **Scaling is cheap to implement and composes.** Per-channel pre-scaling with a single searched exponent $\alpha$ per layer is a small amount of code, needs no differentiability and no reconstruction loop, and — per the paper's INT2 experiment — stacks with Hessian compensation rather than competing with it. An Aesir quantizer roadmap that does GPTQ-style compensation *and* AWQ-style pre-scaling is following the literature, not gold-plating.
- **Protect structure, not individual weights.** AWQ's hardware lesson generalizes to GGUF design: whatever protection a quantizer offers salient channels must be expressible inside the uniform grouped format (scales folded into existing per-group/per-channel parameters), never as scattered high-precision exceptions that the kernel cannot stream.
- **Grade instruction-tuned behaviour separately.** Perplexity on a base-model corpus did not predict GPTQ's multi-modal collapse in AWQ's experiments. Aesir's faithfulness grading should include at least one downstream, instruction-style evaluation per quantized artifact, not perplexity alone.

## 7. Cross-links

- **ExLlamaV2 dossier** (`runners/exllamav2.md`): ExLlamaV2 serves both GPTQ and AWQ checkpoints, and its continuous bit-rate provisioning answers the complementary question — AWQ decides *how* each layer's weights are rounded at a given bit-width; ExLlama-style allocation decides *how many* bits each layer gets. A strong pipeline needs both decisions made well.
- **Aesir ideas dossier** (`aesir/aesir-ideas-for-ollama.md`): AWQ supplies the compression school's calibration-discipline doctrine — low-capacity activation statistics, cross-distribution grading, scaling-before-rounding — and its clearest worked example that a simpler method can beat a heavier one by measuring the right thing.
- **KV wave (KIVI / KVQuant dossiers, `papers/kivi.md`, `papers/kvquant.md`):** the symmetry is exact — AWQ finds that a few activation channels are persistently huge and lets that geometry dictate weight quantization; KIVI finds the same persistent outlier channels in the key cache and lets that geometry dictate cache quantization (per-channel for keys). One outlier phenomenon, two artifacts, same engineering moral: profile the distribution first, then choose the quantization axes.

## 8. Sources

- Lin et al., AWQ, arXiv:2306.00978 — abstract page and HTML full text (v5, MLSys 2024 proceedings version). https://arxiv.org/abs/2306.00978 ; https://arxiv.org/html/2306.00978v5
- Date accessed: **2026-11-15** for all sources in this dossier.
