# MLPerf Inference Benchmark — Scenarios, Tail Latency, and Rules as Anti-Gaming Machinery

## 1. Full citation

- **Title:** MLPerf Inference Benchmark
- **Authors:** Vijay Janapa Reddi, Christine Cheng, David Kanter, Peter Mattson, Guenther Schmuelling, Carole-Jean Wu, Brian Anderson, Maximilien Breughe, Mark Charlebois, William Chou, Ramesh Chukka, Cody Coleman, Sam Davis, Pan Deng, Greg Diamos, Jared Duke, Dave Fick, J. Scott Gardner, Itay Hubara, Sachin Idgunji, Thomas B. Jablin, Jeff Jiao, Tom St. John, Pankaj Kanwar, David Lee, Jeffery Liao, Anton Lokhmotov, Francisco Massa, Peng Meng, Paulius Micikevicius, Colin Osborne, Gennady Pekhimenko, Arun Tejusve Raghunath Rajan, Dilip Sequeira, Ashish Sirasao, Fei Sun, Hanlin Tang, Michael Thomson, Frank Wei, Ephrem Wu, Lingjie Xu, Koichi Yamada, Bing Yu, George Yuan, Aaron Zhong, Peizhao Zhang, Yuchen Zhou (author list as printed in the paper; 30+ organisations, 200+ contributors credited in the text)
- **Venue / year:** 2020 ACM/IEEE 47th Annual International Symposium on Computer Architecture (ISCA 2020), pp. 446–459. DOI: 10.1109/ISCA45697.2020.00045
- **arXiv:** arXiv:1911.02549 [cs.LG] — https://arxiv.org/abs/1911.02549 (v0.5 suite as described in the paper)
- **Identifier correction (verified 2026-11-15):** arXiv:1910.01500, sometimes cited alongside this dossier's commission, is *MLPerf Training Benchmark* (Mattson et al.), a different paper. The Inference paper is 1911.02549. The two are companions — Inference explicitly "complements MLPerf Training" — but conflating their IDs makes every downstream citation wrong, so the correction is recorded here rather than silently propagated.
- **Governance (current):** MLPerf is run by MLCommons (the MLPerf organisation's successor consortium). Rounds continue as versioned releases (v0.5 in the paper; v4.0–v5.0 added the LLM benchmarks discussed in §5; v5.1 was the current round at access date, per MLCommons announcements).

## 2. The problem as framed

The paper opens with an explosion and a measurement vacuum. Over 100 organisations were building specialised inference chips; systems spanned, in the paper's words, at least three orders of magnitude in power and five in performance, from embedded devices to data centres, across a dozen or more frameworks. Every vendor could produce a number; no two numbers meant the same thing. The paper names the three diversities that make naive comparison meaningless:

1. **Model diversity.** Even for one task — image classification — viable models differ ~50× in FLOPs for a few points of accuracy; SE-ResNeXt-50 and Xception reach ~79% Top-1 at a 2× compute difference. A name alone does not pin a model: "ResNet-50" has multiple subtly different implementations, which is why the suite fixes ResNet-50 **v1.5** specifically. An unstable baseline makes improvement unquantifiable.
2. **Deployment-scenario diversity.** The same model serves a phone taking one picture, a car fusing multiple cameras, a translation website under random arrivals, and a photo library processed in bulk. Batching that is optimal in one scenario is inapplicable or harmful in another. Timing isolated on-device latency "fails to reflect the real-world requirements."
3. **System diversity.** Tasks × models × datasets × frameworks × toolchains × architectures multiply out to near-intractability — compounded by silent porting effects (the paper's example: TensorFlow's NMS vs TensorFlow Lite's fast NMS drops SSD-MobileNet accuracy from 23.1% to 22.3% mAP without any "model change" being announced).

Prior benchmarks (AI Benchmark, EEMBC MLMark, AIXPRT, Fathom, DAWNBench, TBD) each lacked at least one of: industry-wide consensus on models/metrics/rules, explicit quality targets, or deployment scenarios. And underneath all of it sits the oldest gaming incentive in benchmarking: **benchmark specialisation** — a system tuned, cached, pruned, retrained, or seed-aware in ways that win the benchmark and do not exist in production. MLPerf's answer is not a better kernel test. It is a *constitution*: fixed reference models and quality floors, a load generator the submitter does not control, scenarios that define what the number *is*, and an audit process with teeth (§3, §4).

## 3. Core mechanism in our own words

### 3.1 Scenarios define the metric — there is no scenario-free speed

Four scenarios (paper Table II), each a traffic pattern plus its own metric. A result without its scenario is not a result:

| Scenario | Traffic (via LoadGen) | Metric (v0.5) | Stands for |
|---|---|---|---|
| **SingleStream** | One sample per query; next query only after the previous completes | **90th-percentile latency** | Interactive single-user: autocomplete, on-device AR, offline voice transcription |
| **MultiStream** | Queries of *N* samples at a fixed interval (50–100 ms by task); ≤1% of queries may skip an interval | **Number of streams sustained** within the latency bound | Multi-camera / multi-sensor: driver assistance, industrial automation |
| **Server** | One sample per query, **Poisson arrivals** | **Queries/second subject to a latency bound** — ≤1% of vision queries (≤3% translation) may exceed it; bounds 10–250 ms by task (paper Table III) | Online services under random load |
| **Offline** | One query containing all samples (≥24,576) | **Throughput, samples/second** — no latency bound | Batch processing: photo categorisation |

Two disciplines are built into this table and are easy to miss. First, **the Server metric is latency-bounded throughput, not throughput**: the reported QPS is the highest Poisson rate at which the tail-latency promise still holds. Second, **the percentile discipline is scenario-specific, not a blanket "99th"**: SingleStream reports the 90th percentile; MultiStream and Server enforce what is effectively a 99th-percentile bound for vision (97th for translation, hence its smaller query count). Later LLM rounds (§5) apply the 99th percentile to TTFT and TPOT explicitly. Anyone quoting "MLPerf uses the 99th percentile" without a scenario is already misreporting it.

### 3.2 Statistical confidence is part of the benchmark

Tail percentiles are expensive to know. The paper derives required query counts from the tail percentile, a 99% confidence requirement, and a margin of one-twentieth of (1 − tail percentile): a 90th-percentile claim needs 24,576 inferences; a 99th-percentile claim needs **270,336** (262,742 rounded up). Server and MultiStream vision runs therefore process 270K queries; Server is run five times and the minimum taken; every run lasts at least 60 seconds so DVFS/power-management equilibrium, not boost behaviour, is measured. This is the part of MLPerf most often skipped when its numbers are borrowed: the percentile is only as real as the sample count behind it.

### 3.3 Quality floors close the accuracy-for-speed trade

Performance is only valid above a per-model quality target, generally **99% of the FP32 reference** (98% for MobileNet-v1, with specific accommodations documented for the MobileNet family, whose quantisation loss without retraining the paper discusses openly). ResNet-50 v1.5's floor, worked in the paper: 76.456% FP32 Top-1 → ≥75.70% required. Quantisation to a registered list of formats (INT4 through FP32) is allowed with the provided calibration set; **retraining and pruning are prohibited** in the regime the paper describes. A faster number bought with a worse model is not a submission; it is a different, undisclosed benchmark.

### 3.4 LoadGen: the measurer is not the measured

The Load Generator (LoadGen) is a standalone C++ module, owned by MLPerf, sitting outside submitter code. It issues queries per the scenario, times responses, logs for the accuracy checker, runs in separate accuracy and performance modes, and self-checks that its own source was not modified. The System Under Test (SUT) boundary is explicit: dataset, LoadGen and accuracy script are fixed; the SUT is the submitter's. Untimed preprocessing/compilation/warmup is allowed — a deliberate, disclosed concession (there is no vendor-neutral preprocessing, and camera-integrated systems legitimately receive ideal-format inputs) — and its disclosedness is the point: the exception is in the rules, not discovered in an audit.

### 3.5 Divisions and categories: comparability is labelled, not assumed

- **Closed division:** same model (mathematically equivalent implementation), same dataset, same quality target, equivalent pre/post-processing, calibration allowed, no retraining. This is the apples-to-apples division — the only one whose numbers compare across submitters.
- **Open division:** same task, but model, quality target, pre/post-processing and retraining are all free, with deviations documented. Open results are, in the paper's words, "directly comparable neither with each other nor with closed submissions" — and the division *says so on the label*.
- **Categories:** Available / Preview / Research-Development-Other (RDO), so a buyable system's number is never silently pooled with a laboratory prototype's.

### 3.6 The audit is a test suite aimed at cheating

Submissions go to a public repository for peer review, backed by validation experiments designed against specific gaming strategies: **random-log accuracy verification** (performance-mode outputs spot-checked against accuracy mode); **caching detection** (unique-index vs duplicate-index runs — a cache shows up as a speed difference; caching is prohibited because production hit rates are unmodelable and the small datasets are entirely cacheable); **alternate-random-seed testing** (optimisations keyed to LoadGen's fixed seed are prohibited and detectable); **custom-dataset substitution** (quality/performance compared off the reference data). §4 records what the audit actually caught — it was not theatre.

## 4. Reported results — as reported, with context

All figures are the paper's own, for **v0.5 (October 2019 call)**: five reference workloads (ResNet-50 v1.5 and MobileNet-v1 image classification; SSD-ResNet-34 and SSD-MobileNet object detection; GNMT translation) on pre-LLM hardware. **No figure below is an LLM figure, a tok/s figure, or a modern-accelerator figure.**

- **Scale of the exercise:** >600 submissions from 14 organisations, >30 systems; 595 cleared as valid after audit. Closed-division coverage was broad across tasks (ResNet-50 the most popular, but under 3× GNMT, the least) and across processor types (CPU, GPU, DSP, FPGA, ASIC).
- **Four orders of magnitude:** the performance spread between the smallest and largest systems was ~10,000×; several individual model/scenario cells spanned 100×. The paper reads this as evidence the method spans embedded-to-datacentre, not as a ranking.
- **The headline finding — scenario sensitivity (paper §VI-B, Fig. 6):** every system delivered less throughput in Server than in Offline. The latency constraint plus suboptimal batching cost **3% to >50% depending on system and model**: one system (B in the paper's anonymised figure) lost ~50%+ on all three models examined; another (A) lost ~40% on translation but ~10% on vision. By model: translation (GNMT) lost **39–55%** across all five systems reporting it; ResNet-50 lost 3–35% (mean ~20%); MobileNet-v1 under 10% on average. The paper's stated lesson, verbatim in substance: *a performance comparison with unconstrained latency has little bearing on a latency-constrained scenario*, and the impact of latency constraints *extrapolates poorly across models* — even between two image classifiers the average loss differed ~2×.
- **Modeled ≠ measured (paper §VII-D):** SSD-ResNet-34 requires 175× more operations per image than SSD-MobileNet, yet measured throughput was only 50–60× lower — a consistent ~3× gap between op-count prediction and delivered performance. FLOP counts are not a performance model.
- **The audit's yield (paper §VII-E):** ~40 issues found in ~180 closed-division results; only **166 released**. Issues ranged from missed quality targets and latency bounds to rule misinterpretation. Auditability was "necessary for ensuring result integrity and reproducibility" — the paper's conclusion, earned by its own numbers.
- **Open division:** 429 results, including 4-bit quantisation explorations, alternative models, results under tighter-than-closed latency bounds, and concurrent use of multiple mobile accelerators — recorded as exploration, explicitly not as comparable rankings.
- **What the paper refuses to produce:** a summary score. "MLPerf Inference provides no 'summary score'" — weighting tasks into one number is subjective and submitter-serving. The refusal is a result in itself.

## 5. What it changed in practice

**The reporting floor.** MLPerf Inference became the industry's default public language for inference claims: vendor launches, cloud instance announcements and accelerator comparisons are routinely stated as MLPerf results (division, scenario, version) or are criticised for not being. Its durable exports are methodological rather than numerical: scenario-first reporting, latency-bounded throughput, quality floors, a submitter-independent load generator, public submission repositories, and peer review with anti-gaming tests. MLCommons continues to run versioned rounds; the suite has absorbed recommendation, speech, medical imaging, BERT-class language models and, eventually, LLMs.

**The LLM era arrived inside MLPerf — later, and by extension (public picture as of 2026-11-15, per MLCommons announcements).** The 2020 paper's workloads predate generative LLM serving entirely: no tokens, no prefill/decode split, no KV cache. The token-level discipline came in subsequent rounds:

- **v4.0 (2024)** added Llama 2 70B as an LLM benchmark: Offline scored in **tokens/second**; Server scored under **99th-percentile TTFT ≤ 2,000 ms and TPOT ≤ 200 ms**. An Interactive variant tightened these to **450 ms / 40 ms** (≈25 tok/s per user at the tail).
- **v5.0 (April 2025)** added Llama 3.1 405B Instruct (long-context summarisation-style workload; mean input/output ≈9,400/680 tokens as announced) with 99th-percentile **TTFT 6 s / TPOT 175 ms** in Server, reference implementation on vLLM — the consortium adopting the field's serving stack as its harness substrate.

So the fair statement is two-sided. The TTFT/TPOT split and token throughput *are* now MLPerf metrics — but they are 2024–2025 extensions of the 2020 constitution, not contents of the ISCA paper, and dossiers that cite "MLPerf (2020)" for a TTFT number are committing exactly the version-erasure this corpus exists to prevent. Conversely, much LLM-era practice still lives *outside* MLPerf: per-request inter-token-latency distributions, goodput-at-SLO reporting (see `papers/distserve.md`), prefix-cache hit effects, and single-user interactive benchmarks are governed by engine-project conventions (vLLM/SGLang benchmarking guides) and serving papers, not by MLCommons rounds. MLPerf also remains a *datacentre-and-edge consortium* instrument: its cost of entry (270K-query runs, review cycles, reference workloads at 70B–405B scale) is calibrated for vendors, not for a person benchmarking a local runner — §6b is the scaled-down translation.

**Limits worth stating plainly.** Closed-division equivalence rules fit fixed reference models better than rapidly mutating LLM stacks; rounds necessarily lag the serving frontier (disaggregated serving, speculative decoding and prefix caching all reached production before they reached a round); and a consortium benchmark measures what submitters choose to submit — coverage gaps (the paper already notes GNMT MultiStream drew zero submissions) are information, not oversight.

## 6. Applicability

### (a) Our own programme — the corpus's grading discipline, restated as methodology

*[Our synthesis — the rules below are this programme's, drawn from the papers in this wave and the memory corpus; they are not quotations from MLPerf.]*

MLPerf's constitution and this programme's house rules are the same shape at different scales. The mapping is exact enough to state as a table:

| MLPerf mechanism | Our rule (programme synthesis) |
|---|---|
| Scenario defines the metric | **Phase defines the metric.** Prefill and decode are reported separately (tok/s by phase, TTFT vs TPOT/gap); a blended tok/s is a scenario error, the local equivalent of quoting Offline throughput as Server performance. |
| Quality floor before performance counts | **Raw-oracle grading before speed counts.** Faithfulness is graded by teacher-forcing rank + logit gap on the *raw* prompt, near-tie band rank ≤2 with sub-logit gap = faithful, oracle backend recorded per row (see `aesir/aesir-ideas-for-ollama.md`). A faster build that diverges is a different model, exactly as a sub-floor MLPerf run is not a submission. |
| LoadGen outside submitter code; comparator is fixed and known | **Comparator-artifact discipline.** Template rendering, BOS rendering, backend mismatch and step-0 boundary effects are a named verdict class: check the comparator before suspecting the engine. Never grade against `llama-cli --single-turn` (it template-renders — a different input). |
| Query counts derived from the percentile claimed | **No percentile without its n.** A p99 latency claim on 20 requests is the local form of the fraud MLPerf's 270,336-query rule exists to prevent. State n, repetitions, and spread (median + distribution), or report a mean and call it one. |
| Minimum run duration; equilibrium, not boost | **Sustained, not peak.** Warm/steady-state figures govern; cold readings (page-in, first-touch) are labelled cold. The corpus's discarded 56.7 tok/s "cold" reading against a ~1,010 tok/s warm baseline (MEMORY-COMPENDIUM §9.2) is this rule's home exhibit. |
| System description file with every submission | **Machine-state disclosure.** Hardware, clocks/governor, co-tenants, contention, memory state. *Walls measured under contention are not baselines* — the Z13 lesson, voiding or flagging contended runs, is MLPerf's system-description discipline applied to a fleet of one. |
| Audit tests aimed at caching / seed-gaming | **As-reported, with context.** Every number in this corpus carries its version, workload and baseline — the DistServe dossier's v1-vs-v3 headline reconciliation (4.48×/10.2× vs 7.4×/12.6×) is the audit habit applied to reading, not submitting. |
| No summary score | **No summary score.** This corpus likewise refuses a single "fastest runner" number: per-phase, per-scenario, per-quality-band results, or nothing. |

Vidur (§ sibling dossier) adds the complementary half: where MLPerf disciplines *measurement*, Vidur disciplines *prediction* — a simulator's numbers are only citable with their validation error against real runs attached. Our capacity claims (what fits, what a second session costs) should carry the same: predicted vs measured, error stated, or labelled unvalidated.

### (b) What a personal-runner benchmark should report — a proposed minimal disclosure set

*[Engineering judgement, labelled as such. This is a proposal by this dossier, scaled from MLPerf's constitution and MEMORY-COMPENDIUM Ch. 9 to one user, one machine, one runner. It is not an MLCommons requirement and no external body endorses it.]*

A local benchmark result (a blog post, a dossier §4, a commit message claiming a speedup) should be considered reportable only if it discloses:

1. **Model + quant, in bytes:** exact model build/checksum where feasible, quantisation format, and file size *and* active bytes under the run's spill/residency state (they differ; Ch. 9 §9.2).
2. **Prompt/decode split:** prompt token count, generated token count, and the sampling/settings that determine output length; prompt-processing tokens never folded into a generation rate.
3. **Tok/s by phase:** prefill (prompt) tok/s and decode tok/s separately; for interactive claims, TTFT and worst/typical inter-token gap alongside decode tok/s.
4. **Memory ledger:** weights resident, KV bytes (per token × context in force), allocator-held vs resident where the engine exposes it — the four-numbers discipline of Ch. 9 §9.1, reduced to the lines the runner can actually produce, with the missing lines named as missing.
5. **Machine state:** machine identity, accelerator + memory size, clocks/governor if known, what else was running, warm vs cold, and the machine's *measured* sustained bandwidth roof where a bandwidth claim is made (STREAM discipline, §7) — or the explicit label "roof unmeasured."
6. **Repetitions and spread:** n runs, median and range/spread; single runs labelled single runs.
7. **Faithfulness spot-check:** for any change claiming speed: the raw-oracle grade (rank/logit-gap band) on a fixed prompt set, or the explicit label "correctness not re-graded."

Seven lines. A claim missing one is not necessarily wrong — it is *incomplete in a named way*, which is the whole MLPerf insight restated for a fleet of one: comparability is a disclosure property before it is a performance property.

## 7. Cross-links

- `memory/memory-wall-and-roofline.md` — the STREAM discipline is MLPerf's ancestor in the memory line: McCalpin's sustained-vs-peak correction ("vendors to pay attention to sustained, rather than peak, bandwidths") is the same anti-gaming move as MLPerf's latency-bounded throughput — both refuse the number the hardware can touch once in favour of the number it can hold under stated conditions. MLPerf adds what STREAM lacks (quality floors, traffic scenarios, audit); STREAM adds what MLPerf v0.5 lacks (a measured roof against which any throughput can be expressed as % of sustained peak). A complete local report uses both.
- `aesir/aesir-ideas-for-ollama.md` — raw-oracle grading is the quality-floor half of this dossier's §6a: MLPerf will not count performance below an accuracy target; Aesir will not count performance from an engine whose outputs diverge from the raw-prompt oracle beyond the near-tie band. Same constitution, different oracle (task accuracy vs per-token rank/gap).
- `memory/MEMORY-COMPENDIUM.md`, Chapter 9 (Measurement Discipline) — this dossier is Ch. 9's paper foundation on the *benchmark-governance* side: Ch. 9 §9.2's red-flag list (batch/context/quant unstated; prompt tokens folded into generation rate; peak vendor bandwidth as roof; single run on a shared machine) is MLPerf's scenario/quality/audit machinery translated to memory claims, and §9.3's MimirAlloc protocol (identical legs, pre-registered bars, evidence packets) is the audit process rebuilt for a one-lab programme. What this wave adds to Ch. 9: the consortium-scale proof that the discipline works (595/600+ audited, ~40 issues caught in closed alone) and the statistical query-count derivation (§3.2) that Ch. 9's "no percentile without its n" abbreviates.
- `papers/vidur.md` (this wave) — the prediction counterpart: MLPerf says how to *measure* honestly; Vidur says how to *avoid measuring* exhaustively without lying about it.
- `papers/distserve.md`, `papers/sarathi-serve.md` — goodput and TTFT/TPOT discipline: the LLM-era metrics MLPerf adopted in v4.0 were forged in the serving literature first; the chronology matters and is recorded in both places.

## 8. Sources

All sources accessed **2026-11-15**.

1. Reddi, V. J., et al. (2020). *MLPerf Inference Benchmark.* ISCA 2020, pp. 446–459. DOI 10.1109/ISCA45697.2020.00045. Full text via arXiv:1911.02549 (ar5iv HTML rendering) — read for the abstract (>30 organisations, >600 measurements, 14 organisations, >30 systems), the three diversities (§I–II), scenario definitions and metrics (Table II), latency bounds (Table III), quality targets (ResNet-50 76.456% → 75.70% floor, §III-B), the statistical query-count derivation (24,576 @ 90th; 270,336 @ 99th; 99% confidence, §III-D), LoadGen design and untimed-preprocessing concession (§IV), closed/open divisions and Available/Preview/RDO categories (§V-A), the four audit tests (§V-B), the no-summary-score refusal (§V-C), scenario-sensitivity findings (Server-vs-Offline losses: GNMT 39–55%, ResNet-50 mean ~20%, MobileNet <10%, §VI-B / Fig. 6), the op-count vs measured-throughput gap (175× ops → 50–60× throughput, §VII-D), and the audit yield (~40 issues, 166/~180 closed results released, §VII-E).
2. arXiv record for arXiv:1911.02549 — verified title, author list head, and identity as the Inference paper; cross-checked against the ISCA proceedings record (DOI above, via OpenAlex / University of Toronto ecosystem copy).
3. Mattson, P., et al. (2019). *MLPerf Training Benchmark.* arXiv:1910.01500 — identity verified for the §1 correction: 1910.01500 is the Training paper, not Inference.
4. MLCommons (2025-04-02). *MLPerf Inference v5.0 Advances Language Model Capabilities for GenAI.* https://mlcommons.org/2025/04/llm-inference-v5/ — for §5's LLM-era state as publicly announced: Llama 2 70B introduced in v4.0 (Server 99th-percentile TTFT 2,000 ms / TPOT 200 ms; Interactive 450 ms / 40 ms), Llama 3.1 405B added in v5.0 (TTFT 6 s / TPOT 175 ms at the 99th percentile; mean input/output ≈9,400/680 tokens; vLLM reference implementation), token-throughput scoring for Offline.
5. MLCommons inference rules summaries (scenario/metric table as rendered in the MLCommons inference_policies documentation mirrors, accessed 2026-11-15) — corroboration for current-round scenario mechanics (SingleStream 90th-percentile, MultiStream 99th, Server/Interactive Poisson with per-benchmark TTFT/TPOT bounds at the 99th percentile, Offline ≥24,576 samples) used only for the §5 present-day picture, not attributed to the 2020 paper.
