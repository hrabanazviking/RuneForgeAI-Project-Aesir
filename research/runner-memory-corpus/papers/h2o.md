# H2O — H2O: Heavy-Hitter Oracle for Efficient Generative Inference of Large Language Models

## 1. Full citation

- **Title:** H2O: Heavy-Hitter Oracle for Efficient Generative Inference of Large Language Models
- **Authors:** Zhenyu Zhang, Ying Sheng, Tianyi Zhou, Tianlong Chen, Lianmin Zheng, Ruisi Cai, Zhao Song, Yuandong Tian, Christopher Ré, Clark Barrett, Zhangyang Wang, Beidi Chen
- **Venue / year:** Advances in Neural Information Processing Systems 36 (NeurIPS 2023), New Orleans, LA, USA, December 2023, pp. 34661–34710
- **arXiv:** arXiv:2306.14048 [cs.LG] — v1 24 June 2023; v3 18 December 2023 — https://arxiv.org/abs/2306.14048
- **Code (as reported in the paper):** https://github.com/FMInference/H2O

## 2. The problem it attacks

For long generation (dialogue, story writing) the KV cache grows linearly with sequence length and batch size until it rivals or exceeds the model itself — the paper's motivating example is ~180 GB of KV cache for a 30B model at batch 128 × 1024 tokens. Recency-only eviction (keep the last N tokens) fits the cache in memory but silently deletes tokens the model actually depends on, and accuracy falls off a cliff on anything requiring long-range recall. The question is whether a *content-based* eviction policy can keep a small cache without losing what matters — and whether it can be cheap enough to run at every decode step.

## 3. Core idea in our own words

Attention is extremely uneven. The paper measures that inference-time attention matrices are over 95% sparse and that accumulated attention scores follow a power law: a small minority of tokens — the **heavy hitters (H2)** — collect the great majority of attention from later tokens, they emerge naturally from frequent token co-occurrence patterns in text, they tend to stay heavy once they become heavy, and deleting them wrecks output quality while deleting most other tokens costs almost nothing.

H2O is an eviction policy built on that observation. The cache budget is split into two pools: a **heavy-hitter pool** and a **recent-token pool**. Every token carries a running score (its accumulated attention received so far, summed per layer / head accounting). When a new token arrives and the cache is full, the token with the lowest accumulated score outside the protected recent window is evicted. In effect: recency guarantees local coherence, heavy-hitter retention guarantees the load-bearing old tokens survive. The authors formulate the selection as a dynamic submodular maximisation problem and prove a near-optimality guarantee for the greedy rule under stated assumptions — the practical content of the theory is that "keep what has been attended to most, greedily, using only past attention" is not a hack but close to the best any causal policy can do.

## 4. Key design details a runner engineer needs

- **Scoring:** maintain per-token cumulative attention scores during decode (the attention weights are already computed; H2O accumulates them). Scores are tracked per layer/head in the full formulation; implementations commonly aggregate. This bookkeeping is the main integration cost — the runner's attention path must expose or accumulate attention weights, which FlashAttention-style fused kernels deliberately do not materialise. Expect a kernel-level trade-off here.
- **Budget split:** total budget B = heavy pool + recent pool. The paper's experiments centre on keeping **20% of the full cache**; secondary analyses of the paper report a default split around 70% heavy / 30% recent within that budget. The split is a tunable; recency share protects fluency, heavy share protects recall.
- **Eviction step:** on overflow, evict the lowest-scored non-recent token. Cost is a linear scan / argmin over the budget per step in the reference design — negligible next to a model forward pass at chat scale, worth watching at very large batches.
- **Irreversibility:** eviction is permanent. A token evicted early can never return even if the conversation later circles back to it. The policy bets, with measurements behind it, that cumulative attention predicts future attention well (heavy hitters persist).
- **Where it hooks in:** inside the decode loop's cache manager, alongside (not instead of) allocation policy. It composes with paged allocation (evict whole blocks whose tokens score low) and with StreamingLLM (attention sinks are, in H2O terms, tokens whose scores explode early — the two policies agree on protecting the head of the sequence, for different stated reasons).

## 5. Reported results — as reported, with context

All figures are the paper's own measurements.

