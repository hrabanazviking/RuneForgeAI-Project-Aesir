# Medusa — Simple LLM Inference Acceleration Framework with Multiple Decoding Heads

## 1. Full citation

- **Title:** Medusa: Simple LLM Inference Acceleration Framework with Multiple Decoding Heads
- **Authors:** Tianle Cai, Yuhong Li, Zhengyang Geng, Hongwu Peng, Jason D. Lee, Deming Chen, Tri Dao
- **Venue / year:** Proceedings of the 41st International Conference on Machine Learning (ICML 2024), PMLR 235.
- **arXiv:** arXiv:2401.10774 [cs.LG] — submitted 19 Jan 2024, v3 14 Jun 2024 — https://arxiv.org/abs/2401.10774
- **Code (as reported in the paper):** https://github.com/FasterDecoding/Medusa

## 2. The problem

Classic speculative decoding works, but it needs a *separate* draft model: one must be found or trained, kept in sync with the target, and served alongside it — a real burden in distributed serving and a non-starter when no smaller same-family model exists. Medusa asks whether the target model can draft for *itself*: its final hidden state already contains rich information about what comes next, so perhaps a few tiny extra output heads can guess several future tokens at once, with no second model to obtain, host, or keep resident.

## 3. Core idea / mechanism in our own words

**Draft source — the target's own hidden state, $K$ extra heads.** Keep the backbone exactly as it is. On top of its last hidden state $h_t$ at position $t$, attach $K$ lightweight *Medusa heads*. The ordinary LM head predicts token $t+1$; Medusa head $k$ is trained to predict token $t+k+1$ directly from $h_t$. Each head is a single feed-forward layer with a residual connection — $p_t^{(k)} = \mathrm{softmax}(W_2^{(k)}(\mathrm{SiLU}(W_1^{(k)} h_t) + h_t))$ — with $W_2^{(k)}$ initialised from the original LM head and $W_1^{(k)}$ at zero, so heads start out mimicking the LM head. All $K$ heads fire in parallel from the *same* forward pass that produced $h_t$: drafting costs essentially one backbone pass, not $K$ draft-model passes. The price of that parallelism is independence — heads predict their positions without seeing each other's tokens, which caps their accuracy below an autoregressive drafter's (the EAGLE paper measures Medusa-style head accuracy at ~0.6).

**Candidate construction — a tree, not a chain.** Each head contributes its top-$s_k$ predictions. The Cartesian product across heads forms many candidate continuations, organised as a tree whose level $k$ branches by head $k$'s predictions. Rather than the full product, the deployed tree is *sparse and optimised*: using per-head top-prediction accuracies measured on a calibration set, nodes are added greedily by expected contribution to acceptance length until a node budget is reached (the paper's ablation uses a 64-node sparse tree beating a 256-node dense tree).

