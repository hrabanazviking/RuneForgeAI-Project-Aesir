# DuoAttention — Efficient Long-Context LLM Inference with Retrieval and Streaming Heads

## 1. Full citation

- **Title:** DuoAttention: Efficient Long-Context LLM Inference with Retrieval and Streaming Heads
- **Authors:** Guangxuan Xiao, Jiaming Tang, Jingwei Zuo, Junxian Guo, Shang Yang, Haotian Tang, Yao Fu, Song Han
- **Affiliations (as listed):** MIT; Tsinghua University; SJTU; University of Edinburgh; NVIDIA (part of Xiao's work done during an NVIDIA internship)
- **Venue / year:** Published as a conference paper at ICLR 2025
- **arXiv:** arXiv:2410.10819 [cs.CL] — v1 14 October 2024 — https://arxiv.org/abs/2410.10819
- **Code (as linked in the paper):** https://github.com/mit-han-lab/duo-attention
- **Verification note:** the coordinator's identifiers checked out exactly — title, first author, ICLR 2025 venue, and arXiv number 2410.10819 are all confirmed on the arXiv record and the ICLR proceedings PDF. No correction needed.

## 2. The problem as framed

Uniform attention spends the same KV cache on every head: every head stores a key and a value for every past token, so cache memory grows linearly with context and decode must read all of it per generated token. The paper's motivating arithmetic: Llama-3-8B serving a 1M-token context at FP16 KV would need at least ~137 GB of KV memory alone — beyond a single 80 GB GPU — before weights are counted.

The waste is measurable, not hypothetical. The paper's opening observation (its Figure 1, on Llama-2-7B) is that heads split visibly into two behaviours: a minority attend back to contextually relevant distant tokens (the first "orange" when the second is generated), while the majority attend almost only to the initial tokens (attention sinks) and the recent window. A passkey probe makes the waste operational: restrict a streaming-pattern head to sinks + recent tokens and passkey retrieval is essentially unharmed; restrict a retrieval-pattern head the same way and retrieval collapses. Uniform full KV therefore buys, for most heads, storage of tokens those heads never read. Prior uniform compressors (StreamingLLM, H2O, TOVA, FastGen, as the paper characterises them) either damage exactly the retrieval capability the minority heads provide, or save too little — and none of them reduces prefill cost.

## 3. Core mechanism in our own words

**The classification is learned once, per model, by optimisation — not profiled from attention maps.** DuoAttention defines a retrieval head operationally: *a head whose restriction to sink + recent tokens significantly alters the model's output.* That definition is deliberately end-to-end — it captures the effect through value states and downstream layers, which attention-score profiling (FastGen, RazorAttention) misses, per the paper's ablations.

The identification procedure:

1. **One gate per KV head.** Each KV head (in GQA models the gate is per KV head, i.e. per group of query heads) gets a trainable scalar α ∈ [0,1], initialised at 1. All model weights are frozen; the only trainable parameters are the gates — thousands of scalars.
2. **Blend, don't switch.** During identification the head's output is α·(full attention) + (1−α)·(streaming attention), where streaming attention uses a Λ-shaped mask over sinks + recent tokens only.
3. **Objective.** Minimise an L2 distillation loss between the mixed model's final hidden states and the full-attention model's, computed **only on the answer (passkey) tokens**, plus an L1 (lasso) penalty on the gates (λ = 0.05) that pushes gates down wherever the distillation loss does not resist. A head whose α stays high under sparsity pressure is, by the definition above, a retrieval head.
4. **Synthetic calibration data.** Natural text gives too sparse a long-range signal (most tokens are locally predictable), so identification runs on a synthetic passkey task: ten random 32-token passkeys embedded at random positions in long BookSum text, recalled at the end. Identification settings as reported: 128 sink tokens and 256 recent tokens during optimisation, batch size 1, sample lengths drawn from 50 intervals up to the model's maximum, 2,000 AdamW steps, runnable on an 8×A100 node in "several hours" (paper's wording for the phase generally).
5. **Binarise and freeze.** At deployment each gate is thresholded (τ set by a target sparsity quantile): α > τ → retrieval head (full KV); otherwise → streaming head. The classification is **per-model-fixed and input-independent** thereafter — the same head is a retrieval head for every prompt, every user, every session. Reported operating ratios: **25% retrieval heads for Llama-2-7B (MHA), 50% for Llama-3-8B (GQA)**; the paper notes MHA models show a lower retrieval ratio than GQA models, where each KV head serves a group and is likelier to contain a retrieval function.

