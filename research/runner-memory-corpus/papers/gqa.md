# GQA — GQA: Training Generalized Multi-Query Transformer Models from Multi-Head Checkpoints

## 1. Full citation

- **Title:** GQA: Training Generalized Multi-Query Transformer Models from Multi-Head Checkpoints
- **Authors:** Joshua Ainslie, James Lee-Thorp, Michiel de Jong, Yury Zemlyanskiy, Federico Lebrón, Sumit Sanghai
- **Affiliation (as listed in the paper):** Google Research (de Jong: University of Southern California, work done at Google Research)
- **Venue / year:** Proceedings of the 2023 Conference on Empirical Methods in Natural Language Processing (EMNLP 2023), pp. 4895–4901
- **arXiv:** arXiv:2305.13245 [cs.CL] — v1 22 May 2023; v3 23 December 2023 — https://arxiv.org/abs/2305.13245

## 2. The problem it attacks

Autoregressive decoding is memory-bandwidth-bound: at every generated token the runner must stream the model weights *and the entire KV cache* from memory. Multi-head attention (MHA) keeps a separate key and value head for every query head, so the cache — and the bandwidth to read it — scales with the full head count. Multi-query attention (MQA, Shazeer 2019) attacks this by sharing a *single* K/V head across all query heads, and it is drastically faster; but MQA measurably degrades quality, can be training-unstable, and — the practical sting — most existing checkpoints (T5, LLaMA at the time) were trained as MHA, so adopting MQA seemed to require training a separate model from scratch. The problem is thus twofold: find the right point *between* MHA and MQA, and find a cheap way to get there from checkpoints that already exist.

## 3. Core idea in our own words

**Grouped-query attention (GQA)** interpolates. Divide the H query heads into **G groups**; all query heads in a group share **one** key head and **one** value head. The endpoints are the familiar schemes: G = 1 is MQA, G = H is MHA, and everything between is a tunable trade of cache size for capacity.

**The exact memory arithmetic** (per token, per layer, in elements — multiply by bytes-per-element and layer count for bytes):

| Scheme | KV heads | Elements cached per token per layer | vs MHA |
|---|---|---|---|
| MHA | H | 2 · H · d_h | 1× |
| GQA-G | G | 2 · G · d_h | G/H× |
| MQA (GQA-1) | 1 | 2 · d_h | 1/H× |

So the cache and the per-step bandwidth to read it shrink by a factor **H/G**, independent of context length — the saving is structural, paid on every token at every length. Worked illustration (our arithmetic, not a paper measurement): a model with H = 32 query heads, d_h = 128, 32 layers at FP16 caches 2·32·128·2 B·32 ≈ 512 KiB/token under MHA; GQA-8 caches 128 KiB/token; MQA would cache 16 KiB/token. GQA's argument for existing at all is that the middle of that range keeps nearly all of MHA's quality (see §5) while MQA visibly does not.

**Uptraining** is the second contribution: an existing MHA checkpoint can be converted rather than retrained. Each group's single K/V projection is initialised by **mean-pooling the projection matrices of the original heads in that group**, and the converted model is then pre-trained further on the original recipe for a small fraction — **α = 0.05, i.e. 5% of the original pre-training compute** — to adapt. Mean-pooling beats the alternatives the paper ablates (taking the first head; random re-initialisation), in that order, tracking how much pre-trained information each preserves.

## 4. Key design details a runner engineer needs