- **Headline:** with **20% heavy hitters** retained, H2O improved throughput over three leading inference systems — **DeepSpeed Zero-Inference by up to 29×, Hugging Face Accelerate by up to 29×, and FlexGen by up to 3×** — on **OPT-6.7B and OPT-30B**; at the same batch size it reduced latency by up to **1.9×** vs FlexGen. (These are system-level comparisons against offloading-heavy baselines on constrained memory; read them as "a small in-GPU cache beats spilling to CPU/disk", not as a 29× kernel effect.)
- **Setup:** implemented on top of **FlexGen**; experiments on a **single NVIDIA A100 (80 GB)** GPU. Accuracy validated across **OPT, LLaMA, and GPT-NeoX** model families on a wide range of tasks drawn from **lm-eval-harness and HELM** (commonsense QA, summarisation, and other standard suites listed in the paper).
- **Quality at small budgets (as analysed in the paper and its follow-on literature):** at a 20% cache budget H2O stays close to full-cache quality (perplexity within ~2% of full cache in the reported language-modelling comparisons) where recency-only window policies at the same budget degrade sharply on recall-sensitive tasks.
- **Foundational measurements:** attention sparsity **>95%** at inference across the studied models; a 30B model at batch 128 × 1024 tokens would need ~**180 GB** of full KV cache — the memory pressure the policy exists to relieve.

## 6. Limitations / what it does not solve

- Eviction is lossy and irreversible, unlike PagedAttention / RadixAttention which are exact. Any workload where a cold token suddenly becomes essential (a name mentioned once, early, and quizzed much later — and which never attracted attention in between) is the adversarial case.
- It needs attention scores at decode time. Runners built on fused attention kernels that never materialise the attention matrix must add score accumulation, which can eat part of the saving — the paper's FlexGen-based implementation predates today's kernel landscape.
- Scores are backward-looking: a token's importance is only known after later tokens have attended to it. The recent-token pool is the patch for this (new tokens are protected until they have had a chance to prove themselves), which is why the policy is a hybrid and not pure heavy-hitter retention.
- Headline throughput numbers are against offloading baselines (DeepSpeed Zero-Inference, HF Accelerate, FlexGen) rather than against a strong in-memory server like vLLM; the durable claim is the quality-at-20%-budget result, not the 29×.
- Per-head / per-layer importance varies; a single global eviction decision per token is a simplification the paper acknowledges through its per-layer analysis.

## 7. Applicability

### (a) Ollama on a 6 GB consumer GPU running long character chats

- H2O is the quality-preserving answer to the question StreamingLLM deliberately does not answer: when the chat must shrink, *which* middle turns can go? Pure recency truncation deletes the early scene-setting exchange and the first mention of every name; H2O keeps exactly the tokens the model kept looking back at — which, in roleplay, are disproportionately the persona-defining lines, names, and plot beats.
- Concrete recipe for a small-card chat mode: cache budget split three ways — pinned head (persona / sinks, per StreamingLLM), recent window (last turns, for fluency), and a heavy-hitter pool scored by accumulated attention. On a 6 GB card this is the difference between an 8K-token effective memory and a much longer *usable* conversation at the same memory.
- Engineering caution specific to Ollama's stack: llama.cpp-class runners use fused attention paths. Before promising H2O, verify the runner can accumulate per-token attention sums cheaply (a per-step reduction over attention weights for the newest query only is O(context) and small; materialising full matrices is not acceptable). If it cannot, a degraded variant — scoring tokens by attention received at a sampled subset of steps — should be labelled as such and quality-tested.
- Failure mode to surface to users: an evicted detail is gone permanently, and the model will confabulate rather than admit it. For character chat this argues for pairing H2O with an external notes / summary memory for facts, using H2O to protect fluency and salience, not as the sole memory of record.

### (b) Project Aesir (Mojo runner — sessions, prefix memory, hybrid SSM models)

- Aesir should treat H2O scoring as a cache-manager signal, not just an eviction rule: accumulated-attention scores can drive (i) which blocks get evicted under pressure, (ii) which prefix blocks are worth persisting to disk between sessions (high-score blocks are the conversation's load-bearing memory), and (iii) which parts of a long session get summarised first when building a memory digest.
- Block granularity: score at block level (sum / max of token scores in the block) so eviction stays compatible with PagedAttention-style allocation; token-level eviction inside blocks fragments the very layout paging exists to protect.
- Mojo / kernel design note: Aesir controls its own attention kernels, so it can accumulate the newest query's attention sums into a per-token score buffer as a fused epilogue — the integration cost that blocks H2O on third-party fused kernels is a design choice Aesir gets to make correctly from the start. Record that as an explicit kernel requirement.
- Hybrid SSM models: SSM layers have no KV to evict, but the *attention* layers of a hybrid benefit identically. More interestingly, heavy-hitter statistics give Aesir a measurable definition of "important tokens" for deciding what crosses the SSM/attention boundary in future architectures — log it as a research instrument, not just a policy.
- Evaluation discipline: any Aesir eviction policy must be reported the H2O way — quality vs full cache at fixed budget fractions (e.g. 20% / 50%) on recall-sensitive tasks — never as speed alone.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2306.14048
- arXiv HTML (read for method + evaluation detail): https://arxiv.org/html/2306.14048v3
- NeurIPS proceedings PDF: https://proceedings.neurips.cc/paper_files/paper/2023/file/6ceefa7b15572587b78ecfcebb2827f8-Paper-Conference.pdf
