# Speculative Decoding / Speculative Sampling — Fast Inference from Transformers via Speculative Decoding + Accelerating Large Language Model Decoding with Speculative Sampling

## 1. Full citation

This dossier covers two near-simultaneous, independent papers that introduced the same core algorithm under two names. They are treated as one family origin.

- **Paper A — Speculative Decoding**
  - **Title:** Fast Inference from Transformers via Speculative Decoding
  - **Authors:** Yaniv Leviathan, Matan Kalman, Yossi Matias (Google Research)
  - **Venue / year:** Proceedings of the 40th International Conference on Machine Learning (ICML 2023), PMLR 202, pp. 19274–19286. Oral.
  - **arXiv:** arXiv:2211.17192 [cs.LG] — submitted 30 Nov 2022, v2 18 May 2023 — https://arxiv.org/abs/2211.17192

- **Paper B — Speculative Sampling**
  - **Title:** Accelerating Large Language Model Decoding with Speculative Sampling
  - **Authors:** Charlie Chen, Sebastian Borgeaud, Geoffrey Irving, Jean-Baptiste Lespiau, Laurent Sifre, John Jumper (DeepMind)
  - **Venue / year:** arXiv preprint, 2023. No peer-reviewed conference version is listed on the arXiv record.
  - **arXiv:** arXiv:2302.01318 [cs.CL] — submitted 2 Feb 2023 — https://arxiv.org/abs/2302.01318
  - **Note on simultaneity:** Chen et al. state explicitly that the work was "undertaken concurrently and independently" of Leviathan et al. Leviathan et al. appeared first on arXiv (Nov 2022 vs Feb 2023); both use a draft-then-verify loop with a modified rejection-sampling correction.

## 2. The problem

Autoregressive decoding produces one token per full forward pass of the target model. For a $K$-token reply that is $K$ serial passes. At batch size 1 — the single-user chat case — each pass is memory-bandwidth bound, not compute bound: the accelerator must stream all model weights (and the KV cache) from HBM for a single token's worth of arithmetic, leaving most FLOPs idle. Making the model larger makes each pass proportionally slower, and sharding it across devices adds all-reduce / communication latency per token. Quantisation and distillation shrink the pass; they do not reduce the number of serial passes.

## 3. Core idea / mechanism in our own words

**Draft source.** A much cheaper *approximation / draft model* $M_q$ with distribution $q$ autoregressively proposes $\gamma$ (Leviathan notation) / $K$ (Chen notation) tokens in a row. $M_q$ must share the target's vocabulary / tokeniser. It can be any autoregressive model — in the papers, a smaller model from the same family; Leviathan et al. also discuss negligible-cost drafters such as bigram / n-gram tables and context-copy heuristics, and non-autoregressive drafters.

**Parallel verification.** The target model $M_p$ with distribution $p$ scores the whole drafted block in *one* parallel forward pass, producing $p_1,\dots,p_{\gamma+1}$ for the prefix and each drafted prefix extension. Scoring $\gamma+1$ positions costs about the same wall time as sampling one token, because the pass is bandwidth-bound: weights are loaded once, and the extra positions are almost free arithmetic.

**Verification rule — modified rejection sampling (the lossless step).** Walk the draft left to right. For draft token $x_i \sim q_i$, draw $r \sim U[0,1]$ and accept it if $r < \min(1, p_i(x_i)/q_i(x_i))$ — i.e. always accept when $p_i \ge q_i$, accept with probability $p_i/q_i$ otherwise. Stop at the first rejection. Then emit one correction token sampled from the residual distribution $p'(x) = \mathrm{norm}(\max(0, p_{n+1}(x)-q_{n+1}(x)))$, where $n$ is the number accepted. If all $\gamma$ drafts are accepted, emit one extra bonus token sampled directly from $p_{\gamma+1}$.

**Why the output distribution is preserved.** The accept step plus the residual resample is a rejection-sampling construction whose marginal is exactly $p$, for *any* $q$ (proved in both papers; Chen et al. qualify this as "within hardware numerics" because different computation graphs produce different floating-point rounding). Greedy decoding is the temperature-0 special case: accept iff the draft token equals the target's argmax. Every iteration therefore emits between 1 and $\gamma+1$ tokens and can never emit fewer than vanilla decoding would in one pass — worst case it degrades to vanilla speed plus draft overhead, never to wrong-distribution output.

**Speedup law (Leviathan et al.).** Let $\alpha = E[\beta]$ be the mean per-token acceptance probability, $\alpha = \sum_x \min(p(x),q(x))$, and $c$ the ratio of one draft pass time to one target pass time. Expected tokens per target pass $= (1-\alpha^{\gamma+1})/(1-\alpha)$. Expected wall-time speedup $= (1-\alpha^{\gamma+1}) / ((1-\alpha)(\gamma c + 1))$. Two consequences an engineer should internalise: (1) speedup is super-sensitive to $\alpha$ and only weakly helped by a larger $\gamma$ once $\alpha^\gamma$ is small; (2) a *bigger* draft can lose — it raises $\alpha$ slightly but raises $c$ a lot. In Leviathan's T5 sweep the smallest draft won.

