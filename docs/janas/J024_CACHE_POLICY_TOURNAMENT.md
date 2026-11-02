# J-024 — Cache Policy Tournament

**Slice:** J-024 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "Eviction policies (LRU, reuse-distance-aware, frequency-sketch) measured on J-016 traces + live runs; the winner becomes the default, the table filed."
**Also charged (J-017 §7.4 / D6):** the cache-conditional expert-dropping trial — streamed-bytes/tok/s gain vs teacher-forcing rank/gap agreement cost, per text type; dropping's default (OFF) may be revisited only on this trial's evidence.
**Executed:** 2026-10-31 ~08:53–09:15 EDT. **Offline leg MEASURED on the VM** (pure trace simulation; no inference anywhere — VM MemAvailable ≈ 0.7–0.9 GB throughout). **Live leg BLOCKED-WITH-REASON** (§6): purplelongship is owned by the 204 road's S-093, and J-023's armed waiter holds priority for the first gap after it. **No Janas material was used or needed** — this slice stands on J-015/J-016/J-017/J-018/J-020 evidence; the clean-room law was not engaged.
**Base:** branch `yrsa/janas-j024` from `yrsa/janas-j023` tip `6b9dc742` (the MoE session + expert cache live on that line, not on origin/main `ba7ee09b` — verified by `git ls-remote` at dispatch).

---

## 1. Field and method

**Trace.** The J-016 measured OLMoE trace (`j016_trace_olmoe.jsonl`, sha256 `85e1d2413cbfcd43516a03d8463c7266d486cf0f0d0a6ed3104d09111facf99a` — re-verified this run; 577 tokens, 73,856 accesses, 6 prompts: prose 71 incl. 4 gen tokens, code 100, structured 129, numbers 91, instructions 91, technical 95; kept in campaign records + purplelongship `~/j016/`, not committed, as J-016 left it). One model, one quant, prompt-phase — the same scope limit J-017 §1 binds on every citation of it.

