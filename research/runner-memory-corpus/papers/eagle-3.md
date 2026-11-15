# EAGLE-3 — Scaling up Inference Acceleration of Large Language Models via Training-Time Test

## 1. Full citation

- **Title:** EAGLE-3: Scaling up Inference Acceleration of Large Language Models via Training-Time Test
- **Authors:** Yuhui Li, Fangyun Wei, Chao Zhang, Hongyang Zhang (Peking University / University of Waterloo; Microsoft Research; Vector Institute)
- **Venue / year:** 39th Conference on Neural Information Processing Systems (NeurIPS 2025).
- **arXiv:** arXiv:2503.01840 [cs.CL] — submitted 3 Mar 2025, v3 23 Apr 2025 — https://arxiv.org/abs/2503.01840
- **Code (as reported in the paper):** https://github.com/SafeAILab/EAGLE (shared repo for EAGLE / EAGLE-2 / EAGLE-3)
- **Lineage note:** EAGLE-2 (Li et al., EMNLP 2024) is a separate paper contributing the *context-aware dynamic draft tree* — draft-tree shape is pruned/expanded per context using draft-model confidence as an acceptance proxy. EAGLE-3 adopts EAGLE-2's tree wholesale; its own contributions are the drafter architecture and training scheme below. This dossier covers EAGLE-3, citing EAGLE-2 only for that inherited component.

## 2. The problem

EAGLE works, but it does not *scale*. The natural next lever — train the drafter on much more data, the way base models improved from 1T to 15T tokens across the LLaMA generations — barely helps EAGLE: its speedup curve flattens as draft-training data grows. EAGLE-3's diagnosis is that EAGLE's defining choice, feature prediction, is itself the ceiling. Forcing the drafter's hidden output to *be* the target's next top-layer feature (via the regression loss $l_{fea}$) constrains the drafter's expressiveness, and it chains the drafter to top-layer features as its only input — features that, the paper argues, are specialised for predicting the *next* token and carry limited information for predicting tokens several steps ahead. The problem EAGLE-3 attacks is therefore: remove the constraint that caps the drafter, in a way that survives multi-step drafting, so that draft quality becomes a function of training-data scale.

## 3. Core idea / mechanism in our own words

EAGLE-3 keeps the speculative-sampling skeleton untouched — draft cheaply, verify in parallel with tree attention, accept by $\min(1, p/\hat p)$, resample rejections from the residual — so **losslessness is inherited unchanged**. All three changes are inside the drafter:

**Change 1 — predict tokens directly; drop the feature-prediction constraint.** The drafter's output vector $a$ is no longer required to approximate the target's feature $f$. It is an unconstrained hidden vector whose only job is to produce good token distributions when passed through the target's LM head. The regression loss $l_{fea}$ is deleted; training optimises token prediction. This frees the drafter's internal representation to encode whatever helps multi-step token prediction, rather than mimicking one layer of the target.

**Change 2 — fuse features from multiple target layers.** Because the output no longer has to live in top-layer feature space, the *input* is freed too. Instead of only the top-layer (pre-LM-head) feature, the drafter consumes a fusion $g$ of the target's low-, middle-, and high-level features: the three $k$-dimensional vectors are concatenated ($3k$) and projected back to $k$ by a fully-connected layer. Lower layers carry more token-identity / syntactic information, higher layers more next-token semantics; the paper's argument is that multi-step drafting needs both. The shifted-token conditioning from EAGLE is retained: the sampled token's embedding is concatenated with $g$ before the drafter's single decoder layer, for the same uncertainty-resolution reason as in EAGLE.

**Change 3 — training-time test (the named technique).** Removing the feature constraint creates a train/test mismatch: at inference, draft step 2+ must consume the drafter's *own* previous outputs $a$ in place of the unavailable target features $g$ (the target has not yet verified those positions), and raw $a$ vectors are far from $g$ in distribution, so a conventionally trained drafter collapses at step 2 (the paper's Fig. 4 shows $1$-$\alpha$ cratering). Training-time test closes the gap by *simulating the test procedure during training*: unroll several draft steps in training, feed each step's own output back as the next step's input, and train through that unroll (with adjusted attention masks so each simulated step attends correctly to original data and its own prediction chain). The drafter is thus trained on exactly the degraded, self-generated inputs it will face at inference. This is the same conceptual move as scheduled sampling / HASS's multi-step training, but applied after removing feature prediction — HASS (Zhang et al., 2024) keeps $l_{fea}$ and top-layer inputs; EAGLE-3's claim is that only *without* the constraint does the unrolled training unlock data scaling.

**The resulting scaling claim.** With changes 1–3, draft-training data scale (ShareGPT = 1× reference) produces a *rising* speedup curve on MT-Bench / LLaMA-Instruct 3.1 8B where EAGLE's curve was flat — presented as the first scaling law for inference acceleration: more drafter data → proportionally higher speedup, with headroom remaining. EAGLE-3 is trained on ~8× EAGLE's data (ShareGPT ~68k + UltraChat-200K ~464k entries, with target-generated responses; plus OpenThoughts-114k-math for the reasoning-model drafter).