## 4. Design details an engineer needs

- **Same tokeniser / vocabulary is mandatory** for the plain form: $p_i$ and $q_i$ must be distributions over the same tokens, and the residual $p-q$ must be meaningful position by position.
- **Draft length $\gamma$/$K$ is a tuned, workload-dependent knob**, not "longer is better". Chen et al. find XSum optimal at $K=3$ (they test $K=4$ in the headline table); Leviathan et al. use $\gamma=3$–$7$ depending on draft size and task. Longer drafts cost linearly more draft time, later positions are accepted only if all earlier ones were, and latency variance grows with $K$ — a P99 concern.
- **Cost coefficient target:** Leviathan et al. report $c < 0.05$ in their experiments, with drafters roughly two orders of magnitude smaller than the target performing best. Chen et al. make the distributed version of the same point: a conventionally shaped 7B draft served on its own optimal topology (4 TPU v4s, 5 ms/token) is a poor drafter for a 70B target served on 16 TPU v4s (14.1 ms/token). They instead trained a wide, shallow 4B draft (8 layers) that samples at 1.8 ms/token *on the target's own 16-TPU topology*, minimising communication overhead. Draft *shape* matters, not just draft size.
- **KV handling:** the target pass computes KV for all drafted positions; on rejection, KV entries past the accepted prefix plus correction token must be discarded / rolled back. The draft model maintains its own KV, truncated to the same point. Getting rollback wrong corrupts all subsequent output — it is the main implementation hazard.
- **Sampling methods:** temperature, top-$k$, and nucleus are folded in by adjusting $p$ and $q$ *before* the rejection step ("standardised sampling" in Leviathan et al.); the correction proof then applies to the adjusted distributions.
- **Arithmetic vs memory:** total FLOPs *increase* (wasted work on rejected positions plus draft passes); total weight/KV memory reads *decrease* by the tokens-per-pass factor. The trade only wins while decoding is bandwidth-bound — at large batch sizes, where the target pass becomes compute-bound, the advantage shrinks or reverses.
- **No target retraining, no architecture change.** Any off-the-shelf pair works in principle; only $\alpha$ and $c$ decide whether it helps.

## 5. Reported results — as reported, with context

All figures are the papers' own measurements.

**Leviathan et al. — T5-XXL target (11B), batch size 1, single TPU-v4, baseline = standard T5X implementation:**

| Task | Draft | Temp | $\gamma$ | $\alpha$ | Speedup |
|---|---|---|---|---|---|
| WMT En→De translation | T5-small (77M) | 0 (greedy) | 7 | 0.75 | **3.4×** |
| WMT En→De translation | T5-small (77M) | 1 | 7 | 0.62 | **2.6×** |
| CNN/DailyMail summarisation | T5-small (77M) | 0 | 5 | 0.65 | **3.1×** |
| CNN/DailyMail summarisation | T5-small (77M) | 1 | 5 | 0.53 | **2.3×** |

- Larger drafts raised $\alpha$ but lowered speedup: on En→De at temp 0, T5-base (250M, $\alpha$ 0.80) gave 2.8× and T5-large (800M, $\alpha$ 0.82) gave only 1.7×.
- Acceptance rates measured across model pairs (10k target-generated tokens): small same-family drafters give $\alpha \approx 0.5$–$0.9$; sharper (lower-temperature) distributions give higher $\alpha$. Even a trivial bigram drafter on En→De with T5-XXL gave $\alpha \approx 0.20$ at temp 0 and, because its $c \approx 0$, a reported 1.25× speedup at $\gamma=3$. A 6M GPT-like drafter for a 97M GPT-like target (lm1b) gave $\alpha \approx 0.88$–$0.89$.
- Headline claim: **2–3×** on T5-XXL with identical outputs. Additional $\alpha$ measurements (no wall-time implementation) cover a 97M GPT-like model and LaMDA 137B with LaMDA 100M / 2B / 8B drafters on a dialogue task.

**Chen et al. — Chinchilla target (70B), distributed on 16 TPU v4s, batch size 1, draft = custom 4B wide/shallow model (1.8 ms/token vs target 14.1 ms/token), $K=4$ in Table 1:**

| Task | Sampling | Baseline quality | SpS quality | Mean token time | Speedup |
|---|---|---|---|---|---|
| XSum (1-shot, max len 128, 11,305 seqs) | Nucleus $p=0.8$ | ROUGE-2 0.112 | 0.114 | 14.1 → 7.52 ms | **1.92×** |
| XSum | Greedy | ROUGE-2 0.157 | 0.156 | 14.1 → 7.00 ms | **2.01×** |
| HumanEval (100-shot, max len 512, 16,400 samples) | Nucleus $p=0.95$, temp 0.8 | 45.1% | 47.0% | 14.1 → 5.73 ms | **2.46×** |

- Headline claim: **2–2.5×** in a distributed setup with no quality compromise. Quality parity is the empirical check of losslessness (exact token-for-token identity is *not* expected under sampling, due to numerics and RNG-stream differences).
- Code (HumanEval) accepted better than summarisation — the authors attribute this to common code subsequences, shorter tokens, and temperature sharpening.

