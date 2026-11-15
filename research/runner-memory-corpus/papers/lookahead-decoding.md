# Lookahead Decoding — Break the Sequential Dependency of LLM Inference Using Lookahead Decoding

## 1. Full citation

- **Title:** Break the Sequential Dependency of LLM Inference Using Lookahead Decoding
- **Authors:** Yichao Fu, Peter Bailis, Ion Stoica, Hao Zhang (UC San Diego; Google; UC Berkeley)
- **Venue / year:** Proceedings of the 41st International Conference on Machine Learning (ICML 2024), PMLR 235.
- **arXiv:** arXiv:2402.02057 [cs.LG] — submitted 3 Feb 2024 — https://arxiv.org/abs/2402.02057
- **Code (as reported in the paper):** https://github.com/hao-ai-lab/LookaheadDecoding

## 2. The problem

Every other method in this wave buys speed with an auxiliary artefact: a draft model to find and serve (speculative decoding), heads to train (Medusa), or a feature head to train per target (EAGLE). Those artefacts are target-specific, data-specific, and often simply unavailable — and a draft trained for one model/dataset does not transfer to another. Lookahead Decoding starts from the opposite question: decoding is memory-bandwidth-bound, so the accelerator's arithmetic is mostly idle — can the *target model itself*, in its idle cycles, generate its own speculations, with no auxiliary model, no training, and no datastore? If so, the speedup would be a pure systems property of the model you already have.

## 3. Core idea / mechanism in our own words

**Foundation — Jacobi decoding.** Autoregressive generation can be written as a system of equations $y_i = \arg\max P_M(y_i \mid y_{<i}, \text{prompt})$, one per position. Such systems can be attacked with Jacobi (fixed-point) iteration: guess all positions at once, re-evaluate every position in parallel given the current guess for its predecessors, repeat. Each Jacobi step is one parallel forward pass over a window of positions, and the first position is guaranteed correct after every step, so the process converges to exactly the autoregressive result in at most (window) steps — occasionally faster, when several positions happen to settle early. Raw Jacobi decoding disappoints in practice: tokens frequently land at the *wrong positions* and correct tokens get overwritten by later iterations, so wall-clock gains are negligible.