## 4. Design details an engineer needs

- **Drafter form factor is unchanged in size:** still one Transformer decoder layer plus FC fusion layers, reusing the target's embedding and LM head. Inputs per step: fused feature $g$ (from the last target pass) *or* the drafter's own previous output $a$ (for steps beyond the first), concatenated with the sampled token's embedding, projected $2k \rightarrow k$, then the decoder layer, then LM head → draft distribution.
- **Dynamic tree:** drafting uses EAGLE-2's context-aware tree — confidence-scored expansion and pruning rather than a fixed static tree. Verification is tree attention over that tree in one target pass, as in EAGLE.
- **Training recipe (as reported):** AdamW ($\beta$ 0.9/0.95), lr 5e-5, gradient clipping 0.5. Training responses are generated by calling the target model (not fixed dataset responses). Multi-step unrolled training requires the special attention masks of the paper's Fig. 6; the implementation trick noted is that simulated-step attention against original data can be computed with vector dot products rather than full matrix multiplies to avoid waste.
- **Acceptance metric:** $n$-$\alpha$ as in EAGLE (acceptance given $n$ self-predicted inputs in the chain). The paper's Fig. 7 (MT-Bench, LLaMA-Instruct 3.1 8B) is the key diagnostic: EAGLE's acceptance falls steeply as $n$ grows; EAGLE-3's stays almost flat — direct evidence that training-time test removes the error-accumulation cliff rather than merely raising step-1 accuracy.
- **Ablation (MT-Bench / GSM8K, LLaMA-Instruct 3.1 8B, temp 0):** EAGLE-2 baseline 3.16× / $\tau$ 4.05 (MT-Bench) → removing the feature constraint alone: 3.82× / 5.37 → adding fused multi-layer features: **4.40× / 6.13**. Both changes contribute materially; neither is decorative.
- **Production check — SGLang:** evaluated by the SGLang team (v0.4.4, single H100, LLaMA-Instruct 3.1 8B, MT-Bench, chain draft length 3, *no tree*): original EAGLE *loses* throughput beyond batch 24 (0.93× at 24, 0.99× at 64), while EAGLE-3 still gains at every batch size — 1.81× at batch 2 down to **1.38× at batch 64**. This is the family's strongest evidence that a well-trained drafter can help throughput, not only single-stream latency.

## 5. Reported results — as reported, with context

All figures are the paper's own. Targets: Vicuna 13B, LLaMA-Instruct 3.1 8B, LLaMA-Instruct 3.3 70B, DeepSeek-R1-Distill-LLaMA 8B (reasoning). Tasks: MT-Bench (chat), HumanEval (code), GSM8K (maths), Alpaca (instruction), CNN/DailyMail (summarisation). Baseline: vanilla autoregressive decoding; batch size 1 for the latency table.

**Headline (abstract):** speedup **up to 6.5×** vs vanilla; **~1.4× over EAGLE-2** at batch 1; **1.38× SGLang throughput at batch 64**.

**Mean speedup / $\tau$ across the five tasks (temp 0), from Table 1:**

| Target | EAGLE | EAGLE-2 | EAGLE-3 |
|---|---|---|---|
| Vicuna 13B | 3.05× / 3.96 | 4.22× / 4.83 | **5.51× / 6.62** |
| LLaMA-Instruct 3.1 8B | — | 3.23× / 4.11 | **4.44× / 6.23** |
| LLaMA-Instruct 3.3 70B | — | 2.85× / 3.78 | **4.12× / 5.88** |
| DeepSeek-R1-Distill-LLaMA 8B | — | 3.26× / 3.92 | **4.16× / 5.84** |

- The 6.5× maximum is specific: **Vicuna 13B on HumanEval at temp 0 — 6.47×, $\tau$ 7.54**. Code remains the easiest drafting terrain (fixed templates), as in every paper in this wave.
- At temp 1 the same means compress to 3.45–4.65× (e.g. Vicuna 13B 4.65× / $\tau$ 5.67; LLaMA 3.1 8B 3.45× / 4.92) — still the best in the comparison table, but the temp-0 headlines overstate what a sampling chat workload should expect by roughly a quarter.
- Summarisation (CNN/DM) is consistently the weakest task for EAGLE-3 (e.g. 3.27× on the 70B target at temp 0), and the reasoning model's best task is GSM8K (5.01×, temp 0) — plausibly, the paper notes, because its drafter was additionally trained on a maths-reasoning dataset. Drafter training data *chooses* where the speedup lives.
- Context for the comparison rows (Vicuna 13B, temp 0, mean): plain speculative sampling 1.92×, PLD (prompt lookup) 1.74×, Medusa 2.12×, Lookahead 1.62×, Hydra 2.80× — EAGLE-3's 5.51× is ~2.6× the Medusa figure on the same target.

