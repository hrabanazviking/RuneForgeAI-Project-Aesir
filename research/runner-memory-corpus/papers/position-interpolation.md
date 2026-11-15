# Position Interpolation — Extending Context Window of Large Language Models via Positional Interpolation

## 1. Full citation

- **Title:** Extending Context Window of Large Language Models via Positional Interpolation
- **Authors:** Shouyuan Chen, Sherman Wong, Liangjian Chen, Yuandong Tian
- **Affiliation (as listed in the paper):** Meta Platforms Inc.
- **Venue / year:** arXiv preprint, 2023. v1 submitted 27 June 2023; v2 28 June 2023 (the version whose HTML text was read in full for this dossier).
- **arXiv:** arXiv:2306.15595 [cs.CL] — https://arxiv.org/abs/2306.15595 — DOI: 10.48550/arXiv.2306.15595
- **Identifier check (verified 2026-11-15):** the coordinator's identifier checks out exactly — title, four Meta authors, and arXiv:2306.15595 are all confirmed at the arXiv record and in the paper's own HTML text.
- **Concurrent community work, as the paper itself records it:** the paper's introduction notes a concurrent blog post — kaiokendev's "SuperHOT" work (2023) — that also interpolated RoPE position encodings to extend context from 2K to 8K, picked up in a Reddit post and in llama.cpp discussion. PI is therefore the first *paper* recipe in this family, not a claim that no one else had the interpolation idea in the same weeks. That honesty matters for §5: this lineage was paper-and-community from its first step.

## 2. The problem as framed

A pre-trained RoPE model knows only the positions it was trained on — 2,048 tokens for the original LLaMA family the paper works on. The paper frames the failure past that length not as gradual forgetting but as a stability catastrophe:

- **Direct extrapolation collapses.** Let position indices run past the trained maximum and, in the paper's words, extrapolation "may lead to catastrophically high attention scores that completely ruin the self-attention mechanism." Empirically the unextended model scores perplexity `>10^3` — untrained-model territory — at every evaluation length beyond 2,048 (Table 1, §4). The paper's theoretical section (§3 below) argues this is structural: the trigonometric basis that fits attention scores well *inside* [0, L] is a universal approximator, so coefficient sets that are tame inside the interval can produce values orders of magnitude larger outside it; the paper's fitted-curve illustration stays within roughly [−1, 1] inside the window and exceeds 8,000 outside it.
- **Direct fine-tuning at the longer length barely works.** The obvious alternative — just fine-tune on longer sequences with unmodified positions — adapts, in the paper's measurement, "very slowly": after more than 10,000 batches the *effective* context window (passkey test, §4) had moved only from 2,048 to 2,560. A recipe that needs pre-training-scale effort to buy 512 tokens is not an extension method.
- **Existing extrapolation-friendly encodings do not transfer.** ALiBi- and LeX-class methods extrapolate by design, but the installed base — LLaMA and its kin — was already trained with RoPE, whose extrapolation properties are weak. The practical question the paper sets itself is therefore narrow and consequential: *extend an existing RoPE checkpoint, reusing its architecture and infrastructure, at a cost negligible next to pre-training.*

The tension the whole family inherits is already visible here, though the paper states only its first half: staying inside the trained angle range buys stability, but the way PI stays inside it — compressing every dimension uniformly — spends positional resolution. That second half is what NTK-aware scaling answers (`papers/ntk-aware-scaling.md`).

## 3. Core mechanism in our own words

### 3.1 The one-line recipe

RoPE rotates each query/key dimension pair *j* by an angle *m·θ_j*, where *m* is the token's position index and *θ_j = 10000^(−2j/d)*. Position Interpolation changes nothing about the model, the angles' frequencies, or the attention code. It changes only the index fed in:

```
f′(x, m)  =  f(x, m · L / L′)  =  f(x, m / s),     s = L′ / L
```

where *L* is the trained length and *L′* the target length. A sequence of *L′* tokens is squeezed into position indices [0, *L*): neighbouring tokens now sit *1/s* apart in position space instead of 1 apart, at non-integer positions the smooth RoPE functions were never explicitly trained on but interpolate between trained neighbours. In YaRN's later *g(m), h(θ)* notation this is *g(m) = m/s, h(θ_d) = θ_d* — positions scaled, frequencies untouched. Every later method in the family is a modification of exactly this choice (§5).

### 3.2 Why interpolation is stable where extrapolation is not — the paper's argument

