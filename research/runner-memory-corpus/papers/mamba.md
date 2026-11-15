# Mamba — Linear-Time Sequence Modeling with Selective State Spaces

## 1. Full citation

- **Title:** Mamba: Linear-Time Sequence Modeling with Selective State Spaces
- **Authors:** Albert Gu (Carnegie Mellon University, Machine Learning Department) and Tri Dao (Princeton University, Department of Computer Science) — equal contribution, alphabetical by first name in the paper
- **Venue / year:** First Conference on Language Modeling (COLM 2024) — the published version is headed "Published as a conference paper at COLM 2024"
- **arXiv:** arXiv:2312.00752 [cs.LG] — v1 submitted 1 December 2023; v2 last revised 31 May 2024 — https://arxiv.org/abs/2312.00752
- **Code / checkpoints (as released by the authors):** `state-spaces/mamba` — pretrained language models at 130M, 370M, 790M, 1.4B and 2.8B parameters, trained on the Pile

## 2. The problem as framed

The paper opens from the position that had become orthodoxy by late 2023: foundation models are "almost universally based on the Transformer architecture and its core attention module" (abstract), and attention's strengths and costs are the same property. Attention routes information densely — every token can look directly at every earlier token — which is why it does content-based reasoning so well: copying a name from earlier in the prompt, resolving an induction pattern, retrieving a value by its key. The price is structural:

- **Training / prefill compute is quadratic in sequence length.** Scoring every token against every earlier token is an $L \times L$ operation.
- **Autoregressive inference carries an unbounded, growing memory.** To avoid recomputing the past, a Transformer runner caches every past token's keys and values. The KV cache grows linearly with $L$, and every decode step must read it all back. Memory and bandwidth per generated token therefore grow with context — the subject of this corpus's KV dossier (`memory/kv-cache-design.md` §1).

The alternatives available before Mamba all traded that cost away by giving up the routing:

- **Linear attention, gated convolutions, and classical RNNs** compress the past into a fixed-size state and scale linearly (or run in constant time per step), but — in the paper's diagnosis — they had "not performed as well as attention on important modalities such as language."
- **Structured state space models (SSMs)** — S4 and its successors, from the same first author's line — had principled long-range machinery and dominated long-range benchmarks on continuous signals (audio, vision), yet lagged on discrete, information-dense data such as text.

The paper names the missing capability precisely: **content-based reasoning**, and more specifically **selection** — the ability to decide, from the current input, what of the past to keep, what to let decay, and what to ignore entirely. A time-invariant system applies the same dynamics to a filler token and to the one token the rest of the sequence will depend on. Attention does not have that defect; it selects. The question Mamba poses is whether an SSM can be made to select without losing the two things that made SSMs attractive in the first place: linear-time training and constant-state inference.

That is the trade the whole state-space lineage negotiates, and it recurs in every later section of this dossier and in its companion (`papers/mamba-2.md`): **Transformers pay growing memory for exact, addressable recall; recurrent / SSM models pay a fixed memory for a lossy, fused summary.** Neither side of the trade is free, and §5 is largely the record of the field discovering the second half of that sentence.

## 3. Core mechanism in our own words

### 3.1 The SSM underneath

A (discrete) state space layer maintains a latent state $h_t$ and updates it token by token:

$$h_t = \bar A\, h_{t-1} + \bar B\, x_t, \qquad y_t = C\, h_t$$

where $x_t$ is the input at step $t$, $y_t$ the output, and $\bar A, \bar B$ are obtained by discretising continuous parameters $(A, B)$ with a step size $\Delta$ (zero-order hold: $\bar A = \exp(\Delta A)$, with the corresponding formula for $\bar B$). In the S4 family $A$ is structured — diagonal (plus, in earlier variants, low-rank) — so the state is $N$ numbers per channel rather than a dense matrix, and the whole transformation can equivalently be computed as a long convolution when the parameters do not vary with time.

That last clause is the crux. If $(\Delta, A, B, C)$ are the same at every step, the model is **linear time-invariant (LTI)**: training can use the fast convolutional form, inference can use the fast recurrent form, and the model cannot, by construction, treat one token differently from another except through the value of $x_t$ itself flowing through fixed dynamics.