- **Scope of application:** GQA is applied to decoder self-attention and cross-attention, explicitly *not* to encoder self-attention — encoder states are computed in parallel, so bandwidth is not the bottleneck there. In a decoder-only model (the modern default, and Ollama's whole world) every layer is in scope.
- **Group count is an architecture constant of the model**, fixed at training/conversion time and recorded in the model config (in GGUF terms, the KV-head count metadata). A runner reads it; it can never choose it. Two models with identical parameter counts can differ 4–8× in cache footprint purely by this number — check it before promising a context length on a given card.
- **Why GQA suits large models and sharding (paper's argument):** as models grow, head count grows, so MQA's single head becomes an ever more aggressive relative cut; GQA keeps the bandwidth/capacity *proportion* stable with scale. Additionally, tensor-parallel sharding replicates MQA's single K/V head on every partition — pure waste that GQA's multiple heads eliminate.
- **Conversion details:** groups are formed from the original heads in order and mean-pooled per group; uptraining uses the *same* data, optimiser (Adafactor for T5), and schedule as original pre-training, just truncated to α of the steps. For T5-XXL at α = 0.05 the paper reports ~600 TPUv3 chip-days — cheap relative to pre-training, enormous relative to anything a serving team would call "conversion". Uptraining is a model-producer operation, full stop.
- **Stability note (paper's Appendix A):** MQA models trained from scratch suffered frequent loss spikes and diverged on fine-tuning for long-input tasks; uptrained MQA was more stable but high-variance (results averaged over three fine-tuning runs); uptrained GQA models were stable. If a catalogue offers an MQA variant of a model, treat its long-context behaviour as suspect until tested.

## 5. Reported results — as reported, with context

All figures are the paper's own measurements. testbed: **T5.1.1 Large and XXL**, JAX/Flaxformer; tasks are five summarisation sets (CNN/Daily Mail, arXiv, PubMed, MediaSum, Multi-News; ROUGE-1), WMT 2014 English→German (BLEU), and TriviaQA (F1); timing is seconds per sample per TPUv4 chip (8 TPUs, largest batch up to 32 per TPU, greedy decoding).

- **Headline (Table 1, 5% uptrained XXL variants):** MHA-XXL — 1.51 s/sample, average score **47.2**. MQA-XXL — **0.24 s/sample**, average **46.6**. **GQA-8-XXL — 0.28 s/sample, average 47.1.** In words: GQA-8 runs at ~5.4× the speed of its own MHA checkpoint and within 0.1 average points of it, while MQA runs marginally faster (0.24 s) but gives up 0.6 points. Per-task, GQA-8 sits between MQA and MHA almost everywhere (CNN/Daily Mail ROUGE-1: MHA 43.8, GQA-8 43.5, MQA 43.0; TriviaQA F1: 81.9 / 81.6 / 81.3; WMT BLEU: GQA-8 28.4 = MHA 28.4, MQA 28.5).
- **The uptraining bargain:** uptrained MQA-XXL (0.24 s, 46.6) is both faster *and* better than the smaller MHA-Large (0.37 s, 46.0) — converting a big checkpoint beats serving a smaller native one.
- **Ablations:** mean-pooling > first-head > random initialisation for conversion. GQA is already reasonable immediately after conversion, while MQA needs uptraining to be usable; both gain from 5% uptraining with diminishing returns by 10%. Raising group count from 1 toward 8 costs little speed; cost steepens as G approaches H — the paper selects **8 groups** as the favourable middle for XXL.
- Note what is *not* in the paper: no decoder-only experiments, no perplexity suite, and no from-scratch GQA comparison (see Limitations). The now-familiar deployments of GQA in decoder-only models (Llama-2-70B and most subsequent open models ship GQA configurations) postdate and build on this paper; they are not its evidence.

## 6. Limitations / what it does not solve

- **Evidence base is encoder-decoder T5 only** (authors' own Limitations section). The authors expect the advantage to be *stronger* in decoder-only models (no separate self-/cross-attention split) but did not measure it; the paper's numbers should not be quoted as decoder-only results.
- **No from-scratch control:** due to compute limits the paper never compares uptrained GQA against a GQA model trained from scratch, so the true cost of conversion vs native training is unknown from this work.
- **Metric weakness (authors' own caveat):** headline quality rests heavily on ROUGE, which the authors call flawed, and long-generation quality — the regime where KV bandwidth matters most — is inherently hard to evaluate. The 0.1-point GQA/MHA gap is within the resolution of the instruments used.
- GQA reduces cache *per token*; it does nothing about cache *growth* with length, nothing about precision (orthogonal to KIVI/KVQuant), and nothing about which tokens matter (orthogonal to eviction). It is one axis of the stack, not a solution to the memory wall by itself.
- The 5% uptraining recipe assumes access to the original pre-training data and recipe — true for T5's producers, false for most downstream holders of a checkpoint, for whom GQA is simply whatever the model shipped with.

## 7. Applicability

### (a) Ollama on a 6 GB consumer GPU

- **Bluntly: GQA is a model property, not a runtime policy.** A runner cannot retrofit it onto an existing GGUF model. Serving an MHA model with fewer KV heads than it was trained with is not "enabling GQA" — it is corrupting the model; the only honest conversion path is the paper's mean-pool + uptraining, which is a training operation requiring the original data recipe and hundreds of chip-days at scale. No serve-time flag exists or can exist.
- **What Ollama *can* do is exploit and surface it:** (i) prefer GQA models in recommendations for small cards — when two models are otherwise comparable, the one with fewer KV heads leaves gigabytes more room for context at 6 GB; (ii) compute and display the true per-token cache cost from the model's KV-head count before a user picks a context length, so "128K context" claims are priced in the model's actual arithmetic (2·G·d_h·layers·bytes), not its marketing; (iii) remember the interaction with quantisation from the KIVI dossier — heavily head-compressed models (MQA, low-G GQA) showed the least remaining headroom for 2-bit KV quantisation (Falcon needed 4-bit), so cache policy should be chosen per model with both numbers in view.
- For model *selection* guidance to users: at fixed weights size, a GQA-8 model at longer context will usually serve a long character chat better than an MHA model at short context, because in chat the binding constraint is cache, not the small quality delta the paper measures.

### (b) Project Aesir (Mojo runner — sessions, prefix memory, hybrid SSM models)

- For Aesir-the-runner, GQA is a *format and kernel* requirement, not a policy: the attention kernel must handle KV-head count ≠ query-head count natively (broadcasting each KV head to its query group), and the cache layout should be sized by G, never by H. Any Aesir kernel that assumes H KV heads wastes the exact memory GQA exists to save — treat "kernel silently expands KV to H heads" as a defect class to test for at model onboarding.
- For Aesir's model-design horizon (fine-tunes or house models), GQA is the conservative default and this paper is the costing evidence: G ≈ 8 at XXL scale bought MHA-level quality at ~MQA speed, and uptraining an existing checkpoint costs ~5% of pre-training — the realistic path if Aesir ever converts a house MHA model rather than training anew.
- The uptraining result also bounds a tempting shortcut: there is no zero-training conversion. If a future Aesir feature proposes "GQA-ify this model at load time", this paper is the refutation — conversion without the 5% adaptation is exactly the configuration the ablations show underperforming (and, for MQA, unstable).
- Hybrid SSM models sidestep part of this: their SSM layers have no KV heads at all, so the GQA choice only prices the attention layers. When Aesir compares a hybrid against a dense GQA model on cache footprint, the honest comparison is per-token bytes across *all* layers of each — the arithmetic style of §3, applied uniformly.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2305.13245
- arXiv HTML (read for method + evaluation detail): https://arxiv.org/html/2305.13245v3
- EMNLP 2023 / ACL Anthology record: in *Proceedings of the 2023 Conference on Empirical Methods in Natural Language Processing*, pp. 4895–4901 (citation as given in the paper's published record)
