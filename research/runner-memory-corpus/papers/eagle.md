# EAGLE — Speculative Sampling Requires Rethinking Feature Uncertainty

## 1. Full citation

- **Title:** EAGLE: Speculative Sampling Requires Rethinking Feature Uncertainty
- **Authors:** Yuhui Li, Fangyun Wei, Chao Zhang, Hongyang Zhang (Peking University; Microsoft Research; University of Waterloo / Vector Institute)
- **Venue / year:** Proceedings of the 41st International Conference on Machine Learning (ICML 2024), PMLR 235.
- **arXiv:** arXiv:2401.15077 [cs.LG] — submitted 26 Jan 2024; v3 4 Mar 2025 — https://arxiv.org/abs/2401.15077
- **Code (as reported in the paper):** https://github.com/SafeAILab/EAGLE
- **Name:** EAGLE = Extrapolation Algorithm for Greater Language-model Efficiency. (The later EAGLE-2, with context-aware dynamic draft trees, is a separate EMNLP 2024 paper and is covered only as context in the EAGLE-3 dossier.)

## 2. The problem

Two failures of the 2023 speculative-decoding setup motivate EAGLE. First, the *draft-model gap*: for a 7B target there is often no suitable smaller same-family drafter at all, and using a 7B model to draft for a 13B target is so expensive that the paper reports *no speedup* in that pairing (1.12× even at 33B, 1.88× at 70B for plain speculative sampling with a 7B draft). Training a dedicated small model from scratch is worse — the paper contrasts TinyLLaMA's 3,000B training tokens with EAGLE's 2–4B. Second, the *accuracy ceiling of token-level drafting*: a standalone draft model must commit to exact tokens from a ~32k+ vocabulary; Medusa-style parallel heads avoid the second model but predict positions independently and reach only ~0.6 draft accuracy. EAGLE asks where a drafter can stand so that prediction is intrinsically *easier* while drafting stays autoregressive and cheap.

## 3. Core idea / mechanism in our own words

**Observation 1 — predict features, not tokens.** The target's *second-to-top-layer feature* $f$ (the hidden state just before the LM head) is a continuous, structured vector. The sequence of features is more regular and predictable than the sequence of discrete tokens sampled from them. So EAGLE's drafter autoregresses *in feature space*: predict $\hat f_{i+1}$ from past features, then obtain the draft token by passing $\hat f_{i+1}$ through the target's own (frozen) LM head. Feature prediction is a regression problem and empirically far more accurate than token prediction at equal drafter size — in the paper's Vicuna-7B / MT-Bench ablation, feature-level drafting alone lifts speedup from 1.5× (token-level) to 1.9×.

**Observation 2 — feature autoregression has a sampling-uncertainty defect, and a one-step shift fixes it.** The next feature depends on which token was actually *sampled* at the current step: after "I", sampling "am" vs "always" leads to genuinely different next features, and $f_I$ alone cannot say which branch happened. A drafter that sees only features is being asked an ill-posed question. EAGLE's fix is to feed the drafter the token sequence *advanced by one time step* — i.e. the already-known sampled tokens — alongside the feature sequence. The drafter's input at each step is the pair (feature history, shifted token history), so the sampling outcome that determines the next feature is an input, not a hidden variable. In the same ablation this lifts speedup from 1.9× to 2.8×. This shifted-token conditioning is EAGLE's signature move; everything else is engineering around it.

**Draft source.** A single lightweight *Autoregression Head*: the target's embedding layer and LM head are reused frozen; the only trained part is one fully-connected layer (which fuses the concatenated [token embedding; previous feature] vector, $2d \rightarrow d$) plus one standard Transformer decoder layer. Trainable size: 0.24B for a 7B target, 0.37B (13B), 0.56B (33B), 0.99B (70B), 0.28B for Mixtral 8×7B. The backbone is never fine-tuned.

