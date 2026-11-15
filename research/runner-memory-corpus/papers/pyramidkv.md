# PyramidKV — PyramidKV: Dynamic KV Cache Compression based on Pyramidal Information Funneling

## 1. Full citation

- **Title:** PyramidKV: Dynamic KV Cache Compression based on Pyramidal Information Funneling
- **Authors:** Zefan Cai, Yichi Zhang, Bofei Gao, Yuliang Liu, Yucheng Li, Tianyu Liu, Keming Lu, Wayne Xiong, Yue Dong, Junjie Hu, Wen Xiao
- **Affiliations (as listed in the paper):** University of Wisconsin–Madison; Peking University; Nanjing University; University of Surrey; Qwen; University of California, Riverside; Microsoft
- **Venue / year:** Second Conference on Language Modeling (COLM 2025) — the revised paper carries the header "Published as a conference paper at COLM 2025". First released as an arXiv preprint in June 2024.
- **arXiv:** arXiv:2406.02069 [cs.CL] — v1 4 June 2024; v4 15 May 2025 — https://arxiv.org/abs/2406.02069
- **Code (as reported in the paper):** https://github.com/Zefan-Cai/PyramidKV

## 2. The problem it attacks

Every KV-cache compression method before this one — StreamingLLM, H2O, SnapKV — allocates the **same cache budget to every layer**. PyramidKV starts from the suspicion that this uniformity wastes exactly the resource being saved: if some layers attend broadly over the whole context and others attend to a handful of tokens, a uniform budget simultaneously starves the broad layers (dropping tokens they genuinely use) and pads the narrow layers (keeping tokens nobody reads). The problem is therefore not only *which* tokens to keep, but *how many per layer* — budget allocation across depth as a first-class design variable.

## 3. Core idea in our own words

The paper visualises attention over layers for multi-document QA (LLaMA family) and names the pattern **Pyramidal Information Funneling**:

- **Lower layers attend broadly** — attention is spread almost uniformly over all content; each individual KV carries little aggregated information, so dropping tokens here destroys raw material the rest of the network has not yet distilled.
- **Middle layers localise** — attention concentrates within each document/context segment; information is being gathered into segment-level summaries.
- **Upper layers collapse onto a few tokens** — "massive attention" lands on a small set of critical tokens (the attention-sink / massive-activation tokens); by this depth the answer-relevant content has been funnelled into very few positions, so most KVs are redundant.

