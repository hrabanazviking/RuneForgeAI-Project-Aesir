# NTK-Aware Scaling — a lineage dossier (community origin, formalised inside YaRN)

## 1. Full citation — a lineage record, not a paper citation

**There is no NTK-aware scaling paper.** No arXiv preprint, no conference publication, and no single canonical document introduces the method. That absence is a corpus fact, recorded here deliberately: NTK-aware scaling is community knowledge that entered the formal literature *through a later paper's account of it*. The citable primary artefacts, in order, are:

- **Primary artefact 1 — the originating post.** bloc97. "NTK-Aware Scaled RoPE allows LLaMA models to have extended (8k+) context size without any fine-tuning and minimal perplexity degradation." Reddit, r/LocalLLaMA, **June 2023**. URL (as cited by YaRN and by later papers): https://www.reddit.com/r/LocalLLaMA/comments/14lz7j5/ntkaware_scaled_rope_allows_llama_models_to_have/ — In YaRN's reference list this is **bloc97 (2023b)**.
- **Primary artefact 2 — the by-parts correction.** bloc97. "Add NTK-Aware interpolation 'by parts' correction." GitHub pull request, **2023** — https://github.com/jquesnelle/scaled-rope/pull/1 — In YaRN's reference list this is **bloc97 (2023a)**. The by-parts idea is the bridge between NTK-aware proper and YaRN (`papers/yarn.md` §3.1).
- **Primary artefact 3 — the sibling post (Dynamic NTK).** emozilla. "Dynamically Scaled RoPE further increases performance of long context LLaMA with zero fine-tuning." Reddit, r/LocalLLaMA, **July 2023**. URL (as cited by YaRN): https://www.reddit.com/r/LocalLLaMA/comments/14mrgpr/dynamically_scaled_rope_further_increases/ — the dynamic-scale idea later folded into YaRN as Dynamic Scaling / Dynamic-YaRN.
- **The formalisation — where the lineage becomes literature.** Peng, Quesnelle, Fan & Shippole, "YaRN: Efficient Context Window Extension of Large Language Models," arXiv:2309.00071 (2023; ICLR 2024) — §1, §3.1, and Appendix A.2 give the first complete published account, in the paper's own words "a complete account of the previous unpublished works on the 'NTK-aware', the 'Dynamic NTK' and the 'NTK-by-parts' interpolations." YaRN's reference list cites artefacts 1–3 above *as what they are* — a Reddit post, a pull request, a Reddit post — which is the citation practice this dossier follows. The EleutherAI blog post "Extending the RoPE" (2023, by the same research circle) is the companion exposition.
- **Author identity, as documented:** "bloc97" is the Reddit/GitHub handle of Bowen Peng, YaRN's first author (YaRN lists correspondence to bloc@nousresearch.com and credits Reddit: /u/bloc97, GitHub: bloc97); "emozilla" is Jeffrey Quesnelle, YaRN's second author. The community posts and the formalising paper therefore share authors — the lineage is not folk knowledge absorbed by strangers, but researchers publishing first in the open, in the fastest venue available, and archiving it properly later. Later literature cites the post directly in the same form (e.g. "bloc97. NTK-aware scaled RoPE… Reddit post on r/LocalLLaMA, June 2023" in subsequent papers' bibliographies, verified in sources read for this dossier).

**How to cite this lineage:** cite artefact 1 for the method, artefact 2 for by-parts, artefact 3 for dynamic scaling, and YaRN §3.1 / App. A.2 for the formal statement. Do not cite a nonexistent "NTK-aware paper," and do not silently re-attribute the method to YaRN — YaRN itself does not.

## 2. The problem as framed

Position Interpolation (`papers/position-interpolation.md`) had just shown, in June 2023, that squeezing positions *m → m/s* makes RoPE extension stable and cheap. The community objection — stated first in the post, then formally in YaRN §3.1 — is that PI squeezes *blindly*:

- **Uniform compression spends the wrong resolution.** RoPE's dimensions are not interchangeable. The high-frequency dimensions (small wavelength; they rotate many times per window) carry fine local order — the difference between adjacent and near-adjacent tokens. The low-frequency dimensions (wavelength comparable to or longer than the window) carry coarse, long-range position. Dividing every position by *s* compresses all of them by the same factor: neighbours move *s×* closer together in *precisely* the dimensions the model uses to tell neighbours apart.
- **The NTK framing of why that loss is hard to recover.** YaRN §3.1 grounds the objection in Neural Tangent Kernel theory via Tancik et al. (2020), "Fourier Features Let Networks Learn High-Frequency Functions in Low-Dimensional Domains": a network fed a low-dimensional input (here, the one-dimensional position) learns high-frequency functions of it slowly and badly unless the embedding itself supplies high-frequency components. RoPE *is* such a Fourier-feature-style embedding. Uniformly scaling positions down removes exactly the high-frequency content the theory says the network cannot easily relearn — which predicts PI's observed behaviour: fine at small *s*, degrading as *s* grows (YaRN reports PI fine-tunes stalling around *s ≈ 8*), with the damage concentrated in local, order-sensitive behaviour.
- **The practical demand the post answered:** an extension that works **without any fine-tuning at all**. PI is a fine-tune recipe; a local-models community running checkpoints on consumer hardware wanted to *reconfigure* a model to a longer window at load time. That demand — zero-training, config-only extension — is the reason the NTK-aware form (a base change, §3) matters: it is a number you can set, not a training run you must do.

## 3. Core mechanism in our own words

### 3.1 Scale the base, not the positions

PI leaves RoPE's frequencies *θ_d = b^(−2d/|D|)* (base *b* = 10,000) untouched and scales the position index. NTK-aware does the exact opposite — in the *g(m), h(θ)* notation YaRN standardised:

```
g(m) = m                                   (positions untouched)
h(θ_d) = b′^(−2d/|D|),   b′ = b · s^(|D| / (|D| − 2))
```

One number changes: the RoPE **base** *b* is raised to *b′*, where *s = L′/L* is the target extension factor and *|D|* the head dimension. Everything else is a consequence of how a base change distributes across dimensions.

### 3.2 Why a base change is dimension-aware

Raising the base does not scale all frequencies by the same factor. The ratio between the new and old frequency in dimension *d* works out to *s^(−2d/(|D|−2))*-shaped — near **1 (no compression)** for the lowest dimensions *d* (the highest frequencies) and approaching the **full 1/s compression** for the highest dimensions *d* (the lowest frequencies). Read in the direction the sources describe it:

- **Low dimensions / high frequency: barely touched — effectively extrapolated.** Their rotations already wrap many times inside the trained window, so their angles stay in-distribution at longer lengths; leaving them alone preserves the local resolution PI destroys.
- **High dimensions / low frequency: interpolated (nearly fully).** These are the dimensions whose angles would leave the trained range at longer lengths; they receive almost all of the interpolation pressure.
- **Middle dimensions: a geometric spread between the two extremes** — the "spread out the interpolation pressure across multiple dimensions" of YaRN §3.1 and the EleutherAI exposition.

In wavelength language (YaRN §2.2): *λ_d = 2π/θ_d* is the distance over which dimension *d* completes one rotation. NTK-aware leaves short-wavelength dimensions at their trained wavelength and stretches long-wavelength dimensions toward *s·λ_d*, grading smoothly between. The one-line summary the corpus uses: **extrapolation in high frequency, interpolation in low frequency** — the formulation also given in Jianlin Su's contemporary community exposition of the method (see §8).

### 3.3 The honest costs, as the formal account records them

YaRN's Appendix A.2 — the formalisation being candid about its subject — records two defects that define what had to come next:

1. **The optimal base is empirical.** There is no closed form for the best *b′* for a given target; in practice the scale value "has to be set higher than the expected scale for a given context length extension," and finding it costs experiments. (Code Llama's deployment, §4, sidestepped the formula entirely and hand-set the base to 1,000,000 — the "adjusted base frequency" (ABF) variant YaRN's footnote records.)
2. **It is not pure interpolation.** Some dimensions are pushed slightly *outside* their trained ("out-of-bound") values, so under fine-tuning NTK-aware performs *worse* than PI (§4) — the method's home ground is the no-fine-tune regime, and its fine-tuned weakness is precisely what NTK-by-parts (artefact 2) was written to fix: keep high-frequency dimensions *exactly* untouched and low-frequency dimensions *exactly* PI-interpolated, with a wavelength-keyed ramp between, instead of NTK-aware's smooth-but-unbounded spread.

## 4. Reported results — as reported, each attached to its source

Community numbers are labelled community numbers. No figure below comes from a peer-reviewed evaluation of NTK-aware alone; the strongest comparative statements are YaRN's, made by the method's own authors in the course of superseding it.

- **The originating claim (bloc97, Reddit, June 2023 — community report).** The post's title is its headline result: LLaMA models extended to **8k+ context with no fine-tuning and "minimal perplexity degradation."** The post's own comparison (as reproduced and described in later expositions) plots LLaMA-7B perplexity against length for baseline, linear (PI-style) interpolation at scale 4, and NTK-aware at its reported setting, with NTK-aware holding markedly lower perplexity across the extended range *without training*. These are single-author, self-run numbers on a forum post — historically decisive, evidentially light, and cited here as exactly that.
- **The formal account's verdict (YaRN, arXiv:2309.00071, §3.1 / App. A.2 / EleutherAI blog — as reported).** Three comparative claims, stated consistently across the paper and blog: (i) *without* fine-tuning, NTK-aware shows **better (lower) perplexity than PI** on longer sequences; (ii) *after* fine-tuning on longer-context data, NTK-aware performs **worse than PI** (the out-of-bound effect, §3.3); (iii) the comparison motivated by-parts, which the same sources report as beating both predecessors in the fine-tuned setting. YaRN's head-to-head fine-tuned ablation (LLaMA-7B → 32k, equal budget; `papers/yarn.md` §4) includes NTK-aware among the compared methods and ranks it behind NTK-by-parts and YaRN; exact per-method perplexities for that ablation are presented graphically in the paper and are not invented here.
- **Deployment as evidence (as reported in YaRN §1 and its footnote).** Within weeks, NTK-aware-class scaling shipped in production open models: **Code Llama** (Rozière et al., 2023) used the base-scaling idea with the base manually set to **1M** ("adjusted base frequency"), and **Qwen-7B** used the sibling Dynamic NTK. A community post becoming a named ingredient in two major model releases inside one quarter is the lineage's real-world result, independent of any perplexity table.
- **What was never reported:** no standardised benchmark suite, no multi-needle or aggregation evaluation, no systematic sweep published by the originators beyond the post's own plots, and no fine-tuned NTK-aware model released as a reference artefact. The method's evidence base is: one post's plots, one successor paper's comparative prose and ablations, and adoption. Later long-context pricing (RULER-class, `papers/ruler.md`) was never applied to a pure NTK-aware configuration as such — by the time such suites existed, NTK-aware survived only inside its descendants.

## 5. Position in the family

The chain, one line per step — what changed (the same chain as `papers/position-interpolation.md` §5, told from this dossier's step):

- **RoPE (Su et al., 2021/2022, arXiv:2104.09864 — the base encoding throughout this corpus):** per-dimension-pair rotations *m·θ_d*; relative position only; undefined behaviour past the trained *L*.
- **Position Interpolation (Chen et al., June 2023; `papers/position-interpolation.md`):** *uniform* interpolation — positions *m → m/s*, frequencies untouched, short fine-tune; stability proved, local resolution spent uniformly.
- **NTK-aware scaling (this dossier, bloc97, June 2023):** *dimension-aware* interpolation — positions untouched, base *b → b·s^(|D|/(|D|−2))*; high frequencies effectively extrapolated, low frequencies interpolated; the first form that works with **no fine-tune**, at the price of an empirical base and out-of-bound dimensions under fine-tuning.
- **NTK-by-parts / Dynamic NTK (bloc97 PR / emozilla post, 2023):** by-parts replaces the smooth base-change spread with an explicit wavelength-keyed three-band rule (interpolate / ramp / leave) that fixes the fine-tuned weakness; Dynamic NTK replaces the fixed target scale with one that follows the current sequence length, *s = max(1, l′/L)*, for graceful no-fine-tune use.
- **YaRN (Peng et al., 2023, arXiv:2309.00071; `papers/yarn.md`):** NTK-by-parts *plus* attention temperature (√(1/t) = 0.1·ln(s) + 1) — and, for this lineage, the paper that *is* its archive: §3.1 and Appendix A.2 are the canonical formal statement of NTK-aware itself.
- **LongRoPE (Ding et al., 2024, arXiv:2402.13753; `papers/longrope.md`):** *searched* per-dimension factors replace every hand-designed distribution rule in the steps above, PI's and NTK-aware's alike.

Wave 7 banked the descendants (YaRN, LongRoPE); this dossier and the PI dossier are the roots. NTK-aware's specific historical role is double: technically, it introduced the family's governing insight — *dimensions differ, so scaling must differ by dimension* — which every successor keeps; institutionally, it is the corpus's cleanest case of a method travelling **post → code → production models → formal paper**, in that order.

## 6. Applicability

### (a) The runner angle — thin, stated thinly

A runner does not choose NTK-aware scaling either — but NTK-aware is the member of this family a runner is most likely to meet *as a bare number*, because its entire content is one changed constant. It reaches the runner as: a raised `rope_theta` / rope frequency base in a checkpoint config (Code Llama's 1M being the famous instance), a GGUF frequency-base field, or a `rope_scaling` type naming an NTK variant with its factor and original length. The runner's obligations are the detect-and-honour obligations of §6a in the PI dossier, sharpened by this method's shape:

- **Honour the base that ships, exactly.** A checkpoint extended by base-scaling *expects* its declared base at every length. Serving it at the stock 10,000 silently un-extends it (long context collapses back to extrapolation failure); serving a *non*-extended checkpoint at a raised base because a user copied a Code Llama setting silently compresses its low frequencies with no fine-tune behind them. Both errors are silent at short lengths, where the angular differences are small — the failure only appears in the long sessions the setting was for.
- **Do not "helpfully" recompute it.** Because the formula *b′ = b·s^(|D|/(|D|−2))* is public and one line long, a runner (or a conversion tool) may be tempted to derive the base from a target factor instead of reading the shipped value — but §3.3 records that practitioners routinely set the scale *higher than nominal*, and Code Llama ignored the formula for a hand-set 1M. The shipped number, not the formula's output, is the model's contract.
- Same class, same rule as the corpus's other detect-and-honour cases — Native Sparse Attention's baked-in sparsity and LayerSkip's baked-in exit structure (`papers/native-sparse-attention.md`, `papers/layerskip.md`): the runner reads the checkpoint's declared geometry and applies it; invention in either direction degrades the model without an error message.

### (b) The usable-number connection (wave 21)

NTK-aware manufactured the *scaled* number (`papers/position-interpolation.md` §6b) in its cheapest possible form: **no training run at all** — a base change and a config line turn a 2K checkpoint into an "8K+" model, per the originating post's title. That is simultaneously its historical importance and the sharpest illustration of why wave 21's pricing discipline exists. A trained number is backed by the training itself; a PI number is backed by a fine-tune and a passkey table; an NTK-aware number, at birth, was backed by one author's perplexity plot on a forum post. None of that makes the claim false — YaRN's later comparisons confirm NTK-aware genuinely beats PI in its no-fine-tune regime — but the *worth* of the number at each length, for retrieval harder than a single needle, was never measured for the pure method (§4). RULER (`papers/ruler.md`) is the instrument that prices such claims; the corpus rule this lineage teaches is that **the cheaper the recipe that mints a context number, the more of the evidentiary burden shifts to the benchmark** — and a runner or model card that repeats a scaled number without naming its recipe (NTK-aware? by-parts? YaRN? searched?) and its pricing evidence is repeating the number in its least informative form.

## 7. Cross-links

- **YaRN dossier** (`papers/yarn.md`) — the formaliser and successor: its §3.1 is this dossier's §3 with the ramp made explicit, its §3.2 adds the temperature NTK-aware never had, and its §5 traces the `rope_scaling` config ecosystem (HF types, vLLM/SGLang blocks, GGUF metadata) through which NTK-descended settings still reach runners.
- **LongRoPE dossier** (`papers/longrope.md`) — the searched-factor successor whose motivating tables compare PI, Dynamic-NTK, and YaRN head-to-head without fine-tuning — the closest the corpus comes to a neutral pricing of this lineage's middle steps.
- **Position Interpolation dossier** (`papers/position-interpolation.md`) — the sibling root: the uniform rule this method exists to correct, written the same month.
- **RULER dossier** (`papers/ruler.md`) — the pricing instrument for no-fine-tune context claims (§6b).
- **KV-cache design** (`memory/kv-cache-design.md`) — the allocated number: a base change, like every scaling in this family, does not discount the per-token cache cost of the lengths it legitimises; and Dynamic NTK's moving scale is the case that forces the corpus's pre-RoPE key-storage rule, since cached post-RoPE keys are bound to the scale under which they were computed (`papers/yarn.md` §3.3).
- **Native Sparse Attention dossier** (`papers/native-sparse-attention.md`) — fellow member of the detect-and-honour class (§6a).

## 8. Sources

- Date accessed: **2026-11-15** (all sources).
- bloc97 (2023b), originating post — cited as recorded in YaRN's reference list and in later papers' bibliographies (the post itself is the primary artefact; its URL as cited): https://www.reddit.com/r/LocalLLaMA/comments/14lz7j5/ntkaware_scaled_rope_allows_llama_models_to_have/
- bloc97 (2023a), "by parts" correction — GitHub pull request, as cited by YaRN: https://github.com/jquesnelle/scaled-rope/pull/1
- emozilla (2023), Dynamic NTK post — as cited by YaRN: https://www.reddit.com/r/LocalLLaMA/comments/14mrgpr/dynamically_scaled_rope_further_increases/
- Peng, Quesnelle, Fan & Shippole, YaRN, arXiv:2309.00071 — HTML v3 read for §1, §3.1, §3.2, Appendix A.2, and the reference-list entries for bloc97 (2023a/b) and emozilla (2023): https://arxiv.org/html/2309.00071v3 ; record: https://arxiv.org/abs/2309.00071
- EleutherAI blog, "Extending the RoPE" (2023) — the companion exposition: NTK-aware formula *b′ = b·s^(|D|/(|D|−2))*, the mixed PI-vs-NTK-aware verdict (better without fine-tuning, worse after), and the by-parts and Dynamic Scaling sections: https://blog.eleuther.ai/yarn/
- Su, Jianlin (2023), "Expand the Context Length with RoPE" exposition (English translation) — contemporary community account confirming the sequence kaiokendev → PI paper → bloc97's NTK-aware, and the "extrapolation in high-frequency, interpolation in low-frequency" formulation and its NTK/Fourier-features motivation: via the translation hosted at normxu.github.io, accessed 2026-11-15.
- Tancik et al. (2020), "Fourier Features Let Networks Learn High Frequency Functions in Low Dimensional Domains," NeurIPS 2020 — the NTK-theory source YaRN §3.1 cites for the method's name and motivation (cited here as YaRN cites it; not independently re-read for this dossier).
- Corpus-internal sources: `papers/position-interpolation.md`, `papers/yarn.md`, `papers/longrope.md`, `papers/ruler.md`, `papers/native-sparse-attention.md`, `papers/layerskip.md`, `memory/kv-cache-design.md`.
- **Verification note:** the Reddit and GitHub artefacts were verified through YaRN's reference list, the EleutherAI exposition's links to them, and later papers' bibliographies quoting their titles, dates, and URLs verbatim — not by direct retrieval of the Reddit pages themselves in this session. Titles, handles, months, and URLs above are exactly as those citing sources record them; no finer-grained claim about the posts' contents is made beyond what YaRN and the EleutherAI exposition themselves report.
