# RULER — RULER: What's the Real Context Size of Your Long-Context Language Models?

## 1. Full citation

- **Title:** RULER: What's the Real Context Size of Your Long-Context Language Models?
- **Authors (COLM / arXiv v3):** Cheng-Ping Hsieh, Simeng Sun, Samuel Kriman, Shantanu Acharya, Dima Rekesh, Fei Jia, Yang Zhang, Boris Ginsburg
- **Affiliation (as listed in the paper):** NVIDIA (contact emails `chsieh,simengs@nvidia.com` in the paper text)
- **Venue / year:** Conference on Language Modeling (COLM 2024) — listed in the COLM 2024 proceedings; arXiv comment field reads "COLM 2024".
- **arXiv:** arXiv:2404.06654 [cs.CL] — https://arxiv.org/abs/2404.06654 — v1 submitted 9 April 2024; v3 (the COLM version) 6 August 2024. DOI: 10.48550/arXiv.2404.06654.
- **Code (as reported in the paper):** https://github.com/hsiehjackson/RULER
- **Identifier check (verified 2026-11-15):** the coordinator's identifiers check out — title, NVIDIA authorship, COLM 2024 venue and arXiv:2404.06654 are all confirmed at the arXiv record. Two version facts must travel with any citation, because the paper changed materially between versions:
  - **v1 (April 2024)** lists **seven** authors (no Yang Zhang) and evaluates **ten** long-context LMs; its abstract concludes that "only four models (GPT-4, Command-R, Yi-34B, and Mixtral) can maintain satisfactory performance at the length of 32K."
  - **v3 / COLM (August 2024)** lists **eight** authors (Yang Zhang added) and evaluates **17** long-context LMs (Gemini-1.5, GPT-4 and 15 open-source models); its abstract softens the same finding to "only half of them can maintain satisfactory performance at the length of 32K."
  - The detailed per-model table reproduced in §4 below is the table read in full for this dossier (the ten-model comparison with the Llama2-7B baseline). Where v1 and v3 wording differ, this dossier says which version a claim comes from rather than blending them.

## 2. The problem as framed

The paper's target is the field's favourite long-context proof: the **needle-in-a-haystack (NIAH) test** — hide one fact ("the needle", e.g. a passkey or a "special magic number") inside a long distractor text ("the haystack") and ask for it back. By 2024 vendors were advertising 32K, 128K, 200K and even 1M-token windows, commonly backed by NIAH-style or passkey-retrieval results. RULER's framing is that this test measures, in the abstract's words, "only a superficial form of long-context understanding":

