# Min-p Sampling — Turning Up the Heat: Min-p Sampling for Creative and Coherent LLM Outputs

## 1. Full citation

- **Title (as verified on the arXiv record, current version):** Turning Up the Heat: Min-p Sampling for Creative and Coherent LLM Outputs
- **Authors:** Minh Nhat Nguyen, Andrew Baker, Clement Neo, Allen Roush, Andreas Kirsch, Ravid Shwartz-Ziv
- **Venue / year:** International Conference on Learning Representations (ICLR 2025) — **oral presentation**. The arXiv record's journal reference reads: *In Proceedings of the 2025 International Conference on Learning Representations (ICLR), 2025.* Camera-ready at https://iclr.cc/virtual/2025/poster/30358
- **arXiv:** arXiv:2407.01082 [cs.CL] — https://arxiv.org/abs/2407.01082 — submitted 1 July 2024 (v1); last revised 20 November 2025 (v8) at the time of reading.
- **Code (as reported in the paper):** https://github.com/menhguin/minp_paper
- **Citation notes (record vs. common citation):** Three discrepancies a careful reader must know. (1) The brief for this dossier gave the title as *"Min-p Sampling for Creative and Coherent LLM Outputs"* — that is not the paper's title in any version. The v1 title (July 2024) was *"Min P Sampling: Balancing Creativity and Coherence at High Temperature"*; from v2 onward, and in the ICLR 2025 proceedings, the title is *"Turning Up the Heat: …"*. This dossier follows the record. (2) The author list grew between versions: v1 lists four authors (Minh Nguyen, Andrew Baker, Andreas Kirsch, Clement Neo); the current record lists six, adding Allen Roush and Ravid Shwartz-Ziv, and spells the first author "Minh Nhat Nguyen". (3) arXiv:2407.01082 is sometimes confused with unrelated token-sparsity work; the identifier belongs to this paper alone — the record above is the one verified at source on 2026-11-15.

## 2. The problem as framed

Sampling decides what a language model actually says, and the paper's framing is that the incumbent truncation methods carry a structural defect: **their thresholds are fixed in a currency that does not track the model's per-step confidence.**

