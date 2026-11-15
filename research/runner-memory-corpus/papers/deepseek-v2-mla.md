# DeepSeek-V2 / MLA — DeepSeek-V2: A Strong, Economical, and Efficient Mixture-of-Experts Language Model (Multi-head Latent Attention)

## 1. Full citation

- **Title:** DeepSeek-V2: A Strong, Economical, and Efficient Mixture-of-Experts Language Model
- **Authors:** DeepSeek-AI (corporate author; the paper carries an author list of over 150 named contributors, headed by Aixin Liu, Bei Feng, Bin Wang, Bingxuan Wang, Bo Liu, et al.)
- **Venue / year:** arXiv technical report, 2024. No conference proceedings publication is recorded on the arXiv record; cite as a technical report.
- **arXiv:** arXiv:2405.04434 [cs.CL] — v1 7 May 2024; v5 19 June 2024 — https://arxiv.org/abs/2405.04434
- **Code / checkpoints (as reported in the paper):** https://github.com/deepseek-ai/DeepSeek-V2
- **Scope note for this dossier:** the focus is **Multi-head Latent Attention (MLA)** as a KV-cache memory reduction. The DeepSeekMoE half of the paper is summarised briefly in §4.

## 2. The problem it attacks

DeepSeek-V2 is a 236B-parameter MoE model (21B activated per token, 128K context) whose designers wanted MHA-grade attention quality without MHA's inference bill. The paper's framing is that the existing cache-reduction schemes buy memory with quality: in its own controlled ablation (7B dense models, same architecture, 1.33T training tokens), MHA beats GQA-8 beats MQA decisively on hard benchmarks — MMLU 45.2 (MHA) vs 41.2 (GQA) vs 37.9 (MQA); C-Eval 42.9 vs 37.7 vs 30.0. For a flagship model that gap is unacceptable, yet the MHA cache at this scale is the binding constraint on batch size and generation throughput. The problem: compress the KV cache *below even MQA's footprint* while performing *at or above* MHA — a combination head-sharing cannot reach, because head-sharing throws away per-head key/value diversity by construction.

## 3. Core idea in our own words

MLA compresses by **rank, not by head count**. Instead of deciding how many K/V heads to keep, it changes *what a cached token is*:

- A single **down-projection** maps each token's hidden state to one shared **compressed latent vector** c^KV of dimension d_c — one vector per token per layer, for *all* heads jointly, covering keys and values together.
- **Only the latent is cached.** Each head's keys and values are *reconstructions*: per-head up-projections (W^UK, W^UV) expand the latent back into that head's key and value when needed.
- At inference the reconstructions never even materialise: W^UK can be **absorbed** into the query projection and W^UV into the output projection (matrix associativity), so attention scores are computed directly against the latent cache. The cache the runner streams per step is the small latent, not per-head tensors — that is where the bandwidth saving comes from, not merely the storage saving.

**The RoPE problem and decoupled RoPE.** Rotary position embedding is applied to keys, and a position-dependent rotation sitting between W^Q and W^UK would break the absorption trick (the rotation for the *current* token would have to be folded into a cached-side matrix). MLA's fix is to split position out of the content path entirely: a small **decoupled RoPE key** — one shared key of dimension d_h^R per token, produced by its own projection and RoPE'd in the ordinary way — is cached alongside the latent and concatenated to every head's (position-free) content key. Content travels through the latent; position travels through the side channel. (Context extension later exploits exactly this split: YaRN is applied only to the decoupled key to stretch 4K → 128K.)

**The exact memory arithmetic** (elements per token, all layers; l = layer count):

| Scheme | Elements per token |
|---|---|
| MHA | 2 · n_h · d_h · l |
| GQA (n_g groups) | 2 · n_g · d_h · l |
| MQA | 2 · d_h · l |
| **MLA** | **(d_c + d_h^R) · l** |

DeepSeek-V2's configuration: n_h = 128 heads, d_h = 128, **d_c = 512 (= 4·d_h)**, **d_h^R = 64 (= d_h/2)**, l = 60 layers, hidden size 5120. Per token per layer that is 576 cached elements vs 32,768 for the MHA counterfactual; the paper's summary is that MLA's cache **equals GQA with only 2.25 groups** (≈ 4.5·d_h·l) — smaller than any GQA configuration anyone would ship — while its ablations show it *outperforming* MHA (§5). Queries are also low-rank compressed (d_c′ = 1536), but that targets training activation memory, not the cache.

## 4. Key design details a runner engineer needs