### 3.2 Selectivity: $B$, $C$ and $\Delta$ become functions of the input

Mamba's central change is one sentence long (abstract): "simply letting the SSM parameters be functions of the input addresses their weakness with discrete modalities."

Concretely, in the selective SSM (the paper's S6 layer):

- $B_t = \mathrm{Linear}_B(x_t)$ and $C_t = \mathrm{Linear}_C(x_t)$ — the input-projection and output-projection of the state are produced per token;
- $\Delta_t = \mathrm{softplus}(\mathrm{Linear}_\Delta(x_t) + \text{bias})$ — the discretisation step is produced per token, per channel;
- $A$ remains a learned, input-independent (diagonal) parameter — but because $\bar A_t = \exp(\Delta_t A)$, the *effective* state transition is input-dependent through $\Delta_t$.

Read $\Delta_t$ as a gate, in the RNN sense the paper itself draws: a large $\Delta_t$ makes the state turn over — attend to the present input, let the old state decay; a small $\Delta_t$ makes the state persist — carry the past forward and largely ignore the present token. $B_t$ controls what of the current token gets written into the state; $C_t$ controls what gets read out of it. Together they are a content-addressable write/read/forget mechanism implemented inside a recurrence, rather than as pairwise comparisons between tokens.

The paper motivates this with two synthetic probes that have since become standard vocabulary:

- **Selective copying** — copy only the relevant tokens from a stream, at random spacings, ignoring distractors. An LTI convolution cannot do this: with fixed spacing it can memorise a delay, with random spacing it must look at content.
- **Induction heads** — the pattern $[\dots A\, B \dots A] \rightarrow B$: on seeing $A$ again, retrieve what followed it before. This is the minimal form of in-context associative recall, and the mechanism attention implements with a previous-token head plus an induction head.

A selective SSM solves both in the paper's experiments, and — the claim that matters for runners — can extrapolate the solution to sequences far longer than those trained on, reported beyond 1M tokens for the synthetic tasks.

### 3.3 The cost of selectivity, and the hardware-aware scan that pays it

Selectivity destroys the convolutional shortcut: if the parameters vary per step, there is no single kernel $K = (CB, CAB, CA^2B, \dots)$ to convolve with. Naively materialising the expanded state would cost $O(BLDN)$ time and memory (batch $\times$ length $\times$ channels $\times$ state dimension) — the bottleneck the paper calls out explicitly — and would be slower than attention in practice despite better asymptotics.

The second contribution is therefore an algorithm, in the same IO-aware spirit as Dao's FlashAttention work (see `papers/flashattention.md`, `papers/flashattention-2.md`):

- **Parallel (associative) scan in recurrent mode.** The linear recurrence, though sequential in form, is an associative operation and can be evaluated with a parallel scan — work-efficient, logarithmic depth — rather than step-by-step in training.
- **Kernel fusion.** Discretisation, the scan, and the multiplication by $C_t$ are fused into one kernel, so the expanded state $(B, L, D, N)$ is never written to high-bandwidth memory (HBM); it lives in SRAM for the duration of the computation.
- **Recomputation in the backward pass.** Instead of storing the large intermediate states for backpropagation, they are recomputed on the backward pass from the much smaller saved inputs — trading FLOPs (cheap, abundant) for memory traffic (the binding constraint), exactly the FlashAttention trade.

The reported implementation consequences, in the paper's own framing (§4 below): the fused scan is up to $3\times$ faster than prior SSM implementations on an A100 in the introduction's summary, and $40\times$ faster than a standard (unfused PyTorch) scan implementation in the efficiency figure.

### 3.4 The Mamba block and architecture

The selective SSM is integrated into a deliberately simplified, homogeneous architecture:

- Each **Mamba block** expands the model dimension, applies a linear projection, a short causal depthwise convolution (kernel size typically 4) and SiLU, then the selective SSM, then a gated branch (SiLU-gated, in the style of gated MLP / H3 blocks), normalisation, and a projection back — with a residual connection around the block.
- Blocks are stacked uniformly. There is **no attention and no separate MLP block** — the paper's phrase is "without attention or even MLP blocks" (abstract). The gating and expansion inside the block do the work an MLP block does in a Transformer.
- Inference is purely recurrent: one state update per token, no cache of previous elements (paper §1: autoregressive unrolling "requires only constant time per step since it does not require a cache of previous elements").

That last sentence is the architectural fact this wave exists to bank. It is true, and §6 is about why it does not mean what a KV-trained intuition first thinks it means.

## 4. Reported results — as reported, with hardware / model context

All figures in this section are the paper's own, in its own framing. Hardware for the efficiency benchmarks is an **A100 80 GB PCIe** GPU unless stated otherwise. Language models are trained on **the Pile**, following the GPT-3 / Chinchilla-style protocol used by the Pythia suite, which is what makes the Pythia comparisons like-for-like in data and tokeniser.

- **Headline language claim (abstract and §1).** "Our Mamba-3B model outperforms Transformers of the same size and matches Transformers twice its size, both in pretraining and downstream evaluation." The concrete downstream illustration given in the introduction: Mamba-3B scores **4 points higher on average on common-sense reasoning than Pythia-3B, and exceeds Pythia-7B** on that average. The model family evaluated runs from ~125M to 2.8B/3B parameters; the scaling-law study itself runs to ~1B.
- **First-of-kind claim (paper §1, §4).** "Mamba is the first linear-time sequence model that truly achieves Transformer-quality performance, both in pretraining perplexity and downstream evaluations" — graded against, among others, the strong modern **Transformer++** recipe (PaLM/LLaMA-style: rotary embeddings, SwiGLU MLP, RMSNorm, no biases) rather than only against a vanilla GPT-3-style Transformer. Earlier subquadratic models (H3, Hyena, RWKV-4, RetNet in the paper's comparisons) do not make that claim in the paper's tables.
- **Throughput — the $5\times$ figure, in context.** Figure 8 (right) and Appendix F.5: end-to-end generation throughput for **Mamba-1.4B and an (untrained, for throughput purposes) Mamba-6.9B vs a standard Transformer in the Hugging Face implementation at 1.3B and 6.7B**, prompt length **2,048**, generation length **128**, batch size swept 1–128, A100 80 GB PCIe. Reported maxima in the figure are on the order of **1,814 tokens/s for Mamba-1.4B** against a Transformer-1.3B curve that runs out of memory at large batch. The paper's summary of the same experiment: Mamba "achieves 4–5$\times$ higher inference throughput than a Transformer of similar size," and the abstract rounds this to "**$5\times$ higher throughput than Transformers**." Two cautions belong with the number whenever it is quoted: (i) the baseline is the standard HF Transformer implementation of its era, not a FlashAttention-2 / paged-serving stack (see `papers/pagedattention-vllm.md`, `papers/flashinfer.md`); (ii) the advantage grows with sequence length and batch precisely because the Transformer's cost is the growing KV read that Mamba does not have — at short context and small batch the gap is correspondingly smaller.
- **Linear scaling and long context.** Training and inference compute/memory are claimed linear in sequence length, and quality on real data (audio pretraining, §4.4) is reported to keep improving as training sequence length increases from $2^{13}$ to $2^{20} \approx 1$M tokens at fixed compute. This is a *scaling* claim about the architecture's cost curve and about those modalities, not a claim that a 2.8B language model was trained at 1M context — the language scaling runs use conventional lengths (the Mamba-2 companion paper makes its Pile scaling runs at sequence length 8,192 explicit; see `papers/mamba-2.md` §4).
- **Scan efficiency.** Figure 8 (left): the fused selective scan is reported **$40\times$ faster than a standard scan implementation**, and faster than convolution and FlashAttention-2 baselines across the long-sequence range plotted (512 to 512K), where attention-based curves run out of memory.
- **Audio and genomics (secondary modalities, as reported).** On SC09 speech generation, a 6.1M-parameter Mamba model reports FID **0.94** vs SaShiMi's 1.99 at comparable size, with the larger 24.3M Mamba at FID **0.67** — the paper's "reducing FID by more than half" claim. On DNA, Mamba is reported to scale better than HyenaDNA/S4 baselines in both model size and sequence length on HG38 pretraining, and to improve on a long-context species-classification fine-tuning task. These results matter to this corpus only as evidence that the result was not a language-only artefact; no runner conclusion should be drawn from them.

## 5. What it changed in practice

### 5.1 It made the recurrent backbone credible at language scale — and then production went hybrid

Before Mamba, "replace attention" papers were read as efficiency proposals with a quality asterisk. After Mamba, the asterisk was small enough that model builders started shipping the architecture — but, with very few exceptions, **not pure**. The documented production pattern of 2024–2025 is interleaving: a majority of SSM / linear-recurrent layers for cheap long-context mixing, plus a minority of full-attention layers for exact retrieval.

- **Jamba (AI21 Labs, March 2024; Lieber et al., arXiv:2403.19887).** The first production-scale hybrid released with open weights: Transformer layers interleaved with Mamba layers, plus mixture-of-experts. The released model is **52B total / 12B active** parameters, supports **256K** context, and — the number that explains the design — carries a KV cache of only **4 GB at 256K context in 16-bit** in the paper's comparison table, because only its attention layers cache at all. It was reported to fit 140K context on a single 80 GB GPU and to perform comparably to Mixtral-8×7B and Llama-2-70B on its benchmarks. Jamba-1.5 (August 2024) scaled the same recipe to Mini (52B/12B active) and Large (398B total / 94B active), still at 256K.
- **Zamba (Zyphra, 2024; Glorioso et al.).** A compact hybrid in the opposite style: a **Mamba-1 backbone (7B class) with a single shared attention block (plus shared MLP) applied repeatedly** at intervals, rather than distinct attention layers. The design goal is explicit economy — obtain the recall benefit of attention while paying for one attention block's parameters — and Zamba2 moved the backbone to Mamba-2 at smaller sizes (2.7B, 1.2B). Zamba is the clearest published evidence that even *one* reused attention pathway was considered worth adding to an otherwise pure SSM stack.
- **The 8B controlled study (NVIDIA, June 2024; Waleffe et al., arXiv:2406.07887).** Not a product, but the experiment the hybrid decision rests on, because it removes the usual confounds: **8B-parameter Mamba, Mamba-2, Transformer, and a Mamba-2-Hybrid, all trained on the same data, up to 3.5T tokens.** Its findings are quoted in §5.2.
- **Qwen3-Next class (Alibaba, September 2025).** The pattern at frontier scale, one generation on: **Qwen3-Next-80B-A3B** — 80B total / ~3B active — uses a **3:1 hybrid**: 75% of layers are **Gated DeltaNet** (a gated linear-recurrent layer in the Mamba-2 lineage, improved with the delta rule; see `papers/mamba-2.md` §5) and 25% are gated full attention, in repeating groups of [3 × (DeltaNet → MoE) → 1 × (Attention → MoE)] across 48 layers, with native 262,144-token context. The Qwen team's own stated reason for the mix mirrors this dossier's §5.2: in their systematic experiments the hybrid "consistently outperforms any monolithic architecture." The corpus's own qwen35 line (next generation of the same family) is of this class — see §6(b).
- Also in the same direction, and noted here only as corroboration of the pattern: NVIDIA's Nemotron-H family and TII's Falcon-H1 both ship as Mamba-2/attention hybrids. No pure-SSM model of comparable scale and visibility shipped as a general-purpose flagship in this period.

### 5.2 Why hybrid, in the published evidence: recall and copying

The hybrid turn was not aesthetic. Three independent lines of published evidence, all careful in the same way, point at the same weakness:

1. **Theory — copying needs state that grows, or attention that reaches back.** Jelassi, Brandfonbrener, Kakade & Malach, *Repeat After Me: Transformers are Better than State Space Models at Copying* (ICML 2024, arXiv:2402.01032), prove that a **two-layer Transformer can copy strings of length exponential in its parameter count**, while **generalised SSMs — models whose per-step memory is a fixed-size latent state, Mamba included in their class — are fundamentally limited by that fixed state**: to reproduce $n$ bits exactly you must, somewhere, retain $n$ bits. Empirically, in their synthetic experiments Transformers learn copying faster and generalise to longer strings better, and on pretrained models (Pythia vs Mamba at 410M–2.8B scales) Transformers "dramatically outperform" SSMs at copying and retrieving information from context. This is an information-theoretic bound, not a training-recipe finding; larger state (Mamba-2's direction, `papers/mamba-2.md` §3) moves the constant, it does not remove the bound.
2. **Synthetic recall — MQAR.** Arora et al., *Zoology: Measuring and Improving Recall in Efficient Language Models* (ICLR 2024, arXiv:2312.04927), introduced **multi-query associative recall (MQAR)**: many key–value pairs in context, many queries afterwards. Their central measurement is that efficient recurrent models' recall is governed by **state size relative to the number of associations to be stored**, and degrades as either sequence length or the number of pairs grows — where attention, which stores every pair explicitly in KV, does not degrade in the same way. The Mamba-2 paper itself (§9.1 of that paper) takes MQAR as its hard synthetic, notes that phonebook-style lookup "has been shown to be challenging for recurrent models such as SSMs, due to their finite state capacity," and shows Mamba-2 improving over Mamba-1 there *by using larger state* — confirming the mechanism of the limitation while mitigating it.
3. **At scale, on natural tasks — Waleffe et al. (2024), above.** Pure Mamba and Mamba-2 at 8B "match or exceed Transformers on many tasks" but **lag on tasks requiring strong copying or in-context learning — five-shot MMLU (nearly 15 points behind the Transformer after 1.1T training tokens) and Phonebook lookup** — and on long-context reasoning; the gap on Phonebook persists regardless of training tokens. Their **Mamba-2-Hybrid — 43% Mamba-2 layers, 7% self-attention, 50% MLP (24 Mamba-2 + 4 attention + 28 MLP layers at 8B)** — **exceeds the 8B Transformer on all 12 standard tasks (+2.65 points on average)**, matches or exceeds it on 23 long-context tasks at 16K/32K/128K, and is predicted up to **$8\times$ faster at generation**. In other words: ~7% attention layers bought back the entire recall deficit and left the efficiency advantage substantially intact. That exchange rate is the economic reason production went hybrid.

A runner-facing paraphrase, stated carefully: a pure SSM's state is a **lossy compression of the prefix, made without knowing what will be asked later**. Attention's KV cache is the **uncompressed prefix, addressable by content**. Tasks whose answer is a *summary* of the past tolerate the compression; tasks whose answer is an *exact item* from the past (a name, a number, a quoted line, a few-shot exemplar's label) expose it. Hybrids keep a thin exact channel open for the second kind.

## 6. Applicability

### (a) Ollama / runners — what a selective SSM does to serving

- **The KV growth term disappears — for those layers.** A pure Mamba sequence carries, per layer, a recurrent state of shape (channels $\times$ state dimension $N$, $N = 16$ in Mamba-1's released language models) plus a short convolution state (kernel width ~4). Neither grows with $L$. The per-sequence serving memory of a pure-SSM model is therefore a **constant**, and the decode step is $O(1)$ in context length in both compute and bandwidth: no growing read, no crossover point where cache exceeds weights (`memory/kv-cache-design.md` §1.3 simply does not apply). Admission control, the binding problem of Transformer serving, becomes trivial in the length dimension.
- **But "constant" does not mean "small," and it changes shape, not just size.** The constant is per *layer* and per *sequence*, and in hybrid descendants it is large in absolute terms: the corpus's qwen35 record puts one full SSM+conv snapshot for a 27B hybrid at **≈158.9 MB** (`memory/kv-cache-design.md` §6.2). A runner budget that reads "no KV, therefore no state problem" will be wrong by hundreds of megabytes per session the moment snapshots are kept.
- **Prefix caching changes shape entirely.** KV prefix reuse works because KV is token-addressable: share the blocks for the common prefix, copy-on-write at the branch (`memory/kv-cache-design.md` §3). A recurrent state has no per-token pieces to share — the state after token 500 is tokens 1–500 fused. The only exact reuse primitive is **checkpoint-and-restore whole**: snapshot the state (plus conv state, plus boundary KV for hybrids) at a prefix boundary, store the blob, restore it to resume. Consequences a runner must design for, all developed in the KV dossier §6.4: snapshot placement becomes a policy (which boundaries earn a ~159 MB checkpoint?); branching costs a full state copy, not a block copy; eviction is whole-blob or nothing — there is no H2O/SnapKV-style scoring *inside* a fused state; and non-prefix reuse (CacheBlend-style fusion at new positions) is effectively unavailable for the recurrent component.
- **Batching and preemption change too.** Decode batching is *easier* (every sequence's step is the same size, regardless of its length — no ragged KV reads), while preemption by recompute is *more* attractive relative to swap than for KV in one respect (recompute cost is linear, state is bounded) and checkpoint-restore is the natural spill mechanism: the state is already a bounded blob.
- **Ecosystem reality.** Mamba-1's speed depends on its fused selective-scan kernel (CUDA/Triton in the reference implementation). A portable runner (Ollama/llama.cpp class, CPU/ARM/Metal/Vulkan targets) cannot assume that kernel; a naive scan implementation forfeits much of §4's advantage — the paper's own $40\times$ gap between fused and standard scan is the warning. llama.cpp's answer in the corpus is its `llama_memory_i` abstraction, under which "memory" can be KV cells, recurrent state, or both (`runners/llamacpp-ggml.md` §3.1, cited in the KV dossier §6.3) — the right shape: one memory manager, per-kind components.

### (b) Aesir — the qwen35 work as the lived example

Aesir did not serve a pure Mamba model; it served the descendant this paper predicts — a **hybrid** (reference: `aesir/aesir-ideas-for-ollama.md` §3.2; synthesis: `memory/kv-cache-design.md` §6.2). Per the corpus record, and not re-derived here:

- **qwen35 27B:** 64 blocks, hidden 5,120, 24 query heads / 4 KV heads, head dim 256, context 262,144; **most layers recurrent Gated-DeltaNet (conv + recurrent state), full attention only at intervals**, partial rotary (64 of 256 dims). Its KV is therefore priced only on the attention layers (4,096 B/token per attention layer in the KV dossier's arithmetic), while its recurrent layers contribute the fixed state term.
- **Q35-5, the proven mechanism:** snapshot hybrid state (SSM + conv + boundary KV) at a prefix boundary; **restore is bit-exact (SSM/conv/KV diffs 0.0)**; a stateless resend **reused 72 of 90 tokens** via snapshots after residency had been destroyed; the snapshot store is **bounded at 4 per session, FIFO-bounded**, at **≈158.9 MB SSM+conv per snapshot** plus boundary KV.
- The lesson Aesir's record adds to this paper: Mamba's "no cache of previous elements" is a statement about *decode*, not about *sessions*. The moment a product wants prefix reuse, branching (swipe/regenerate), pause/resume, or stateless-API resends, the state comes back as an explicit, stored, versioned object — larger per unit than any KV block, and manageable only with the discipline Q35-5 applied: snapshots only at boundaries, bit-exactness as the acceptance test, and a hard bound on how many are kept.

## 7. Cross-links

- **KV-design dossier** (`memory/kv-cache-design.md` §6, "The hybrid-model complication"): this paper is the architectural origin of that section's second memory kind. The KV dossier treats SSM state as the complication; this dossier is why the complication exists — a selective SSM is a deliberate decision to replace an exact, growing, addressable memory with a fixed, fused, lossy one, in exchange for linear cost.
- **Aesir ideas dossier** (`aesir/aesir-ideas-for-ollama.md` §3.2, esp. Q35-5 / ledger item T5): the corpus's first-hand hybrid-serving evidence, and the reference implementation of checkpointed prefix reuse for recurrent state.
- **GQA / MLA dossiers** (`papers/gqa.md`, `papers/deepseek-v2-mla.md`) — **the three architectural responses to the same KV pressure, compared:** GQA shrinks the cache *per token* by sharing each KV head among a group of query heads (a constant-factor cut, exactness preserved, growth unchanged); MLA shrinks it further by caching a compressed latent per token and reconstructing heads from it (a larger constant-factor cut, still token-addressable, still growing); Mamba abolishes the per-token cache for its layers altogether by compressing the whole prefix into a fixed state (growth eliminated, addressability and exactness surrendered). They are not three versions of one idea — they sit at three different points on the exactness axis — and the hybrid models of §5 are what you get when a builder wants Mamba's point on the cost axis without fully accepting its point on the exactness axis: GQA/MLA-priced attention layers, kept deliberately few, interleaved with SSM layers that pay nothing per token.
- **Companion dossier:** `papers/mamba-2.md` — State Space Duality, the scalar-identity restriction, larger state, and the chunked matmul algorithm; also the direct ancestor of the Gated DeltaNet layers in the Qwen3-Next/qwen35 hybrids.
- **Attention-side context:** `papers/flashattention.md`, `papers/flashattention-2.md` (the IO-aware method Mamba's kernel design inherits), `papers/pagedattention-vllm.md` and `papers/radixattention-sglang.md` (the KV reuse machinery whose hybrid generalisation — SGLang's MambaRadixCache / Unified Radix Cache — is described in the KV dossier §6.3).

## 8. Sources with dates accessed (2026-11-15)

All sources accessed **2026-11-15**.

- Gu, A. & Dao, T. *Mamba: Linear-Time Sequence Modeling with Selective State Spaces.* COLM 2024. arXiv:2312.00752 — abstract page https://arxiv.org/abs/2312.00752 and full text (COLM 2024 published version, read for §§3–4, Figure 8, and Appendix F.5).
- Dao, T. & Gu, A. *Transformers are SSMs: Generalized Models and Efficient Algorithms Through Structured State Space Duality.* ICML 2024. arXiv:2405.21060 — §9.1 (MQAR / phonebook discussion), §9.2.3 (hybrid experiments). See companion dossier `papers/mamba-2.md`.
- Lieber, O. et al. *Jamba: A Hybrid Transformer-Mamba Language Model.* arXiv:2403.19887 (2024) — abstract, §1–§2, KV-cache comparison table; and Jamba Team, *Jamba-1.5: Hybrid Transformer-Mamba Models at Scale.* arXiv:2408.12570 (2024).
- Glorioso, P. et al. *Zamba: A Compact 7B SSM Hybrid Model.* (2024) — architecture as described in the paper and in the hybrid-overview literature consulted.
- Waleffe, R. et al. *An Empirical Study of Mamba-based Language Models.* arXiv:2406.07887 (2024) — abstract and §1 (8B controlled comparison; five-shot MMLU and Phonebook findings; Mamba-2-Hybrid composition and results).
- Jelassi, S., Brandfonbrener, D., Kakade, S. M. & Malach, E. *Repeat After Me: Transformers are Better than State Space Models at Copying.* ICML 2024. arXiv:2402.01032 — abstract and theoretical claim as published.
- Arora, S. et al. *Zoology: Measuring and Improving Recall in Efficient Language Models.* ICLR 2024. arXiv:2312.04927 — MQAR formulation and recall-vs-state-size finding, as cited and summarised in the works above.
- Qwen team. *Qwen3-Next: Towards Ultimate Training & Inference Efficiency.* Alibaba Cloud / Qwen blog post (September 2025) — hybrid 3:1 Gated DeltaNet + Gated Attention description, 80B-A3B configuration, 262,144 native context.
- Corpus-internal: `memory/kv-cache-design.md` §1, §6; `aesir/aesir-ideas-for-ollama.md` §3.2; `runners/llamacpp-ggml.md` §3.1; `runners/sglang.md` §5.4.