**The streaming-head KV policy.** A streaming head keeps a **constant-length** cache: attention sinks + a recent window, and nothing else — its memory is O(1) in context length. Reported numbers differ by phase and must not be collapsed into one: identification used 128 sinks / 256 recent; the long-context (NIAH/LongBench) deployment used **64 sinks / 256 recent**; short-context benchmarks used smaller settings (e.g. 32/128 on MMLU, 16/64 on MBPP/MT-Bench); and the deployment ablation (Mistral-7B) found performance **plateaus at 16 sinks / 64 recent**, with marginal gains beyond. The honest summary: the deployed window is a few hundred tokens at most, and the paper's own ablation says a much smaller one (80 tokens total) already saturates on the ablated model/task.

**Kernel / serving realisation.** Before deployment the Q/K/V projection output channels are **reordered** so retrieval heads and streaming heads form two contiguous clusters per layer — slicing instead of gather/scatter. Each layer then holds two caches: a growing full cache for the retrieval cluster and a constant cache for the streaming cluster; a new token's QKV is split along the head dimension, each cluster runs its own attention shape, and outputs are concatenated before the output projection. Prefill is chunked (FlashAttention-2): as each chunk's KVs are computed, streaming heads prune immediately to sinks + recent, giving streaming-head prefill **O(L·K) time and O(K) memory** (L = length, K = chunk size) instead of O(L²)/O(L). The design is stated to be batch-friendly and composable with GQA and with KV/weight quantisation (demonstrated with QServe kernels, §4).

## 4. Reported results — as reported, with hardware/model context

All figures are the paper's own; hardware throughout is a **single NVIDIA A100** (80 GB where stated), PyTorch implementation with FlashInfer RoPE/RMSNorm kernels, BF16 weights/activations unless quantisation is stated, KV cache pre-allocated for the benchmark sequence.

