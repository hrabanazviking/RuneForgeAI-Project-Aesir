# J-025 — Prefetch from the Router's Shadow

**Slice:** J-025 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "One-layer-ahead expert prefetch (the router's previous-layer pattern) measured; kept only if it pays on the real traces."
**Executed:** 2026-10-31 ~09:4x–10:1x EDT. **Offline trace work only** (VM; no inference anywhere; purplelongship untouched — the 204 road's S-094 driver has been live there since 09:22 EDT and this slice needed no heavy run). VM MemAvailable ≈ 0.5 GB throughout.
**Base:** branch `yrsa/janas-j025` from `yrsa/janas-j024-integration` tip `ad261281` (J-018 expert cache + J-024 fsketch tournament, integration, and shipping-default flip). **No Janas material was used or needed** — this slice stands on J-015/J-016/J-018/J-020/J-024 evidence; the clean-room law was not engaged.
**Headline verdict: REJECTED — measured.** Router-shadow prefetch does not pay on the real J-016 trace under any predictor, width, or admission discipline tested, at either operating budget. Nothing is built; there is no prefetch hook in the engine. The strongest evidence is the ceiling: even a *perfect* shadow (the oracle, §5.3) loses +12…+29 % streamed bytes when it admits freely, and gains only −0.03 % / −0.49 % when it submits to the cache's own admission gate — the gate that makes it harmless also makes it nearly useless. The best *buildable* configuration (previous-token top-4 behind the pre-test gate) *costs* +0.22 % at 128 pairs. §7 states the verdict and the exact conditions under which this question may be reopened.

---

## 1. Field and method

**Trace.** The J-016 measured OLMoE trace (`j016_trace_olmoe.jsonl`, sha256 `85e1d2413cbfcd43516a03d8463c7266d486cf0f0d0a6ed3104d09111facf99a` — re-verified this run; 577 tokens, 9,232 token-layers, 73,856 accesses; 6 prompts: prose 71 incl. 4 gen tokens, code 100, structured 129, numbers 91, instructions 91, technical 95; kept in campaign records + purplelongship `~/j016/`, not committed, as J-016 left it). One model, one quant, prompt-phase — the same scope limit J-017 §1 binds on every citation of it. This slice is *not* J-020's question: J-020 measured a warm-up predictor at token 0 (before the sequence starts; FIRSTTOK-128 adopted there). J-025 is within-sequence shadow prediction during prefill/decode — layer-to-layer and token-to-token — a different evidence base, measured separately.

**Budgets.** Byte budgets built exactly as J-016/J-018/J-024 built them: pairs × mean pair size (3,809,280 B full-scale; sizes simulated scaled ÷1024 = 3,720 mean, exact for both OLMoE layer classes). Operating budgets **128 / 512 pairs** (≈0.49 / 1.95 GB), with 256 run for the direct-admission rows. Full-scale streamed bytes = scaled × 1024; MB/token uses 10⁶ B and 577 tokens.

**Base policy.** `fsketch` — the shipping default since J-024's integration step (single LRU segment; aged exact-counter sketch, halved every 4,096 accesses; a miss is admitted only when the candidate's frequency exceeds the victim's, otherwise bypassed). All deltas below are against the no-prefetch fsketch base re-measured in this run (§3).

## 2. Predictors, mechanics, and the verdict rule — all stated before the payoff tables

The demand target is the routed set S(t,l) = the top-8 experts the router chose for token t at layer l (trace order = router rank order). A predictor emits an ordered candidate list for (t,l) using **only** information available before (t,l)'s router runs:

| Predictor | Definition |
|---|---|
| `PL` | Same-token previous layer: cand(t,l) = S(t,l−1), l ≥ 1. **The roadmap's named pattern** — the router's previous-layer set, read as expert IDs at layer l. |
| `PT` | Previous-token same layer: cand(t,l) = S(t−1,l); t not the first token of its prompt. |
| `PTD` | Previous-token diagonal: cand(t,l) = S(t−1,l−1); both guards. |
| `UNION` | PL ∪ PT deduplicated, ranked by the larger source weight, truncated to 8. |
| `ORACLE` | cand(t,l) = S(t,l) itself — the perfect shadow. Not buildable; the ceiling every real predictor is graded against. |

Widths: PL/PT/PTD run at FULL8 (all 8 candidates) and TOP4 (the source set's top-4 by router weight); UNION is 8 by definition.

**Prefetch mechanics (the honest charging model, fixed in advance).** The candidate batch for (t,l) is issued immediately before (t,l)'s demand accesses, in candidate rank order (in a sequential replay, every earlier issue point inside the gap is indistinguishable except for batch grouping; per-layer issue is the grouping the one-layer-ahead design actually has). A candidate already resident costs nothing. A fetched candidate is charged its **full pair size as streamed bytes whether or not it is admitted**. Prefetch evictions are real evictions (they enter the evicted-before-reuse window and can destroy useful residents; that cost shows up in the demand hit rate). A fetched+admitted candidate demand-hit before eviction is **useful**; a fetched candidate refused, evicted before use, or resident-but-unused at trace end is **waste**, and its bytes stay in the streamed total. Prefetches never touch demand statistics and never bump sketch frequencies. Four admission disciplines were measured:

- **DIRECT** — prefetch admits unconditionally, evicting LRU residents until the pair fits (a dedicated prefetch path).
- **GATED** — prefetch must pass fsketch's own admission test, with the fetch charged *before* the test (the demand path's ordering; victims evicted one at a time, a refusal leaves earlier evictions standing — the tournament loop verbatim).
- **GATEDPRE** — the same test evaluated on metadata *before* the fetch (frequencies and LRU order are in memory; a real hook can and would test first). A failing candidate is never fetched and costs nothing (a *gate skip*); a passing candidate is fetched, its victim chain evicted, and it is admitted.
- **BUFFER** — DIRECT admission, but prefetched entries carry an artificially ancient recency stamp, so any later admission sheds unused prefetches before touching a demand-admitted resident; a demand hit re-stamps the entry (use promotes it). (Its measured behaviour carries an implementation artifact, recorded in §8 — the verdict does not rest on it.)

**Verdict rule (stated before results).** Prefetch is KEPT only if some buildable (predictor, width, admission mode) at an operating budget (128 or 512) achieves **all** of: (a) negative net streamed-bytes delta vs the no-prefetch base in the global session; (b) no per-text-type segment worse than +2 %; (c) useful-prefetch fraction ≥ 0.25. If several pass, the winner is the largest global net saving at 128 (the harsh bigger-than-RAM edge is Part II's operating point), tie-broken at 512. The oracle is a ceiling, never a candidate.

## 3. Validation gate — PROVEN

No payoff number below was trusted before this gate passed. The no-prefetch base run of this slice's simulator (`PrefetchFSketch`, a subclass of J-024's tournament `FSketchCache` with the demand path inherited unchanged) reproduces, **EXACTLY at 128/256/512**, the fsketch counters in `j024_tournament_results.json` (hits, misses, cold, bypasses, admissions, evictions, evicted-before-reuse, streamed bytes, entries, resident bytes — every field), **and** at 128/512 the real-MoJO-module replay counters from J-024's integration (`j024_replay_results.txt`): hits 25,953 / 56,781; streamed (scaled) 178,149,792 / 63,662,880; bypasses 46,724 / 14,895; admissions 1,179 / 2,180; evictions 1,050 / 1,668; evicted-before-reuse 22,335 / 12,194; cold exactly 1,024. **Gate: 3/3 budgets EXACT against the tournament record, 2/2 against the real module.** Base re-measured: hit 0.351 / streamed 316.2 MB/token @128; 0.533 / 227.6 @256; 0.769 / 113.0 @512 — identical to J-024 §2/§9, as they must be.

## 4. Predictor quality — the shadow itself (MEASURED from the trace)

Cache-free: mean overlap |cand ∩ S(t,l)| of an 8-candidate prediction (random 8-of-64 expectation: **1.000**), and mean demand-weight mass covered:

| Predictor | Mean overlap /8 | Mean mass covered | n token-layers |
|---|---:|---:|---:|
| PL (the roadmap's pattern) | **0.977** | 0.122 | 8,655 |
| PL-TOP4 (of 4) | 0.488 | 0.061 | 8,655 |
| PTD | 0.953 | 0.118 | 8,550 |
| PT | 2.288 | 0.296 | 9,120 |
| PT-TOP4 (of 4) | 1.311 | 0.175 | 9,120 |
| UNION | 2.925 | 0.375 | 9,225 |
| ORACLE | 8.000 | 1.000 | 9,232 |

**The previous-layer pattern carries no signal.** PL's overlap (0.977) is *below* the random expectation (1.000): knowing which experts layer l−1 routed to for this token tells you nothing about layer l beyond chance — per text type it is 0.92–1.05 everywhere, and per layer it never exceeds 1.45 (layer 11) and sits at 0.67–1.07 on ten of fifteen layers. Adjacent MoE layers route essentially independently on this model; expert IDs do not shadow across layers. PTD (0.953) confirms it from the diagonal: any predictor routed through a layer change is at chance. **The real shadow is temporal, not vertical:** PT overlaps 2.288/8 (mass 0.296), strongest on code (3.60 — the local workload, as J-016/J-024 found), weakest on instructions (1.71); per layer it is 1.66–2.84, uniformly above chance. UNION buys +0.64 overlap over PT at up to double the candidate volume. So the buildable signal exists — §5 shows why it still cannot pay.

## 5. The payoff measurement (SIMULATED on the MEASURED trace)

Global session (cache carries across prompts, as a real session's would). Net = total streamed (demand + prefetch) vs the §3 base. Full counters: `j025_prefetch_results.json`.

### 5.1 Free admission (DIRECT) and fetch-then-test (GATED) — catastrophic

| Config | @128: hit / MB-per-token / net | @512: hit / MB-per-token / net |
|---|---|---|
| base (no prefetch) | 0.351 / 316.2 / — | 0.769 / 113.0 / — |
| PL direct | 0.115 / 886.8 / **+180.5 %** | 0.693 / 322.6 / **+185.6 %** |
| PL-TOP4 direct | 0.237 / 558.3 / +76.6 % | 0.721 / 215.5 / +90.8 % |
| PTD direct | 0.113 / 882.0 / +179.0 % | 0.694 / 319.0 / +182.4 % |
| PT direct | 0.285 / 816.6 / +158.3 % | 0.756 / 191.4 / +69.4 % |
| PT-TOP4 direct | 0.280 / 458.6 / +45.1 % | 0.774 / 142.1 / +25.7 % |
| UNION direct | 0.365 / 1190.8 / +276.6 % | 0.696 / 400.1 / +254.1 % |
| PL gated | 0.352 / 716.2 / +126.5 % | 0.768 / 332.7 / +194.5 % |
| PT gated | 0.354 / 620.8 / +96.4 % | 0.771 / 212.4 / +88.0 % |
| PT-TOP4 gated | 0.353 / 457.4 / +44.7 % | 0.770 / 154.4 / +36.7 % |

Three failure shapes, all measured: (i) **pollution** — DIRECT prefetching churns the small cache: PL/PTD at 128 *collapse the demand hit rate itself* (0.351 → 0.115 / 0.113) because tens of thousands of chance-level fetches (69,240 attempts, 60,712 evicted before use for PL@128) evict the residents fsketch had chosen; total evictions rise from the base's 1,050 to 102,171. (ii) **wasted fetch volume** — even where the hit rate survives (PT@512: 0.756), the useful fraction caps the gain: PT-TOP4@512 converts at 0.662 useful yet still nets +25.7 %, because every non-useful fetch costs exactly one demand miss's bytes and the displacement tax is charged on top. (iii) **GATED's ordering tax** — charging the fetch before the metadata test streams 60,948 fetches @128 of which 60,687 are then refused (useful fraction 0.003–0.039 across GATED rows): the demand path's fetch-then-test order is ruinous for prefetch, which is why GATEDPRE exists.

Per text type under DIRECT @128, every segment is worse for every predictor (+37…+382 %); the only segment-level wins anywhere in the direct tables are code under PT at 512 (PT −19.9 %, PT-TOP4 −29.5 %) — the one local workload, at the larger budget — while the same configurations' global nets are +69.4 % / +25.7 %. A code-only prefetch would still need its global case; it does not have one.

### 5.2 The protective disciplines — the gate makes it harmless and useless; the buffer eats itself

| Config (GATEDPRE) | @128 net (fetches / gate skips / useful frac) | @512 net (fetches / gate skips / useful frac) |
|---|---|---|
| PL | +0.72 % (275 / 60,627 / 0.666) | +4.75 % (786 / 32,616 / 0.709) |
| PT | +0.51 % (387 / 45,912 / 0.884) | +2.52 % (582 / 14,613 / 0.885) |
| PT-TOP4 | **+0.22 %** (241 / 21,294 / 0.892) | +1.16 % (324 / 6,073 / 0.883) |
| UNION | +1.04 % (578 / 101,584 / 0.789) | +6.75 % (1,219 / 46,556 / 0.778) |

Behind the pre-test gate, prefetch nearly vanishes: of 69,240 PL attempts @128 the sketch's own test lets **275** through (60,627 gate skips, 8,338 already resident). Those few are good predictions (useful 0.67–0.89) — but they are precisely the admissions fsketch would have made anyway one layer later, and their early arrival still nets **positive cost everywhere** (best buildable row: PT-TOP4@128, +0.22 % = +396,144 scaled bytes ≈ +0.70 MB/token over the session — small, and the wrong sign). The gate's opinion and the shadow's opinion almost never agree in the shadow's favour; where they agree, arriving early buys nothing on bytes, because the demand miss it replaces was going to be admitted and streamed exactly once either way — the saving can only come from *repeat* residency the base would not have had, and the gate by construction grants no extra residency.

BUFFER rows are uniformly catastrophic (+20…+248 %; useful fractions 0.004–0.070) for an implementation reason recorded in §8: the ancient-stamp ordering makes each new batch's admissions evict the previous batch's still-unused prefetches first, so the buffer cannibalises itself before demand can use it. The verdict does not rest on BUFFER — §5.3 bounds what *any* admission discipline could achieve — but the artifact is recorded, not hidden.

### 5.3 The oracle ceiling — even a perfect shadow does not pay

| ORACLE | @128 | @256 | @512 |
|---|---|---|---|
| direct: hit / net | 0.921 / **+28.5 %** | 0.999 / **+17.3 %** | 0.999 / **+12.4 %** |
| gatedpre: hit / net | 0.359 / **−0.03 %** | — | 0.786 / **−0.49 %** |
| gated (fetch-then-test): net | +98.9 % | — | +92.0 % |
| buffer: net | +108.0 % | — | +74.6 % |

Read this table as the slice's core proof. With **perfect** knowledge of every routed set, free admission drives the hit rate to 0.92–1.00 and *still* streams 12–29 % **more** bytes than doing nothing: the oracle fetches 55,634 experts @128 (every non-resident demand, including the long tail fsketch deliberately bypasses — 46,724 bypasses in the base), each fetch costs exactly the demand miss it replaces, and its admissions evict 59,959 residents whose later re-demand is charged again. Prefetch has no bytes economy of its own: a prefetch fetch and a demand miss are the same read. It can only win by creating residency the base policy would not have created *and* having that residency re-used — and on this trace (entropy 5.9836/6.0, no hot set, median stack distance 298 pairs against budgets of 128–512) re-use before eviction is exactly what the working set denies. Behind the gate, the oracle's total possible gain is **−0.03 % @128 and −0.49 % @512** — the entire headroom of one-layer-ahead prefetch on this trace, with a predictor that cannot exist. Every buildable predictor sits strictly inside that headroom and pays the waste the oracle doesn't; all of them land on the wrong side of zero.

## 6. Why — the arithmetic in one paragraph

Streamed bytes are conserved under prefetch: moving a read earlier does not make it smaller. The base policy already streams each admitted miss once and *refuses* (bypasses) the misses its frequency evidence condemns — 63 % of misses @128. A shadow prefetch therefore has exactly two ways to lose and one narrow way to win: it loses by fetching what is never used (§4: the vertical shadow is chance; the temporal shadow wastes 34–88 % of fetches even at TOP4), and it loses by displacing what the sketch chose (§5.1: eviction counts up to 145× the base's). It wins only when a fetched expert is re-demanded while resident *beyond* the use that was predicted — second and third uses the base would have streamed again. J-016's reuse structure (median stack distance 298 pairs; working set = the whole 1,024-pair body within 32 tokens) makes that event rare at any sub-body budget, and §5.3 prices its total value at ≤0.5 % even under perfection. This is the same all-or-nothing shape J-017 §4.3 and J-024 §2.4 measured from the policy side; J-025 closes the prefetch side of the question.

## 7. Verdict

**REJECTED — no router-shadow prefetch is built, and none is wired into `expert_cache.mojo` or `moe_session.mojo`.** No buildable configuration satisfies the §2 rule at either operating budget: every global net is positive (cheapest: PT-TOP4 + GATEDPRE, +0.22 % @128 / +1.16 % @512; the roadmap's own PL pattern is the worst family measured, +0.72 % at its very best and +180 % at its natural one). Per the slice's instruction, the measured rejection **is** the result. Nothing in the engine changes; fsketch stands as the default exactly as J-024 left it.

**Scope honesty — what this verdict does not claim.** (a) It grades **streamed bytes**, the currency Part II's roadmap text ("kept only if it pays") and every sibling slice use. A prefetch could in principle pay in *latency* (hiding disk time behind compute) while losing on bytes; no latency was measured here (offline replay has no wall), so a latency case is **NOT PROVEN either way** and would have to be argued on a live vehicle with its own pre-registered rule — it may not be smuggled in as this slice's conclusion. (b) It is one trace, one model, prompt-phase demand (4 generated tokens) — the J-016 scope limit. **Reopen conditions, named:** a decode-heavy trace (J-033's soak shape) whose temporal shadow is materially stronger than PT's 2.29; a second model's trace with cross-layer routing correlation materially above chance (PL overlap > ~1.5); or a cache budget at a much larger fraction of the body, where displacement is cheap. Any of those reopens J-025's question with this doc's tables as the bar. (c) J-020's FIRSTTOK warm-up is untouched by this verdict — it acts before token 0, inside the same budget, and its evidence (+10.07 % net) stands on its own measurement.

## 8. Honesty ledger

- **PROVEN:** the validation gate — this slice's simulator base reproduces J-024's tournament fsketch counters EXACTLY at 128/256/512 and the real Mojo module's replay counters EXACTLY at 128/512, every field (§3). Trace integrity: sha256 re-verified. Determinism: the full matrix was run twice (see the defect note below); every printed number agreed between runs.
- **SIMULATED (on a MEASURED trace):** every payoff number in §5 — offline prefetch simulation over the J-016 recorded demand, through a simulator whose demand path is validated as above and whose prefetch path follows §2's charging model exactly. No live run, wall, or tok/s is claimed anywhere in this document.
- **MEASURED (from the trace itself):** the §4 predictor-quality statistics (overlaps, mass coverage, per-type and per-layer breakdowns) — direct computations over the recorded routed sets.
- **NOT PROVEN:** any latency effect of prefetch, in either direction (§7a); prefetch behaviour on decode-heavy demand, on Granite/`qwen2moe` demand, or on any second model (no traces exist); the batch-protected buffer repair below (bounded, not run).
- **Defects found and fixed in scope (never-leave-a-bug law):** (1) The verdict code's first pass admitted the ORACLE into the candidate pool and printed KEEP on the oracle's gatedpre row — a category error (a ceiling is not a candidate); caught on inspection of the first run's output, fixed by excluding oracle-labelled configurations from the pool, and the full matrix re-run (the re-run's verdict: REJECT, no passing buildable configuration). (2) BUFFER's ancient-stamp ordering self-cannibalises across batches (each batch's admissions evict the previous batch's unused prefetches before any resident — useful fractions 0.004–0.070 are the artifact's signature). The repair (protect the current batch until its demand point; age older pending entries below residents) was **not** built, deliberately: §5.3 bounds every admission discipline by the oracle's −0.03 %/−0.49 % gatedpre headroom and +12…+29 % free-admission loss, so no buffer repair can change the verdict on bytes; the artifact and the bounding argument are recorded here instead of silently leaving the variant unexplained. (3) Environment incident, recorded for the keeper: during this run the VM intermittently refused file writes from shell/Python (`Operation not permitted`; 0-byte files) for ~15 minutes while tool-mediated writes and reads stayed healthy — the first full-matrix run's results file was lost to it (its console record survived and agrees with the re-run's, which is part of the determinism evidence above); the interdict lifted on its own and the canonical results file was then written by the script itself.
- **Coordination:** 204 road checked at dispatch (S-094 live on purplelongship from 09:22 EDT) — this slice ran no purplelongship work at all; VM work was simulation-only at MemAvailable ≈ 0.5 GB. No README touched. Hailo untouched/parked.

## 9. Artefacts

Filed beside this doc in `docs/janas/`: `j025_prefetch.py` (predictors, the four admission disciplines, the validation gate, the verdict rule — the trace path and the J-024 results path are arguments; the 1.2 MB trace itself stays in campaign records, as J-016 left it) and `j025_prefetch_results.json` (validation gate, base counters, coverage, full per-run counters with per-text-type segments, the verdict). Campaign copies of the script and results live in `~/workspace/model-tests/janas/`.