If information funnels as depth increases, the cache budget should funnel with it. PyramidKV therefore keeps the *total* budget identical to uniform baselines but distributes it as a **pyramid: many entries in lower layers, few in upper layers**. Within each layer, token selection reuses the SnapKV mechanism (vote from the final tokens' attention, with pooling) — PyramidKV's original contribution is the allocation, not the scoring signal. The claim of novelty is explicit: the first KV compression method with per-layer varied retention.

## 4. Key design details a runner engineer needs

- **Allocation rule:** given total budget k_total over m layers, the bottom layer gets k⁰ = 2·k_total / m entries; the top layer's size is set via a shape hyperparameter **β = 20** (paper's setting); intermediate layers form an **arithmetic sequence** between the two, monotonically decreasing with depth. The pyramid is a fixed heuristic shape — it is not learned per model or per prompt, and β is a single global knob.
- **Protected tail:** the last **α = 8 tokens** of the input (the paper's "instruction tokens") are retained in *every* layer before any selection, and their attention over the prefix is the voting signal, exactly as in SnapKV: per head, score s_i = Σ over instruction-token queries of attention to position i, pool, take top-k^l for that layer's budget k^l.
- **One-shot, prompt-side, fine-tuning-free** — same operating shape as SnapKV: compress at the end of prefill, discard permanently, decode against the compressed cache. All of SnapKV's structural caveats (prefill cost untouched, irreversibility, tail-dependent voting) are inherited unchanged; PyramidKV changes only how the kept entries are distributed across layers.
- **Fair-comparison discipline in the paper:** total memory is held equal across methods (PyramidKV's *average* per-layer size equals the baselines' uniform size), so every reported win is purely an allocation win — a clean experimental design a runner team should copy when evaluating allocation policies.
- **Memory accounting (paper's Table 2, LLaMA-3-8B-Instruct, batch 1, sequence 8192, FP16):** full KV cache 6848 MB; average cache size 2048 → 1712 MB (25.0%); 1024 → 856 MB (12.5%); 256 → 214 MB (3.1%); 64 → 53 MB (0.8%). Per-layer non-uniformity means the cache manager must support a different capacity per layer — in a paged allocator this is a per-layer block quota, not a global one.

## 5. Reported results — as reported, with context

All figures are the paper's own measurements. Benchmark: **LongBench, 17 datasets** (single-/multi-document QA, summarisation, few-shot learning, synthetic, code), greedy decoding, backbones **LLaMA-3-8B-Instruct, LLaMA-3-70B-Instruct, Mistral-7B-Instruct**, baselines SnapKV, H2O, StreamingLLM at equal total budget.

- **Performance-preserving regime (average cache size 2048):** LLaMA-3-8B-Instruct LongBench average **41.49 for PyramidKV vs 41.46 for the full cache** — the basis of the abstract's "matches full-KV performance while retaining only 12% of the KV cache" claim (12% is the retained fraction at the benchmark's average prompt lengths). Per-model at 2048: Mistral-7B average 41.63 (full cache 42.71); LLaMA-3-70B 46.55 (full cache 46.55 — exact match). Margins over SnapKV at this budget are small (LLaMA-3-8B: 41.49 vs 41.35) — at comfortable budgets, allocation barely matters.
- **Memory-starved regime (average cache size 64, ≈0.7% retained), where the method earns its keep:** LLaMA-3-8B average **34.76 (PyramidKV) vs 33.89 (H2O), 33.05 (SnapKV), 30.43 (StreamingLLM)**, full cache 41.46. The flagship task is **TREC** (few-shot classification): LLaMA-3-8B scores **58.00 with PyramidKV vs 38.50 SnapKV / 38.00 H2O / 38.00 StreamingLLM** — the source of the abstract's "up to 20.5 absolute accuracy improvement on TREC" (the largest per-model gap; Mistral-7B TREC at 64: 54.00 vs 37.50 for SnapKV). The paper's reading: few-shot tasks aggregate information from many examples in lower layers, which uniform budgets starve first.
- **Needle-in-a-Haystack (contexts to 8K in the main figure, cache size 128):** with **128 retained entries, LLaMA-3-70B-Instruct reaches 100.0 accuracy, matching the full cache**, and PyramidKV degrades more gracefully than SnapKV/H2O as context grows within the tested range; appendix results extend to Mistral-7B at 32K context.
- **Trend across budgets (paper's Figure 4):** PyramidKV beats all three baselines at every tested average size (64, 96, 128, 256, 2048) on all three backbones, with the advantage *growing* as the budget shrinks — consistent with the allocation story: the tighter the total, the more it matters where entries sit.

## 6. Limitations / what it does not solve

- **The funnel is an observation, generalised by hope.** The pyramidal pattern is demonstrated visually on multi-document QA with LLaMA models; the paper then applies one fixed arithmetic pyramid (β = 20, α = 8) to every task and model and shows it works on LongBench. There is no per-model or per-task funnel measurement, no learned allocation, and no analysis of architectures whose attention may not funnel the same way (hybrid SSM/attention models, MLA models, heavily GQA'd small models are all untested).
- It inherits SnapKV's limits wholesale: one-shot prompt compression, prefill cost and peak untouched, discarded tokens unrecoverable, voting dependent on the prompt tail.
- **No systems evaluation.** The paper reports accuracy and cache-memory arithmetic only — no latency, throughput, or kernel implementation results. Per-layer variable capacities complicate paged allocation and kernel tiling; the real cost of that complexity is unmeasured by the authors.
- At realistic (non-starved) budgets the win over plain SnapKV is within noise on several models (41.49 vs 41.35). The method's value is concentrated in the extreme-compression corner — which is, to be fair, exactly the corner a 6 GB card lives in.
- LongBench prompts average ~1.2K–18.4K tokens by dataset; nothing here validates the pyramid at 100K+ contexts.

## 7. Applicability

### (a) Ollama on a 6 GB consumer GPU

- **Runtime policy, retrofittable** — like SnapKV, it needs no training or calibration and applies to an existing GGUF model; the runner work is SnapKV's voting machinery plus per-layer capacity quotas in the cache manager.
- **This is the wave's most precisely-targeted idea for a 6 GB chat product**, because its advantage is largest exactly when the cache budget is brutally small. If Ollama implements any SnapKV-class prompt/history compression for small cards, it should implement the pyramidal allocation on top from the start: the allocation change is a few lines once per-layer budgets exist, and the paper's evidence says uniform allocation leaves several LongBench points — and ~20 TREC points — on the table at cache sizes a 6 GB card will actually use (64–256 entries per layer average for very long histories).
- Practical shape for chat: pin the persona/system block in all layers (outside the budget, as with StreamingLLM), then distribute the remaining history budget pyramidally and re-vote per turn with the latest message as the instruction window (the per-turn re-snap adaptation described in the SnapKV dossier — ours, not the paper's, and to be validated as such).
- Do not import β = 20 blindly: it was set once, for three specific models, on LongBench. Treat pyramid steepness as a per-model-family tunable with a small sweep (flat → paper's β → steeper) on a recall-sensitive chat test before fixing a default.

### (b) Project Aesir (Mojo runner — sessions, prefix memory, hybrid SSM models)

- Aesir's cache manager should expose **per-layer capacity as a native concept** from the start — a budget vector, not a scalar. Even if the first policy shipped is uniform, the data structure should not bake uniformity in; PyramidKV is the standing proof that allocation across depth is a real axis, and later policies (head-level allocation is the obvious next step in the literature) will want the same hook at finer granularity.
- The funnel observation is a *measurement Aesir can repeat per model*: log per-layer attention entropy / top-k mass during prefill for each onboarded model and derive its actual funnel shape, rather than assuming the arithmetic pyramid. That converts a heuristic from the paper into per-model calibration data — cheap to collect, and exactly the kind of instrument a from-scratch runner can build in.
- For hybrid SSM models the pyramid idea translates rather than transfers: attention layers can take pyramidal budgets, while SSM layers have fixed state by construction. But the funnel hypothesis predicts hybrids need *less* attention cache in upper layers still — worth an explicit experiment in Aesir's hybrid evaluation suite, since no paper in this wave tests a hybrid.
- Session persistence: per-layer budgets mean a persisted session's blocks are unevenly distributed across layers; the prefix-store format must record per-layer block counts rather than assuming a rectangular cache. Small format decision, expensive to retrofit — record it now.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2406.02069
- arXiv HTML (v3, read for method + evaluation detail): https://arxiv.org/html/2406.02069v3
- COLM 2025 conference version (PDF as published): https://lacuna.tiptreesystems.com/pdf/art_3cf34e56a9e41409e16d5b98bf4c4129