- **Top-p (nucleus) sampling** keeps the smallest set of tokens whose cumulative probability reaches a fixed $p$ (the paper's comparisons use $p = 0.9$ / $0.95$). The defect appears at temperature. Raising temperature flattens the distribution; a fixed cumulative-mass rule then admits a long tail of individually implausible tokens, because the mass budget is spent the same way whether the model is certain or guessing. The result, in the paper's words, is that top-p "often struggle[s] to balance quality and diversity, especially at higher temperatures, leading to incoherent or repetitive outputs."
- **Top-k** has the mirror defect: a fixed *count* of candidates, blind to whether the distribution is a spike (where $k$ candidates include junk) or nearly flat (where $k$ candidates exclude most of the plausible mass).
- The paper's two case studies (§4 of the paper) make the failure concrete. In a **high-certainty** step — "…refraction, reflection, and dispersion of ___", where *light* holds 98.3% at $\tau=1$ — temperature $\tau=3$ flattens *light* to 34.4%, and top-p's renormalised pool still gives the correct token only 38.2%, leaving real probability on *water*, *sunshine*, *a*, *moisture*. In a **low-certainty** creative step ("The battle that ensued ___"), the opposite is wanted: many continuations are legitimately plausible and the pool should stay wide. No fixed threshold can be right in both steps, because the two steps differ in the one quantity the thresholds ignore — the probability of the top token itself.

The paper's claim is therefore not "a better constant" but a change of variable: **the truncation threshold should be denominated relative to the model's own confidence at that step.**

## 3. Core mechanism in our own words

Min-p is a one-line rule. Let $p_{\max}$ be the probability of the most likely next token (after temperature scaling, in the reference implementations), and let $p_{\text{base}} \in (0,1]$ be the single user parameter. Then:

$$p_{\text{scaled}} = p_{\text{base}} \times p_{\max}$$

and the sampling pool is every token whose probability is at least $p_{\text{scaled}}$, renormalised:

$$\mathcal{V}_{\text{min}} = \{v : P(v \mid x_{<t}) \ge p_{\text{scaled}}\}$$

That is the whole algorithm — no auxiliary model, no entropy estimate, no state carried between steps. Its behaviour follows directly from the multiplication:

- **Confident step** ($p_{\max}$ near 1): the floor is high in absolute terms. With $p_{\text{base}} = 0.1$ and $p_{\max} = 0.983$, only tokens above 9.83% survive — in the paper's Case Study 2, *light* and *sunlight* alone, renormalised to 80.9% / 19.1%. The sampler becomes nearly greedy exactly when the model knows the answer, *even at $\tau = 3$*.
- **Uncertain step** ($p_{\max}$ small): the floor falls proportionally. With $p_{\max} = 0.1$ and $p_{\text{base}} = 0.1$, the floor is 1% — a wide, diverse pool. The sampler opens up exactly when the model is genuinely torn between continuations.
- **Temperature robustness is a corollary, not a patch.** Temperature flattens all probabilities, $p_{\max}$ included; because the floor is a *ratio* to $p_{\max}$, flattening shrinks the floor with the peak instead of letting a fixed mass budget leak into the tail. This is why the method's advantage in the paper's tables grows with temperature (§4 below).

Parameter guidance as published: $p_{\text{base}}$ of **0.05–0.1** "effectively balances creativity and coherence across tasks and models"; much higher values (0.5–0.7, even toward 1) can buy benchmark coherence at very high temperatures at the cost of diversity. The paper also explicitly recommends min-p as the **primary** truncation method rather than one filter stacked among several: its combined-sampler experiments found "double normalization issues and suboptimal performance" when truncation methods are layered, because each method's hyperparameters were tuned standalone. That sentence matters for §6 — it is the paper itself warning against naive sampler chaining.

Provenance note from the paper's contribution statement: Andrew Baker conceived the original idea and "tested and shared it with hobbyists within the open-source LLM community, leading to its rapid and widespread external adoption" — min-p was a community sampler before it was a paper, which explains the adoption pattern in §5.

## 4. Reported results — as reported, with context

All numbers below are the paper's own (v8 / ICLR 2025 camera-ready text, read 2026-11-15), in the paper's frame. Main configuration: Mistral 7B, min-p at $p_{\text{base}} = 0.05$ / $0.1$ vs. top-p at $p = 0.9$; temperatures 0.7–3.0 in the main tables.

**GPQA Main (5-shot) and GSM8K CoT (8-shot), accuracy %, Mistral 7B (paper Table 2):**

| Method | GPQA τ=0.7 | τ=1.0 | τ=1.5 | τ=2.0 | τ=3.0 | GSM8K τ=0.7 | τ=1.0 | τ=1.5 | τ=2.0 | τ=3.0 |
|---|---|---|---|---|---|---|---|---|---|---|
| Temperature only | 27.23 | 22.77 | 25.22 | 5.80 | 0.89 | 29.56 | 17.51 | 0.00 | 0.00 | 0.00 |
| Top-p | 29.02 | 25.00 | 24.78 | 6.47 | 0.46 | 36.09 | 27.67 | 0.68 | 0.00 | 0.00 |
| Min-p | 29.18 | 25.89 | 28.13 | 26.34 | 24.55 | 35.18 | 30.86 | 18.42 | 6.21 | 0.00 |

Read honestly, the table says: at ordinary temperatures the methods are close (on GSM8K at τ=0.7 top-p is nominally ahead, 36.09 vs. 35.18 — within the paper's stated ±1–1.5% standard error); the claimed effect is a **collapse-resistance** effect. Top-p and temperature-only fall off a cliff between τ=1.5 and τ=2.0; min-p degrades gracefully (GPQA 28.13 → 26.34 → 24.55). The paper also notes $\eta$- and $\epsilon$-sampling "showed exponential runtime increases with temperature and failed completely at τ > 1.5" in its setup, while min-p's cost is a comparison per token.

**Scale check (paper Table 3a):** on Mistral Large (123B), GPQA at τ=3.0: min-p 22.77% vs. top-p$_{0.95}$ 2.01% and temperature-only 2.90%; at τ=4.0 min-p still holds 13.84% vs. ≤0.89% for both baselines. The paper reports the same direction across Llama 3 models from 1B to 70B (appendix).

**Creative writing (paper Table 3b):** AlpacaEval Creative Writing win rate vs. a fixed baseline, openchat-3.5-0106 generations judged by GPT-4 Turbo: min-p **52.01%** at τ=1.0 and **56.54%** at τ=1.5, vs. top-p 50.43% (τ=1.0), temperature-only 49.97 / 53.18, $\epsilon$-sampling 43.50 / 45.51, and mirostat 16.69 / 14.23 (see the companion dossier, `papers/mirostat.md` — mirostat's poor showing here is a GPT-2-era controller meeting a modern chat model, not a refutation of its own paper's claims in its own setting). An independent EQ-Bench Creative Writing figure is cited: min-p at τ=1.5, $p_{\text{base}}=0.1$ scoring 62 vs. a 51.5 baseline at τ=1.0.

**Human evaluation (paper §6, Table 4):** Llama 3 70B stories ("Write me a creative story?"), Prolific participants, 54 valid responses after attention checks (of 70), each configuration's 3 samples rated 1–10 for quality and diversity. In the higher-diversity settings min-p leads top-p at every temperature on both axes — e.g. at τ=3: quality 7.57 vs. 7.11, diversity 7.66 vs. 7.49; at τ=1: quality 8.02 vs. 7.67, diversity 7.74 vs. 7.04. The paper itself flags the design's limits: diversity is a point estimate from one triplet per configuration, and the sample is small.

**Accuracy–diversity trade-off:** on GSM8K CoT with self-consistency, sweeping 20 hyperparameter combinations per method, the paper reports min-p configurations lying closer to the accuracy–diversity Pareto frontier than top-p's, with a wider spread — i.e. min-p's knob actually moves the operating point, where top-p's settings cluster.

**Contested status — required reading.** A 2025 re-examination, *"Turning Down the Heat: A Critical Analysis of Min-p Sampling in Language Models"* (arXiv:2506.13681), re-analysed all four of the paper's evidence lines and disputes them: it reports that the human evaluation omitted data and applied statistical tests incorrectly (its reanalysis finds no min-p advantage in quality, diversity, or their trade-off), that benchmark sweeps controlling for hyperparameter count erase the advantage, and that the original community-adoption figures (49k repositories / 1.1M stars) were unsubstantiated and were removed from the camera-ready. The current arXiv text's adoption claim is the revised, weaker form (framework integrations; "over 667,000 GitHub stars" across the integrating frameworks collectively). **Corpus position:** the mechanism (§3) is sound and trivially verifiable; the *magnitude* of the empirical superiority is contested in print. Any engineering decision below rests on the mechanism and on observed practice (§5), not on the disputed effect sizes.

## 5. What it changed in practice

- **It became a standard sampler, fast.** The paper records adoption as a logits processor / sampling parameter in Hugging Face Transformers, vLLM and SGLang; in the local-runner world it is present in llama.cpp (as the `min_p` sampler in the chain, CLI `--min-p`, server default 0.05) and exposed by Ollama as the `min_p` option. In llama.cpp's documented default chain — `penalties;dry;top_n_sigma;top_k;typ_p;top_p;min_p;xtc;temperature` — min-p sits **late, after the other truncation filters and immediately before XTC and temperature**, i.e. it acts as the last confidence-relative gate on an already-shaped candidate set, and temperature scales what survives it.
- **It displaced top-p as the persona-chat default recommendation.** In the KoboldCpp-centred fiction ecosystem documented by this corpus (`runners/koboldcpp.md` §4.1), min-p appears in the canonical sampler list as "removes tokens under a probability floor relative to the top token; 0 disables", and community presets for creative/persona work routinely run min-p as the sole truncation sampler — which is, not coincidentally, exactly the usage the paper recommends (§3 above). The practical pairing that emerged is **min-p + moderately high temperature** (1.0–1.5) for creative chat: the regime the paper's tables say top-p cannot survive.
- **It changed the default question.** Before min-p, tuning meant choosing a mass budget (top-p) or a count (top-k). After it, the first question in sampler guides is which *confidence-relative* floor to use, with top-p demoted to an optional second filter. Ollama's own surface tells the adoption story in miniature: `min_p` exists as an option but defaults to **0.0 (disabled)** in Ollama, against llama.cpp's enabled-by-default 0.05 — the method is available everywhere and *on* by default only in some stacks, a gap §6 addresses.

## 6. Applicability

### (a) Ollama build — IDEA-LEDGER #37, the sampler pipeline

*Recommendations in this subsection are engineering judgment, argued from the paper and the corpus's canon dossier (`runners/koboldcpp.md` §§4, 9.2) and marked as such.*

- **Ship min-p as the primary truncation sampler, enabled by default.** The mechanism costs one max-reduction and one comparison per candidate — negligible beside a forward pass — and it is the only truncation rule in the stack whose strictness tracks per-step confidence. Concretely (judgment): persona-chat preset `min_p = 0.05–0.1`, `top_p = 1.0` (off), `top_k = 0` (off); general/factual preset `min_p = 0.05` with temperature ≤ 0.8. Do **not** inherit Ollama's `min_p = 0.0` default: an off-by-default confidence floor means the flagship failure mode (high-temperature tail leakage) is unguarded for every user who never opens the options panel.
- **Order: penalties → DRY → truncation (min-p last among truncators) → XTC → temperature last.** This follows the llama.cpp chain documented in §5 and the KoboldCpp dossier's temperature-last rationale (`runners/koboldcpp.md` §4.2): penalty and anti-repetition stages shape the candidate set first, min-p applies the confidence-relative floor to what remains, XTC may then remove a surviving top choice, and temperature scales the final pool — flattening *before* the filters would change what the filters see and silently retune every threshold. The paper's double-normalisation warning (§3) is the counterweight: the chain must renormalise **once**, at the end, and preset validation should reject stacks of multiple aggressive truncators rather than letting users layer top-k + top-p + min-p + typical-p at full strength.
- **Expose it per request, with the preset, not as server config.** Per #37 and the KoboldCpp canon, sampler settings are part of a character/story artefact. `p_base` belongs in the preset file beside temperature, and the API should echo the *effective* sampler chain (order + values) in the response metadata, so a bad generation is debuggable from the artefact that produced it.
- **Conformance tests (from #37's Aphrodite-derived habit):** fixed seed, fixed prompt, recorded output distributions per sampler change. Min-p has a razor-sharp unit test available from the paper itself: reproduce Case Study 2 — at τ=3, the pool after min-p ($p_{\text{base}}=0.1$) on the rainbow prompt must contain *light* and *sunlight* only. If a Go implementation fails that, the threshold is being computed pre-temperature or against the wrong normalisation.

### (b) Project Aesir

At the level of the corpus's Aesir material (`aesir/aesir-ideas-for-ollama.md`) and the programme's sampling-parity slice **QS-4** as referenced in the commission: min-p is the cheapest parity item in the sampler set and should be graded as such. It is a pure function of the step's probability vector — no state, no history, no kernel fusion required — so an Aesir implementation can be verified token-for-token against a reference (llama.cpp-class) implementation on recorded distributions: same $p_{\max}$, same floor, same surviving set, at several temperatures including τ=3. The parity risk is not the rule but its *placement*: whether the floor is applied to pre- or post-temperature probabilities changes the surviving set at high temperature, so QS-4's test vectors must pin the placement explicitly (post-temperature, matching the reference implementations the paper cites) rather than letting two "correct" min-p implementations diverge silently. Unlike mirostat (companion dossier), min-p carries no cross-step state, so it composes cleanly with Aesir's resident-session and prefix-memory designs: a session can change $p_{\text{base}}$ mid-conversation without invalidating any cached state.

## 7. Cross-links

- **KoboldCpp dossier** (`runners/koboldcpp.md`) — §4.1 for min-p's place in the persona-chat canon (probability floor relative to the top token; 0 disables); §4.2 for sampler order as a first-class, user-visible setting and the temperature-last rationale; §9.2 for the idea as adopted into this programme. This dossier supplies the published-methods layer underneath that product-level description.
- **IDEA-LEDGER #37** (`synthesis/IDEA-LEDGER.md`, rank 15) — "Sampler pipeline as a first-class, ordered, per-request surface", sourced from the KoboldCpp and Aphrodite dossiers. Min-p is #37's best-evidenced member: the only truncator in the stack with a peer-reviewed mechanism paper and a one-line reference rule to test against.
- **Ollama dossier** (`runners/ollama.md`) — for the as-banked sampler surface: `min_p` present among the `PARAMETER`/options set alongside `temperature` (default 0.8), `top_k` (40) and `top_p` (0.9), with no order exposure and (per §5 above) a disabled-by-default posture that #37 exists to supersede.
- **Mirostat dossier** (`papers/mirostat.md`, this wave) — the other paper-backed member of the canon; the two are alternatives in spirit (stateless confidence floor vs. stateful perplexity controller) and the Min-p paper's own creative-writing table benchmarks against mirostat.

## 8. Sources

- Date accessed: **2026-11-15** (all sources).
- arXiv abstract record (title, authors, ICLR 2025 journal reference, v1–v8 history): https://arxiv.org/abs/2407.01082
- arXiv HTML, v8 (full text — mechanism §3, case studies §4, Tables 2–4, human evaluation §6, parameter guidelines, combined-sampler warning): https://arxiv.org/html/2407.01082v8
- ICLR 2025 camera-ready (oral presentation record): https://iclr.cc/virtual/2025/poster/30358
- Critical re-examination: *Turning Down the Heat: A Critical Analysis of Min-p Sampling in Language Models*, arXiv:2506.13681 — https://arxiv.org/html/2506.13681v1
- llama.cpp server documentation (default sampler chain `penalties;dry;top_n_sigma;top_k;typ_p;top_p;min_p;xtc;temperature`; `--min-p` default 0.05): https://raw.githubusercontent.com/ggml-org/llama.cpp/master/tools/server/README.md
- Corpus-internal sources: `runners/koboldcpp.md`, `runners/ollama.md`, `synthesis/IDEA-LEDGER.md` (this corpus).