- **Retrieval is one behaviour, not the whole job.** Real long-context use requires finding *all* of several relevant items, ignoring near-identical distractors, following a chain of references across the context, and aggregating information that is spread over the whole input (the summarisation shape). A model can pass single-needle retrieval while failing every one of those — and, the paper shows, most do.
- **The test saturates.** Models score nearly perfectly on vanilla NIAH, so the test cannot rank them and cannot locate the length at which they actually break. A saturated benchmark certifies the claim it was meant to test.
- **Realistic benchmarks cannot isolate the variable.** Human-annotated suites (ZeroSCROLLS, L-Eval, LongBench, LooGLE, ∞Bench — the paper's Table 1) mix long-context ability with parametric knowledge (the model may answer from training, not from the context), fix their lengths, and cannot dial task complexity independently of length. RULER's answer is the opposite design: **solely synthetic tasks**, so length and complexity are controlled variables, parametric knowledge is minimised by construction, and any length can be generated on demand.
- **"Effective context size" as a measurable quantity.** The paper's central move is to turn the marketing number into a measurement: fix a quality threshold, sweep length, and define a model's *effective length* as the largest length at which it still clears the threshold (§3.4). The gap between that number and the *claimed* length is the paper's headline object — not a vibe, a table (§4).

## 3. Core method in our own words

### 3.1 The task taxonomy — four categories, 13 representative tasks

All tasks are synthetic and configurable in both sequence length and complexity. The haystack is scaled in proportion to the target context length; complexity knobs (number of needles, hops, chains, distractors) scale independently.

**Retrieval — NIAH, hardened in four directions.** The needle is a key–value pair ("the special magic number for *X* is: *Y*") inserted into a haystack of Paul Graham essays or repeated noise sentences; the query sits at the end. Keys/values can be words, 7-digit numbers, or 32-digit UUIDs.

- *Single NIAH (S-NIAH)* — the vanilla test: one needle, retrieve its value.
- *Multi-keys NIAH (MK-NIAH)* — several needles with different keys; retrieve one. The other needles are **hard distractors**; in the extreme setting the haystack is filled with distractor needles.
- *Multi-values NIAH (MV-NIAH)* — several needles share one key; retrieve **all** values. Tests recall completeness, not just first-hit.
- *Multi-queries NIAH (MQ-NIAH)* — several needles with distinct keys; retrieve all of them (the multi-query associative-recall shape).

The three stated criteria for retrieval done properly: agnostic to needle/haystack type, robust to hard distractors, and high-recall when multiple items are required.

**Multi-hop tracing — Variable Tracking (VT).** A minimal proxy for coreference-chain resolution. A variable is initialised (`X1 = 12345`), then a chain of bindings (`X2 = X1`, `X3 = X2`, …) is scattered through noise; the model must return **all** variable names that resolve to the queried value. Complexity scales with the number of hops and the number of parallel chains. Nothing here is retrieval of a stated fact — the answer must be *derived* by following the chain.

**Aggregation — Common / Frequent Words Extraction (CWE / FWE).** Proxies for summarisation, where the relevant information is a large fraction of the context rather than one needle. The input is a long word sequence sampled from a synthetic vocabulary: in CWE, a fixed set of common words is repeated against a growing body of uncommon words (uniform sampling) and the model must return the common set; in FWE, frequencies follow a Zeta (Zipf-like) distribution and the model must return the top-3 most frequent words. Complexity scales with the number of common words or the distribution parameter α (smaller α = closer frequencies = harder discrimination).

**Question Answering (QA).** Short-context QA datasets (SQuAD is the worked example in the paper's Table 2) are stretched to length by embedding the gold paragraph among distractor paragraphs sampled from the same dataset. The question is the query, the gold paragraph the needle, the distractors the haystack — but unlike NIAH the match between question and paragraph is fuzzy, not an exact key lookup.

### 3.2 The length-scaling protocol

- **Lengths:** 4K, 8K, 16K, 32K, 64K, 128K (with Yi-34B probed further, to 256K, in the error analysis).
- **Volume:** 500 generated examples per task per length; task configurations chosen from a correlational study so the 13 tasks are representative rather than redundant (paper Appendices B–C).
- **Scoring:** recall-based accuracy — an answer prefix is appended to suppress refusals/explanations, and the check is whether the target output is present. Each length's headline score is the unweighted average over the 13 tasks.
- **Inference setup (as reported):** all open models run under **vLLM**, **BF16**, **greedy decoding**, on **8× NVIDIA A100**, each model with its required chat template.

### 3.3 Model ranking beyond the threshold

Because a single threshold is coarse, the paper also aggregates each model's scores across lengths into two **weighted averages** — weights linearly increasing with length (simulating long-input-dominated use) and linearly decreasing (short-input-dominated use) — and ranks under both. The top group (GPT-4, Command-R, Yi-34B, Mixtral) is stable across both weightings.

### 3.4 The effective-context-size definition, as the paper states it

> Fix a threshold that indicates "satisfactory performance"; a model's **effective length** is the maximum evaluated length at which its average RULER score still exceeds that threshold.

The paper's chosen threshold is deliberately modest: **the score of Llama2-7B (chat) at 4K context — 85.6%** — i.e. "as good at length *L* as a 4K model is at 4K." It is a qualitative bar, and the paper says so; §4's gaps are therefore, if anything, conservative — a stricter bar would shrink every effective length further.

## 4. Reported results — as reported

All figures are the paper's own, from the ten-model table read in full (v1 comparison set; the COLM v3 roster expands to 17 models with the same headline pattern — see §1). Scores are the 13-task average at each length; "effective" is per §3.4's 85.6% threshold.

| Model | Claimed length | Effective length | 4K | 32K | 128K |
|---|---|---|---|---|---|
| GPT-4 | 128K | **64K** | 96.6 | 93.2 | 81.2 |
| Command-R (35B) | 128K | **32K** | 93.8 | 89.5 | 76.0 |
| Yi-34B | 200K | **32K** | 93.3 | 87.5 | 77.3 |
| Mixtral (8×7B) | 32K | **32K** | 94.9 | 85.9 | 44.5 |
| Mistral-7B | 32K | **16K** | 93.6 | 75.4 | 13.8 |
| ChatGLM-6B | 128K | **4K** | 87.8 | 69.9 | 42.0 |
| LWM-7B | 1M | **<4K** | 82.3 | 69.1 | 65.0 |
| Together-7B | 32K | **4K** | 88.2 | 63.0 | 0.0 |
| LongChat-7B | 32K | **<4K** | 84.7 | 59.3 | 0.0 |
| LongAlpaca-13B | 32K | **<4K** | 60.6 | 43.6 | 0.0 |

Headline findings, as reported:

- **Near-perfect NIAH, broad collapse elsewhere.** Despite nearly perfect accuracy on vanilla NIAH / passkey retrieval, **all** models degrade substantially as length grows. GPT-4 degrades least (96.6 → 81.2 from 4K to 128K, a 15.4-point drop) and still falls below the threshold before its claimed 128K.
- **No model holds the threshold at its claimed length except Mixtral** — and Mixtral is the one model whose claim (32K) was modest; it even retains moderate performance at 64K, double its claim. The most extreme gap is LWM: **1M claimed, <4K effective** — it scores below the Llama2-7B baseline even at 4K, though it degrades more slowly than most thereafter.
- **Which task families degrade first.** The error analysis (centred on Yi-34B-200K, probed to 256K and at raised complexity) shows the failure order clearly: plain retrieval with a word–number needle survives longest; degradation arrives with (i) **needle-type change** — UUID needles fail first, Yi sometimes returning incomplete 32-digit strings beyond 128K; (ii) **distractor load** — filling the haystack with distractor needles costs Yi ~40 points at 256K, with errors that retrieve values *near* the target (coarse localisation, no precision); (iii) **multi-item recall** — going from 1 to 8 queries costs ~15 points, and multi-value answers come back incomplete or duplicated; (iv) **tracing and aggregation** — variable tracking degrades with both hops and chains, CWE/FWE fail by *copying* (over 80% of Yi's CWE output at 128K is copied from the one-shot example) or by falling back on parametric knowledge (returning "the / an / a" as frequent words without counting); and (v) **QA** — at large lengths Yi's QA performance approaches its *no-context* baseline, i.e. the context has effectively stopped being used, with hallucinated answers coinciding with what the model would have said anyway.
- **Scaling findings.** Longer training context helps on average but not monotonically (LWM-1M is worse than LWM-512K at 256K evaluation); extrapolation past the trained length drops abruptly; **larger models degrade less** (Yi-34B vs Yi-9B vs Yi-6B at identical 200K training length); the top open models share large RoPE base frequencies and larger parameter counts. Non-Transformer entrants (RWKV-v5, Mamba-2.8B) lag the Transformer baseline by large margins and degrade sharply by 8K.
- **Dating caveat.** The roster is a 2024 roster by construction (GPT-4 of that period, Command-R, Yi-34B-200K, Mixtral-8×7B, LWM, LongChat, LongAlpaca). The numbers grade those artefacts, not their successors; what transfers is the *shape* — claimed ≫ effective, retrieval last to fall — not any specific model's current standing.

## 5. Position vs Wave 7 — three numbers, not one

Wave 7 (`papers/yarn.md`, `papers/longrope.md`) established the corpus's honesty rule: a context length is **three different quantities**, and vendors quote the largest.

- **Trained length** — the length the model's positions were actually trained at (YaRN's *L*; the GGUF `context_length`).
- **Scaled length** — the length a positional-scaling method (YaRN, LongRoPE) makes *addressable*: positions beyond *L* are remapped so the model does not fall off the perplexity cliff. Wave 7's dossiers are about extending this number, and both papers validate the extension primarily with perplexity and single-fact passkey probes.
- **Allocated length** — the length a runner actually reserves and pays for: Ollama's `num_ctx`, which sizes the KV cache whether or not any token ever uses it (`memory/kv-cache-design.md`).

**RULER measures a fourth thing that grades the first two: the *usable* (effective) length** — the largest length at which the model still does work of threshold quality across retrieval-with-distractors, tracing, aggregation and QA. It is not a property of the positional encoding alone; it is an empirical property of (model, task mix, threshold). ∞Bench (`papers/infbench.md`) measures the same usable quantity from the realistic-task side at 100K+.

The relationships, stated precisely:

- A scaling method can raise the scaled number without raising the usable number by the same amount — RULER's Yi-34B row is the canonical exhibit: 200K claimed/scaled, 32K effective under a modest threshold. YaRN's own passkey evidence (§4 of `papers/yarn.md`) is exactly the class of evidence RULER shows to be insufficient: single-needle success coexists with aggregation and tracing failure at the same length.
- The allocated number is set by the *user/runner*, independently of both: nothing in Ollama stops `num_ctx` being set to the scaled number, and the KV-cache arithmetic (`memory/kv-cache-design.md` §1.2) charges full price for every allocated token — 128 KiB/token for a Llama-3.1-8B-class GQA model at f16 cache, 512 KiB/token for an MHA 7B — regardless of whether the model can use those positions.
- **Policy consequence (our synthesis, labelled as such): allocating beyond the usable length buys cost without capability.** Every allocated token past the effective length consumes real VRAM, lengthens prefill, and — worse — fails *quietly*: the model keeps producing fluent text while its grip on the early context loosens (RULER's QA-to-no-context-baseline collapse is this failure, measured). A runner that defaults `num_ctx` to the advertised window is spending the user's scarcest resource on the vendor's largest number. The honest default is to allocate to a *measured* usable length for that model+quant, and to label any allocation above it as reach, not capability.

## 6. Applicability

### (a) The personal runner — a cheap local effective-context check (proposal)

**Proposal (a build-campaign measurement proposal, not a result):** ship a RULER-style synthetic probe as a per-model onboarding measurement in the Ollama fork / Aesir grading harness:

- **Shape:** a reduced RULER — S-NIAH + MK-NIAH (distractor-filled) + MV/MQ-NIAH + a short VT chain set + one aggregation task — generated locally at the user's *actual* `num_ctx` and at one or two lengths below it (e.g. `num_ctx`, `num_ctx`/2, `num_ctx`/4), a few dozen examples per task per length rather than the paper's 500. Synthetic generation means no dataset download, no parametric-knowledge contamination, and the probe can be regenerated per model so it cannot be memorised or tuned against.
- **Output:** the largest probed length clearing a stated threshold (the paper's device — a fixed reference score — or a stated absolute bar), reported as the model's **measured effective length for this quant on this machine**, beside the trained / scaled / allocated figures (§5). Re-run once per (model, quant) pair at onboarding; cache the verdict with the artefact.
- **Cost, stated honestly:** prefill-dominated — each example is a full-context prefill, so a probe at 32K with ~50 examples × 4 task families is on the order of tens of millions of prefill tokens: minutes on a datacentre card, plausibly tens of minutes on the fleet's 6 GB laptop card at large `num_ctx`, and it must run at the *real* cache precision (see below) to mean anything. It is a once-per-artefact cost, not a per-session cost — the same economic shape as the corpus's raw-oracle grading (IDEA-LEDGER #34, which already requires "a retrieval-style test (passkey/RULER-shaped) at the *longest* supported context" for cache-precision claims; this proposal generalises that requirement from cache changes to model onboarding).

**Quantisation interacts — what the paper does and does not say (exact):**

- RULER's own evaluation is run at a **single precision: BF16 weights via vLLM, greedy decoding**, on A100s. The paper contains **no weight-quantisation and no KV-cache-quantisation ablation** — it says nothing, in either direction, about whether quantisation shrinks the usable length. Any claim that "RULER shows Q4 costs you context" would be fabricated; it does not.
- The corpus-side expectation — labelled **our synthesis, not the paper's finding** — is that quantisation plausibly shrinks the *usable* number before it shrinks the *allocated* one: the allocated number is just an integer in a config, while the usable number depends on exactly the fine discriminations (distractor vs target needle, near-tied word frequencies) that low-bit weights and low-bit KV caches degrade first (cf. the KV-quantisation dossiers of Wave 3 — KIVI, KVQuant — whose own evaluations are short-context, and IDEA-LEDGER #34's warning that KV damage "hides" at the longest context). That is precisely why the probe above must run at deployment precision: a BF16 effective length quoted for a Q4_K_M artefact with a q4_0 cache would be the three-numbers dishonesty in a new costume.

### (b) Honesty in reporting

Under the measurement law (IDEA-LEDGER #44 — disclose, or the number is not real), any context figure the build campaign publishes must carry **which of the numbers it is**: trained, scaled, allocated, or measured-usable — plus, for the usable figure, the probe, threshold, precision (weights + KV), and n behind it, per #44's disclosure set. "Supports 128K context" with no qualifier should be treated in our own release notes the way RULER treats it in vendors': as a claim about the scaled number, priced at zero until a usable-length measurement is attached. RULER's threshold device is also a reporting lesson: an effective length is only meaningful *with its threshold named* — the paper names its (Llama2-7B @ 4K = 85.6%); ours must name ours.

## 7. Cross-links

- **YaRN dossier** (`papers/yarn.md`) — extends the *scaled* number; its §4 passkey/perplexity evidence is the evidence class RULER proves insufficient, and its §6 three-lengths UI rule is the display form of §5 above.
- **LongRoPE dossier** (`papers/longrope.md`) — extends the scaled number furthest (2048K); RULER is the instrument that would price how much of that reach is usable, task by task.
- **KV-cache design** (`memory/kv-cache-design.md`) — the allocation arithmetic: bytes/token by layers × KV-heads × head-dim × precision; the allocated number's price is computed there, and it is charged in full regardless of the usable number.
- **MLPerf Inference dossier** (`papers/mlperf-inference.md`) — benchmark-design discipline: fixed tasks, disclosed conditions, anti-gaming audits. RULER is the same philosophy aimed at context claims — configurable synthetic tasks the submitter cannot pre-tune against a fixed test set, a named threshold, and a headline metric (effective length) designed so that the easy win (vanilla NIAH) cannot substitute for the real one.
- **∞Bench dossier** (`papers/infbench.md`) — the companion measurement: realistic + synthetic tasks at a fixed 100K+ scale, where RULER sweeps length with synthetic control. Read together: RULER locates *where* usability ends; ∞Bench shows *what* real work at 100K+ does to models that claim to live there.
- **IDEA-LEDGER #44** (`synthesis/IDEA-LEDGER.md`) — the measurement law this dossier's §6(b) applies to context figures; and **#34** (raw-oracle grading), whose longest-context retrieval-test requirement this wave's proposal extends.

## 8. Sources

- Date accessed: **2026-11-15** (all sources).
- arXiv record (v1 + version history; COLM 2024 comment; v3 author list and 17-model abstract): https://arxiv.org/abs/2404.06654
- arXiv v1 abstract page (7 authors; 10 models; "only four models" finding): https://arxiv.org/abs/2404.06654v1
- Full text read for method, task taxonomy, protocol and the per-model results table (HTML rendering of the paper): https://ar5iv.labs.arxiv.org/html/2404.06654
- COLM 2024 proceedings listing (RULER entry): https://proceedings.colm.cc/paper_files/paper/2024
- Corpus-internal sources: `papers/yarn.md`, `papers/longrope.md`, `papers/infbench.md` (this wave), `papers/mlperf-inference.md`, `memory/kv-cache-design.md`, `synthesis/IDEA-LEDGER.md` (#34, #44).