The paper's Theorem 2.1 bounds how far an interpolated attention score can stray from the linear interpolation of its two neighbouring *trained* (integer-grid) scores. Because trained scores are well-behaved by construction, and the interpolation error term carries a factor *(s−s₁)(s₂−s) ≤ 1/4* divided by *ln c* (with *c = 10000* the RoPE base), the resulting bound is small. The corresponding extrapolation bound, built from the RoPE paper's own estimate, is numerically **at least ~600× larger** in the LLaMA-7B setting — the abstract's headline theoretical claim. In plain terms: between two known-good points, a smooth curve cannot wander far; beyond the last known point, nothing constrains it. PI is the decision to always stay between known-good points.

### 3.3 Why a short fine-tune suffices — as argued

Interpolation alone already leaves the model functional (§4: perplexity <20 at 8K with *zero* fine-tuning steps, against `>10^3` for extrapolation). What remains for fine-tuning to teach is modest: to treat fractional spacings as real distances and to use evidence spread over the wider window. The paper's stated reasoning is that the model is "only adapting to the new context window during the fine-tuning phase, starting from a good initialization, as opposed to acquiring new knowledge" — supported by two observations it reports: results are **not sensitive to the choice of fine-tuning examples** (Pile vs RedPajama give near-identical benchmark outcomes, §4), and adaptation is essentially complete within **200–1,000 steps** (passkey-effective window reaches its target by 200 steps; perplexity keeps improving gently to 1,000). The recipe as run: full fine-tuning with the next-token objective on the Pile, AdamW, learning rate 2×10⁻⁵ (7B/13B) or 10⁻⁵ (33B/65B), 1,000 steps for PI against 10,000 for the direct-fine-tuning baseline, no architecture changes, existing optimisation and infrastructure reused — a point the paper makes explicitly and which is why the recipe spread so fast.

### 3.4 The cost PI knowingly pays

Uniform compression is not free, and the paper reports the price rather than hiding it: perplexity *inside* the original 2,048 window degrades slightly (e.g. +0.01 to +0.05 on Proof-pile across extended models), and short-context benchmark scores fall as *s* grows (§4). The mechanism is the one NTK-aware later names precisely: squeezing all dimensions equally moves adjacent tokens *s×* closer in the high-frequency dimensions that encode fine local order, so local resolution is the currency spent to buy global range. PI spends it uniformly because, in June 2023, uniform was the recipe that worked and could be proved stable.

## 4. Reported results — as reported

All figures are the paper's own (Tables 1–6), on LLaMA 7B/13B/33B/65B extended from *L* = 2,048. Perplexity is sliding-window (stride 256) on PG19 and on the Arxiv Math Proof-pile test sets.

