# Contrastive Decoding — Contrastive Decoding: Open-ended Text Generation as Optimization

*Ollama Research Forge, OR-3 Paper Sweep, Wave 23 (decoding for truth). Companion dossier: `papers/dola.md`. This wave covers the third decoding family — methods that reshape the distribution at decode time to suppress the model's own failure modes — after sampling (Wave 9) and constraint (Wave 18).*

## 1. Full citation (as verified)

- **Title (as verified on the arXiv record):** Contrastive Decoding: Open-ended Text Generation as Optimization
- **Authors:** Xiang Lisa Li, Ari Holtzman, Daniel Fried, Percy Liang, Jason Eisner, Tatsunori Hashimoto, Luke Zettlemoyer, Mike Lewis — Stanford University; University of Washington; Carnegie Mellon University; Johns Hopkins University; FAIR (Meta AI).
- **Venue / year:** Proceedings of the 61st Annual Meeting of the Association for Computational Linguistics (ACL 2023), Volume 1: Long Papers, pp. 12286–12312. The arXiv record's comments field reads: "Main conference long paper at ACL 2023."
- **arXiv:** arXiv:2210.15097 [cs.CL; also cs.AI, cs.LG] — https://arxiv.org/abs/2210.15097 — submitted 27 October 2022 (v1); last revised 10 July 2023 (v2). DOI: 10.48550/arXiv.2210.15097.
- **Code (as reported in the paper):** https://github.com/XiangLi1999/ContrastiveDecoding
- **Identifier check:** The coordinator's believed identifier **arXiv:2210.15097 is correct** — it resolves to exactly this paper, with exactly this title and author list, and the **ACL 2023** attribution checks out against both the arXiv comments field and the proceedings header (pp. 12286–12312) on the published PDF. No correction is required.
- **Scope note for §4:** This paper is an *open-ended generation* paper. It reports no TruthfulQA or reasoning-benchmark table of its own. The widely cited reasoning gains for contrastive decoding come from a separate follow-up — O'Brien & Lewis, *Contrastive Decoding Improves Reasoning in Large Language Models* (arXiv:2309.09117) — and are reported in §4 under that attribution, not as this paper's results.

## 2. The problem as framed

The paper opens on a dilemma in likelihood decoding for open-ended generation, and the dilemma is structural, not a tuning complaint:

- **Maximum probability is the wrong objective.** Searching for the most likely continuation (greedy / beam search on $\log p_{\text{exp}}$) produces text that is, in the abstract's words, "short and repetitive" — the model's most probable continuations are its most generic ones. Likelihood rewards the safe, frequent, already-said token.
- **Sampling escapes repetition by paying in coherence.** Drawing from the (possibly truncated) distribution can produce "incoherent text that drifts from the original topics," because unlucky draws compound over a long continuation.
- **The failure modes are shared across scale — and that sharing is the signal.** The paper's founding observation: the failures of a large model (repetition, incoherence, topic drift, self-contradiction) are *even more prevalent* in a small model of the same family. A small model is, in effect, a concentrated specimen of everything the large model does badly. If the bad behaviours are amplified in the small model and the good behaviours (including factual knowledge the small model never learned) are present only in the large one, then the *difference* between the two distributions separates the two: tokens the expert prefers *over* the amateur are disproportionately the expert's genuine competence; tokens both prefer are disproportionately generic.

The fix the paper argues for therefore lives entirely at decode time: no retraining, no fine-tuning, no external knowledge — two frozen models and a different objective to optimise while searching. Factual knowledge, on this framing, is already in the network; the standard decoding objective simply does not privilege it, because it does not privilege *anything* the expert knows that a much weaker model does not also find likely.

## 3. Core mechanism in our own words