## 6. Limitations

- The scaling law is demonstrated over ~8× data range on one primary scaling plot (MT-Bench, one 8B target). "More data keeps helping" is shown, not proven to datacentre scale, and each step up costs target-generated training data — the drafter's training set must be produced by running the target model itself.
- One bespoke drafter per target model, as with all EAGLE-family methods — now with a *larger* training bill than EAGLE-1 (more data, unrolled training, target-in-the-loop data generation). The amortisation argument (train once, serve many queries) is strong for a hosted model and weak for a user's arbitrary local model.
- Requires access to the target's *internal multi-layer features* at inference. Any runtime that treats the target as a black box (API models, some quantised pipelines that fuse or discard intermediate activations) cannot host EAGLE-3 drafting without engine-level integration.
- Headline numbers are batch-1, temp-0, on datacentre evaluation setups; the SGLang batch results are more conservative (≤1.82×) and are the better guide for served throughput.
- No quality evaluation is presented — correctly, since the method is lossless by construction — but that also means the paper provides no evidence about drafter behaviour under distribution shift (unusual personas, languages, or long contexts) beyond the five standard tasks.

## 7. Applicability

### (a) Ollama on a 6 GB GPU, single user, long chat

- **Best-in-family speed, same residency class as EAGLE.** The drafter is still a single decoder layer plus small fusion projections — sub-GB at low precision for 7–8B targets (see eagle.md §7a for the arithmetic). If a trained EAGLE-3 checkpoint exists for the user's model, it is the strongest speculation option that fits a 6 GB card: paper-grade expectations for chat-like work are the temp-1, MT-Bench-class figures (~3–4.5× latency on 8–13B targets in the paper's setup) as an *upper reference*, discounted for GGUF quantisation and consumer hardware.
- **This is the EAGLE variant the GGUF world actually ships.** Current llama.cpp exposes an EAGLE-3 draft path (`--spec-type draft-eagle3`) alongside draft-model and n-gram speculation, and EAGLE-3 checkpoints circulate for popular LLaMA/Qwen-family targets. That makes EAGLE-3, alone among the trained-head methods in this wave, a realistic near-term Ollama-adjacent option: same GGUF target, plus a small EAGLE-3 draft file, verified losslessly. Ollama itself does not surface these controls; reaching them today means driving llama.cpp directly.
- **Long-chat caution — context length of the drafter's training.** Drafters are trained on ShareGPT/UltraChat-length dialogues. In a very long session (tens of thousands of tokens of accumulated context), the drafter conditions on fused features from a context regime it never trained in; watch $\tau$ decay over session length before trusting the headline. The n-gram path has the opposite profile (it *feeds* on accumulated session text), which is why the two compose well: n-gram for the repetitive long tail, EAGLE-3 for fresh prose.
- **Budget rule:** EAGLE-3 draft file + its KV/tree buffers must still leave the target's long-context KV intact. If the choice is between EAGLE-3 and 8k more tokens of context on a 6 GB card, long chat usually wants the context — a drafter can be toggled per session; a truncated persona cannot be un-truncated.

### (b) Project Aesir

- Training-time test is the transferable invention, independent of EAGLE: *train every Aesir drafter under the input degradation it will face at inference* — its own previous outputs fed back, for the full draft depth. Aesir's drafter training harness should unroll to the maximum draft depth used at runtime and report $n$-$\alpha$ curves as the acceptance gate for shipping a drafter.
- Multi-layer feature fusion argues for an Aesir engine contract: the target pass must be able to *export* features from at least three depths (low/mid/high) plus the LM-head logits, per position, for accepted tokens. Design that export into the forward-pass API now; retrofitting it into fused kernels later is the expensive path. For hybrid SSM models, the analogous export is (attention features at several depths + SSM state summaries) — decide the drafter-visible state surface deliberately.
- The scaling result reframes drafter training as a *data* problem Aesir can win locally: Aesir sessions generate target-verified text continuously, which is exactly training-time-test training data. A per-user drafter improvement loop (train on the user's own verified sessions, on-device during idle) is the local, private analogue of EAGLE-3's data scaling — and it converges with the online-speculative-decoding dossier's thesis.
- Keep EAGLE-2's dynamic tree: confidence-pruned trees spend verification FLOPs where acceptance is likely, which matters more on Aesir's thermally constrained targets (Pi-class, iGPU) than on an H100.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2503.01840
- arXiv HTML (read for method + evaluation detail): https://arxiv.org/html/2503.01840v3
- NeurIPS 2025 proceedings record: https://proceedings.neurips.cc/paper_files/paper/2025/hash/c7b5a35ea98b62512a869c19ea7b03cb-Abstract-Conference.html