**Draft construction — tree.** The head autoregresses step by step, branching at each step to grow a *draft tree* (the paper's example: a 10-token tree in 3 head passes). Multiple candidate continuations therefore exist per position, as in Medusa/SpecInfer, but each branch is produced by genuine autoregressive feature prediction conditioned on that branch's own tokens — unlike Medusa's independent heads.

**Verification rule.** Standard speculative sampling, applied recursively over the tree with tree attention (one target pass scores the whole tree; ancestor-only masking as in Medusa). Acceptance probability $\min(1, p/\hat p)$ per token along a path; first rejection resamples from $\mathrm{norm}(\max(0, p-\hat p))$ and discards the rest of that path. **Output distribution is therefore preserved exactly (greedy and non-greedy)** — EAGLE is lossless by the same proof as Leviathan/Chen, a point the paper stresses against Medusa's typical acceptance and Lookahead's greedy focus.

## 4. Design details an engineer needs

- **Training objective:** combined loss $L = L_{reg} + 0.1 \cdot L_{cls}$, where $L_{reg}$ is Smooth-L1 between predicted and true next features, and $L_{cls}$ is cross-entropy between the token distributions obtained by passing predicted vs true features through the LM head. Training data: fixed ShareGPT set (~68k dialogues) — notably *not* target-generated text; the paper reports low sensitivity to the training set. AdamW, lr 3e-5, gradient clipping 0.5.
- **Error-accumulation defence:** because at inference the head consumes its *own* predicted features (which drift), training adds uniform noise $\mathcal{U}(-0.1, 0.1)$ to target features as augmentation. The paper's $n$-$\alpha$ measurements (acceptance when the input already contains $n$ self-predicted features) quantify the residual drift: on MT-Bench at temp 0, $0$-$\alpha \approx 0.75$–$0.79$ falling only to $4$-$\alpha \approx 0.64$–$0.70$ across Vicuna / LLaMA2-Chat 7B–70B.
- **Training cost:** 1–2 days on 4× A100 40G for the 70B head; 7B/13B/33B heads trainable in 1–2 days on a single RTX 3090 node. One head per target model; zero-shot across tasks afterwards (same weights for MT-Bench, HumanEval, GSM8K, Alpaca).
- **Tree attention contribution (ablation):** tree drafting/verification adds ~+0.6–0.8 to acceptance length $\tau$ and ~+0.3–0.5 to speedup over the chain form; chain-only EAGLE still achieves ~2.3–2.7×. Budget accordingly: the head is the main course, the tree is a side dish.
- **Composability:** EAGLE stacks with quantisation/compilation. With gpt-fast on a single RTX 3090, LLaMA2-Chat 7B goes from 24.5 tok/s (HF vanilla) / 55.1 (gpt-fast FP16) / 106.9 (gpt-fast int4) to **100.2 (FP16) / 160.4 (int4) tok/s** with EAGLE added (MT-Bench, temp 0).
- **MoE caveat:** on Mixtral 8×7B Instruct, speedup is only 1.50× ($\tau$ 3.25, MT-Bench temp 0). Reason given: vanilla MoE decoding reads only the ~2 active experts per token, but verifying many drafted tokens touches more experts, so the "verification is almost free" premise weakens. Dense models read all weights anyway, so verification stays cheap for them.

## 5. Reported results — as reported, with context

All figures are the paper's own. Batch size 1 unless noted; baselines are vanilla autoregressive decoding in the same framework; tasks: MT-Bench (dialogue), HumanEval (code), GSM8K (maths), Alpaca (instruction following).

**Headline (abstract):** LLaMA2-Chat 70B latency speedup **2.7–3.5×** across tasks, with doubled throughput, distribution preserved. Against contemporaries on MT-Bench, EAGLE is reported **1.7–2.1× faster than Lookahead** and **1.5–1.6× faster than Medusa**.

**Speedup × / acceptance length $\tau$ (tokens per target pass), selected rows:**

| Setting | Model | HumanEval | GSM8K | Alpaca |
|---|---|---|---|---|
| Temp 0 | Vicuna 7B | 3.33× / 4.29 | 3.01× / 4.00 | 2.79× / 3.86 |
| Temp 0 | LLaMA2-Chat 13B | **3.76× / 4.52** | 3.20× / 4.03 | 3.01× / 3.83 |
| Temp 0 | LLaMA2-Chat 70B | 3.52× / 4.42 | 3.03× / 3.93 | 2.97× / 3.77 |
| Temp 1 | Vicuna 7B | 2.39× / 3.43 | 2.34× / 3.29 | 2.21× / 3.30 |
| Temp 1 | LLaMA2-Chat 70B | 2.92× / 3.76 | 2.74× / 3.58 | 2.65× / 3.47 |

- Pattern to note: code (HumanEval) accepts best (fixed templates), temp 0 always beats temp 1 by ~0.5–0.9× of speedup, and $\tau$ sits at ~3.2–4.5 (temp 0) vs vanilla's 1.0 — i.e. the target pass is doing 3–4.5 tokens of work per weight-streaming.
- MT-Bench acceptance rates (chain draft): $0$-$\alpha$ 0.74–0.79 at temp 0, 0.71–0.73 at temp 1 across the Vicuna and LLaMA2-Chat families — versus ~0.6 quoted for Medusa heads and lower for Lookahead. This $\alpha$ gap, at a drafter cost of one decoder layer per step, is the paper's central empirical claim.

## 6. Limitations

- Still one trained head *per target model*. The head is cheap to train by datacentre standards, but it is a bespoke artefact: no head, no speedup. Community models without a published EAGLE head are unserved until someone trains one on ShareGPT-like data.
- Feature-space drafting couples the drafter tightly to the target's internals (hidden size, LM head, embedding). Quantising or otherwise modifying the target after head training can shift the feature distribution the head expects; the paper evaluates FP16 targets (plus int4 via gpt-fast for the target weights in the composability test) and does not characterise head robustness across aggressive GGUF quant levels of the backbone.
- Error accumulation is mitigated (noise augmentation, $n$-$\alpha$ stays high) but not eliminated; deep draft trees still decay in acceptance with depth.
- MoE targets gain much less (1.50× on Mixtral) for the expert-read reason above.
- All headline numbers are batch-1 latency on A100/3090-class hardware with HF/gpt-fast baselines; throughput at larger batch sizes is claimed ("doubled") with detail deferred to the paper's §4.4, and the win is expected to shrink as batches make decoding compute-bound.

## 7. Applicability

### (a) Ollama on a 6 GB GPU, single user, long chat

- **Residency: the head is small, but not free.** For a 7B target the trained head is 0.24B parameters — roughly 0.5 GB at FP16, ~0.25 GB at Q8, plus its own small KV for the draft tree. That is ~4–8× cheaper than a separate 1–3B draft GGUF and, unlike Medusa heads, it is a *single decoder layer* whose weights llama.cpp already knows how to run. It fits a 6 GB budget next to a Q4 7–8B target far more comfortably than draft-model speculation — *if* a trained head exists for that exact model.
- **The GGUF reality check:** EAGLE heads are distributed as separate checkpoints tied to specific HF models (LLaMA/Vicuna family in the paper). The llama.cpp ecosystem's EAGLE support has historically centred on EAGLE-3 checkpoints (see eagle-3 dossier); classic EAGLE-1 heads for arbitrary community GGUFs are rare. For Ollama use today, the practical ranking on 6 GB remains: (1) n-gram speculation (no weights), (2) small same-family draft GGUF (if it fits), (3) EAGLE-family head (best speed/memory *when a checkpoint exists for your model*). Do not plan a 6 GB setup around a head that has not been published for the chosen model.
- **Long chat fit:** EAGLE was trained once on ShareGPT and applied zero-shot across tasks, which is encouraging for chat, but a persona-heavy character model is again a shifted distribution; expect $\alpha$ below the paper's 0.75–0.79 until measured on real transcripts. The saving grace versus Medusa: the head conditions on the target's *actual features from this conversation*, so it adapts to context at inference time in a way fixed parallel heads do not.
- **Temperature honesty:** character chat at temp ~0.8–1.0 should expect the paper's temp-1 band ($\tau$ ~3.2–3.8, speedup ~2.2–2.9× on 7B-class targets) as the optimistic reference, not the temp-0 headlines.

### (b) Project Aesir

- EAGLE's shifted-token trick is a general lesson for Aesir's drafter design, beyond this one head: *any* feature/state-level predictor must be given the discrete sampling outcomes that its continuous state depends on. For hybrid SSM models the analogue is direct — a drafter predicting the next recurrent state must receive the sampled token, or it faces the same ill-posed branching EAGLE diagnosed.
- Aesir should adopt the $n$-$\alpha$ metric as a standard drafter health check: acceptance as a function of how many consecutive self-predicted states the drafter has consumed. It separates "drafter is inaccurate" from "drafter accumulates error", which need different fixes (more capacity vs noise-augmented / multi-step training — the road EAGLE-3 later takes).
- The head's shape — reuse embedding + LM head, train one decoder layer — is the right default drafter form factor for Aesir-native models: ship the head in the model package, versioned against the backbone's feature layout, and invalidate it automatically when the backbone is re-quantised or fine-tuned.
- Aesir's tree-attention + rollback infrastructure (needed for Medusa) is reused verbatim; EAGLE adds only the requirement to cache *features* of accepted tokens (the verification pass already computes them) as drafter input for the next round.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2401.15077
- arXiv HTML (read for method + evaluation detail): https://arxiv.org/html/2401.15077v3