Contrastive decoding (CD) is a **search** method (beam search, beam size 5 in the paper's main experiments), not a sampler. At each step it scores candidate tokens by a contrastive objective, restricted to a plausibility set.

**The contrastive objective.** For a continuation $\textsf{x}_{\text{cont}}$ given a prompt $\textsf{x}_{\text{pre}}$:

$$\mathcal{L}_{\text{CD}} = \log p_{\text{exp}}(\textsf{x}_{\text{cont}} \mid \textsf{x}_{\text{pre}}) - \log p_{\text{ama}}(\textsf{x}_{\text{cont}} \mid \textsf{x}_{\text{pre}})$$

Factored to the token level, the score of a candidate $x_i$ is $\log p_{\text{exp}}(x_i \mid x_{<i}) - \log p_{\text{ama}}(x_i \mid x_{<i})$ — the log-ratio of expert to amateur probability — if the token is in the plausibility set, and $-\infty$ otherwise. The paper's worked example makes the intent concrete: for a prompt about Barack Obama's birthplace, the expert spreads mass over a repetitive "Hawaii / Honolulu" continuation and a nonsensical "Washington," while the factually correct "1961" holds only probability 0.1 under the expert — yet "1961" is what CD selects, because the amateur assigns it far less still, so its log-ratio is the highest among plausible candidates. CD selects *plausible tokens that least resemble the amateur*.

**The adaptive plausibility constraint (the $\alpha$ mask).** The raw log-ratio alone is unsafe in both directions, and the paper names both failure modes:

- *False positives:* an implausible token can win the ratio outright. The paper's example: "NetMessage" at $p_{\text{exp}} = 3\times10^{-9}$, $p_{\text{ama}} = 8\times10^{-14}$ attains a contrast of 10.6 — higher than any plausible token — purely because both probabilities are in the unstable near-zero range.
- *False negatives:* an easy, correct token both models are sure of (the paper's example: "#orn" completing "unicorn," at $\approx$0.99 under both) scores a contrast of only $6\times10^{-4}$ and would lose to worse continuations.

The guard is the adaptive plausibility set:

$$\mathcal{V}_{\text{head}}(x_{<i}) = \{\, x_i \in \mathcal{V} : p_{\text{exp}}(x_i \mid x_{<i}) \ge \alpha \max_w p_{\text{exp}}(w \mid x_{<i}) \,\}$$

with **$\alpha = 0.1$ throughout the paper**, reported as robust across domains. The set is *adaptive* because it is denominated relative to the expert's own top probability at that step: when the expert is highly confident, the set can shrink to a single token, which neutralises the contrast exactly where the contrast has nothing to add (the false-negative case); when the expert is uncertain, the set stays wide and the contrast does the choosing. Note the family resemblance to min-p's confidence-relative floor (Wave 9, `papers/min-p-sampling.md`) — the same ratio-to-max construction, here used as a guard on a contrast rather than as a sampler in its own right. DoLa (§ companion dossier) reuses this exact constraint, with the same $\alpha$.

**What "amateur" choices were used.** Three design axes, all specified in the paper (§3.4, §5.3):

- *Scale:* the amateur is the **smallest model in the expert's own family**. Main pairings: OPT-13B expert with OPT-125M amateur; OPT-6.7B also evaluated; GPT-2 XL (1.5B) expert with GPT-2 small ($\approx$100M-class, as the paper states it) amateur. The paper reports (§7.1) that a *larger* scale gap gives *better* results — the optimal amateur is also the cheapest to run. An n-gram amateur was tried and hurt quality: too weak to share the expert's failure modes, so its contrast stops being informative.
- *Amateur temperature $\tau$:* the amateur's distribution can be sharpened ($\tau < 1$, emphasising its mode — where its errors concentrate) or flattened. Main settings: $\tau = 1.0$ for OPT experiments, $\tau = 0.5$ for GPT-2 experiments.
- *Context restriction:* the amateur can be weakened further by conditioning it on only part of the prompt (in the limit, the last token only), so that the contrast additionally rewards continuations that use the full context — the paper credits part of its coherence gain to this (§6.1) and studies it in §7.5. This is the same construction that makes CD, in a special case, equivalent to the MMI / pointwise-mutual-information decoding objective.

**Special cases worth holding onto.** With a uniform amateur, CD reduces to maximum-probability decoding. With an n-gram amateur whose counts update on the generated prefix and a very small amateur temperature, CD approaches soft n-gram blocking (hard no-repeat-ngram in the limit). CD is thus a generalisation that contains both plain likelihood search and a standard anti-repetition heuristic as corners — a fact that matters for §5's ordering question.

## 4. Reported results — as reported, with context

All numbers in the first half of this section are this paper's own (ACL 2023 text, read 2026-11-15), in the paper's frame. Setup: prompts are the first 32 words of a passage; continuations are 256 tokens; domains are Wikinews (news), WikiText-103 (Wikipedia), and BookCorpus / Project Gutenberg (stories); baselines are nucleus sampling ($p=0.95$), top-$k$ ($k=50$), typical decoding ($\tau=0.95$), greedy (max-probability), and contrastive search (CS).

**Automatic evaluation (paper Table 1) — CD leads on MAUVE and coherence in every (model, domain) cell.** Headline cells:

| Expert | Domain | CD: div / MAUVE / coh | Best sampling baseline (MAUVE / coh) | Max-prob (MAUVE / coh) |
|---|---|---|---|---|
| OPT-13B | Wikinews | 0.94 / 0.94 / 0.69 | nucleus 0.92 / 0.62 | 0.30 / 0.65 |
| OPT-13B | WikiText | 0.91 / 0.91 / 0.69 | nucleus 0.89 / 0.55 | 0.08 / 0.63 |
| OPT-13B | Story | 0.89 / 0.94 / 0.62 | nucleus 0.91 / 0.48 | 0.05 / 0.51 |
| GPT-2 XL | WikiText | 0.89 / 0.92 / 0.69 | nucleus 0.87 / 0.57 | 0.05 / 0.62 |

Diversity is the honest cost line: CD is "comparable or slightly worse" than nucleus / typical sampling on diversity (e.g. story domain at 1.5B: 0.83 vs. 0.94), while being *substantially* more diverse than the other search methods (max-probability diversity collapses to 0.01–0.08). The paper notes the diversity gap shrinks as the expert scales (story: 0.89 vs. 0.93 at 13B), and attributes the coherence gain to three sources: search avoiding chance drift, the objective implicitly rewarding what larger models do better (coherence included), and the amateur context restriction.

**Human evaluation (paper Table 2).** Mechanical Turk pairwise judgements against nucleus and typical decoding, across three domains and two models: evaluators preferred CD on **coherence 2.6× more than nucleus sampling and 6.4× more than typical decoding** on average, and on **fluency 1.4× and 3.5×** respectively. Individual cells are mostly statistically significant on coherence; the paper reports CD as "better or comparably fluent" overall rather than uniformly dominant on fluency.

**Reasoning gains — follow-up paper, reported separately and attributed.** O'Brien & Lewis (arXiv:2309.09117, 2023) applied CD off-the-shelf to reasoning and report, in their abstract's terms: improvements over greedy decoding of **up to 8 absolute points on GSM8K** across LLaMA models; on **HellaSwag**, CD ranking with a LLaMA-65B expert outperforming LLaMA 2, GPT-3.5 and PaLM 2-L, and on GSM8K outperforming LLaMA 2, GPT-3.5 and PaLM-540B; with the honest caveats in the same work that results on some commonsense tasks were mixed and factual retrieval slightly degraded in their setting. Their weighted form of the objective introduces a second parameter ($\beta$, the contrast weight; their figures use $\alpha = 0.1$, $\beta = 0.5$ with a 65B expert) — that weighting is *their* extension, not the original paper's unweighted log-ratio. The corpus records these as the follow-up's claims about CD, not as results of the paper under dossier.

**Dating caveat (applies to this dossier and its companion).** Both Wave 23 papers are 2022–23-era work evaluated on 2022–23-era models: OPT and GPT-2 here; LLaMA-1 in the companion. None of the headline numbers were measured on instruction-tuned chat models, on quantised weights, or on any model generation a current personal runner would actually serve. The *mechanisms* (§3) are architecture-level claims and transfer in principle; the *effect sizes* above are as-reported history, to be re-measured before any reliance (§6b).

## 5. Position in the decoding stack

CD is a **logit transform**, not a sampler and not a mask in the Wave 18 sense — and placing it precisely against the corpus's other two families is this wave's stack question.

**The three families, in the order a token actually meets them.** (i) *Validity (Wave 18):* the grammar mask (`papers/xgrammar.md`, `papers/outlines-guided-generation.md`) sets invalid tokens to $-\infty$; it is a hard constraint from outside the model, and it must be *correct* — a wrong mask is a different sampler, not a faster one. (ii) *Contrast (this wave):* CD replaces the expert's per-token score $\log p_{\text{exp}}$ with $\log p_{\text{exp}} - \log p_{\text{ama}}$, gated by its own $\mathcal{V}_{\text{head}}$ plausibility set. (iii) *Truncation / temperature (Wave 9):* top-$k$, top-$p$, min-p, typical-p and temperature reshape whatever distribution survives, and a draw (or, in CD's original form, a beam search) selects from it.

**The ordering question, stated precisely.** Contrast operates on **raw logits (equivalently, log-probabilities) before masking and before truncation** — it has to: the log-ratio is only meaningful on the two models' untruncated distributions, and $\mathcal{V}_{\text{head}}$ is defined from the expert's raw top probability. But three interactions are **under-specified in the literature**, and the corpus records them as open, not settled:

1. *Contrast vs. validity mask.* If a grammar mask is applied first, the expert's renormalised probabilities change, so $\mathcal{V}_{\text{head}}$'s $\alpha \cdot \max$ threshold and the amateur's scores are computed against a different distribution than either paper specifies. If contrast is applied first, the mask must then be applied to the *contrasted* scores — but a token can be grammar-valid and contrast-negative, or grammar-invalid and contrast-high, and neither paper says which stage owns the final $-\infty$. The safe composition (validity last, as an absolute veto over whatever the contrast produced) is an engineering judgement, not a published result.
2. *Contrast vs. truncation.* CD as published *replaces* the Wave 9 chain with beam search over contrasted scores plus $\mathcal{V}_{\text{head}}$; it does not stack nucleus or min-p on top. Whether a contrasted distribution should then be temperature-scaled, min-p-floored, or sampled at all — and in which order — has no canonical answer in either Wave 23 paper. (The follow-up reasoning work applies CD as a *scoring / ranking* rule for candidate answers, a third usage again.)
3. *$\mathcal{V}_{\text{head}}$ vs. min-p.* Both are $\alpha$-ratio-to-max sets. Running both is running the same-shaped gate twice with two different constants and two different referents (expert-only vs. contrasted). Nothing published says whether they compose, coincide, or interfere.

**The speculative-decoding break.** Both Wave 23 methods break the assumption speculative verification's acceptance maths relies on: that *the distribution being sampled from is the target model's distribution*. Speculative decoding (Waves 2/13; `papers/speculative-decoding.md`) accepts a draft token with probability $\min(1, p_{\text{target}}/p_{\text{draft}})$ precisely so that the output is distributed *exactly* as the target model alone — the guarantee is the product. Under CD there is no single "target distribution": the sampled distribution is a function of *two* models' logits, and under DoLa of *two layers'* logits. A verifier would have to define acceptance against the contrasted distribution $\hat{p}$ — which requires the amateur's (or premature layer's) logits at verification time, on both the draft and target sides, and a re-derived correction term. **Constrained / contrasted speculation is a research gap**: the corpus knows of no published acceptance rule that preserves the contrasted distribution exactly, and this dossier notes the gap without attempting to close it. Any build that combines CD/DoLa with speculation is, until that maths exists, choosing between exactness to the contrasted distribution and the speed speculation exists to buy.