**Verification — tree attention in one backbone pass.** All candidates are scored by the backbone in a single forward pass using a custom attention mask: each tree token attends only to its ancestors in the tree (its own candidate's prefix) plus the shared context, with positional indices set by depth in the tree, not by position in the flattened batch. This verifies every branch simultaneously without expanding the batch.

**Verification rule — two options, and only one is lossless.**
- *Rejection sampling* (the Leviathan/Chen rule applied along each tree path): preserves the target distribution exactly. The paper notes it cannot further raise the acceptance rate and loses efficiency as temperature rises.
- *Typical acceptance* (the paper's proposed default for speed): accept a candidate token if the *target model's* probability for it exceeds a threshold $\min(\epsilon, \delta \exp(-H(p_{\text{original}})))$, where $H$ is the entropy of the target distribution at that position — plausible tokens pass, with a looser bar when the target itself is uncertain. The first token is always taken greedily; the longest accepted prefix among all candidates wins. **This rule does not preserve the output distribution.** It preserves *judged quality* in the paper's MT-Bench evaluation, which is a weaker and different guarantee. Any dossier or product claim must keep the two rules distinct: Medusa-1/2 with rejection sampling is lossless; Medusa with typical acceptance is a quality-preserving approximation.

## 4. Design details an engineer needs

- **Head count:** up to 5 heads trained; the paper finds 5 sufficient, and with an optimised tree 3–4 often suffice at inference — unused heads can simply be ignored.
- **Two training regimes:**
  - *Medusa-1 (frozen backbone):* only the heads are trained, with per-head cross-entropy $\mathcal{L} = \sum_k -\lambda_k \log p_t^{(k)}(y_{t+k+1})$, $\lambda_k$ decaying as $\sim 0.8^k$ because farther heads are inherently less certain. Because the backbone never moves, output quality is unchanged by construction and training is cheap: the paper reports ~5 hours for Vicuna-7B heads on a single A100 PCIe over 60k ShareGPT samples, and notes the backbone can be quantised during head training (QLoRA-style) so it fits a single consumer GPU.
  - *Medusa-2 (joint training):* heads and backbone train together with a combined loss (LM loss + weighted Medusa loss), differential learning rates, and a heads-warmup two-stage schedule to stop early head gradients from distorting the backbone. Higher head accuracy and speedup, but the backbone's weights change — the result is a *new model*, which must be re-validated as one.
- **Self-distillation:** when the target's fine-tuning data is unavailable or the model went through RLHF, generate the head-training set from the target itself (seed prompts from ShareGPT / UltraChat, model generates replies; ~100k samples in the paper's Vicuna-33B / Zephyr-7B cases). For Medusa-2 the backbone loss becomes a KL distillation loss against the original model, implementable memory-free with a LoRA adapter (adapter off = teacher).
- **Overhead accounting:** the paper reports per-step overhead factors of 1.18–1.27× (Table 1) — a Medusa step costs ~20% more than a vanilla step — against acceptance lengths ("acceleration rates") of ~3.0–3.5 tokens per step. Net speedup is acceptance length divided by overhead; both numbers must be reported together.
- **Tree size is a compute dial:** acceptance length grows only logarithmically with tree nodes while per-step cost grows with nodes processed. Past the sweet spot, bigger trees *reduce* tokens/s even as they raise tokens/step (paper Fig. 4).
- **Batch size:** the paper's experiments are batch size 1 by design ("representative of locally hosted personal use"); larger-batch support is delegated to downstream frameworks (TensorRT-LLM, TGI).

## 5. Reported results — as reported, with context

All figures are the paper's own. Baseline throughout: the default Hugging Face implementation; benchmark: MT-Bench (GPT-4 as quality judge, scores /10); batch size 1.

**Vicuna case study (ShareGPT-trained heads, 2 epochs):**

| Model | Medusa-1 speedup | Medusa-2 speedup |
|---|---|---|
| Vicuna-7B | **2.18×** | **2.83×** |
| Vicuna-13B | **2.33×** | **2.83×** |

- Vicuna-7B quality (MT-Bench, GPT-4 judge): baseline 6.17, Medusa-1 6.23, Medusa-2 6.18; naive direct fine-tuning *degraded* quality to 5.925 — the two-stage recipe is load-bearing.
- Per-category Medusa-2 / Vicuna-7B speedups range widely: extraction 3.62× and coding 3.29× at the top; the 2.3–2.8× headline band is the cross-category range.

**Self-distillation case study (Medusa-2, ~100k self-generated samples):**

| Model | Acceptance length (tokens/step) | Step overhead | Quality Δ vs original | Medusa speedup | Plain speculative decoding speedup (same models, open-source drafts) |
|---|---|---|---|---|---|
| Vicuna-7B | 3.47 | 1.22 | +0.01 | 2.83× | 1.47× |
| Zephyr-7B | 3.14 | 1.18 | −0.07 | 2.66× | — |
| Vicuna-13B | 3.51 | 1.23 | −0.14 | 2.83× | 1.56× |
| Vicuna-33B | 3.01 | 1.27 | +0.05 | 2.35× | 1.60× |

**Ablation ladder (Vicuna-7B):** Medusa-1 heads with a single chain candidate ~1.5× → adding tree attention ~1.9× → optimised sparse tree ~2.2× → Medusa-2 joint training ~2.8×. Roughly half the total gain is the verification machinery (tree), not the heads themselves.

**Abstract headline:** Medusa-1 "over 2.2× speedup without compromising generation quality"; Medusa-2 "2.3–3.6×" (the 3.6× upper end is the best single category, extraction on Vicuna-7B — the cross-model band in the body is 2.3–2.8×).

## 6. Limitations

- Heads must be trained *per target model* on data matching its output distribution. There is no universal Medusa head; a GGUF model without published heads gets nothing until someone trains them.
- Head predictions are position-independent (no autoregressive conditioning between heads), so per-token accuracy is intrinsically lower than EAGLE-style drafting; the tree compensates by trying many branches, spending compute to do so.
- Typical acceptance — the configuration behind the most favourable speed/temperature behaviour — is not distribution-preserving. Deployments that promise "same output, faster" must use rejection sampling and accept its lower speedup.
- Medusa-2 changes the backbone: it is a fine-tune, with all the regression-testing burden that implies, and its quality evidence is a GPT-4-judged MT-Bench delta, not an exactness proof.
- Gains are demonstrated at batch size 1 on A100-class hardware against a Hugging Face baseline; a highly optimised baseline (continuous batching, fused kernels) narrows the relative win.

## 7. Applicability

### (a) Ollama on a 6 GB GPU, single user, long chat

- **Memory is Medusa's decisive advantage in this family.** There is no draft model. The extra resident weights are $K$ heads, each dominated by a $d \times V$ projection — for a 7B-class model (hidden 4096, vocab ~32k) that is on the order of 130M parameters per head in full precision, i.e. a few hundred MB for a small head set at low precision, versus 0.5–4 GB for a separate draft GGUF. On a 6 GB card where the target Q4 already takes ~4–5 GB, Medusa is the only *neural* drafter that plausibly fits alongside a long-chat KV cache — provided heads exist for the exact model.
- **That proviso is the blocker in a GGUF world.** llama.cpp / Ollama models are distributed as quantised GGUF weights, usually without Medusa heads, and head training (Medusa-1) needs the *unquantised* backbone's hidden states plus a matching dataset. In practice today: llama.cpp's shipped speculation options are draft-model and n-gram based; Medusa-style multi-token heads appear in the GGUF ecosystem mainly where a model family ships them natively (multi-token-prediction models), not as bolt-on heads for arbitrary community GGUFs. Treat Medusa as the design to copy when *we* control a model's release, not as a switch available for arbitrary Ollama models.
- **For long chat specifically:** heads are trained on general chat data (ShareGPT-style); a heavily persona'd character model is a distribution shift away from that, so expect acceptance lengths below the paper's 3.0–3.5 until heads are self-distilled on text in the target model's own voice — the paper's self-distillation recipe is exactly the tool for that, and it runs on one GPU.
- **Verification-rule discipline matters for chat:** character work often uses elevated temperature for creativity. That is precisely the regime where the paper pushes typical acceptance — which changes the distribution. If the product promise is "same model, faster", use rejection sampling; if typical acceptance is used, say plainly that output is approximately, not exactly, the base model's.

### (b) Project Aesir

- Medusa is the cheapest possible *integrated* drafter for Aesir-native models: when Aesir ships its own fine-tunes, bake Medusa-1-style heads in at fine-tune time (frozen-backbone head training is a few GPU-hours) and ship heads inside the model package with a manifest entry, so the runner gets speculation with zero extra model files and zero extra residency beyond the heads.
- Aesir's runtime needs the two generic primitives Medusa requires regardless of drafter: tree attention (ancestor-only mask + depth-based positions) and per-candidate KV bookkeeping. Build them once for Medusa and EAGLE / EAGLE-2 dynamic trees reuse them unchanged.
- Keep both acceptance rules in the engine, explicitly labelled: `exact` (rejection sampling) and `typical` (thresholded), with the session recording which was used. Aesir's correctness grading (teacher-forcing rank + logit gap against the unmodified model) can then measure typical acceptance's actual drift on Aesir workloads instead of trusting a judge score.
- For hybrid SSM models, heads read the final hidden state as usual; nothing in Medusa touches the recurrent state except through verification rollback, which Aesir already needs for any tree drafter (see speculative-decoding dossier §7b).

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2401.10774
- arXiv HTML (read for method + evaluation detail): https://arxiv.org/html/2401.10774v3