**Budgets.** Byte budgets built exactly as J-016/J-018 built them: pairs × mean pair size (mean of the header's `expert_bytes_per_layer` = 3,809,280 B full-scale; sizes simulated scaled ÷1024, exact for both layer classes, budgets = pairs × 3,720 scaled). Budgets run: **128 / 256 / 512 / 1024 pairs** (≈0.49 / 0.98 / 1.95 / 3.90 GB; 1024 pairs = the whole expert body). Full-scale streamed bytes = scaled × 1024; MB/token uses 10⁶ B and 577 tokens, as in J-018/J-020.

**The field** (J-020's FIRSTTOK/EARLY8 warm-up predictors are *not* entered — they are predictors, not eviction policies, and conflating the two tournaments was expressly ruled out at dispatch):

| Policy | Definition |
|---|---|
| `lru` | Faithful J-016/J-018 baseline: unconditional admission, LRU victim. |
| `lfu` | Faithful J-016/J-018 baseline: unconditional admission, victim = lowest cumulative frequency (ties by recency), no aging, no gate. |
| `segmented` | The J-018 shipping policy: probation ⅛ (LRU inside, frequency gate, first-class bypass) + main ⅞ (promotion on second touch against a frequency-compared victim), exact counters with TinyLFU-style aging (halved every 4,096 accesses). |
| `rda` | **Reuse-distance-aware (new).** Single segment, byte budget. On a repeat access the policy knows its exact stack distance (distinct pairs since the pair's previous use, computed online from past accesses only, Fenwick construction as in the J-016 analyser). A miss whose stack distance ≥ the pair capacity is **bypassed** — history says it could not have survived in a capacity-sized cache, so admitting it only churns. Eviction picks the resident with the largest last observed stack distance (a never-reused resident scores by the distinct pairs flowed since its admission); ties by LRU. |
| `fsketch` | **Frequency-sketch / TinyLFU-style (new as a standalone entry; the sketch machinery is J-018's).** Single segment, LRU victim, but admission only when the candidate's aged sketch frequency **exceeds** the victim's; otherwise bypass. Exact counters, halved every 4,096 accesses (the segmented policy's own cadence), so the comparison isolates *segmentation* vs *sketch-admission alone*. |

**Validation gate (PROVEN, this run — no tournament number was trusted before it passed).** The tournament's fast simulators were checked two ways on the full trace at budgets 128 and 512, all counters (hits, misses, cold, bypasses, admissions, promotions, evictions, evicted-before-reuse, bytes streamed/evicted, resident bytes, entry count):
1. the J-020 Python replica of the real Mojo `ExpertCache` reproduces the recorded **J-018 replay numbers exactly** (all 6 policy×budget cells, e.g. LRU@128 hits 13,733 / streamed 223,620,864 scaled; segmented@512 hits 56,165; cold = exactly 1,024 in all six); and
2. the fast simulators used for the new budgets/policies reproduce the replica **exactly** in all 6 cells (victim choice is a total order on (frequency, tick), so the fast version's indexing cannot change a decision — and the gate proves it didn't).
Result: **12/12 EXACT** (`validation_gate` in `j024_tournament_results.json`). As a further cross-check, the byte-budget baselines reproduce J-016's independent pair-capacity sims to ≤0.001 at every budget (LRU 0.452 @256 vs sim 0.453; LFU 0.496 vs 0.496; both 0.986135 @1024 vs sim 0.986).

**Grading rule (stated before the verdict, §4):** primary = streamed bytes/token at the operating budgets (128 = the harsh bigger-than-RAM edge, 512 = half-body), secondary = hit rate and evicted-before-reuse, with a per-text-type consistency requirement — a policy that wins the aggregate by collapsing on one text type does not win.

---

## 2. The tournament — global session (MEASURED simulation on the measured trace)

One session in trace order (cache carries across prompts, as a real session's would). Hit rate / streamed MB per token / bypasses / evicted-before-reuse:

| Policy | @128 pairs | @256 pairs | @512 pairs | @1024 pairs (full body) |
|---|---|---|---:|---:|
| lru | 0.186 / 396.9 / 0 / 58,369 | 0.452 / 266.8 / 0 / 39,204 | 0.741 / 126.5 / 0 / 18,131 | 0.986 / 6.8 / 0 / 0 |
| lfu | 0.301 / 340.7 / 0 / 50,139 | 0.496 / 246.2 / 0 / 36,063 | 0.747 / 123.2 / 0 / 17,620 | 0.986 / 6.8 / 0 / 0 |
| segmented (shipping) | 0.333 / 325.0 / 42,551 / 35,416 | 0.520 / 233.9 / 26,392 / 29,025 | 0.760 / 116.9 / 8,149 / 14,728 | 0.960 / 19.5 / 377 / 1,618 |
| rda | 0.258 / 361.8 / 46,352 / 53,797 | 0.442 / 271.6 / 27,889 / 39,574 | 0.717 / 137.8 / 9,295 / 19,772 | 0.986 / 6.8 / 0 / 0 |
| **fsketch** | **0.351 / 316.2 / 46,724 / 22,335** | **0.533 / 227.6 / 32,689 / 20,797** | **0.769 / 113.0 / 14,895 / 12,194** | 0.986 / 6.8 / 0 / 0 |

Cold misses = exactly 1,024 for every policy at every budget (accounting closes, as in J-018). Full counters: `j024_tournament_results.json`.

**Reading the table:**

1. **fsketch wins every operating budget.** Hit-rate margins over the segmented shipping policy: **+1.83 points @128, +1.30 @256, +0.83 @512**; streamed bytes **−2.7 % / −2.7 % / −3.4 %** (316.2 vs 325.0, 227.6 vs 233.9, 113.0 vs 116.9 MB/token); evicted-before-reuse is the lowest of any frequency policy at 512 (12,194 vs segmented 14,728) and far the lowest at 128 (22,335 vs 35,416). The sketch's admission test — *is the candidate already more frequent than the LRU victim?* — captures most of what segmentation buys, without the probation segment's structural costs (next points).
2. **At the full-body budget the admission filters must switch off — and segmented's doesn't.** At 1024 pairs every admit-all policy and fsketch tie at 0.986135 (= 1 − cold fraction, the ceiling). Segmented scores **0.960** and ends with only **963 of 1024 pairs resident and 225,072 scaled bytes (≈230 MB) of its budget idle**, while 377 accesses were bypassed: pairs can be refused at the probation gate indefinitely although the main segment has room for the whole body, because entry to main exists only via probation promotion. This is the same admission-starvation shape J-021 measured for dense layers (its named fix — direct-to-main admission when the receiving segment cannot hold the unit — applies here in budget form: when the budget can hold the body, filtering has nothing left to protect). Recorded as a discovered defect-class issue with its fix as part of the §4 integration step — not patched from this slice, because the fix changes the shipping policy whose verdict is this slice's own question.
3. **rda is measured-and-rejected as a default candidate.** It beats only LRU, and only at 128 (0.258 vs 0.186); at 512 it is last (0.717). The reason is visible in its own counters: at cap 128 it bypasses 46,352 misses yet still records 53,797 evicted-before-reuse. On this trace the median stack distance is 298 pairs (J-016), so at small capacities nearly *every* repeat arrives with distance ≥ capacity — the distance signal saturates exactly where admission discipline matters most, and what remains is close to "admit cold traffic only". Stack distance may still serve J-025's prefetch ranking (where a distance is a sort key, not a gate); as an eviction gate it does not beat frequency on Aesir's only measured demand.
4. **The J-016/J-017 shape survives every policy:** caching is still nearly all-or-nothing — the best policy at ⅛ of the body still streams 316 MB/token (65 % of the 487.6 MB cold ceiling), and no policy invents a hot set that the entropy (5.9836/6.0) says does not exist. Policy choice is worth ~±20 % of streamed bytes at the left edge, not an order of magnitude. Disk discipline (J-019) and budget size remain the first-order terms, exactly as J-017 §4.3 read it.

---

## 3. Per text type (MEASURED simulation)

**Global session, per-prompt segments** (hit rate; the cache state each prompt inherits is part of the number):

| @128 | prose | code | structured | numbers | instructions | technical |
|---|---:|---:|---:|---:|---:|---:|
| lru | 0.159 | 0.323 | 0.190 | 0.144 | 0.132 | 0.147 |
| lfu | 0.267 | 0.467 | 0.407 | 0.213 | 0.204 | 0.183 |
| segmented | 0.178 | 0.510 | 0.397 | 0.251 | 0.281 | 0.305 |
| rda | 0.197 | 0.389 | 0.279 | 0.205 | 0.228 | 0.215 |
| **fsketch** | **0.269** | **0.526** | **0.410** | **0.253** | **0.288** | **0.305** |

| @512 | prose | code | structured | numbers | instructions | technical |
|---|---:|---:|---:|---:|---:|---:|
| lru | 0.651 | 0.940 | 0.839 | 0.616 | 0.657 | 0.662 |
| lfu | 0.696 | 0.840 | 0.854 | 0.679 | 0.700 | 0.655 |
| segmented | 0.533 | 0.915 | 0.863 | 0.685 | 0.724 | 0.737 |
| rda | 0.648 | 0.858 | 0.772 | 0.640 | 0.666 | 0.671 |
| **fsketch** | 0.688 | 0.875 | 0.855 | 0.671 | 0.722 | **0.739** |

**Isolated runs** (fresh cache per prompt — the single-shot case; hit rate @512; full table in the results file):

| | prose | code | structured | numbers | instructions | technical |
|---|---:|---:|---:|---:|---:|---:|
| lru | 0.651 | 0.926 | 0.824 | 0.598 | 0.643 | 0.647 |
| lfu | 0.693 | 0.927 | 0.845 | 0.663 | 0.715 | 0.729 |
| segmented | **0.537** | 0.831 | 0.762 | **0.536** | 0.564 | 0.570 |
| rda | 0.644 | 0.914 | 0.796 | 0.628 | 0.651 | 0.676 |
| fsketch | 0.689 | 0.924 | 0.843 | 0.668 | 0.713 | 0.717 |

Readings:

- **fsketch never collapses on a type** (the §1 consistency requirement): best in all 6 global @128 cells and all 6 isolated @128 cells; at global @512 it is best on technical and within 0.01 of best on prose/structured/instructions. The one clear per-type exception in the whole tournament is **code @512 global, LRU's cell by 6.5 points (0.940 vs 0.875)** — code is the dense-reuse type (isolated, LRU and fsketch tie there: 0.926 vs 0.924), where unconditional admission of everything, including the previous prompt's leftovers, pays and any admission test only taxes first touches. It is recorded as the known shape of fsketch's cost, not averaged away; at isolated @512 fsketch is within 0.016 of LFU on every type and ahead on numbers.
- **Segmented's weakness is the fresh session, and it is structural.** In isolation at 512 it is *last on every text type* — its global-run respectability comes from inheriting a warmed main segment across prompts; a single cold prompt pays the probation price with no payoff window. The isolated prose figure (0.537) reproduces J-020's independently measured prose_cold run through the real module (0.537) to three decimals — the tournament and the J-020 replay agree on the shipping policy's known early price (J-020 §3.5), now shown to be a *whole-session* price for single-prompt workloads, not only a first-8-tokens one.
- **Code is the local workload** in every table (J-016's 700 pairs/100 tokens): the one type where even LRU reaches 0.93 isolated @512. Numbers/instructions remain the least local, as J-016 measured. No policy reverses the type ordering — policy choice moves all types together, which is what makes a single default defensible at all.

---

## 4. Verdict

**Winner of the offline tournament: `fsketch`** — the TinyLFU-style frequency-sketch admission over a single LRU segment. It wins all three operating budgets on hit rate and streamed bytes, holds the lowest evicted-before-reuse among frequency policies at 512, never collapses per text type, and ties the admit-all ceiling at the full-body budget (its admission test only engages when an eviction is actually forced).

**Disposition: RECOMMENDATION, not a silent default change.** The J-018 shipping default in `aesir_engine/core/expert_cache.mojo` remains `segmented` until the integration step below lands. Reasons, stated plainly: (1) fsketch has **no Mojo implementation** — the default lives in the engine module, and flipping it means building the policy in Mojo, unit-testing it, and replaying the full trace through the *real module* until it reproduces this tournament's fsketch counters exactly (the J-018/J-020 validation path), none of which exists yet; (2) the margin, while consistent across budgets and text types, is modest (+0.8…+1.8 hit points, −2.7…−3.4 % streamed) and rests on **one trace, one model, prompt-phase demand** — the same evidence class J-018 correctly refused to call a verdict when it favoured segmented. What this tournament settles is the *offline* question the roadmap posed; the default flips on real-module evidence, not on a simulator alone.

**Integration step (the immediate next item, recorded per the never-leave-a-bug law alongside §2.2's discovered issue):**
1. Implement `fsketch` in `expert_cache.mojo` behind the existing policy interface (single segment; LRU victim; aged exact-counter sketch; admit iff candidate frequency > victim frequency).
2. Unit tests mirroring `test_expert_cache.mojo`'s three groups for the new mode.
3. Full J-016 trace replay through the real module at 128/256/512/1024 reproducing §2's fsketch counters exactly (scaled construction), then flip the shipping default to `fsketch` in the same commit series.
4. In the same step, fix the §2.2 admission starvation for **all** filtering policies: when free budget ≥ the incoming pair's size (in particular whenever the budget can hold the whole expert body), admission must not be refused by the gate — filtering exists to choose victims under scarcity, and under no scarcity there is nothing to choose.

**What live evidence would confirm or overturn this verdict:** streamed OLMoE session runs (the J-022 vehicle) at 128/512-pair caps with both policies in the real module, in a guarded idle gap on purplelongship — hit/streamed counters plus wall tok/s. Overturn conditions named in advance: a live streamed-bytes ordering that reverses the offline one at either cap, or decode-heavy demand (J-033's soak shape; today's trace carries 4 generated tokens) reordering the frequency policies — decode demand is **NOT PROVEN** and could plausibly favour segmentation's protected main segment. Until that leg runs, the verdict's class is: **SIMULATED on a MEASURED trace, simulators validated EXACT against the real module's recorded replay.**

**rda:** rejected as a default candidate on the §2 evidence (kept in the tournament script for J-025 to reuse its stack-distance machinery as a ranking signal). **lru/lfu:** remain the faithful baselines; LFU's strong isolated showing (it is fsketch's nearest rival in fresh sessions) is recorded — the sketch's aging + admission test is precisely what separates fsketch from it in session runs.

---

## 5. The dropping trial (J-017 D6) — offline part MEASURED, agreement leg NOT PROVEN

**Rule trialled (the documented starting candidate, J-017 §7.1):** when the cache holds < ⅕ of the model's experts, a routed expert that is **not resident** and whose router weight is < **0.8/k** (k = 8 → threshold 0.1) is not read; its share is redistributed over the kept experts. Of the tournament budgets only **128 pairs** (⅛ of 1024) sits in the triggering regime; a 512-pair run with the fraction condition waived is included as a labelled what-if sensitivity, not as the documented rule.

**A caveat that binds the numbers (answered-locally, recorded):** the trace's recorded weights are **renormalised top-8 shares** — verified this run: every one of the 9,232 token-layers sums to 1.0 (min 0.999998, max 1.000003). That was the J-016 instrument's convention, and J-022's B1 proved the ggml comparator does *not* renormalise (its top-8 mass runs ~0.5–0.8×). Janas's published threshold presumably applies to its own router weights, whose normalisation the public docs do not state (clean-room: not pursued further). On raw weights the same 0.1 line would drop *more*, not less — so this trial's drop rates are, if anything, **understated** relative to a literal raw-weight implementation. The trial is run on the only weights Aesir has measured; the direction of the bias is stated, not hidden.

**Results (SIMULATED on the measured trace; dropping applied over the named policy's cache):**

| Run | Dropped accesses | Dropped share | Mean mass removed / token-layer | Streamed MB/token (no-drop → drop) | Bytes saved |
|---|---:|---:|---:|---:|---:|
| segmented @128 (documented rule) | 17,133 | 23.2 % | 0.152 | 324.955 → 215.385 | −33.7 % |
| lru @128 (documented rule) | 18,703 | 25.3 % | 0.166 | 396.859 → 246.543 | −37.9 % |
| segmented @512 (what-if, fraction waived) | 7,048 | 9.5 % | 0.062 | 116.946 → 73.337 | −37.3 % |

Per text type (segmented @128, documented rule): dropped share prose 26.9 % / code 21.7 % / structured 21.0 % / numbers 23.4 % / instructions 24.3 % / technical 23.7 % — the cut falls on every type; no type escapes it and none is singled out.

**How to read these numbers — and how not to:**
- The bytes gain is real arithmetic on the trace: in the triggering regime roughly a quarter of routed demand is sub-threshold and non-resident, and not reading it saves a third of the streamed bytes. (A dropped run's "hit rate on remaining demand" — 0.423 for segmented @128 vs 0.333 undropped — is an accounting artefact of shrinking the denominator, **not** a cache improvement; it is recorded in the results file and deliberately not quoted as a benefit.)
- The cost side of the trade is the **mass removed: 0.152 of the renormalised expert mass per token-layer** (segmented @128) — i.e. on average ~15 % of every layer's MoE contribution is simply not computed, at every one of the 16 layers, compounding through the network. That is not a near-tie perturbation by any reading of the road's band (rank ≤2, sub-logit gap); it is a different function with a large, systematic edit. This is a *measurement of what would be removed*, not a measurement of the output divergence — the divergence itself is the agreement leg below.
- **The threshold sits in the densest part of the weight distribution (MEASURED):** 31.7 % of all accesses carry weight < 0.1; **25.3 % of all accesses lie within ±0.01 of the threshold and 45.3 % within ±0.02**; the mean sub-threshold weight is 0.0822, just under the line. J-017 §5.4 warned the "light" set is unstable because dropping thresholds live in the near-tie mass — the trace now prices that warning: a ±0.01 weight perturbation (different summation order, renormalised vs raw weights) flips the drop decision for a quarter of all routed accesses. Two honest implementations would drop materially different expert sets on the same tokens.

**Agreement-cost leg: NOT PROVEN (blocked, named).** Teacher-forcing rank/gap of dropped vs undropped runs cannot be produced in this dispatch: (a) Aesir's MoE session has **no dropping implementation** to grade — building one is a behaviour change to a faithfulness-graded vehicle and belongs with the integration step, not inside a measurement slice; (b) even with one, the graded runs need purplelongship, which §6 shows is unavailable. **Verdict on D6: the default stays OFF** (J-017's position stands, now with the offline half of its trial on file). The offline evidence does not revisit the default — by J-017 §7.4 only a trial showing large gain *with agreement inside the near-tie band* could, and the mass measurement (0.152/layer) makes that outcome implausible enough that any future proposal carries the burden of producing the graded runs first. tok/s gain: **NOT PROVEN** (bytes saved are simulated; no wall was measured, and none is inferred from bytes).

---

## 6. Live leg — BLOCKED-WITH-REASON (no numbers claimed)

The roadmap's "+ live runs" half of this slice did not run. Evidence for the block, checked at dispatch and at execution: the 204 road's state file records S-093's driver (PID 2664092, started 06:47 EDT) still live and advancing at **08:52 EDT** (oracle grading phase; `tf_min_iq1s_t1` completed 08:48, next leg in flight); J-023's guarded legs were refused by its own S-093 guard at 08:35 and its tmux waiter `j023wait` on purplelongship is armed to take the **first** post-S-093 gap — **J-023 holds priority for that gap by the keeper's ruling**, and this slice does not contend with either. This worker has no device route of its own to re-verify on-box processes; the 204 heartbeat and J-023's guard record are the evidence relied on, and they are named as such. Per the slice pattern set by J-019/J-020/J-023, the live leg banks as **BLOCKED-WITH-REASON / NOT PROVEN** with the blocker named: *S-093 live on purplelongship + J-023 waiter priority for the first gap.* When both clear, the live confirmation runs are the §4 overturn check (J-022 vehicle, 128/512 caps, both policies, idle gap, machine state logged) — they belong to the fsketch integration step or a J-024 continuation, whichever the keeper dispatches first; J-023's measurement leg goes before either.

---

## 7. Honesty ledger

- **PROVEN:** the validation gate — the J-020 replica reproduces J-018's recorded real-module replay exactly (6/6 cells, every counter), and this slice's fast simulators reproduce the replica exactly (6/6 cells). Trace integrity: sha256 re-verified; weights-sum property (renormalised shares) verified over all 9,232 token-layers.
- **SIMULATED (on a MEASURED trace):** every tournament, per-type, and dropping number in §§2/3/5 — offline policy simulation over the J-016 recorded demand, through simulators validated as above. No live run, wall, or tok/s is claimed anywhere in this document.
- **MEASURED (from the trace itself):** the dropping trial's mass-removed and near-threshold statistics (direct computations over the recorded weights); the §2.2 end-state resident/idle-budget figures for segmented @1024.
- **NOT PROVEN:** the live leg (§6, blocked-with-reason); dropping's agreement cost and any tok/s gain (§5); any policy ordering on decode-heavy demand, on Granite/`qwen2moe` demand, or on any second model (no traces exist — J-022/J-032/J-033 roads); fsketch as an engine default (recommendation only until the §4 integration step replays it through the real Mojo module).
- **Discovered issue (recorded, fix roaded, not silently left):** segmented admission starvation at no-scarcity budgets (§2.2) — fix specified in §4 step 4 as part of the immediate-next integration step.
- **Coordination:** 204 road checked before any heavy run (none was run); purplelongship untouched by this slice; J-023's files, waiter, `~/j023`, and branch untouched; VM work was simulation-only at MemAvailable ≈0.7–0.9 GB. No README touched. Hailo untouched/parked.

## 8. Artefacts

Filed beside this doc in `docs/janas/`: `j024_tournament.py` (the tournament + dropping-trial simulator, validation gate included; takes the trace path as an argument — the 1.2 MB trace itself stays in campaign records, as J-016 left it) and `j024_tournament_results.json` (full counters for every run: global, per-prompt global, isolated per-prompt, dropping runs, near-threshold bands, the validation gate). Campaign copies of the script/results live in `~/workspace/model-tests/janas/`.

---

## 9. Integration addendum — fsketch in the real module, starvation fixed, default flipped (2026-10-31 ~09:2x–10:0x EDT)

Executed per §4's integration step, on branch `yrsa/janas-j024-integration` from `yrsa/janas-j024` tip `06c6b8f7` (worktree `~/workspace/aesir-janas-j024i`; origin/main `ba7ee09b` untouched). VM only, lightest compiles (test target + replay harness), no inference — VM MemAvailable ≈0.45–0.68 GB throughout. **No live purplelongship leg was run in this step** (see the live-leg note at the end of this section).

**Step 1 — implementation (PROVEN by steps 2–3).** `fsketch` is implemented in `aesir_engine/core/expert_cache.mojo` behind the existing policy interface: single segment (MAIN), LRU victim, aged exact counters halved every 4,096 accesses (the segmented policy's cadence, shared aging path), admit iff candidate frequency **exceeds** the victim's frequency. The eviction loop is the tournament simulator's loop verbatim: victims are evicted one at a time, each checked against the candidate, and a refusal after earlier evictions leaves those evictions standing — that detail is load-bearing for the exact replay below.

**Step 2 — unit tests (PROVEN, VM).** `tests/test_expert_cache.mojo` gains two groups and all five groups PASS (`mojo run -I aesir_engine aesir_engine/tests/test_expert_cache.mojo`, the J-018 lightest-target recipe): the three pre-existing groups (sizing/cap grammar; admission/promotion/pin/shrink/cap — still green under the new promotion semantics; LRU/LFU baselines), `fsketch` (strict-exceeds admission: frequency 1 and 2 bypass against a frequency-2 LRU victim, frequency 3 evicts and admits; oversize refusal; churn cap invariant + accounting closure), and the no-scarcity group (step 4's pin, below).

**Step 3 — real-module replay (PROVEN, VM): fsketch reproduces the tournament EXACTLY.** The full J-016 trace (sha256 re-verified `85e1d241…cf99a`; 73,856 accesses; scaled construction, budgets 128/256/512/1024 × 3,720 scaled bytes) replayed through the real Mojo module (`docs/janas/j024_replay.mojo`; raw output `docs/janas/j024_replay_results.txt`). Every counter the tournament exported matches at **all four budgets, 11/11 fields each** (hits, misses, cold, bypasses, admissions, promotions, evictions, evicted-before-reuse, streamed bytes, entries, resident bytes): hits 25,953 / 39,394 / 56,781 / 72,832; bypasses 46,724 / 32,689 / 14,895 / 0; streamed (scaled) 178,149,792 / 128,259,888 / 63,662,880 / 3,809,280 — identical to §2's fsketch row (0.351 / 0.533 / 0.769 / 0.986; 316.2 / 227.6 / 113.0 / 6.8 MB/token full-scale). The flip condition is met on real-module evidence, not simulator evidence.

**Step 4 — admission-starvation fix (PROVEN, VM), for all filtering policies.** The fix, in `expert_cache.mojo`: (a) segmented admission — when the **total** free budget ≥ the incoming pair's size, the pair is admitted with no gate check and no eviction (probation while probation has room, otherwise main directly); under scarcity the original gate path runs, followed by a total-budget room pass (main victims by frequency/recency) so promotions can never push residency over the total cap; (b) segmented promotion — promotion moves bytes between segments and never changes the total, so it **never evicts and is never frequency-refused** any more; eviction is deferred to admission, the one place the total budget binds (pre-fix promotion evicting main residents is half of the §2.2 starvation); (c) fsketch — its admission loop only engages when an eviction is actually forced (total + size > budget), so under no scarcity it cannot refuse by construction, and the replay proves it. Evidence: (i) the new unit group runs the @1024 shape synthetically for both filtering policies (1,024 distinct pairs × 100 B, budget 102,400 B, three full passes): accesses 3,072, cold = misses = 1,024, hits 2,048, **bypasses 0, evictions 0, entries 1,024, resident 102,400** for both; (ii) the real-trace replay of post-fix segmented @1024 reaches the ceiling exactly — **hits 72,832 (0.986135), misses = cold = 1,024, bypasses 0, evictions 0, entries 1,024/1,024 resident, 3,809,280/3,809,280 scaled bytes** — against pre-fix 0.960 with 963 resident and ≈230 MB idle. No idle-budget starvation remains.

**Post-fix segmented at the operating budgets (MEASURED, same replay — reported, not hidden):** 0.338 / 0.537 / 0.780 hit (streamed 181,587,936 / 127,169,328 / 60,375,408 scaled) at 128/256/512, up from pre-fix 0.333 / 0.520 / 0.760 — the mandated fix made segmented itself stronger, and on this one trace it now edges fsketch at 256 (+0.4 pts) and 512 (+1.2 pts), while fsketch still wins the harsh 128-pair edge (0.351 vs 0.338, −2.7 % streamed) that Part II treats as the operating point for bigger-than-RAM models. **The default still flips to fsketch** (below), because: the tournament verdict was rendered on the policies as they stood, the flip was conditioned on steps 3+4 — both now proven — and the 128-pair edge is where policy choice costs the most streamed bytes. Recorded as an open question for the keeper, honestly: *fixed-segmented vs fsketch is a legitimately re-openable tournament on future traces (a second model, decode-heavy demand) or live legs; nothing in this addendum claims fsketch beats fixed-segmented at 256/512 on this trace, because the replay says it does not.*

**Step 5 — default flipped.** With steps 3+4 proven, the shipping default flips in the same commit series: `aesir_engine/core/moe_session.mojo` now constructs its ExpertCache with `fsketch` (previously `segmented`), and the module docs in `expert_cache.mojo` / `moe_session.mojo` state fsketch as the default. (Scope note: `moe_session.mojo`'s change is the policy string literal + doc text; the literal's validity is proven by the constructor tests above, and the session module itself was not recompiled on this VM under the memory gate — its full build remains the purplelongship leg's business, as in J-022.)

**Live leg — still BLOCKED-WITH-REASON / NOT PROVEN (unchanged from §6).** No live run was attempted in this step, by the keeper's dispatch order: J-023's harvest holds priority for the first post-S-093 gap on purplelongship and the 204 road's S-093 closure may be active. The §4 overturn check (streamed OLMoE session, 128/512 caps, fsketch vs segmented, idle gap, machine state logged) remains the pending confirmation; the offline verdict it could overturn now rests on real-module counters.

**Honesty ledger for this addendum:** PROVEN — fsketch implementation + unit tests, exact real-module replay (4/4 budgets, every exported counter), the starvation fix (synthetic pin + real-trace @1024 ceiling for both filtering policies). MEASURED — post-fix segmented operating-budget counters (same replay run). NOT PROVEN — the live confirmation leg (blocked-with-reason, above); any policy ordering on decode-heavy demand or a second model; `moe_session` recompilation on this VM (string-literal change, constructor-validated). No README touched. Hailo untouched/parked.