- **Cache contents, precisely:** per token per layer, store [c^KV (512 floats); k^R (64 floats)]. Nothing else. Keys per head, values per head: never stored, either reconstructed or absorbed away.
- **Two inference forms exist and a runner must pick consciously:** the *absorbed* form (fold W^UK into W^Q, W^UV into W^O; attend against latents; minimal bandwidth, more per-step compute in the projected space) and the *materialised* form (expand latents to per-head K/V, then ordinary attention; simpler kernels, gives back much of the bandwidth win). The paper's efficiency claims assume the absorbed-style deployment together with its FlashAttention-2-based MLA optimisation.
- **Precision in the deployed system:** the paper's serving numbers come from a deployment with parameters converted to **FP8** and the (already latent) KV cache further **quantised to ~6 bits average per element** — MLA composes with cache quantisation rather than replacing it; the latent is still a vector that can be quantised KIVI/KVQuant-style.
- **Training configuration (for scale calibration):** pre-trained on 8.1T tokens (bilingual, ~12% more Chinese than English tokens), max sequence 4K, then YaRN extension + 1000 steps at 32K to reach 128K; AdamW, batch size ramped 2304 → 9216 sequences; trained on an NVIDIA H800 cluster with the internal HAI-LLM framework. This is a train-from-scratch architecture — every MLA property above is baked into the weights (down/up-projections are learned).
- **DeepSeekMoE, briefly (the non-MLA half):** all FFNs except the first layer are MoE layers with **2 shared experts + 160 fine-grained routed experts** (expert intermediate size 1536), **6 routed experts activated per token**, device-limited routing (each token's experts confined to at most M = 3 devices under expert parallelism), three balance losses (expert-, device-, communication-level), and a training-time token-dropping strategy at capacity factor 1.0. This is what makes 236B total / 21B active economical to train; it does not itself reduce KV memory.
- **DeepSeek-V2-Lite:** a 15.7B-total / 2.4B-active sibling with the same MLA + DeepSeekMoE design, released for the community — the only member of the family whose scale is even adjacent to local serving, and still far beyond a 6 GB card in full form.

## 5. Reported results — as reported, with context

All figures are the paper's own measurements.

- **The controlled MLA-vs-MHA ablation (Appendix D.2) — the cleanest evidence in the paper.** Same-architecture MoE pairs differing only in attention, at two scales:
  - Small MoE (~16B total, trained on 1.33T tokens): KV cache per token **110.6K elements (MHA) → 15.6K (MLA), 14%**; MMLU 48.7 → **50.0**, BBH 37.9 → **39.0**, CMMLU 52.3 → **53.4** (one reversal: C-Eval 51.6 → 50.9).
  - Large MoE (~250B total, 420B tokens): KV cache per token **860.2K → 34.6K elements, 4%**; MMLU 57.5 → **59.0**, BBH 46.6 → **50.7**, C-Eval 57.9 → **59.2**, CMMLU 60.7 → **62.5**.
  MLA is simultaneously ~7–25× cheaper in cache and better on nearly every listed benchmark. That inversion — compression as a *quality gain*, plausibly because the low-rank bottleneck regularises — is the result that makes MLA more than an engineering trick.
- **Full-model headline vs DeepSeek 67B (dense, MHA):** KV cache **reduced by 93.3%**; training cost **−42.5%** (172.8K vs 300.6K GPU-hours per trillion tokens on the H800 cluster); maximum generation throughput **5.76×** — measured on a single node of 8× H800 with the FP8 + ~6-bit-KV deployment above, exceeding 50K generated tokens/s and 100K prompt tokens/s on the production prompt/generation distribution of the earlier DeepSeek service. Read the 5.76× as a *system* result (MLA + MoE sparsity + FP8 + KV quantisation + serving stack), never as MLA alone.
- **Full-model quality (internal evaluation framework, base models):** DeepSeek-V2 scores MMLU 78.5 (DeepSeek 67B: 71.3; LLaMA3-70B: 78.9; Mixtral 8×22B: 77.6), GSM8K 79.2, MATH 43.6, HumanEval 48.8, C-Eval 81.7, CMMLU 84.0 — top-tier among open models with 21B activated parameters. Needle-in-a-Haystack is reported as performing well across all window lengths to 128K (Figure 4). Chat (RL) version: AlpacaEval 2.0 length-controlled win rate 38.9, MT-Bench 8.97, AlignBench 7.91.

## 6. Limitations / what it does not solve

- **MLA is train-from-scratch architecture.** The paper contains no conversion or uptraining recipe from an existing MHA/GQA checkpoint (contrast GQA's 5% uptraining). A runner cannot retrofit MLA onto a GGUF model; the latent projections must be learned as part of the model. (Later third-party work on MHA→MLA conversion exists outside this paper and is outside this dossier's scope.)
- **The flagship is not a local model.** 236B total parameters must be *stored and streamed* even though only 21B activate per token; the KV triumph does not make DeepSeek-V2 itself servable on consumer hardware. Its relevance to small-card serving is entirely through architecture inheritance by smaller future models (V2-Lite at 15.7B is the paper's own gesture in that direction).
- The paper's own discussion (§5 / Appendix E) records relative weaknesses: a slight gap to LLaMA3-70B on some English commonsense tasks (TriviaQA, NaturalQuestions, HellaSwag), attributed to fewer English training tokens; and degraded scores on culture-specific test subsets (analysed for MMLU Humanities–Moral) attributed to the team's pre-training debiasing filter. Neither is an MLA defect, but both bound the "stronger than MHA" headline to the benchmarks actually listed.
- Efficiency evidence is single-vendor and single-stack: H800 nodes, internal framework, FP8 deployment. No consumer-GPU, no independent-runner (vLLM/llama.cpp) MLA numbers appear in the paper; absorbed-form kernels are specialised work that each runner must implement and validate itself.
- MoE serving costs are real and separate: expert routing, all-to-all communication, and load imbalance are operational burdens a small deployment inherits along with the KV savings if it adopts the full architecture.

## 7. Applicability

### (a) Ollama on a 6 GB consumer GPU

- **Bluntly: MLA is a model property, exactly like GQA, and cannot be retrofitted at serve time.** No flag, quantisation, or cache policy turns an existing GGUF model into an MLA model. If a user asks for "MLA efficiency" on a model that was not trained with MLA, the honest answer is that the efficiency lives in the weights or nowhere.
- **What Ollama should do with MLA is be ready for the models:** MLA support in the runner means (i) a cache whose per-token record is [latent; RoPE key] rather than per-head K/V, (ii) an absorbed-form attention kernel (or an honest materialised form with its bandwidth cost disclosed), and (iii) context-length pricing computed from (d_c + d_h^R)·layers·bytes. When MLA-architecture models at locally-servable scales appear (V2-Lite-class and successors), that support converts directly into the longest contexts a 6 GB card can hold: at V2-Lite scale the latent cache is an order of magnitude below a comparable GQA cache per token.
- **Model-selection guidance in the meantime:** for today's 6 GB catalogue, the practical proxy for MLA's benefit is "fewest cached bytes per token" — compare candidate models by their true per-token cache arithmetic (GQA head count × head-dim × layers × precision, from the GQA dossier) and prefer the smaller figure when chat length matters. MLA simply wins that comparison by a large factor whenever an MLA model is on the list.
- Note the composition the paper itself demonstrates: MLA + KV-cache quantisation (~6-bit in their deployment) stack multiplicatively. An MLA model served by Ollama should still get KIVI/KVQuant-class cache quantisation on its latents — the techniques are complements, not rivals.

### (b) Project Aesir (Mojo runner — sessions, prefix memory, hybrid SSM models)

- **MLA is the strongest argument in this wave for Aesir to treat "what a cached token is" as a pluggable per-architecture format.** Aesir's cache abstraction should not hard-code [K per head; V per head]: it needs at least three record shapes — MHA/GQA per-head K/V, MLA [latent; RoPE key], and SSM state checkpoints — behind one session/prefix-store interface. MLA support designed-in is a kernel and a record type; MLA support retrofitted is a fork.
- **The absorbed-form kernel is a named Aesir work item:** attention computed against latents with W^UK folded into the query path and W^UV into the output path, in Mojo, with the decoupled RoPE key handled as a concatenated side input. This is also where Aesir's accelerator-first law bites: the absorbed form trades bandwidth (scarce) for dense matmul FLOPs (comparatively plentiful on GPU/NPU) — the right trade on the hardware Aesir targets, and it should be measured per device class rather than assumed.
- **Prefix memory gets *simpler* under MLA:** a persisted prefix is one latent sequence, ~28× smaller per token than an MHA prefix at V2 scale — session restore bandwidth and disk footprint shrink by the same factor, and quantising latents for cold storage (per §7a) shrinks them further. If Aesir's session store is sized using MHA assumptions, MLA models will wildly under-use it; size it per record shape.
- **For Aesir's own model ambitions, MLA is the credible path past GQA:** the ablation evidence (§5) says a house model trained or fine-tuned with MLA need not pay GQA's quality tax for its cache savings. The cost is the train-from-scratch (or heavy conversion) requirement — record MLA as an architecture decision to make *before* any house-model training run, since it cannot be revisited afterwards.
- Watch-item: MLA's interaction with eviction/quantisation policies is under-evidenced in this paper (eviction over latents is not token eviction in the usual sense — dropping a latent drops the token for all heads at once, which is at least clean; quantisation of latents is demonstrated only in the authors' own deployment). Aesir should treat SnapKV/PyramidKV-over-MLA and KIVI-over-MLA as open experiments with the wave's standard evaluation discipline, not as established compositions.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2405.04434
- arXiv HTML (read for architecture, ablations, and evaluation detail): https://arxiv.org/html/2405.04434v5