**Lookahead's fix — harvest the trajectory, don't just read its endpoint.** Run Jacobi iteration inside a fixed 2-D window: $W$ = how many future positions are iterated in parallel (lookahead width), $N$ = how many past Jacobi steps are retained (lookback depth). As the window slides, the *trajectory* of guesses — the sequence of token strings the iterations produced at successive steps — contains many $n$-grams (with $n = N$ in the paper's setup). Some of those $n$-grams are exactly the continuations the model will later need, even if they were generated "at the wrong position" for their original step. So:

- **Lookahead branch:** performs the Jacobi-style parallel updates across the window, generating fresh tokens at every window position every step.
- **$n$-gram pool:** every $n$-gram appearing along the trajectory is cached in a pool (the prompt itself can also seed the pool — the paper integrates prompt-as-reference and shows it helps).
- **Verification branch:** in the *same* forward pass, take up to $G$ pool $n$-grams whose first token matches the last accepted token, lay them out as disjoint candidate continuations, and score them with the target model. Any candidate whose tokens match the target's own predictions token-by-token is accepted wholesale, advancing the sequence by up to $N-1$ tokens at once.

Both branches execute as one model call per step under a single custom attention mask (lookahead tokens and verification tokens are mutually invisible; each verification candidate attends only to its own prefix), with a FlashAttention implementation hard-coding the mask pattern (~20% end-to-end gain over the naive PyTorch version in the paper's tests).

**Verification rule / distribution.** Verification is speculative-decoding-style checking against the target's own distributions. For greedy decoding, accept iff the candidate token equals the target's argmax at that position — exact by construction. For sampling, the paper adapts tree-verification ideas to disjoint $n$-grams (progressive verification along the $n$-gram, pruning candidates with mismatched prefixes) and proves the output distribution is preserved; a key simplification is that pool $n$-grams are *generated greedily* in the lookahead branch, so their proposal distribution is a one-hot vector and no per-token proposal probabilities need to be stored for the whole pool. The method is presented as exact/lossless for both regimes, with ROUGE parity on summarisation as the empirical check (see §5).

**Scaling law (the paper's theoretical centrepiece).** Steps compress by a factor $\mathcal{S}$ = tokens generated / Lookahead steps. Because each step can try $G$ candidates of length $N-1$ and keep the best, $\mathcal{S}$ grows *linearly in $\log(\text{per-step FLOPs})$* — equivalently, exponentially more FLOPs per step buys a linear reduction in step count. Unlike chain speculative decoding, whose tokens-per-pass is capped at $1/(1-\alpha)$, Lookahead has no fixed ceiling — but the exponential price makes the practical ceiling arrive quickly (see Limitations).

## 4. Design details an engineer needs

- **Three knobs, one budget:** $W$ (window width), $N$ ($n$-gram size), $G$ (max candidates verified per step; paper sets $G = W$). Per-step input tokens $\approx (W+G)(N-1)$, and per-step FLOPs scale with that count: the paper's near-optimal A100 configs imply **120× (7B), 80× (13B), 56× (34B) extra FLOPs per step** versus vanilla decoding — absorbed only because decoding is bandwidth-bound, so extra arithmetic is nearly free *until the device becomes compute-bound*.
- **Paper's tuned configs (A100, $G=W$):** 7B → $W=15, N=5$; 13B → $W=10, N=5$; 34B → $W=7, N=5$. Smaller models afford wider windows on the same GPU; the window must shrink as the model grows. These are A100 numbers — re-tune per device.
- **Ablations (LLaMA-2-Chat-7B, MT-Bench, FlashAttention on):** prompt-lookup alone (HF transformers implementation) 1.44×; Lookahead with balanced branches ($W=15, G=15, N=5$) 1.78× without prompt seeding, **1.88×** with the prompt seeding the pool; lopsided configs (huge $W$ with $G=1$, or huge $G$ with $W=1$) fall to 1.04–1.61×. Both branches are load-bearing, and balance beats extremity.
- **Lookahead Parallelism (multi-GPU):** because lookahead branches and verification candidates are mutually independent, they can be sharded across GPUs with *a full model replica per GPU* and near-zero communication during the forward pass (only generated tokens are synchronised afterwards) — unlike tensor/pipeline parallelism, which communicates per layer per step. The paper reports TP/PP baselines *slowing down* single-batch serving (0.75–0.82×) where Lookahead Parallelism reaches up to 4× on code completion (ClassEval, 8× A100-40G). The cost is memory: one full replica per device.
- **No training, no extra weights, no datastore.** The only new state is the $n$-gram pool (token sequences; the paper caps verification at $G$ candidates per step to bound its cost) and the window's KV. Compatible with FlashAttention; sampling and greedy both supported.
- **Where it wins/loses by workload:** repetitive text (code completion above all) produces reusable $n$-grams and the highest speedups; diverse chat text (MT-Bench, "many unique tokens") is the hard case the headline 1.8× is measured on.

## 5. Reported results — as reported, with context

All figures are the paper's own. Hardware: S1 = A100-80G (7B/13B/34B on one GPU; 70B on 2 GPUs with pipeline parallelism); S2 = DGX with 8× A100-40G for multi-GPU tests. Precision FP16, batch size 1, greedy unless noted. Primary baseline: Hugging Face greedy search; a stronger FlashAttention baseline is used where stated.

- **Headline (abstract):** up to **1.8× on MT-Bench** and up to **4× with strong scaling on multiple GPUs in code completion**.
- **Single-GPU range across tasks/models:** **1.5–2.3×**, with code completion at the top (~2.3×) and chat lower. Smaller models speed up more than larger ones on the same GPU (they have more spare FLOPs headroom before hitting the compute cap).
- **With FlashAttention (7B, MT-Bench):** FlashAttention alone gives the baseline 1.07×; Lookahead + FlashAttention reaches **1.9× in the paper's Fig. 6 comparison (1.8× net vs the FlashAttention baseline)**. FlashAttention adds ~20% to Lookahead's own PyTorch implementation.
- **Sampling quality check (LLaMA-2-7B-Chat, summarisation):** ROUGE essentially identical to autoregressive at both temp 0 and temp 1 (e.g. CNN/DailyMail temp 1: ROUGE-1 36.55 AR vs 36.53 Lookahead; XSum temp 0: 19.38 vs 19.39), with speedups of 1.46–1.60× and step-compression $\mathcal{S}$ of 1.64–1.77 on those tasks.
- **Weaker-hardware note:** on RTX 3090 the paper still reports a "gentle" ~30% MT-Bench speedup (vs >50% on A100) — the method degrades gracefully as spare FLOPs shrink, it does not fall off a cliff.
- **Honest internal comparison (from the EAGLE-3 paper's Table 1, same protocol):** Lookahead on Vicuna 13B averages 1.62× / $\tau$ 1.67 across five tasks at temp 0 — the lowest of the trained/untrained methods compared there, roughly one third of EAGLE-3's figure. Zero training is paid for in acceptance length: $\tau \approx 1.5$–$2.0$ versus 4–7.5 for trained drafters.

## 6. Limitations

- **It spends the scarcest thing on small hardware: FLOPs.** The whole scheme converts idle compute into fewer steps. At batch size >1, on compute-bound workloads, or on weak GPUs, the surplus it eats does not exist — the paper is explicit that large-batch serving can *slow down*, and per-step cost multipliers of 56–120× FLOPs leave little headroom on consumer parts.
- **Exponential price, linear return:** the $\log(\text{FLOPs})$ scaling law is a diminishing-returns law. Doubling the window does not double the speedup; the paper's own curves flatten, and tree/head methods with trained drafters reach far higher $\tau$ per verification pass.
- **Acceptance depends on self-repetition.** $n$-grams come from the model's own Jacobi trajectory and prompt; genuinely novel text offers few reusable continuations. Chat with diverse vocabulary is the weakest case (hence MT-Bench as the "challenging" headline).
- **Kernel complexity:** the fused lookahead+verification step needs a bespoke attention mask; the paper hard-codes the pattern into FlashAttention. Porting to a new attention backend (or a GGUF CPU/GPU kernel) is real engineering, not a flag.
- **Multi-GPU form needs a full replica per GPU** — irrelevant for single-GPU local use, and a hard memory price where it is used.

## 7. Applicability

### (a) Ollama on a 6 GB GPU, single user, long chat

- **Memory profile: the best in the wave alongside n-gram speculation.** No draft weights, no heads — only the $n$-gram pool (small; bounded by the $G$ cap) and a wider per-step activation/KV footprint for the window. On a 6 GB card this is the only *neural-quality* speculation scheme whose residency cost rounds to zero, which is why its close relative already ships in llama.cpp: the `--spec-type ngram-*` modes are, mechanically, Lookahead's pool-and-verify idea with the pool built from context/generated text rather than from a Jacobi trajectory (prompt-lookup decoding is the same family; the Lookahead paper itself benchmarks prompt lookup as its closest baseline/ablation at 1.44×).
- **Compute profile: the worst in the wave for this hardware — and that is the honest caveat.** A 6 GB consumer GPU running a Q4 7–8B model at batch 1 is bandwidth-bound, so *some* surplus FLOPs exist, but far less than an A100's. The paper's own RTX 3090 result (~1.3× on MT-Bench) is the realistic reference class, not the A100's 1.8×; on a weaker 6 GB card (e.g. a 3050/4050-class part), expect the low end of that or less, and re-tune $W$ *down* (the paper's $W=15$ for 7B is an A100 setting). The llama.cpp n-gram modes sidestep most of this cost because their drafting is table lookup, not extra model FLOPs — on 6 GB they dominate full Jacobi Lookahead on speed-per-nothing.
- **Long chat is Lookahead's best local case:** the longer the session, the richer the pool of reusable phrasing (persona catchphrases, recurring scene language, the user's own repeated prompts if seeded). Repetition, not model size, is the acceptance engine — and long character chat is the most repetitive workload a local user has.
- **Verdict for Ollama:** adopt the *idea* via llama.cpp's n-gram speculation today; treat full Jacobi Lookahead as a research reference for what the pool could become (trajectory-mined $n$-grams in addition to context-mined ones), not as a feature to wait for.

### (b) Project Aesir

- Lookahead is the zero-dependency fallback drafter for Aesir: any model Aesir can run at all can be Lookahead-accelerated with no per-model training artefacts. That makes it the right *default-on* speculation for newly imported / community models that have no EAGLE head and no draft sibling — some speedup for every model, best speedup for models with trained drafters layered on top.
- Aesir's device reality cuts both ways: on the NPU/GPU-rich targets there are genuine idle FLOPs during bandwidth-bound decode, but on Pi-class ARM the compute surplus is thin. Aesir should gate window size ($W$, $G$) on a measured per-device spare-FLOPs estimate and shrink to $W{=}1$ (effectively prompt-lookup) rather than disabling speculation outright.
- The trajectory-mining insight generalises: Aesir's verification pass already computes target distributions for many positions; *any* discarded-but-computed continuation (rejected tree branches included) is candidate pool material for future steps. A unified "speculation pool" fed by Jacobi trajectories, rejected branches, prompt text, and session history is a clean Aesir-level abstraction over this whole wave.
- For hybrid SSM models, Jacobi iteration has a wrinkle: positions in the window depend on the recurrent state, which is sequential by nature. Lookahead over the attention layers still works if the SSM state is advanced along each candidate as a checkpointed stream (see speculative-decoding dossier §7b); budget that state-copy cost into the per-step FLOPs accounting before enabling wide windows.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2402.02057
- arXiv HTML (read for method + evaluation detail): https://arxiv.org/html/2402.02057v1
