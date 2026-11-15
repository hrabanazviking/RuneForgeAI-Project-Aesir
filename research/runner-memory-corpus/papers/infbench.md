# ∞Bench — ∞Bench: Extending Long Context Evaluation Beyond 100K Tokens

## 1. Full citation

- **Title:** ∞Bench: Extending Long Context Evaluation Beyond 100K Tokens (typeset in the paper as $\infty$Bench; the released code/data use the spelling "InfiniteBench")
- **Authors:** Xinrong Zhang, Yingfa Chen, Shengding Hu, Zihang Xu, Junhao Chen, Moo Khai Hao, Xu Han, Zhen Leng Thai, Shuo Wang, Zhiyuan Liu, Maosong Sun
- **Affiliation (as listed in the paper):** Department of Computer Science and Technology, Tsinghua University, Beijing, China (contact: `zxr19@mails.tsinghua.edu.cn`)
- **Venue / year:** Proceedings of the 62nd Annual Meeting of the Association for Computational Linguistics (Volume 1: Long Papers), ACL 2024, pp. 15262–15277. ACL Anthology ID: 2024.acl-long.814 — https://aclanthology.org/2024.acl-long.814
- **arXiv:** arXiv:2402.13718 [cs.CL] — https://arxiv.org/abs/2402.13718 — v1 submitted 21 February 2024; v3 (current) 24 February 2024. DOI: 10.48550/arXiv.2402.13718.
- **Code / data (as reported in the paper):** https://github.com/OpenBMB/InfiniteBench ; dataset at https://huggingface.co/datasets/xinrongzhang2022/InfiniteBench
- **Identifier check (verified 2026-11-15):** the coordinator's identifiers check out in full — title, first author Zhang et al., ACL 2024 venue and arXiv:2402.13718 are all confirmed at the arXiv record and the ACL Anthology. No correction needed. One naming note for citers: the benchmark's name contains the symbol ∞ (hence this dossier's ASCII filename, `infbench.md`); the GitHub/Hugging Face artefacts spell it "InfiniteBench", and RULER's comparison table spells it "InfiniteBench" as well — all three spellings denote the same benchmark.

## 2. The problem as framed

By early 2024, models *claiming* 100K–200K-token contexts existed (GPT-4 at 128K; Claude 2 and Kimi-Chat claiming 200K; Yi-200K; YaRN-extended Mistral at 128K), but the benchmarks available to grade them did not operate at that scale: the paper's Table 1 puts LRA and LongBench at ~10K average length, L-Eval at 4K–60K, LooGLE at ~20K. The evaluation had fallen an order of magnitude behind the claims, which meant the claims were effectively unpriced at the lengths being advertised.

∞Bench's framing adds two design requirements beyond sheer length:

- **Retrieval must not be sufficient.** The tasks are "designed to require well understanding of long dependencies in contexts, and make simply retrieving a limited number of passages from contexts not sufficient" (abstract). A benchmark at 100K+ that a passkey probe could pass would repeat the needle-in-a-haystack failure at a larger scale (cf. `papers/ruler.md` §2 — the two papers diagnose the same disease from opposite ends).
- **Real work, both languages, several domains.** Document comprehension and agent construction — the motivating applications — involve novels, code repositories, mathematics and long dialogues, in English and in Chinese. A single-domain, single-language suite at 100K would still leave most of the claim untested. ∞Bench is bilingual (English + Chinese) and multi-domain by construction, mixing human-annotated realistic tasks with auto-generated synthetic tasks that can be scaled to arbitrary length.

The benchmark's own stated limit is worth recording with its claim: the authors note (Limitations) that even 100K+ "may fall short for applications requiring analysis of extensive datasets, such as multiple books or entire databases" — ∞Bench prices the 100K–200K claim generation, not the million-token one.

## 3. Core method in our own words

### 3.1 The suite at a glance

12 tasks, 5 domains (retrieval, code, math, novels, dialogue), **3,946 examples** in total. The paper's Table 1 gives the benchmark's average length as **~200K tokens**; the abstract's more careful claim is "the first LLM benchmark featuring an average data length surpassing 100K tokens." Per-task average *input* lengths (paper Table 2) run from ~44K (Math.Calc) and ~75K (Code.Run) up through ~103–115K (En.Sum, En.Dia, Code.Debug), ~121–122K (the three retrieval tasks) and ~184–193K (En.MC, En.QA) — i.e. the average is an average over a wide spread, not a uniform 200K, and two tasks sit below 100K on input length. Half the suite is human-annotated through five purpose-built annotation pipelines (iteratively refined, each annotation quality-checked by at least two other annotators); the rest is auto-generated.

### 3.2 Realistic tasks (human-annotated unless noted)

**Novels — En.Sum, En.QA, Zh.QA, En.MC.** Source novels are gathered from the web (study-guide sites are named in the paper's footnotes) and manually filtered. The key anti-contamination device is **key entity replacement**: prominent entities (e.g. main character names) are replaced with unrelated ones throughout the novel *and* the annotations, producing "fake novels" — so a model cannot answer from having memorised the real book; it must use the context in front of it. The same modified English novels back three task shapes:

- *En.Sum* — summarise the whole novel; gold summaries sourced from the web and manually filtered.
- *En.QA / Zh.QA* — questions constructed to need long-range reasoning, in two named shapes: **aggregation** ("How much money in total did A spend on lunch?" — compile scattered facts) and **filtering** ("What color dress did A wear when A met B for the second time?" — select the right occurrence from a set).
- *En.MC* — the QA pipeline recast as four-option multiple choice, with annotators instructed to make the options challenging.

**Dialogue — En.Dia (auto-generated over real scripts).** Long multi-role movie/drama scripts (from IMSDB, per the paper's footnote) are collected; randomly chosen character-name occurrences are replaced with `$$MASK$$` and the model must identify the masked speaker. Scripts shorter than 100K tokens are padded with additional scripts to reach length.

**Code — Code.Debug (human-annotated).** Real Python repositories from PyPI, filtered to the 64K–256K token range (tiktoken tokenisation), are flattened into a single file with each file's relative path prefixed. Three of the authors inject one deliberate, obvious error into one function per repository, using six named bug types: (1) deleting a necessary variable declaration; (2) wrong argument count in a call; (3) infinite loops; (4) indentation errors; (5) references to undefined variables/functions; (6) blatant syntax errors (e.g. unclosed brackets). The task is presented as four options in `Class.Function` form — the paper states plainly that the open form proved too hard for current models (none could find even an unclosed bracket unaided) and that the multiple-choice form is a deliberate softening, with a warning that external retrieval preprocessing would make many examples easy and is discouraged as unfair.

### 3.3 Synthetic tasks (auto-generated)

The paper groups these by the capability they isolate: location/retrieval, elevated information resolution, state preservation, and sequential processing.

- *Retrieve.PassKey* — the Mohtashami & Jaggi passkey task: a random 5-digit key hidden in noisy context; 59 evenly distributed key positions × 10 keys = 590 examples.
- *Retrieve.Number* — PassKey hardened for **local resolution**: the answer is 10 digits with successive repeated digits (e.g. `9998877762`), which the authors' preliminary experiments show models struggle to discern exactly.
- *Retrieve.KV* — key–value lookup inside a large JSON object of UUID→UUID pairs (after Liu et al.); relevant and irrelevant entries are format-identical, so the haystack gives no surface cue.
- *Code.Run* — simulate execution: generated Python of simple functions (addition/subtraction only, nested calls, cascade depth 2–10, each function calling at most one other); predict the result. Trivial for an interpreter — the point is **long-term state tracking** across the context.
- *Math.Find* — given a very long list of numbers, find one of seven targets: the three largest, the three smallest, or the median. Requires a complete scan with state preserved (no early exit can be correct).
- *Math.Calc* — evaluate a very long addition/subtraction expression; because direct final-answer attempts failed in pilot experiments, the model is asked for the intermediate result after each operator (sequential processing, scored per §3.4).

### 3.4 Evaluation method, per task, as reported

- **Scoring:** predominantly exact-match-style accuracy against the gold answer; **En.Sum** is scored with **ROUGE-L-Sum**; **Math.Calc** is scored by the number of correct intermediate values *before the first error* (a prefix-accuracy measure — one early slip ends the credit). For multiple-choice tasks, a response that does not emit one of the options is scored 0. The paper's Limitations section flags the reliance on exact match and prompt/answer parsing as a known fragility when porting the suite to new models.
- **Prompts:** a separate prompt template per (model, task) pair, tuned on short dummy examples to optimise each model's performance (templates in the paper's Appendix B) — the benchmark grades each model under *its own best prompt*, not one shared prompt.
- **Truncation:** inputs exceeding a model's limit are truncated by **removing the centre and joining the ends**, on the stated assumption that instructions/titles sit at the boundaries. This matters for interpretation: an over-length example is not skipped, it is silently shortened — and the paper's own lost-in-the-middle analysis (§4) catches one artefact of exactly this (a mid-context answer deleted by truncation).
- **Access and cost (as reported, Appendix D):** GPT-4 via its official API at default hyperparameters, total cost ~US$5,000; Claude 2 and Kimi-Chat entered **by hand through their web interfaces** (Claude 2: three authors over several weeks, ~US$160 of membership fees); YaRN-Mistral run locally on **one A100 80GB** at the YaRN paper's default decoding hyperparameters, ~10 minutes per example, several days for the full suite. Per-task maximum output tokens for the local run are tabulated (6 tokens for PassKey up to 30,000 for Math.Calc).

## 4. Reported results — as reported

Four baselines, chosen as the then-current models claiming 100K+: **GPT-4** (128K), **Claude 2** (200K claimed), **Kimi-Chat** (200K claimed), **YaRN-Mistral-7B-128K** (the open-source entrant; Mistral-7B extended from 8K training length to 128K by YaRN). Main results (paper Table 3; En.Sum is ROUGE-L-Sum, the rest accuracy-style scores):

| Task | GPT-4 | Claude 2 | Kimi-Chat | YaRN-Mistral |
|---|---|---|---|---|
| Retrieve.PassKey | 100.00 | 97.80 | 98.14 | 92.71 |
| Retrieve.Number | 100.00 | 98.14 | 95.42 | 56.61 |
| Retrieve.KV | 89.00 | 65.40 | 53.60 | 0.00 |
| En.Sum | 14.73 | 14.45 | 17.93 | 9.09 |
| En.QA | 22.22 | 11.97 | 16.52 | 9.55 |
| En.MC | 67.25 | 62.88 | 72.49 | 27.95 |
| En.Dia | 8.50 | **46.50** | 11.50 | 7.50 |
| Zh.QA | 23.06 | 10.53 | 18.62 | 16.98 |
| Code.Debug | 39.59 | 2.28 | 18.02 | 0.76 |
| Code.Run | 23.25 | 2.50 | 2.00 | 1.25 |
| Math.Calc | 0.01 | 0.00 | 0.00 | 0.00 |
| Math.Find | 60.00 | 32.29 | 12.57 | 17.14 |
| **Average** | **45.63** | **37.06** | **34.73** | **19.96** |

Headline findings, as reported:

- **Retrieval is nearly solved at the easy end and nothing else is.** PassKey is at or near ceiling for all four models — at ~122K average length. But the moment retrieval demands resolution or discrimination, the floor moves: Retrieve.Number halves YaRN-Mistral (56.61) and Retrieve.KV **zeroes** it (0.00) while GPT-4 holds 89.00. This is RULER's central pattern (`papers/ruler.md` §4) reproduced with realistic-scale inputs: the vanilla needle test is the last thing to fail, not the first.
- **The realistic tasks are low for everyone.** En.QA tops out at 22.22 (GPT-4); En.Sum ROUGE at 17.93 (Kimi-Chat, the one novel task with no proprietary winner pattern — the paper notes no distinct winner among the proprietary models on novel tasks); Code.Run at 23.25 with the other three at ≤2.50; Code.Debug at 39.59 (GPT-4, and see the prompting caveat below) against 0.76 for YaRN-Mistral. **Math.Calc is effectively zero for all four models** (0.01 best) — sequential state over ~44K tokens of arithmetic is beyond every entrant.
- **The open-source gap is the YaRN gap.** YaRN-Mistral averages 19.96 against GPT-4's 45.63 — the paper's verdict is that it "lags behind the proprietary models in most tasks, exhibiting almost random performance in multiple areas," while noting it is also weaker at short context, so the gap is not purely a length effect. For this corpus the row matters doubly: YaRN-Mistral is a **scaled** model (8K trained → 128K via YaRN, `papers/yarn.md`), and ∞Bench is what its scaled number is worth on realistic 100K+ work as reported by an independent suite: strong on the easiest retrieval, near-zero on KV retrieval, code and execution tasks.
- **Length ablation:** on shortened versions of the auto-generated tasks, performance generally **declines as input length grows** — the models are "technically equipped to handle extended inputs" whose "effectiveness diminishes significantly" (paper §5.1). ∞Bench does not define a per-model effective-length threshold (that formalisation is RULER's); its length claim is the gradient, not a cutoff.
- **"Lost in the middle" does not replicate cleanly at this scale.** Across three position-sensitive tasks, the paper finds **no consistent position trend**: GPT-4 prefers early answers in Retrieve.KV but late answers in En.Dia; Claude 2 is roughly position-insensitive; YaRN-Mistral and Kimi-Chat favour end positions (YaRN-Mistral scores zero at *every* position on Retrieve.KV). The authors hypothesise the phenomenon is task- and model-specific, and note their setting is ~8× longer than the original study's ≤16K. (One Kimi-Chat mid-context dip on Retrieve.KV is explicitly attributed to the centre-truncation of §3.4 deleting the answer — a benchmark artefact, disclosed as one.)
- **Context recalling (a prompting result, reported as such).** On Code.Debug, instructing GPT-4 to work step-by-step scores **15.74%**; instructing it to first **repeat the relevant code** and then analyse scores **39.59%** — the paper's headline Table 3 number for GPT-4 on this task is the *recalling* number. The authors present recalling as a promising technique needing further investigation; a careful reader should treat the 39.59 as "GPT-4 + a specific elicitation prompt," not raw model capability — the paper itself supplies both numbers, and this dossier reports both.
- **Appendix data point:** RWKV-4-World-7B, tested on Retrieve.PassKey only, scores **0.00%** with unintelligible output; the authors explicitly caution this reflects a model never trained at this length (train–test shift), "not evidence that the architecture of RWKV is incapable," and exclude it from the remaining tasks.
- **Dating caveat.** The roster is four models from early 2024, two of them evaluated by hand through web UIs. The absolute scores grade those artefacts at that moment; what transfers is the ordering of task difficulty (passkey ≫ KV retrieval ≫ realistic QA/code/math) and the size of the open-vs-proprietary gap for a RoPE-scaled 7B at 128K — not any current model's standing.

## 5. Position vs Wave 7 — three numbers, not one

Wave 7 (`papers/yarn.md`, `papers/longrope.md`) established the corpus's honesty rule: context length is **three quantities** — *trained* (positions seen in training), *scaled* (positions made addressable by YaRN/LongRoPE-style remapping), and *allocated* (the runner's `num_ctx`, the number memory is actually spent on, per `memory/kv-cache-design.md`). ∞Bench, with RULER (`papers/ruler.md`), grades a fourth, empirical quantity: the **usable** length — what the model can actually *do* at the lengths the other numbers advertise.

∞Bench's contribution to that grading is the realistic end of it:

- **Its test length is itself a scaled-number artefact.** The suite operates at ~100–200K because that is where the claims were. Every model it tests is there by extension: GPT-4's 128K, Claude 2's and Kimi-Chat's claimed 200K, and most transparently YaRN-Mistral — an 8K-trained model whose entire presence in this benchmark is a YaRN scaling (`papers/yarn.md`). ∞Bench therefore reads, in corpus terms, as an audit of the scaled number by realistic work: the scaled window *opens* (nothing crashes; PassKey returns), and then the usable number asserts itself task by task (KV retrieval 0.00, Code.Debug 0.76, Code.Run 1.25 for the scaled 7B).
- **It complements RULER's controlled sweep with ecological validity — and inherits the reciprocal weakness.** RULER can say *where* usability ends because it controls length and complexity; ∞Bench fixes length at the claim scale and varies realism, so it can say *what breaks* at 100K+ (state tracking and sequential processing first, exact retrieval last) but cannot draw RULER's effective-length curve. The corpus needs both shapes of evidence before it calls a length usable.
- **The allocated number is untouched by either benchmark — and that is the point.** A runner allocating 128K or 200K of KV cache pays the full arithmetic of `memory/kv-cache-design.md` §1.2 for every token, at whatever cache precision, whether the workload is PassKey-shaped (usable) or Math.Calc-shaped (scored ~0 for every 2024 entrant). **Policy consequence (our synthesis, labelled as such): allocating beyond the usable length buys cost without capability** — VRAM, prefill time and latency spent holding positions the model cannot work over. ∞Bench sharpens the consequence: "usable" is *task-dependent*, so a single usable-length figure is itself a simplification — a runner honest about context should expect the usable length for retrieval-shaped chat to exceed the usable length for whole-repository code work, and should not let the retrieval number sell the code workload.

## 6. Applicability

### (a) The personal runner — what ∞Bench does and does not license locally

- **∞Bench itself is not the local probe.** Its realistic tasks need human annotation pipelines, its full run cost its authors ~US$5,000 of API calls plus weeks of manual web-UI entry plus days on an A100 — it is a laboratory instrument. The local effective-context check proposed for the build campaign lives in `papers/ruler.md` §6(a) (a reduced synthetic RULER-style probe at the user's actual `num_ctx`, once per model+quant). ∞Bench's role in that proposal is as the **task-difficulty prior**: it tells the local probe which synthetic shapes are worth including (KV-style indistinguishable-distractor retrieval and a state-tracking task, not passkey alone), because those are the shapes that separated models at scale while passkey sat at ceiling.
- **A workload warning for the chat product.** The fleet's target workload — long character chat — is closest, among ∞Bench's tasks, to En.Dia/En.QA territory (who said what, what happened earlier, aggregation over a long history), and those are precisely the tasks where 2024's best model scored 22.22 (En.QA) and where the field was weak across the board. The honest product inference (our synthesis): a long chat held in raw context is operating in the regime these benchmarks grade harshest, which is the empirical case for the corpus's memory programme (resident anchors, summaries, retrieval — the `memory/` dossiers) rather than for ever-larger `num_ctx`. Context is the most expensive and least reliable memory tier the system has; ∞Bench is part of the evidence.
- **Quantisation — what the paper does and does not say (exact).** ∞Bench contains **no quantisation study of any kind**: no weight-precision ablation, no KV-cache-precision ablation, and no precision sweep. Its three proprietary models were evaluated as hosted services whose serving precision is not disclosed in the paper; its one local model, YaRN-Mistral, was run with the YaRN paper's default decoding hyperparameters on an A100, and the paper does not report a quantised variant. Therefore ∞Bench licenses **no claim** that quantisation preserves or shrinks usable context at 100K+. The corpus-side expectation — that KV quantisation (Wave 3: `papers/kivi.md`, `papers/kvquant.md`) and weight quantisation plausibly shrink the *usable* number before the *allocated* one, since the allocated number is a config integer and the usable number depends on fine discrimination among near-identical entries (Retrieve.KV's exact failure mode) — is **our synthesis, not this paper's finding**, and it is testable only by the local probe of `papers/ruler.md` §6(a) run at deployment precision.

### (b) Honesty in reporting

∞Bench is a model of two reporting virtues the build campaign should copy under the measurement law (IDEA-LEDGER #44). First, **its headline is an average with its spread visible**: "~200K average" always appears beside per-task lengths that include 44K and 75K tasks — a campaign figure for context should likewise never quote a suite average without the distribution under it. Second, **its artefacts are disclosed in-line**: the centre-truncation rule, the multiple-choice softening of Code.Debug (with the reason), the hand-entered evaluations, and the fact that its best Code.Debug number depends on a named prompting technique — each is stated where a reader relying on the number will meet it. The #44 form for any context figure we publish follows directly: name which number it is (trained / scaled / allocated / measured-usable), name the suite and task mix, name the precision, and name any elicitation the score depended on — or the figure is marketing, whoever publishes it.

## 7. Cross-links

- **RULER dossier** (`papers/ruler.md`) — the companion measurement: synthetic, length-swept, with the formal effective-length definition. RULER locates where usability ends; ∞Bench shows what realistic 100K+ work does to models claiming to live there. RULER's Table 1 already positions ∞Bench in its own landscape (~200K, hybrid, controllable context: no) — the two papers cite each other's design space accurately.
- **YaRN dossier** (`papers/yarn.md`) — extends the *scaled* number; ∞Bench's YaRN-Mistral row (19.96 average; 0.00 on Retrieve.KV) is the independent, realistic-task price of one such extension, and a standing exhibit for YaRN §6's warning that scaling confers reach, not capability.
- **LongRoPE dossier** (`papers/longrope.md`) — extends the scaled number to 2048K; ∞Bench (with RULER) is the class of instrument that would have to grade how much of that reach is usable, and neither 2024 suite operates anywhere near 2048K — the usable length of million-token claims is, as of these papers, unmeasured by public realistic benchmarks.
- **KV-cache design** (`memory/kv-cache-design.md`) — the allocation arithmetic the allocated number is charged by, in full, regardless of the usable number established here.
- **MLPerf Inference dossier** (`papers/mlperf-inference.md`) — benchmark-design discipline: disclosed conditions, named scenarios, no summary score without its conditions. ∞Bench's in-line artefact disclosures (§6(b)) are that discipline practised by a benchmark paper; RULER is its anti-gaming form for context claims specifically (configurable tasks that cannot be pre-tuned against).
- **IDEA-LEDGER #44** (`synthesis/IDEA-LEDGER.md`) — the measurement law: a context figure published by the build campaign carries which-of-the-three (here: four, with measured-usable) it is, or it is not real.

## 8. Sources

- Date accessed: **2026-11-15** (all sources).
- arXiv record (v1–v3 history; author list; abstract): https://arxiv.org/abs/2402.13718
- Full text read for task construction, statistics, results, analyses and evaluation appendices (arXiv HTML v1): https://arxiv.org/html/2402.13718v1/
- ACL Anthology record (ACL 2024 Long Papers, pp. 15262–15277; BibTeX; anthology ID 2024.acl-long.814): https://aclanthology.org/2024.acl-long.814 — reached via the Anthology PDF at https://aclanthology.org/anthology-files/anthology-files/anthology-files/pdf/acl/2024.acl-long.814.pdf
- Dataset record (citation block confirming venue, pages and author list): https://huggingface.co/datasets/xinrongzhang2022/InfiniteBench
- Corpus-internal sources: `papers/ruler.md` (this wave), `papers/yarn.md`, `papers/longrope.md`, `papers/mlperf-inference.md`, `memory/kv-cache-design.md`, `synthesis/IDEA-LEDGER.md` (#44).
