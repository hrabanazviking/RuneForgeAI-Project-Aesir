# J-046 — Within-Tolerance Proof

**Slice:** J-046 (Part III — Choosing What Runs Where, J-035–J-052), Project Aesir Janas clean-room road.
**Roadmap text:** "On at least three models, Aesir's auto choice measured against the full configuration sweep: the Janas claim (auto within ~1.5% reading / ~2.6% writing of best) tested as a target — met, beaten, or missed honestly per model."
**Executed:** 2026-10-31 ~19:0x–19:5x EDT. **Closure shape: the within-tolerance proof is BUILT and unit-PROVEN (the pre-registered tolerance rule on injected sweeps, its NOT PROVEN branches, the aggregate rule, the report), and the live proof ran on the VM — 3 shapes × 2 kinds × 3 repetitions, all 18 repetitions filed. The Janas tolerance claim is NOT reproduced on this VM in this window: prompt MISSED on all three shapes, reply BEATEN on two shapes and MISSED on one (§6–§7). Every MISSED repetition is one where the chooser's own rule had already withheld the win (DEFAULT-BY-NOISE) — the proof grades the median gap the tolerance claim is stated in, and under this contention that gap is honestly large. No repetition was re-run, dropped, or replaced. Draft-check is NOT PROVEN by construction (no pass exists, J-035 G1).** No model inference ran anywhere.
**Base:** branch `yrsa/janas-j046` in fresh worktree `~/workspace/aesir-janas-j046`, from `yrsa/janas-j045` tip `262f48e533c37225d2896992053ee61728cd819d` (ls-remote verified at slice start; origin/main at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`, untouched — verified again at banking, §10).
**Coordination:** purplelongship not used at all — the 204 road's S-101 was dispatched there ~18:22 EDT and is live; this slice needs no on-box leg by design, and §9 files the quieter-machine re-measurement recipe for the J-052 gate / J-141 audit. VM MemAvailable ~1.8 GB at slice start, ~0.9–1.3 GB during builds/runs — far below the 5,500 MB inference gate; the proof is harness micro-work, not inference, and the gate does not block it; lightest compiles only, one at a time.

---

## 1. Question and ground

**Question.** J-040/J-041's choosers pick a placement per kind and keep it for the session. How good is that pick — not in the chooser's own hurdle terms (margin + separation against the runner-up), but against the whole field it chose from? Janas publishes for its own auto choice that it lands within ~1.5% (reading) / ~2.6% (writing) of the best configuration a full sweep finds. Does Aesir's auto choice land within the same tolerances of Aesir's own sweep best, per model?

**Ground, and only that ground.** The choosers and their pre-registered rule are J-040/J-041's (default `cpu threads=1`; a winner must beat the runner-up by >10% of its median AND pass separation, else the default is kept as DEFAULT-BY-NOISE / DEFAULT-CONFIRMED). The measurement discipline (settle discarded, ≥3 measured rounds, median summary, per-candidate 2,000 ms / per-sweep 10,000 ms bounds, bound-stopped never ranked) is J-038's. The rankable axis is J-039's thread ladder through one threaded executor; J-039's central finding — **verdicts flip between sweeps under contention, a single sweep is not a stable verdict** — is the reason this proof is built on repetitions (§3). The model keying is J-044's `ModelShape`. The draft-check absence is J-035 gap G1 (Part V owns the pass). Janas's 1.5% / 2.6% figures are *its* numbers on *its* machine, taken here as a **target to test**, exactly as the roadmap words it — never quoted as Aesir's. No Janas source was opened; none was needed.

## 2. Where the code lives, and what "the full sweep" is

The road's established pattern (J-036 §2 through J-045 §2): a small dedicated standalone module in `core/` plus a standalone lightest-target test suite, host contract in the module, a comment block in `aesir_engine/aesir.mojo`. This slice follows it exactly:

- **New module `aesir_engine/core/within_tolerance.mojo`** (~560 lines): the tolerance candidates/grades, the pre-registered rule as pure functions (`grade_repetition`, `aggregate_verdict`), the proof report, and the live builder (`run_within_tolerance_proof`) that runs the real choosers.
- **Tests at `aesir_engine/tests/test_within_tolerance.mojo`** (11 groups, §5/§10).
- **A comment block in `aesir_engine/aesir.mojo`** beside J-036–J-045's, recording the entry point and the consumption gap. The module is not registered in `tests/run_all.mojo` (the standing Part III precedent: registration rides with a counted run the VM's memory gate does not permit; the standalone suite is the filed evidence).

**The full sweep, exactly.** Per kind, the sweep is **every candidate the kind's chooser can rank: every measured thread rung of the J-039 ladder on this machine** — on this VM, `cpu threads=1` (serial), `threads=2` (half the cores), `threads=4` (all cores), each with the J-038 discipline (1 settle round discarded, 5 measured rounds, median). The device axis is **named, never silently dropped**, and is not in the sweep, for the reasons J-040 already registered: the J-038 device sweep's CPU timing comes from a different (serial) executor and is a cross-check, never ranked — ranking across executors would compare two workloads and call it placement; GPU/NPU singles and co-work forms carry no executor today and stand EXCLUDED (GPU absent on this VM, the probe's reason; NPU parked by law) / UNMEASURABLE-WITH-REASON on every chooser record with verbatim reasons. When device executors land (Part IV), their candidates enter the rankable set and this proof's sweep widens with them — nothing in the rule is CPU-specific except the choosers' default.

**This slice wires the proof into no live session path** — no session consumes a tolerance proof, and the `aesir.mojo` comment says so.

## 3. The tolerance rule — pre-registered

**This rule was written into the module header and this section before any J-046 live number was measured** (the module and this doc's §§1–4 were authored before the first test build ran; the filed live numbers in §6 come from after). `grade_repetition` / `aggregate_verdict` are the rule as pure functions, unit-tested on injected sweeps (§5).

- **Per model shape, per pass kind (prompt = reading, reply = writing), per repetition:**
  - **BEST** = the lowest median among the sweep's MEASURED candidates (full rounds only; bound-stopped recorded, never ranked).
  - **AUTO** = the median, **in the same repetition's sweep**, of the configuration the real chooser actually chose (its chosen device + thread count looked up among the sweep's measured candidates). Grading the choice against its own sweep is the only honest comparison: medians move between sweeps under contention, so a choice from one sweep graded against another sweep's best would grade the weather, not the chooser.
  - **GAP %** = (auto_median − best_median) / best_median × 100, carried in hundredths of a percent (`gap_x100`) so the arithmetic is exact integer work.
  - **TARGETS:** prompt ≤ **1.50%**, reply ≤ **2.60%** — Janas's published claim for its own auto choice, adopted as the target to test.
  - **Per-repetition verdict:** **BEATEN** when auto == best (gap 0 — the chooser picked the sweep's fastest configuration); **MET** when 0 < gap ≤ target; **MISSED** when gap > target; **NOT PROVEN**, with the reason, when the repetition holds no gradeable pair (the chooser refused; no candidate measured; or the chosen configuration is not among the repetition's measured candidates — e.g. it was bound-stopped in this sweep).
- **Repetitions: exactly 3** independent chooser-vs-sweep repetitions per shape per kind, run back to back, **all of them reported**. No repetition is re-run, dropped, or replaced because its outcome is unwelcome.
- **Aggregate per shape per kind:** **BEATEN** when every repetition is BEATEN; **MET** when every repetition is BEATEN or MET and at least one is MET; **MISSED** when at least one repetition is MISSED and none is NOT PROVEN (one over-target repetition means the claim "auto lands within tolerance" does not hold for that shape on this machine in this window); **NOT PROVEN** when at least one repetition is NOT PROVEN.
- **Draft-check is not graded:** no draft-check pass exists (J-035 G1), every draft-check candidate is UNMEASURABLE-WITH-REASON in the harness, and a tolerance grade needs a measured pair. It stands **NOT PROVEN** with that reason on every proof report; no proxy is faked. Part V (J-071/J-072) owns the pass that could change this.
- **The builder refuses a non-auto option** for either kind: the proof grades the *auto* choice, and a manual option (MANUAL-FIXED supremacy) has no auto choice to grade and is never argued with.

## 4. The three models — and the shape honesty

Three distinct model shapes, keyed the J-044 way (`ModelShape`: architecture, embedding, blocks, heads/KV heads, FFN, context, experts/used), each repetition filed under its shape:

| # | Shape key | Values (emb / blk / heads / kv / ffn / ctx / experts / used) | Source |
|---|---|---|---|
| M1 | `olmoe` | 2048 / 16 / 16 / 16 / 1024 / 4096 / 64 / 8 | J-015 §2, measured from the sha-pinned OLMoE Q4_K_M file (FFN is the file's per-expert width) |
| M2 | `granitemoe` | 1536 / 32 / 24 / 8 / 512 / 131072 / 40 / 8 | J-015 §2, measured from the sha-pinned Granite-3.1-3B-A800M Q4_K_M file |
| M3 | `llama` (dense) | 4096 / 32 / 32 / 8 / 14336 / 131072 / 0 / 0 | The dense shape the tree carries in the J-044/J-045 test fixtures (Llama-3 class) |

**How the shape enters the measurement — plainly: it does not enter the workload at all.** The choosers take no model argument (`choose_prompt_placement(options, inventory, facts, config)`), and the harness workloads are fixed shapes (`prompt_workload()`: 16 rows × (512→256), reps 2; `reply_workload()`: 1 row × (1024→512), reps 4 — `core/placement_harness.mojo`). The shape is the J-044 key the repetition is filed under, nothing more. Consequences, stated rather than hidden:

- The three shapes' measurements are **not expected to differ systematically**, and §6's numbers bear that out (the variation across shapes is the same contention weather the variation across repetitions shows). Any per-shape difference in verdicts is window weather, not a model effect, and this doc claims none.
- **No model inference ran**, no number here is a model pass timing, and no per-model placement claim is made beyond the per-shape grading of the chooser's own behaviour. The roadmap's "on at least three models" is met in the only form today's tree honestly supports: three shape-keyed repetitions of the real auto choice against the real full sweep. A proof whose workloads are parameterised by real model passes is roaded to the J-052 gate / J-141 audit, behind real session wiring (§9).

*Note on M1's key:* J-044/J-045's own test fixtures key an `olmoe` shape with ffn 11008 / ctx 8192 — a keying fixture, not a file claim. J-046 keys M1 by J-015's measured file values instead (ffn 1024 per-expert, ctx 4096) so the key names the real file's shape; the difference is recorded here so the two records are never conflated. This is an observation about fixture material, not a defect in J-044 (its fixtures never claimed file identity).

## 5. What the synthetic tests prove (PROVEN, VM, lightest target)

`test_within_tolerance`, 11 groups, all PASS (full output filed as `j046_test_output.txt`):

1. **BEATEN** — auto is the sweep's best: gap exactly 0.
2. **MET at the boundary** — prompt gap exactly 1.50% (auto 10,150 vs best 10,000 ns) is MET; the gap arithmetic is pinned exactly in hundredths.
3. **MISSED one hundredth beyond** — prompt gap 1.51% is MISSED.
4. **Reply target** — gap exactly 2.60% MET, 2.61% MISSED.
5. **NOT PROVEN** — the chosen rung bound-stopped in its own sweep: no gradeable pair, reason stated ("not among this repetition's measured candidates").
6. **NOT PROVEN** — empty sweep (all bound-stopped) and chooser refusal, each with its reason.
7. **Aggregate rule** — all-BEATEN → BEATEN; BEATEN+MET → MET; one MISSED → MISSED; one NOT PROVEN (even beside a MISSED) → NOT PROVEN; kinds and shapes aggregate separately; no repetitions → NOT PROVEN.
8. **Report rendering** — aggregates per kind, the draft-check NOT PROVEN line, and both targets on the face of the report.
9. **Formatter + target pins** — `format_x100` exact (0 → "0.00", 150 → "1.50", −260 → "-2.60"); targets pinned at 150 / 260 hundredths; REPETITIONS pinned at 3.
10. **Live builder refuses a manual option** — a `cpu` prompt option raises before any measurement.
11. **Live proof** (§6) — 18 grades filed (3 shapes × 2 kinds × 3 repetitions), repetition indices exactly the pre-registered ones, every graded gap ≥ 0 (the auto configuration is in its own sweep by construction).

Neighbours rebuilt from this tree, all PASS: `test_prompt_placement` 11/11, `test_reply_placement` 11/11, `test_thread_topology` 10/10, `test_placement_harness` 10/10, `test_draft_placement` 12/12, `test_learned_file` 13/13, `test_retrial` 15/15.

## 6. The live proof (MEASURED mechanics, VM, contended)

Machine: VM (KVM), AMD EPYC 9D25 126-Core Processor (as this boot's cpuinfo states it), 4 vCPU (ladder [1, 2, 4]), kernel 7.0.0-39-generic. Load average 4.88/7.62/8.80 at slice start and ~3.5–11 across the runs (sibling keeper campaigns live); MemAvailable ~0.9–1.8 GB. **These are harness micro-workload medians under heavy contention — not baselines, not model timings.** Medians in ns; the chooser decision is the repetition's own J-040/J-041 decision.

### M1 — `olmoe` (J-015 measured shape)

| Kind | Rep | t=1 | t=2 | t=4 | Best | Auto (chooser) | Gap | Verdict |
|---|---|---|---|---|---|---|---|---|
| prompt | 1 | 74,099,338 | 69,698,798 | 12,946,841 | t=4 | t=1 (DEFAULT-BY-NOISE) | 472.33% | MISSED |
| prompt | 2 | 19,668,683 | 22,399,920 | 17,746,489 | t=4 | t=1 (DEFAULT-BY-NOISE) | 10.83% | MISSED |
| prompt | 3 | 13,572,218 | 14,998,387 | 17,376,795 | t=1 | t=1 (DEFAULT-CONFIRMED) | 0.00% | BEATEN |
| reply | 1 | 78,759,188 | 100,778,026 | 23,446,860 | t=4 | t=4 (MEASURED-WIN) | 0.00% | BEATEN |
| reply | 2 | 9,492,058 | 21,320,521 | 17,747,361 | t=1 | t=1 (DEFAULT-CONFIRMED) | 0.00% | BEATEN |
| reply | 3 | 14,151,718 | 20,899,999 | 15,898,618 | t=1 | t=1 (DEFAULT-CONFIRMED) | 0.00% | BEATEN |

**Aggregates: prompt MISSED · reply BEATEN.**

### M2 — `granitemoe` (J-015 measured shape)

| Kind | Rep | t=1 | t=2 | t=4 | Best | Auto (chooser) | Gap | Verdict |
|---|---|---|---|---|---|---|---|---|
| prompt | 1 | 11,569,034 | 78,126,379 | 13,659,739 | t=1 | t=1 (DEFAULT-CONFIRMED) | 0.00% | BEATEN |
| prompt | 2 | 10,196,765 | 13,555,733 | 19,841,182 | t=1 | t=1 (DEFAULT-CONFIRMED) | 0.00% | BEATEN |
| prompt | 3 | 77,461,532 | 16,974,441 | 17,835,693 | t=2 | t=1 (DEFAULT-BY-NOISE) | 356.34% | MISSED |
| reply | 1 | 14,097,246 | 15,407,061 | 72,904,386 | t=1 | t=1 (DEFAULT-CONFIRMED) | 0.00% | BEATEN |
| reply | 2 | 20,457,115 | 15,734,462 | 16,796,714 | t=2 | t=1 (DEFAULT-BY-NOISE) | 30.01% | MISSED |
| reply | 3 | 17,126,630 | 32,267,801 | 20,263,926 | t=1 | t=1 (DEFAULT-CONFIRMED) | 0.00% | BEATEN |

**Aggregates: prompt MISSED · reply MISSED.**

### M3 — `llama` dense (J-044/J-045 fixture shape)

| Kind | Rep | t=1 | t=2 | t=4 | Best | Auto (chooser) | Gap | Verdict |
|---|---|---|---|---|---|---|---|---|
| prompt | 1 | 17,534,982 | 15,072,589 | 13,234,471 | t=4 | t=1 (DEFAULT-BY-NOISE) | 32.49% | MISSED |
| prompt | 2 | 20,731,677 | 71,095,393 | 19,806,780 | t=4 | t=1 (DEFAULT-BY-NOISE) | 4.66% | MISSED |
| prompt | 3 | 91,786,058 | 27,418,427 | 11,262,684 | t=4 | t=1 (DEFAULT-BY-NOISE) | 714.95% | MISSED |
| reply | 1 | 15,613,240 | 76,912,969 | 73,828,792 | t=1 | t=1 (MEASURED-WIN) | 0.00% | BEATEN |
| reply | 2 | 12,046,280 | 67,130,225 | 70,835,092 | t=1 | t=1 (MEASURED-WIN) | 0.00% | BEATEN |
| reply | 3 | 25,893,099 | 82,953,990 | 27,069,734 | t=1 | t=1 (DEFAULT-CONFIRMED) | 0.00% | BEATEN |

**Aggregates: prompt MISSED · reply BEATEN.**

**Totals: 18 repetitions — BEATEN 11, MET 0, MISSED 7, NOT PROVEN 0. Aggregates: BEATEN 2 of 6 (both reply), MISSED 4 of 6, MET 0.**

## 7. Reading the result — what is proven, and what the misses are made of

- **The tolerance claim, as a claim about this machine in this window, is MISSED for prompt on all three shapes and mixed for reply** (BEATEN on M1/M3, MISSED on M2). That is the filed verdict; nothing in §6 was re-run toward a better one.
- **Every MISSED repetition is a DEFAULT-BY-NOISE repetition.** In each, the chooser's own rule had already refused to claim the fastest rung: the fastest rung's rounds interleaved with the runner-up's (separation failed), so the claim was withheld and the serial default kept. The tolerance grade then compares *medians* — the statistic the claim is stated in — and in those sweeps the serial rung's median itself carried contention spikes (74.1M / 77.5M / 91.8M ns in the three worst repetitions, against 9.5–25.9M ns for serial in the calm ones). The two instruments answer different questions: the chooser asks "is this win separable from noise?" and answers no; the tolerance proof asks "how far is the kept choice's median from the sweep's best median?" and answers: far, in a contended window. Both answers are on the record, and neither is edited to flatter the other.
- **No repetition landed in the MET band at all** — outcomes bifurcate on this machine today: when the default is the sweep's best, the gap is 0 (BEATEN, 11 of 18); when another rung's median is lower in a contended sweep, the gap is 4.66%–714.95%, never near 1.5%/2.6%. A within-a-few-percent near-miss was not observed in any repetition.
- **Reply BEATEN on two shapes is the same weather, not a model effect** (§4): in M1/M3's reply windows the serial rung (or the MEASURED-WIN rung) was the sweep's best in all three repetitions; in M2's window one contended repetition (30.01%) flipped its aggregate. Per-shape verdict differences here are window differences.
- **What this does NOT show:** anything about a quiet machine. The VM window was heavily contended throughout (by design of the keeper ecosystem, ~14 campaigns), and J-039 already proved this VM's per-kind verdicts flip between sweeps. The tolerance question on an idle machine — purplelongship's ladder is [1, 4, 8, 16] on its recorded Ryzen 9 facts — is exactly the J-052 gate / J-141 re-measurement (§9), and this slice's verdicts neither predict nor prejudice it.

## 8. Answered-locally

- **"Full configuration sweep"** — the census/docs do not define it for Aesir; answered from Aesir's own architecture: every candidate the chooser can rank (the thread ladder), with the device axis named-and-excluded for J-040's registered executor reasons (§2). Recorded here per the clean-room law.
- **Repetitions and the aggregate rule** — Janas publishes a single tolerance figure with no repetition discipline; Aesir's own J-039 flip finding forbids resting a verdict on one sweep, so the 3-repetition + aggregate discipline of §3 was derived locally and pre-registered.
- **Shape sources** — M1/M2 keyed from J-015's measured file anatomies (not J-044's fixture values, §4 note); M3 from the tree's carried dense fixture shape, no J-015-class file record existing for it in this branch line.

## 9. NOT PROVEN / deferred, with the roads

- **Draft-check tolerance — NOT PROVEN** (no pass, J-035 G1; Part V J-071/J-072 owns the pass and the harness executor that could grade it).
- **Any GPU/NPU/co-work term in the sweep — NOT PROVEN:** no device executor exists in the harness; those candidates stand excluded/unmeasurable-with-reason. Part IV owns the executors; when they land, the sweep widens and this proof re-runs against the wider field.
- **The tolerance question on a quiet machine — NOT PROVEN:** recipe for the J-052 gate / J-141 audit — on purplelongship in a guarded idle gap (204-road heartbeat checked first), run this slice's own suite (`test_within_tolerance`, same build line) and file its output beside this doc; expected ladder [1, 4, 8, 16]. The VM aggregates in §6 stand as the contended-window record either way.
- **A model-parameterised proof — NOT PROVEN / not built:** today's workloads are fixed harness shapes and no session consumes a placement (§4). Behind real session wiring, a later slice can parameterise the workloads by the opened model's own pass shapes; until then the shape-keyed form is the honest one.
- **Session consumption** of the proof (no live wiring — the established Part III pattern), and the **counted `run_all` run** (VM memory gate), as in every Part III slice.

## 10. Defects, environment, banking

**Defects.** No defect found in prior work: the choosers, harness, thread trials, and learned-file keying behaved exactly as their contracts state (all seven neighbour suites pass unchanged from this tree, §5). One observation recorded, not a defect: the J-044/J-045 fixture `olmoe` shape's ffn/ctx differ from J-015's measured file (§4) — fixture material that never claimed file identity; J-046 keys from the file record. No defect in this slice's own drafts survived to a filed number: the module and tests as banked are the first versions built (the only edits before building were naming the reply chooser's decision through the prompt module's identical decision table — the DEC codes coincide in both modules, verified first-hand).

**Environment incidents (recorded, nothing hidden).** (1) The VM was heavily contended throughout (load ~4.9–11; MemAvailable ~0.9–1.8 GB, below the inference gate) — compiles took minutes each and ran strictly one at a time; no timing in this slice is filed as a baseline. (2) Staging lived on the workspace overlay (`~/workspace/.verify-tmp/j046stage`) from the start, per the road's /tmp lesson; /tmp itself was healthy (~5%) and nothing was deleted by this slice. (3) `pixi` is not on this shell's PATH; builds ran through `~/.pixi/bin/pixi run --manifest-path ~/workspace/aesir-janas-j021/pixi.toml` — the same j021 env the prior slices used, an environment fact, not a tree defect. (4) This boot's cpuinfo names the host CPU "AMD EPYC 9D25 126-Core Processor" — reported as this boot states it.

**Banking.** Per-slice commits on `yrsa/janas-j046` (code, then doc + filed output), pushed by explicit refspec in the foreground, verified with `git ls-remote`: remote `yrsa/janas-j046` == local tip, origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`. Campaign copies of this doc + `j046_test_output.txt` in `~/workspace/model-tests/janas/`, sha-identical to the repo copies. No README touched. Hailo untouched/parked. purplelongship not used.
