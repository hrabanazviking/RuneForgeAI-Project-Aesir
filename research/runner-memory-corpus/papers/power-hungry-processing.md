# Power Hungry Processing: Watts Driving the Cost of AI Deployment?

## 1. Full citation

- **Title:** Power Hungry Processing: Watts Driving the Cost of AI Deployment?
- **Authors:** Alexandra Sasha Luccioni (Hugging Face), Yacine Jernite (Hugging Face), Emma Strubell (Carnegie Mellon University; Allen Institute for AI)
- **Venue / year:** ACM Conference on Fairness, Accountability, and Transparency (ACM FAccT '24), June 3–6, 2024, Rio de Janeiro, Brazil. ACM, 21 pages. DOI: 10.1145/3630106.3658542
- **arXiv:** arXiv:2311.16863 [cs.LG] — https://arxiv.org/abs/2311.16863 (submitted 28 Nov 2023, v1; last revised 15 Oct 2024, v3 — the version read for this dossier)
- **Companion artefact:** the authors released their code, Code Carbon logs, and an interactive demo for exploring the per-model results; the paper's own experimental total is reported in §4 below.

## 2. The problem as framed

Before this paper, the environmental accounting of machine learning was almost entirely an accounting of **training**. Training is easy to bound — one run, one cluster, one time window — and its headline numbers are dramatic, so it absorbed the field's attention from Strubell et al. (2019) onward. Deployment had no equivalent ledger. What existed were top-down shares quoted from operators — the paper cites AWS's estimate that inference is 80–90% of ML cloud demand, Meta's attribution of roughly one-third of its internal end-to-end ML carbon footprint to inference, and Google's 60% inference / 40% training split of ML energy — none of which say what a *query* costs, for *which task*, on *which kind of model*.

That gap mattered because the industry was simultaneously changing what a deployed model *is*. The shift the paper targets is from many small, task-specific, fine-tuned models (a BERT for classification, a BERT for extractive QA) to single multi-purpose, generative systems (the BLOOMz / Flan-T5 families in the study; GPT-class systems in the market) asked to do every task zero-shot. Judged on training cost alone, one multi-purpose model can look efficient — train once, serve everything. The paper's framing move is to insist that the judgement be made over the model's *lifetime*: inference is repeated billions of times, so a per-query penalty, however small, compounds past any one-off training saving. §4's parity calculation is that argument made numeric.

Translated into this corpus's terms: the runner community optimises tokens/second, a rate. This paper argues the binding quantity for deployment is often a *budget* — energy per task performed, and the carbon that follows from where the energy comes from — and that in 2023 that budget was essentially unmeasured at task granularity. A tok/s number cannot answer "what does it cost to run this, a thousand times, forever?"; a kWh-per-1,000-inferences number can.

## 3. Core method in our own words

- **Unit of account:** energy (kWh) and carbon (g CO₂eq) **per 1,000 inferences** on a representative benchmark dataset. Not per token, not per second — per completed task instance, aggregated over 1,000. That choice is deliberate: it is the granularity at which a deployment decision ("which model serves this feature?") is actually made.
- **Corpus of models:** **88 models across 10 tasks and 30 datasets**, spanning text and vision. The 10 tasks: text classification, token classification, extractive question answering, masked language modelling, text generation, summarisation (text); image classification, object detection (vision); image captioning and image generation (multimodal). Three datasets per task, drawn from the most-downloaded on the Hugging Face Hub.
- **Two model classes, compared head-to-head:** (i) *task-specific* models — for each task, the 8 most popular (by Hub downloads) models fine-tuned for that task; (ii) *multi-purpose* models — 8 zero-shot models tested across a 3-task subset (text classification, extractive QA, summarisation) where a unified architecture could do all three: four Flan-T5 sequence-to-sequence models (base 222M, large 750M, XL 2.8B, XXL 11B) and four BLOOMz decoder-only models (560M, 1B, 3B, 7B), prompted with a constant zero-shot prompt format.
- **Protocol:** each model ran **1,000 inferences per dataset, sequentially — explicitly without batching**, to reflect in-situ deployment variability that makes batching hard; each set repeated **10 times** for statistical significance. Inference via the Transformers library. Performance/accuracy of both classes was also checked (evaluate library; LM Evaluation Harness for the zero-shot models) so the energy comparison is not silently a quality comparison.
- **Hardware and instrument:** all experiments on **one node of 8× NVIDIA A100-SXM4-80GB on AWS**, with each experiment running on a single GPU — the paper discloses (footnote) that the idle draw of the node's other GPUs is included in the reported numbers. Energy and carbon measured with the **Code Carbon** package, which also logs a per-component (GPU / CPU / RAM) breakdown. Carbon conversion uses the grid intensity of AWS us-west-2 (Oregon): **297.6 g CO₂eq/kWh**. The paper is explicit that energy transfers across regions on the same hardware while carbon does not — hence both are reported.
- **Training-parity extension:** for the BLOOMz family only, the authors combined published BLOOM training logs and BLOOMz fine-tuning logs with their measured per-inference energy to compute how many inferences equal the training + fine-tuning energy (the "cost parity" point, §4).

What the method is *not*: no batching, no serving stack, no quantisation sweep, no latency measurement, one GPU type, one cloud region, open models as of 2023. The paper names most of these itself as scope, not oversight — it is a first systematic map, not a serving benchmark (contrast `papers/words-to-watts.md`, which measures an LLM serving-adjacent stack directly, and Wave 10's `papers/mlperf-inference.md`, whose rule is the one §4 follows: no number without its conditions).

## 4. Reported results — as reported, with full context

All figures are the paper's own. Conditions applying to **every** figure in this section unless stated otherwise: A100-SXM4-80GB (single GPU in an 8-GPU AWS node, sibling idle draw included), Code Carbon measurement, sequential unbatched inference, 1,000 inferences × 10 repetitions, carbon at 297.6 g CO₂eq/kWh. Following Wave 10's rule — *no number without its conditions* — no figure below should be quoted stripped of those conditions.

**Task dominates (task-specific models, mean kWh per 1,000 inferences, paper Table 2):**

| Task | Mean kWh / 1,000 | Std |
|---|---|---|
| Text classification | 0.002 | 0.001 |
| Extractive QA | 0.003 | 0.001 |
| Masked language modelling | 0.003 | 0.001 |
| Token classification | 0.004 | 0.002 |
| Image classification | 0.007 | 0.001 |
| Object detection | 0.038 | 0.02 |
| Text generation | 0.047 | 0.03 |
| Summarisation | 0.049 | 0.01 |
| Image captioning | 0.063 | 0.02 |
| Image generation | 2.907 | 3.31 |

- The spread from cheapest to most expensive task mean is **a factor of over 1,450** (0.002 → 2.9 kWh per 1,000). Generative tasks cost, on average, **over 10×** the classification tasks at the same inference count (~0.05 vs 0.002–0.007 kWh per 1,000).
- The paper's own calibration: an average smartphone charge is 0.022 kWh; the most efficient text-generation model measured used ~9% of one charge per 1,000 inferences, while the least efficient image-generation model used the equivalent of **522 charges per 1,000 inferences** (≈11.49 kWh; roughly half a charge per single image). The most carbon-intensive image model, stable-diffusion-xl-base-1.0, emitted 1,594 g CO₂eq per 1,000 inferences.
- **Task structure explains more variance than model size.** Size correlates with emissions *within* a modality/task family, but a ~500M-parameter image-generation model emits orders of magnitude more than text-to-category models (~100 g vs ~0.6 g CO₂eq per 1,000 in the paper's comparison). Mechanism, as the paper states it: output-space and output-length. A classifier emits one decision from a tiny output space; a generator autoregressively emits many tokens (in their setup, text generation produced 10 new tokens per input vs masked LM's one — and measured ~15× the energy), and an image model emits raw pixels.
- **Within generation, output length is the driver**, and it hits decoder-only models harder: emissions rise with average output length with a steeper slope for BLOOMz (decoder-only) than for Flan-T5 (sequence-to-sequence), which the paper attributes to decoder-only attention over the full sequence at every step.

**The multi-purpose gap (the paper's headline):**

- On the two discriminative tasks, task-specific models beat **both** multi-purpose families by **orders of magnitude** at the same task and dataset. Worked example from the text: on extractive QA (SciQ), the most efficient task-specific models emit ~**0.3 g CO₂eq per 1,000 inferences**; multi-purpose models emit ~**10 g** for the same work.
- Named-model comparisons from the discussion: a BERT-large fine-tuned for extractive QA averages **0.70 g CO₂eq per 1,000 queries**, vs 2.36 g (Flan-T5-base) and 2.34 g (BLOOMz-560M) — the *smallest* multi-purpose models, ~3× more. For text classification, bert-base-multilingual-uncased-sentiment emits **0.32 g per 1,000**, vs 2.66 g (Flan-T5-XL) and 4.67 g (BLOOMz-7B) — ~8–15× more, at far larger parameter counts.
- On the generative task (summarisation) the gap narrows but does not close: task-specific models ~4–10 g CO₂eq per 1,000 vs multi-purpose ~20–30 g, a difference the paper attributes mostly to size (task-specific summarisation models ≤600M parameters vs multi-purpose up to 11B).
- The gap persists **when controlling for parameter count** (abstract and §4.2) — it is an architecture-and-paradigm cost, not only a size cost. The paper's mechanism: a fine-tuned classifier answers with a softmax over (e.g.) two classes; a general model must *generate* the word "positive" from its full vocabulary, autoregressively, through a much larger network.
- **Within the multi-purpose class:** at matched size, sequence-to-sequence is cheaper than decoder-only — Flan-T5-XL (2.8B) averages ~2 g CO₂eq per 1,000 less than BLOOMz-3B (3B); Flan-T5-XXL (11B, 11.48 g / 0.083 kWh per 1,000 averaged across the three tasks) is cheaper than the smaller BLOOMz-7B (7B, 14.46 g / 0.104 kWh per 1,000). Table 3 averages, per 1,000 inferences across the studied tasks: Flan-T5 family 0.026–0.083 kWh; BLOOMz family 0.054–0.104 kWh, rising with size within each family.

**Training ↔ inference parity (BLOOMz family, paper Table 5):** measured inference energy per single inference rises from 5.4×10⁻⁵ kWh (BLOOMz-560M) to 1.0×10⁻⁴ kWh (BLOOMz-7B). Against published training + fine-tuning energy, parity — the inference count at which cumulative deployment energy equals creation energy — is **~205 million inferences (560M) to ~593 million (7B)**, growing with model size. The paper's gloss: a huge number for one instance, a few weeks-to-months of traffic for a popular multi-instance deployment. For scale, the cited prior figure for the deployed BLOOM-176B API was ~0.004 kWh per query — ~40× BLOOMz-7B's per-query figure at ~25× the size, and measured *with* API deployment overhead this study excludes.

**The study's own footprint, disclosed in its ethics statement:** 754.66 kWh consumed, 178.97 kg CO₂eq emitted, to produce these measurements.

## 5. The metric lesson

*[Paper-supported statements are unmarked; our inference for runner practice is labelled.]*

The paper's unit — **energy per completed task** — exposes a blindness in rate metrics. Two systems with identical tokens/second can differ by an order of magnitude in energy per answer if one generates longer outputs, attends over longer contexts, or is a general model doing a specialist's job. Conversely, a *slower* system can be the cheaper one per task. The paper demonstrates the second blindness directly: its cheapest-per-task models (small fine-tuned encoders) are not the systems anyone would rank by generative throughput at all — the tok/s leaderboard and the joules-per-task leaderboard are populated by different machines.

Three consequences the paper supports:

1. **"Per token" is itself task-contaminated.** Because output length drives energy (§4), a joules/token figure is only comparable at matched output-length distributions. The paper's per-1,000-*tasks* unit sidesteps this by fixing the task; a runner reporting joules/token must fix (and disclose) the workload just as strictly — Wave 10's disclosure rule applied to energy.
2. **Model choice is an energy decision before hardware choice is.** The task-specific vs multi-purpose gap (orders of magnitude, size-controlled) is larger than any hardware-generation effect reported in either paper of this wave. Routing a well-defined discriminative job to a general chat model is, energetically, the most expensive "optimisation" available to get wrong.
3. **Generality is a subscription, not a purchase.** The parity numbers convert the training-vs-inference debate into arithmetic: whatever generality saves in training is repaid, with interest, per query, forever. Whether it is worth it is a utility judgement — the paper explicitly asks that it be *weighed intentionally* rather than defaulted.

*[Our inference, labelled:]* for a local runner, the transferable form of the paper's unit is **joules per response at a stated prompt/output profile**, reported alongside decode tok/s — the pair, not either alone. A configuration that wins tok/s by burning disproportionate watts (higher clocks, a bigger model than the task needs, an unbatched general model for a classification-shaped job) is the laptop-scale instance of exactly the deployment pattern this paper measured at datacentre scale.

## 6. Applicability

### (a) The personal fleet

*[Engineering judgement, labelled as such — the paper measured A100s in a datacentre; everything in this subsection is our transfer, not its claim.]*

Volmarr's fleet inverts the paper's cost function: on a 6 GB RTX 2060 Max-Q laptop or a Strix Halo APU, energy is not a bill line, it is **heat in a chassis and charge in a battery**. The paper still transfers, in three specific ways:

- **Task routing is the largest lever a personal user actually controls.** The orders-of-magnitude task-specific gap says: embedding, classification, reranking, and extraction-shaped jobs should not be routed through the big chat model when a small specialist (or a much smaller LLM) does them comparably. On a laptop this is the difference between a fan-silent background process and a thermal-throttling one.
- **Output length is a battery setting.** The paper's output-length → energy slope (steepest for decoder-only models — i.e. for every chat LLM in the fleet) means max-token caps, concise system prompts, and stopping discipline are energy controls, not just style controls. A runner that exposes an "efficiency mode" would, on this evidence, be mostly an output-length and model-size mode.
- **What an energy-aware runner could expose:** a per-request energy estimate (joules, and % of battery) accumulated from measured device power over the request — the laptop analogue of the paper's per-1,000-inferences ledger, at n=1 granularity; a session total in Wh next to the token total; and a small-model/specialist suggestion when a request pattern is classification-shaped. None of this requires datacentre instrumentation: the quantity is average watts × seconds, both locally observable. The honest caveat is the paper's own footnote at laptop scale: whole-system draw includes idle and sibling consumers, so a laptop energy figure is a *system* figure and should be labelled as one.

### (b) The corpus

Wave 10 (`papers/mlperf-inference.md` §6b) proposed a seven-line minimal disclosure set for any local benchmark claim: model+quant in bytes; prompt/decode split; tok/s by phase; memory ledger; machine state; repetitions and spread; faithfulness spot-check. This dossier proposes the **energy addition** — an eighth line, required whenever a claim touches efficiency, battery, thermals, or "lightweight" operation, and recommended for all benchmark reports:

> **8. Energy:** total energy for the run (Wh or J, instrument or estimator named — e.g. Code Carbon, DCGM/nvidia-smi integration, RAPL, wall meter), mean power draw (W), and the derived **joules per output token** and **joules per response** at the §6b-line-2 prompt/output profile; idle/baseline draw of the machine stated or explicitly labelled unmeasured; thermal state (sustained vs cold) cross-referenced to line 5.

The form follows this paper (energy per task, instrument named, idle disclosed — its A100 footnote is the model) and its sibling (joules/token as the LLM-native derived unit). A tok/s claim without line 8 remains reportable as a *speed* claim; it is not reportable as an *efficiency* claim.

## 7. Cross-links

- `papers/words-to-watts.md` (this wave, sibling) — the same argument from inside LLM serving: Luccioni et al. fix the task and vary the model class across all of ML; Samsi et al. fix the model family (LLaMA) and vary hardware, sharding, batch, and power cap, arriving at joules/token. Read together: model/task choice sets the order of magnitude; serving configuration then moves you within it — except power capping, which moves the frontier itself.
- `papers/mlperf-inference.md` (Wave 10) — the governance parent of both energy dossiers: MLPerf's constitution (scenario defines the metric, quality floor, no number without its system description) is why §4 above carries its conditions in-line, and §6b's energy line is written as an amendment to that dossier's minimal disclosure set. Note the chronology honestly: MLPerf's own power measurement (MLPerf Power) is a later, parallel development, not part of the 2020 ISCA paper.
- `papers/vidur.md` (Wave 10) — the prediction counterpart: Vidur simulates latency/throughput/cost-per-dollar for configurations not yet run. An energy-extended Vidur-style search is the obvious joint future — QPS-per-watt as the objective where Vidur used QPS-per-dollar — but neither paper in this wave performs it; the link is a programme direction, not a reported result.
- `memory/memory-technologies-dram-cxl.md` — the microscopic version of this dossier. Horowitz's per-access energy ladder (see the NPU dossier below for the table: a 32-bit DRAM access at ~640 pJ vs ~5 pJ for a small SRAM read at 45 nm — roughly two orders of magnitude per hierarchy jump) prices the *single memory touch*; Luccioni et al. price the *millionth inference*. They are the same ledger at opposite ends: decode is a DRAM-streaming workload, so the system-level kWh-per-1,000 figures in §4 are, mechanistically, the Horowitz ladder multiplied by bytes-moved-per-token × tokens. Any technique that reduces bytes moved per token (quantisation, KV compression, SRAM residency) is simultaneously a speed technique and an energy technique — this paper is the system-level evidence that the energy side of that identity is large enough to measure from the wall.
- `memory/npu-memory-and-dataflows.md` — energy per access *is* the NPU argument: dataflow architectures exist because keeping accesses on the cheap rungs of the Horowitz ladder beats making the arithmetic faster. This dossier supplies the deployment-scale confirmation of that dossier's premise — at fleet scale, the models that avoid unnecessary computation-and-movement (task-specific, right-sized, shorter outputs) win by the same orders of magnitude the ladder predicts.

## 8. Sources

All sources accessed **2026-11-15**.

1. Luccioni, A. S., Jernite, Y., & Strubell, E. (2024). *Power Hungry Processing: Watts Driving the Cost of AI Deployment?* ACM FAccT '24, pp. (21 pages). DOI: 10.1145/3630106.3658542. Full text read via the arXiv v3 PDF (arXiv:2311.16863) — for the abstract's first-systematic-comparison claim and orders-of-magnitude finding; the inference-share citations (AWS 80–90%, Meta ~⅓, Google 60/40, §1); the method (88 models, 10 tasks, 30 datasets, 1,000 inferences × 10 repetitions, sequential/unbatched, 8× A100-SXM4-80GB AWS node, single-GPU runs with sibling idle included, Code Carbon, us-west-2 at 297.6 g CO₂eq/kWh, §3); Table 2 task means (text classification 0.002 → image generation 2.907 kWh per 1,000) and the >1,450× spread, smartphone-charge calibration, and output-length mechanism (§4.1); the multi-purpose comparison (SciQ ~0.3 g vs ~10 g CO₂eq per 1,000; summarisation 4–10 g vs 20–30 g; Table 3 Flan-T5 0.026–0.083 vs BLOOMz 0.054–0.104 kWh per 1,000; seq2seq-vs-decoder-only at matched size, §4.2); Table 5 parity (5.4×10⁻⁵–1.0×10⁻⁴ kWh per inference; ~205M–~593M inferences to parity, §4.3); the discussion's named-model comparisons (BERT QA 0.70 g; sentiment 0.32 g vs Flan-T5-XL 2.66 g / BLOOMz-7B 4.67 g per 1,000, §5); and the study's own 754.66 kWh / 178.97 kg CO₂eq disclosure (Ethical Considerations).
2. arXiv record for arXiv:2311.16863 — verified title, author list, submission/revision history (v1 28 Nov 2023; v3 15 Oct 2024), subject (cs.LG), and the FAccT '24 journal reference with its DOI.