## 6. Limitations

- Needs a good draft model to exist. For the smallest model in a family there may be nothing suitable below it; training a dedicated draft costs data and compute (Chen's 4B draft was trained for the purpose).
- Gains collapse when $\alpha$ is low (open-ended, high-entropy, or domain-shifted text) or when $c$ is high (draft not much faster than target). With $\alpha < c$ there may be no $\gamma$ that helps at all (Leviathan Corollary 3.9 contrapositive in practice).
- A latency technique for small batches. As batch size grows, verification of many positions stops being "free" and throughput-oriented batching wins instead.
- Two models resident means two weight sets and two KV caches in memory (see §7a — decisive on small GPUs).
- Exactness is distributional, not bitwise: under sampling, outputs differ run-to-run from vanilla sampling even though the distribution is the same.

## 7. Applicability

### (a) Ollama on a 6 GB GPU, single user, long chat — where does the draft live?

This is the family's home turf in one respect — batch size 1, bandwidth-bound, latency is the whole user experience — and its hardest constraint in another: memory.

- **The budget arithmetic.** On a 6 GB card running, say, a 7–8B model at Q4, target weights already take roughly 4–5 GB, leaving ~1–2 GB for KV cache, compute buffers, and *everything else*. A separate neural draft must fit in that remainder *without* evicting KV that a long chat needs. Realistic candidates: a 0.5–1B same-family model at Q4/Q8 (~0.3–1.0 GB) or a 1–3B model only if the target is smaller (e.g. a 3–4B target). A draft that forces a shorter context window to fit is a bad trade for long character chat.
- **Placement options, in order of fit for 6 GB:** (1) draft weights in GPU memory alongside the target, if the pair fits — fastest, since draft passes are also bandwidth-bound; (2) draft on CPU with GPU target — viable only for very small drafts, because CPU draft latency directly adds to every iteration ($c$ is measured in wall time, not FLOPs); (3) no separate weights at all — see the n-gram point below.
- **Which family member fits a GGUF world?** The plain Leviathan/Chen form maps directly onto llama.cpp's draft-model speculation (`--model-draft` / `--spec-type draft-simple` in current llama.cpp): a small GGUF from the same family and tokeniser drafting for the main GGUF, verified by the main model. Ollama itself exposes no speculative-decoding controls as of this writing, so in practice this is a llama.cpp-underneath capability a user reaches by running llama.cpp directly, not an Ollama flag.
- **The zero-weight drafter is the 6 GB winner.** Leviathan et al. already showed a bigram drafter ($\alpha \approx 0.2$, $c \approx 0$) buying 1.25× for free. llama.cpp ships exactly this lineage as its n-gram / prompt-lookup speculation (`--spec-type ngram-*` variants): continuations are proposed by matching recent token n-grams against the prompt and the text generated so far, with a small hash/cache structure (megabytes, not gigabytes) instead of a second model. Long character chat is unusually favourable terrain for it — persona boilerplate, repeated phrases, quoted dialogue, and the model echoing its own earlier wording all repeat verbatim, and every hit is verified losslessly by the target, so a miss costs a little compute and a hit costs no memory at all. This is the only family member that improves a 6 GB setup without spending the scarcest resource.
- **Tuning guidance from the papers:** keep $\gamma$ small (3–5) to bound variance and wasted verification; prefer the smallest draft that holds $\alpha$; measure $\alpha$ on *actual chat transcripts*, not benchmarks — acceptance on repetitive chat will differ sharply from acceptance on fresh prose.

### (b) Project Aesir

- Implement the Leviathan/Chen loop as Aesir's reference speculation path: it is the correctness anchor every fancier drafter (EAGLE-style heads, n-gram pools) must be graded against, because its losslessness proof is drafter-agnostic. Aesir's draft interface should therefore take (tokens, per-token distributions) and nothing else — any proposer that can emit that pair plugs in.
- Aesir's accelerator-first law changes the $c$ calculus: a draft running on the NPU while the target verifies on the GPU can overlap drafting with verification instead of serialising them, and $c$ should be measured per device pairing, not assumed from parameter counts. Chen et al.'s wide/shallow, topology-matched draft is the design precedent: shape the draft for the device it will actually run on.
- For hybrid SSM/attention models, verification is not a pure attention-style parallel score: the SSM state must be advanced through drafted positions and rolled back on rejection just like KV. Aesir should treat "speculative state" (KV blocks + recurrent state snapshot) as one checkpoint/rollback unit per iteration.
- Log $\alpha$ and tokens-per-pass per session from day one. Every later optimisation in this wave (Medusa, EAGLE, Lookahead, online adaptation) is, mechanically, a claim about raising $\alpha$ or lowering $c$; without those two counters Aesir cannot tell which claim is true on its own hardware.

## 8. Access

- Date accessed: **2026-11-15**
- Leviathan et al. abstract: https://arxiv.org/abs/2211.17192 — HTML read: https://arxiv.org/html/2211.17192v2
- Chen et al. abstract: https://arxiv.org/abs/2302.01318 — HTML read: https://arxiv.org/html/2302.01318v1