## 6. Applicability

### (a) The personal runner — a residency question

*Statements in this subsection about runner internals are implementation facts as banked in this corpus; recommendations are labelled proposals, not adopted techniques.*

CD's cost is not compute, it is **residency**: the amateur model must be loaded, resident, and run on every token alongside the expert — a second forward pass per step, a second KV cache, a second weight allocation. On the personal runner's target hardware (a 6 GB-class card, per the corpus's fleet arithmetic), that budget question is real but unusually favourable in CD's specific case:

- The paper's own design rule — *smallest model in the expert's family* — puts the amateur at 0.5–1.5B-class for a modern small-expert pairing, and smaller still for the paper's own pairings (125M against 13B). At aggressive quantisation an amateur of that class is a few hundred megabytes of weights plus a small KV cache: cheap *relative to the expert*, but not free, and it comes out of the same single pool that funds the expert's weights, its KV cache, and the display reserve. The ledger's one-pool budgeting applies without exception: the amateur is a line item in the same budget, competing token-for-token with context length.
- The amateur also costs a forward pass per generated token. The paper argues the optimal amateur "incurs very little inference time overhead" because it is so much smaller than the expert; on a memory-bandwidth-bound personal card that argument needs re-measuring, not assuming — decode there is bandwidth-bound, and every byte of amateur weight read per token is bandwidth the expert's read does not get.
- **Contrast with the companion dossier, in one distinction:** CD is a *residency* question (can we afford to keep a second, small model loaded?), DoLa is a *backend-capability* question (can the backend expose per-layer logits at all?). CD needs nothing from the backend that a standard runner does not already have — two ordinary model loads and their final logits. That is the wave's practical yield, stated fully in the DoLa dossier §6a.

### (b) The accuracy commission — a testable proposal, not an adopted technique

**Label: proposal for testing. CD is not adopted by the build campaign on the strength of this dossier.**

CD is a candidate entry for the build campaign's fact-retention battery, to be *tested* under the corpus's raw-oracle discipline: teacher-forcing rank and logit gap on the raw prompt, CPU engine against CPU comparator, no template-rendered prompts, near-tie band (rank ≤ 2 with sub-logit gap) graded as faithful. Concretely, a fair test would: fix expert and amateur from the same family at the sizes the runner would actually serve; grade CD against greedy and against the shipped sampler chain on the same prompts, with the contrast computed from raw logits in both engines; and report separately on (i) factual-recall prompts, where the paper's mechanism predicts the gain, (ii) easy / high-confidence prompts, where $\mathcal{V}_{\text{head}}$ should make CD a no-op — a built-in control condition — and (iii) repetition-prone long generations, the original paper's home ground. A result that wins on (i) and (iii) while exactly matching the baseline on (ii) would be evidence the mechanism, not a side effect, is doing the work. Anything less is a number without a cause.

## 7. Cross-links

- **DoLa dossier** (`papers/dola.md`, this wave) — the sibling contrast: same log-difference form, same $\mathcal{V}_{\text{head}}$ / adaptive plausibility constraint at the same $\alpha = 0.1$, but the "amateur" is the same model's own earlier layer. DoLa's paper benchmarks directly against CD (with LLaMA-7B as CD's amateur) and reports CD's characteristic failure on open-ended TruthfulQA — mass refusal ("I have no comment") — that DoLa avoids; see that dossier §4.
- **Min-p dossier** (`papers/min-p-sampling.md`, Wave 9) — chain neighbour and structural relative: min-p's floor and CD's $\mathcal{V}_{\text{head}}$ are the same confidence-relative construction (threshold as a ratio to the step's maximum probability). §5 above records the open question of how the two gates compose if both are present.
- **Mirostat dossier** (`papers/mirostat.md`, Wave 9) — the other non-standard member of the sampler surface: a stateful controller that *substitutes* for the truncation chain rather than composing inside it. CD has the same shape of problem for the pipeline abstraction — see the IDEA-LEDGER note below.
- **XGrammar dossier** (`papers/xgrammar.md`, Wave 18) — the validity half of decode control. §5's ordering question (mask first or contrast first, and who owns the final $-\infty$) is the joint between this wave and Wave 18; neither literature specifies it.
- **Agent memory architectures** (`memory/agent-memory-architectures.md`) — the complementary honesty layer. Memory-side honesty is about what the model is *given*: retrieved context that is present, attributed, and not silently truncated or beheaded, so the model is not asked to answer from an absence it cannot see. Decode-side honesty (this wave) is about what the model *does with what it has*: surfacing knowledge already in the weights that the default objective buries under generic continuations. Neither substitutes for the other — contrast cannot surface a fact that was never in the weights nor in the context, and perfect context does not stop likelihood decoding from preferring a generic falsehood over a specific truth that both context and weights support. "Less hallucination by the way we use memory" (the accuracy commission's framing) needs both layers, tested separately so a gain in one is not mistaken for a gain in the other.
- **IDEA-LEDGER #37** (`synthesis/IDEA-LEDGER.md`, rank 15) — "Sampler pipeline as a first-class, ordered, per-request surface," with its v3 compose-or-substitute law (min-p composes late in the chain; mirostat substitutes for the chain; the two are exclusive modes). **Contrast is another non-chain-shaped transform in exactly mirostat's pattern:** it does not slot into a linear chain of filters over one distribution, because it *changes which distribution there is* — it needs a second model's logits (CD) or a second layer's logits (DoLa) as an input the chain does not carry. The pattern the ledger keeps meeting: the pipeline abstraction assumes transforms of the form *distribution → distribution*, and the interesting decode-time methods keep arriving as *distributions → distribution* (CD, DoLa) or *stateful controller replacing the chain* (mirostat). #37's surface, if it grows to admit contrast, must admit a second logits input and an explicit exclusive-mode declaration — not pretend contrast is one more filter between penalties and temperature.

## 8. Sources

- Date accessed: **2026-11-15** (all sources).
- arXiv abstract record (title, authors, ACL 2023 comments field, v1–v2 history): https://arxiv.org/abs/2210.15097
- arXiv full text via ar5iv (mechanism §§3–4 including $\mathcal{V}_{\text{head}}$, $\alpha = 0.1$, amateur scale / temperature / context choices; setup §5; Tables 1–2 and §§6–7): https://ar5iv.labs.arxiv.org/html/2210.15097
- ACL 2023 proceedings PDF (venue, pp. 12286–12312 header): Proceedings of the 61st Annual Meeting of the Association for Computational Linguistics, Volume 1: Long Papers.
- Follow-up reasoning results (§4, attributed separately): O'Brien & Lewis, *Contrastive Decoding Improves Reasoning in Large Language Models*, arXiv:2309.09117 — https://ar5iv.labs.arxiv.org/html/2309.09117
- Corpus-internal sources: `papers/dola.md`, `papers/min-p-sampling.md`, `papers/mirostat.md`, `papers/xgrammar.md`, `papers/speculative-decoding.md`, `memory/agent-memory-architectures.md`, `synthesis/IDEA-LEDGER.md` (this corpus).