- **Extension range.** PI extends every model size tested to 8,192 and 16,384, and 7B/13B to **32,768 — 16× the trained length** — within the standard 1,000-step fine-tune. The paper's summary claim is extension "up to 32 times of the original size" as a method capability; the largest *demonstrated* ratio in its tables is 16× (2,048 → 32,768). Citers should keep those two apart.
- **Long-sequence perplexity improves with length under PI, and degrades under direct fine-tuning (PG19, Table 1).** LLaMA-7B PI→32,768: **7.23 @ 2k, 7.04 @ 4k, 6.91 @ 8k, 6.80 @ 16k, 6.77 @ 32k** — against the unextended model's 7.20 @ 2k and `>10^3` beyond it, and against direct fine-tuning to 8,192, whose perplexity *rises* with evaluation length (7.21 → 7.69). LLaMA-13B PI→32,768 reaches **6.09 @ 32k**; 33B PI→16,384 reaches 5.67–5.68 at 8k–16k. On Proof-pile (Table 2) the same pattern holds at lower absolute values (7B PI→16,384: 2.25 @ 16k), with one honest wrinkle the paper's tables show: at the extreme 32,768 evaluation point Proof-pile perplexity ticks *up* (7B: 2.48; 13B: 2.35) even as PG19 keeps improving — the edge of the extension is visible in the paper's own numbers.
- **Adaptation speed (Table 3, PG19, LLaMA-7B).** Zero steps: 16.10 (→8k) / 112.13 (→16k) — degraded but functional, versus `>10^3` extrapolated. By **200 steps: 7.12 / 7.05**, already better than the original model's 2k perplexity; by 1,000 steps: 6.95 / 6.83.
- **Effective window by passkey retrieval (Table 4).** PI models reach their *full target* effective window — *k_max* = 8,192 / 16,384 / 32,768 as targeted — **after 200 fine-tuning steps**, for both 7B and 33B. The direct-fine-tuning baseline reaches only 2,560 after 10,000 steps. This is the paper's "effective context" evidence, and its limits should be noted with it: passkey retrieval is a single-fact probe with a ≥20% success criterion over 10 attempts per distance — a lenient, single-needle standard by the measure RULER later applies (`papers/ruler.md`).
- **Original-window benchmarks (Table 5, zero-shot subset).** Degradation grows with *s*. LLaMA-7B extended to 8,192 (Pile): BoolQ 76.1 → 73.2, PIQA 78.9 → 78.2, WinoGrande 69.6 → 69.0 ("up to 2%" in the paper's summary). Extended to 32,768 the cost is no longer minor: BoolQ **64.7**, Race-M 55.7 → 50.1, WinoGrande 66.9. The paper flags BoolQ — short-paragraph word-order sensitivity — as the most affected, which is consistent with the local-resolution cost in §3.4.
- **Long-document summarisation (GovReport, Table 6).** LLaMA-7B PI-extended to 16,384, fine-tuned for the task: ROUGE-1/2/L **60.0 / 28.0 / 29.5**, between CoLT5-Base (58.7 / 29.6 / 31.4) and CoLT5-XL (61.3 / 32.2 / 33.8) — "competitive" in the paper's word, with minimal hyper-parameter tuning.
- **What the paper does not show:** no evaluation beyond 32,768; no multi-needle, aggregation, or variable-tracking long-context suite (such suites did not yet exist in standard form); no non-LLaMA architecture; and no test of PI *without* fine-tuning as a deployment mode — the zero-step numbers are an adaptation-speed diagnostic, not a recommendation. Later work found the failure mode this leaves open: perplexity and single-needle success can survive well past the length where harder retrieval has already degraded (`papers/ruler.md`, `papers/yarn.md` §4).

## 5. Position in the family

The chain, one line per step — what changed:

- **RoPE (Su et al., 2021/2022, arXiv:2104.09864 — cited throughout this corpus as the base encoding; see `papers/yarn.md` §1–§3):** position becomes per-dimension-pair rotation angles *m·θ_d*; relative distance is all attention sees; nothing past the trained *L* is defined behaviour.
- **Position Interpolation (this dossier, June 2023):** *uniform* interpolation — every position index divided by *s*, frequencies untouched; stability proved (~600× bound) and a ≤1,000-step fine-tune makes 16× extension real. The first scaling recipe.
- **NTK-aware scaling (bloc97, June 2023; `papers/ntk-aware-scaling.md`):** *dimension-aware* interpolation — leave positions alone, change the RoPE base so high frequencies are compressed barely at all and low frequencies nearly fully; PI's uniform spend of local resolution is refused.
- **NTK-by-parts / Dynamic NTK (bloc97 / emozilla, 2023; formalised in YaRN):** by-parts makes the dimension-aware idea *piecewise by wavelength* (interpolate / ramp / leave, by how a dimension behaves over the window); Dynamic NTK makes the scale *follow the current sequence length* instead of a fixed target, for no-fine-tune use.
- **YaRN (Peng et al., 2023, arXiv:2309.00071; `papers/yarn.md`):** NTK-by-parts *plus* an attention temperature correction (logit scale √(1/t) = 0.1·ln(s) + 1) — the ramp decides *which* dimensions move, the temperature repairs what stretching does to attention entropy.
- **LongRoPE (Ding et al., 2024, arXiv:2402.13753; `papers/longrope.md`):** *searched* factors — the hand-designed per-dimension rule is replaced by evolutionary search over per-dimension rescaling factors, plus a progressive fine-tune, taking the same family past 2M tokens.

Wave 7 of this corpus banked the two descendants (YaRN, LongRoPE); this dossier and its companion are the roots they cite. Every step after PI keeps PI's founding decision — *stay inside, or near, the trained angle range rather than extrapolating blindly* — and disputes only how the staying-inside should be distributed across dimensions.

## 6. Applicability

### (a) The runner angle — thin, stated thinly

A runner does not choose PI. The scaling was chosen when the checkpoint was extended and fine-tuned, and it reaches the runner as part of the model's contract: in modern stacks as a `rope_scaling` block (type `linear` is PI's direct descendant in HF/vLLM config vocabulary — a position-scaling factor with an original length) or as GGUF metadata carrying the scaling type, factor, and original context length. The runner's whole job is to **detect and honour** it exactly:

- Apply the factor the config declares, to the positions, with the original length the config declares. A runner that ignores a `linear` scaling block serves the model at positions it was fine-tuned never to see raw — long context degrades silently while short context, where the error is proportionally small, looks fine.
- Conversely, applying PI-style scaling to a checkpoint that was *not* extended with it (a common user override) manufactures the §3.4 cost — compressed local resolution — with none of the fine-tune that was supposed to compensate. The paper is unambiguous that PI is a fine-tune recipe, not a free inference switch; its zero-step numbers (§4) are a stability demonstration, not a quality claim.
- This is the same detect-and-honour class the corpus records for Native Sparse Attention and LayerSkip (`papers/native-sparse-attention.md`, `papers/layerskip.md`): an architectural fact baked into the checkpoint that a runner cannot invent, improve, or safely approximate — only read correctly or get wrong quietly. PI's version is the oldest and simplest member of the class, which is why it is the right teaching example: one factor, one original length, and a model that will not tell you if you dropped either.

### (b) The usable-number connection (wave 21)

The corpus's context vocabulary distinguishes the *trained* number (*L*), the *scaled* number (*L′ = s·L*), and the *allocated* number (what a runner actually reserves; `memory/kv-cache-design.md`). **PI is the machine that first manufactured the scaled number as a product claim.** Before June 2023 a model's context was what it was trained with; after PI, "32K LLaMA" could be produced from a 2K checkpoint with 1,000 fine-tuning steps — legitimately, per the paper's evidence, but by a recipe whose cost and whose quality-at-length are properties of the *extension*, not the base model. Everything wave 21's pricing work does follows from that split: RULER (`papers/ruler.md`) exists to measure what a scaled number is actually worth at each length, because the scaled number alone — PI's, YaRN's, or anyone's — certifies only that positions were remapped and a fine-tune was run. When this corpus cites a context length for any post-2023 open model, the PI question is the first one to ask: *trained, or scaled — and if scaled, by what recipe, with what fine-tune, priced by which benchmark?*

## 7. Cross-links

- **YaRN dossier** (`papers/yarn.md`) — the direct descendant: §3.1 there is NTK-by-parts, the disciplined successor to both PI and NTK-aware; §2 there frames PI as the baseline whose uniform compression YaRN set out to repair, and §5 traces the `rope_scaling` config ecosystem PI's recipe ultimately produced.
- **LongRoPE dossier** (`papers/longrope.md`) — the searched-factor end of the chain in §5; its motivating tables price hand-designed rules (PI included) against searched factors at 8k–64k without fine-tuning.
- **NTK-aware scaling dossier** (`papers/ntk-aware-scaling.md`) — the sibling root, written the same month: the dimension-aware objection to this paper's uniform rule.
- **RULER dossier** (`papers/ruler.md`) — the pricing instrument for the scaled number this paper invented (§6b); RULER's critique of single-needle evidence applies retroactively to this paper's passkey table.
- **KV-cache design** (`memory/kv-cache-design.md`) — the allocated number: PI changes which positions are *legitimate*, not what a token of cache costs; a PI-extended 32K window bills exactly like a trained 32K window.
- **Native Sparse Attention dossier** (`papers/native-sparse-attention.md`) — fellow member of the detect-and-honour class (§6a): checkpoint-baked structure a runner must read, not choose.

## 8. Sources

- Date accessed: **2026-11-15** (all sources).
- arXiv record (identifier, authors, dates, DOI verified): https://arxiv.org/abs/2306.15595
- arXiv HTML v2 (read in full for method, theory, and Tables 1–6): https://arxiv.org/html/2306.15595
- YaRN paper, arXiv HTML v3 (for the *g(m), h(θ)* restatement of PI and the family's own account of PI's place in it): https://arxiv.org/html/2309.00071v3
- EleutherAI blog, "Extending the RoPE" (community-side summary of the same lineage, PI section): https://blog.eleuther.ai/yarn/
- Corpus-internal sources: `papers/yarn.md`, `papers/longrope.md`, `papers/ntk-aware-scaling.md`, `papers/ruler.md`, `papers/native-sparse-attention.md`, `papers/layerskip.md`, `memory/kv-cache-design.md`.