- **Headline (abstract):** memory reduction **up to 2.55× (MHA) / 1.67× (GQA)**; decoding speedup **up to 2.18× (MHA) / 1.50× (GQA)**; prefill acceleration **up to 1.73× (MHA) / 1.63× (GQA)**, "with minimal accuracy loss compared to full attention." The body (§3.4, Figure 9) reports slightly lower maxima at the tested operating points — up to 2.45× memory / 2.13× latency for MHA and 1.65× / 1.5× for GQA — approaching the inverse of the retrieval ratio as context grows; the abstract's larger figures come from the KV-budget sweep (Figure 11/12 in the HTML numbering). Both sets are the paper's; we record the discrepancy of presentation, not a contradiction of substance: savings scale ~linearly as the retrieval ratio is lowered.
- **Long-context quality:** on Needle-in-a-Haystack, DuoAttention at 25% (MHA) / 50% (GQA) full-attention ratio is reported comparable to full attention across depths, handling lengths **up to 1,048K tokens** on Llama-3-8B-Instruct-Gradient-1048k, while H2O/TOVA/StreamingLLM at the same KV budget fail at various depths. On LongBench (14 tasks plotted, 21 in appendix tables) it is reported to achieve the best KV-budget/accuracy trade-off of the compared methods and performance comparable to full attention on most tasks at those same ratios.
- **Short-context quality (Llama-3-70B, 50% budget, paper's Table 1):** MMLU 79.35% (full: 79.38%), MBPP 47.09% (full: 47.85%), MT-Bench 9.14 (full: 8.93) — versus, at the same budget, StreamingLLM collapsing on MBPP (5.57%) and MT-Bench (5.41). The 70B short-context row is the paper's cleanest single demonstration that the head split, not the budget cut, is what preserves capability.
- **Prefill (Figure 10 settings):** Llama-2-7B pre-filling 100K tokens and Llama-3-8B pre-filling 320K tokens, gains growing as chunk size shrinks: up to 1.73× / 1.63× latency and 2.38× / 1.53× memory reduction (MHA / GQA).
- **With quantisation:** combined with 8-bit weights + 4-bit KV (QServe), Llama-3-8B decodes with **3.3M-token context on a single A100-80G** — a reported **6.4× capacity increase** over the naive full-attention BF16 deployment. This is a capacity demonstration, not a quality-at-3.3M claim.
- **Ablations (Mistral-7B-Instruct-v0.2, passkey + MMLU):** the optimisation-based identification on synthetic data beats both attention-profiling identification and natural-language-modelling identification; both sink and recent components are necessary during optimisation; deployment quality plateaus at 16 sinks / 64 recent (see §3).

## 5. Position in the corpus

**Vs StreamingLLM (`papers/streamingllm.md`, wave 1).** StreamingLLM is DuoAttention's own ancestor (same first author) and its foil. StreamingLLM applies one policy — sinks + recent window — to **every head uniformly**. That buys constant memory and endless streaming, at the price the wave-1 dossier records: anything that leaves the window is unretrievable, forever. DuoAttention's claim is that StreamingLLM's failure is not a failure of the sink+window policy but of its *uniform application*: the waste — and the capability — is **head-structured**. Keep the identical policy, but only on the heads whose attention maps already look like it, and retrieval survives because the heads that do retrieval keep everything. The classification is the contribution; the streaming policy itself is inherited unchanged.

**Vs SnapKV (`papers/snapkv.md`, wave 1/3 line).** The two are mirror images on the time axis. SnapKV decides **per prompt, per head, at the end of prefill**, which *tokens* survive — dynamic, input-dependent, one-shot and irreversible for that prompt. DuoAttention decides **per model, per head, once, offline**, which *heads* keep tokens at all — static, input-independent, and applied identically to every future prompt. Consequences: SnapKV adapts to the document in front of it (and can be wrong about a conversation that pivots); DuoAttention cannot adapt, but its policy costs nothing at serve time, needs no observation-window attention materialisation, composes with chunked prefill (SnapKV explicitly does not reduce prefill), and its failure mode is a property of the model, testable once, rather than a property of each prompt. They also compose in principle — SnapKV selection inside DuoAttention's retrieval heads — but neither paper tests that composition; recorded here as corpus synthesis, not as a reported result.

**Vs H2O / PyramidKV (same family, other waves).** H2O evicts by accumulated attention score, dynamically, for all heads; PyramidKV budgets unevenly *across layers*. DuoAttention's axis is neither score nor layer: it is a permanent per-head cache *type*. Its identification objective (output deviation under restriction) is also the family's most direct: it measures the thing deployment will actually do.

## 6. Applicability

### (a) Retrofit honesty — the most retrofittable design in this wave's family, with one real gate

**Judgment (labelled as ours, argued from the paper's method): DuoAttention is a retrofit, not a training recipe — and it is the most retrofittable conditional-compute design in the corpus's sparsity line.** The reasoning, step by step:

- **No model weights change.** The optimisation trains only the per-KV-head gates (thousands of scalars) with the base model frozen. The artefact produced is a **binary mask over (layer, KV-head)** plus two integers (sink count, window size). A mask is metadata: a GGUF-side representation (a per-layer head-policy tensor or key-value metadata) is conceivable without touching a single weight.
- **The serving change is a cache-policy change, not an architecture change.** Two cache shapes per layer (growing vs constant), a head reorder (or equivalently a per-head cache-length table — the reorder is an optimisation, not a semantic requirement), and a streaming mask that StreamingLLM-class runners already implement. Nothing in the forward mathematics changes for retrieval heads at all.
- **The derivation needs only forward passes.** Identification is distillation against the model's *own* full-attention outputs on synthetic passkey text — no labels, no gradient through the base model, no fine-tune to undo. A converter-side or first-run calibration that runs the gate optimisation against a reference implementation is therefore *plausible* in a way that, e.g., LayerSkip's recipe (§5 of the wave-24 dossiers) never is.

The gate, stated honestly: **"plausible" is not "proven," and the mask is only as good as its derivation.** The paper derives masks with a full PyTorch/FlashInfer stack on A100s, 2,000 steps, lengths sampled up to each model's maximum. A GGUF-side derivation that used shorter calibration lengths, a different sink/window during optimisation, or a quantised reference model would produce a *different mask*, and a wrong mask fails silently — the model still talks; it just can no longer find things. The grading such a derivation would need, before any mask ships beside a model: (i) **raw-oracle comparison per family** — gate values / final masks from the local derivation vs the paper's published masks where they exist (Llama-2-7B, Llama-3-8B, Mistral-7B are the checkable set), with rank agreement reported per layer; (ii) **RULER-style needle checks per head-policy** — the derived mask applied, passkey/RULER retrieval swept over depth × length against the unmodified model, any depth band that collapses invalidates the mask, not the benchmark; (iii) a long-document QA spot-check (LongBench-class), because passkey-only calibration is exactly the distribution the mask was trained on and overfitting to it is the known risk shape. Until (i)–(iii) are run for a given model, a DuoAttention flag on a GGUF file is a claim, not a feature.

For models whose masks the *authors* publish, the calculus is better: honouring a shipped, paper-derived mask is detect-and-honour work — the runner implements the two-cache policy and trusts the artefact, grading it once per family as above.

### (b) The 6 GB arithmetic (labelled arithmetic, priced against `memory/kv-cache-design.md` §7.2)

The corpus's worked case: Llama-3.1-8B-class, Q4_K_M weights ≈ 4.9 GiB, on the 6 GB RTX 2060 — budget after weights and reserve: **614 MiB for KV**, f16 `kv_rate` 131,072 B/token → **4,912 tokens** at full f16 KV; the dossier's shipped decision is q8_0 KV at 8,192 tokens.

Apply DuoAttention's GQA operating point (50% retrieval heads — the ratio the paper itself uses for Llama-3-8B) to that same budget, as pure arithmetic, not as a paper result:

- Retrieval half of the KV heads grows as before: ½ × 131,072 = 65,536 B per token.
- Streaming half costs a constant: at the paper's long-context deployment window (64 sinks + 256 recent = 320 tokens), 320 × 65,536 B ≈ **20 MiB, fixed**, independent of context length.
- Context that fits: (614 − 20) MiB ÷ 65,536 B/token ≈ **9,500 tokens at f16 KV precision** — versus 4,912 unmodified. DuoAttention roughly **doubles** resident context at *full* cache precision, i.e. it reaches past the dossier's 8K minimum *without* spending the q8_0 precision step, or — composed with q8_0 (×0.53125 bytes) — ≈ **17,900 tokens**, past the 16K desired target at the precision tier the dossier already accepts.
- Equivalently, read through the paper's own reported GQA figure (1.67× memory reduction at long context): the same ~1.7–2× band, not the MHA 2.55× — the 8B is a GQA model and the honest multiplier is the GQA one.

Caveats that keep this arithmetic honest: it assumes the Llama-3.1-8B mask behaves like the paper's Llama-3-8B mask (same 50% ratio — plausible, underived, see §6a grading); decode *speed* on the 2060 does not inherit the A100's 1.50× — at ~9.5K tokens the cache is still a minority of per-token traffic next to 4.9 GiB of weights (kv-cache-design §7.2's roofline note), so the local win is **fit**, not speed. But fit is the binding constraint on this card: halving KV is, at the margin this dossier prices, the difference between a conversation that fits at honest precision and one that silently truncates.

## 7. Cross-links

- `papers/streamingllm.md` — the uniform sink+window policy DuoAttention makes head-selective (§5).
- `papers/snapkv.md` — the per-prompt dynamic mirror image: token selection vs head policy (§5).
- `papers/layerskip.md`, `papers/skipdecode.md` — wave 24's depth axis; DuoAttention is the width/cache axis of the same conditional-compute family, and the retrofittability contrast (§6a) is drawn against LayerSkip's trained-in recipe.
- `memory/kv-cache-design.md` — §7.2's 6 GB worked case is the budget priced in §6b; its sink+scored+window eviction (§7.1 Step 6) is the incumbent local policy a head-policy would refine per head rather than replace.
- `synthesis/IDEA-LEDGER.md` — **checked for head-policy entries on 2026-11-15: none found.** The ledger contains no DuoAttention entry and no per-head cache-policy entry (its KV entries concern selection, precision, tiering and state-movability). Recorded as an honest absence: this dossier is the corpus's first head-policy artefact, and whether it earns a ledger entry is the coordinator's call, not assumed here.

## 8. Sources

- Date accessed: **2026-11-15**
- arXiv abstract record: https://arxiv.org/abs/2410.10819
- arXiv HTML full text (read for method, settings, and results): https://arxiv.org/html/2410.10819v1
- ICLR 2025 proceedings PDF (venue confirmation): https://proceedings.iclr.cc/paper_files/paper/2025/file/5c1ddd2e59df46fd2aa85c833b1b36ed-Paper-Conference.pdf
