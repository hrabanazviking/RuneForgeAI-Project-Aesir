# J-040 — Auto Choice for Prompt Passes

**Slice:** J-040 (Part III — Choosing What Runs Where, J-035–J-052), Project Aesir Janas clean-room road.
**Roadmap text:** "The engine picks prompt placement by measurement (CPU / GPU / split), keeps it for the session, reports what it chose and why."
**Executed:** 2026-10-31 ~15:12–15:31 EDT. **Closure shape: the prompt-pass auto-chooser is BUILT and unit-PROVEN (decision rule on synthetic sets, session keeping, manual supremacy at this slice's level), with a live run over the real J-038 harness + J-039 thread trials on the VM filed as MEASURED mechanics — outcome DEFAULT-CONFIRMED under heavy contention (§6). GPU/split choice is NOT PROVEN and is carried excluded/unmeasurable-with-reason throughout — no device executor exists yet, and no GPU or split number is faked anywhere in this slice.** No model inference ran anywhere.
**Base:** branch `yrsa/janas-j040` in fresh worktree `~/workspace/aesir-janas-j040`, from `yrsa/janas-j039` tip `35023d8abf7c52431842029ef922baa51caad03c` (ls-remote verified at slice start). Origin/main untouched at `ba7ee09b6b4d09967b571f2f39714e9119dc3772` (ls-remote verified at banking, §10).
**Coordination:** purplelongship untouched — the 204 road's S-099 is live there (per the keeper's dispatch note) and this slice needs no on-box leg by design; §9 files the deferred laptop leg's recipe for the first slice that wants a quieter machine's choice. VM MemAvailable ~0.7–1.1 GB during the runs — far below the 5,500 MB inference gate; the chooser's live proof is harness micro-work, not inference, and the gate does not block it; lightest compiles only, one at a time.

---

## 1. Question and ground

**Question.** J-036 says what a user *asks for*, J-037 what the machine *offers*, J-038 *measures* device candidates, and J-039 measures the CPU thread ladder — but nothing yet *chooses*. For the prompt pass kind: how does the engine turn those measurements into one placement, keep it for the session instead of re-deciding it per token, and report what it chose and why — honestly, on a machine whose own thread verdicts J-039 just proved flip between sweeps?

**Ground, and only that ground.** The pass taxonomy is J-035's (prompt is the batched-prefill kind). The option forms and precedence are J-036's (auto / single / `a+b` co-work / comma race; kills; sources). The inventory truth and its refusal text are J-037's. The measurement discipline (settle discarded, median of 5, hard bounds) is J-038's, and its candidate honesty (excluded / unmeasurable-with-reason, never silently dropped) is inherited verbatim. The thread ladder and its executor are J-039's, including its **central honesty finding: under VM contention per-kind verdicts flip between sweeps, so no single sweep may be consumed as a stable verdict** — the decision rule in §3 is designed around that finding, not despite it. The roadmap's own J-040 sentence names CPU / GPU / split as the choice space; §2 records what of that space can honestly be chosen today. No Janas source was opened; none was needed. Questions the census does not answer are answered locally and recorded in §8.

## 2. Where the code lives, and the honest shape of the choice space

The road's established pattern (J-036 §2 through J-039 §2): a small dedicated standalone module in `core/` plus a standalone lightest-target test suite, host contract in the module, a comment block in `aesir_engine/aesir.mojo`. This slice follows it exactly:

- **New module `aesir_engine/core/prompt_placement.mojo`** (~640 lines): the measurement record, the pre-registered decision rule as a pure function, the session holder, the stable report, and the live entry point that builds measurements from J-038 + J-039.
- **Tests at `aesir_engine/tests/test_prompt_placement.mojo`** (11 groups, §10).
- **A comment block in `aesir_engine/aesir.mojo`** beside J-036/J-037/J-038/J-039's, recording the entry point and the consumption gap. The module is not registered in `tests/run_all.mojo` (the J-031/J-036–J-039 precedent: registration rides with a counted run the VM's memory gate does not permit; the standalone suite is the filed evidence).

**Entry points:** `decide_prompt_choice(measurements, option, source, default_available) -> PromptChoiceRecord` (pure; the rule), `choose_prompt_placement(options, inventory, facts, config) -> PromptChoiceRecord` (live: measure, then decide), `PromptPlacementSession.decide_once(record)` + `report()` (session keeping). **This slice wires the chooser into no live session path** — no session consumes a prompt placement yet, and the `aesir.mojo` comment says so; the record + report are the deliverable a CLI/server surface prints later, per the host contract in the module header.

**The choice space, honestly.** The roadmap names CPU / GPU / split. On today's tree the measurable axis is narrower, and the chooser says so on every record instead of pretending otherwise:

| Candidate | State today | Where the fact comes from |
|---|---|---|
| CPU at a thread-ladder rung (1 / 2 / 4 on this VM) | **MEASURABLE — the rankable set** | J-039's trials: one threaded executor, medians comparable within the sweep |
| CPU as a device (J-038 sweep) | measured, but **cross-check only, never ranked** | J-038's serial executor differs from J-039's threaded one; J-039 §6 proved their serial medians are not comparable — ranking across executors would compare two workloads and call it placement |
| GPU single | EXCLUDED on this VM (absent, probe's reason); UNMEASURABLE-WITH-REASON where present | J-037 inventory; J-038: no device executor exists in the harness yet |
| NPU single | EXCLUDED on this road (parked ledger, by law) | J-037; Hailo stays parked — reported, never probed, never run |
| Split (`a+b` co-work) | UNMEASURABLE-WITH-REASON where both members present; EXCLUDED where a member is absent | J-038; co-work execution is J-043 — a split timing faked by running one device twice would be a fabricated number |

So the chooser's real work today is: rank the CPU thread rungs under a rule that distrusts single sweeps, carry the rest of the field as records with reasons, fix manual choices without ranking against them, and keep whatever comes out for the session. When device executors land (J-043 / Part IV), their candidates enter the same record shape and the same rule — nothing in the rule is CPU-specific except the default (§3).

## 3. The decision rule — pre-registered

**This rule was written into the module header and this section before any J-040 live number was measured** (the module and this doc's §3 were authored before the first test build ran; the filed live numbers in §6 come from after). `decide_prompt_choice` is the rule as a pure function, unit-tested on injected measurements (§10, groups 1–8).

- **Session default: `cpu threads=1` (serial).** It exists wherever the inventory states a CPU present, needs no co-scheduling and no topology assumption, and is the fallback every non-win lands on.
- **Manual first.** A single-device or co-work prompt option **fixes** the choice (decision `MANUAL-FIXED`). The chooser never ranks against it and never substitutes a faster measured candidate — manual supremacy is J-047's slice; this slice's binding duty is the weaker one the task states: auto never overrides an explicit non-auto option. The named candidate's own measured state (measured / excluded / unmeasurable, with its reason) rides on the record, so a manual choice that cannot execute today is reported as exactly that; open-time refusal of a hand placement remains J-047's work, as J-038 recorded. A device option does not fix a thread count, and the record says so.
- **Auto and race rank the measured set** (a race ranks only its named members — a faster non-member measurement, if one were ever handed in, is ignored by the ranking; test group 8). Bound-stopped candidates (partial rounds) are recorded and **never ranked**: a partial sweep is not a measurement of the candidate.
- **Zero measured:** the default is chosen as `NO-MEASURED-FALLBACK` when the CPU is present, with every exclusion's reason on the record; when the CPU itself is absent the record is a `REFUSAL` — no choice, reasons stated. A chooser that invents a placement on an empty field would be fabricating.
- **Exactly one measured:** chosen as `SOLE-MEASURED` — last candidate standing, not a victory; no margin exists and none is claimed.
- **Two or more:** let BEST be the lowest median and RUNNER the second lowest. BEST is a `MEASURED-WIN` only when **both** hurdles clear:
  - **(a) Margin:** (runner − best) exceeds **10%** of best's median. The band is deliberately wider than J-039's 5% thread band: J-039 showed verdicts flipping between sweeps even beyond 5% under contention, so a chooser that re-decides on a 5% wobble would pretend stability the measurements do not have.
  - **(b) Separation:** best's slowest counted round (its max) is still below runner's median — the two candidates' rounds do not interleave.
  
  If either hurdle fails, the **default is kept**: `DEFAULT-BY-NOISE` when a non-default candidate was fastest but did not clear the rule, `DEFAULT-CONFIRMED` when the default itself was fastest but the win is not claimed. The choice is the same CPU the session would have run anyway; what the rule withholds is the *claim*, and the record states which hurdle failed, with the numbers.

**Session keeping.** `PromptPlacementSession` decides **once**: `decide_once` stores the first record and refuses a second decision for the same session (the refusal names J-045's re-trial road). This is the direct answer to J-039's flip finding — a wobbling measurement cannot re-decide a running session token by token because there is no per-token decision to wobble. The report is a stable rendering of the stored record: two reports of one session are byte-identical (test group 9), which is what makes it testable and what a CLI/server surface can print verbatim later. Every report carries the stability line in the open: *this choice rests on a single sweep; choice stability under contention is NOT PROVEN (J-039)*.

## 4. The choice record and report

`PromptChoiceRecord` carries: the resolved option (text + source), the decision code + a decision sentence with the numbers it rests on, the chosen label (or NONE on refusal), best / runner-up / margin % / separation outcome where they exist, **every** candidate as a measurement line (measured with median/min/max/spread/rounds; excluded and unmeasurable with their verbatim reasons; bound-stopped with the rounds that stand), the device-sweep cross-check note (labelled NOT ranked, with the executor reason), and the fixed session + stability lines. The full live record from §6 is filed verbatim in `j040_test_output.txt`.

## 5. What the synthetic tests prove (PROVEN, VM, lightest target)

`test_prompt_placement` groups 1–9 are pure decision/session tests on injected measurements — no clock, no machine state:

1. **Clear winner chosen:** rungs 1000 / 400 / 900 ns → `MEASURED-WIN`, threads=2, margin 125%, separation ok.
2. **Within-noise (margin):** 1000 vs 960 → `DEFAULT-BY-NOISE`, default kept, text states "inside the 10% band".
3. **Within-noise (separation):** margin clears at 25% but the winner's max (1200) interleaves the runner's median (1000) → `DEFAULT-BY-NOISE`, separation recorded failed, "interleave" stated.
4. **Default fastest, unproven:** 900 vs 950 → `DEFAULT-CONFIRMED` — chosen is the default, text states the win is withheld ("kept as the default").
5. **Sole measured:** one measured rung + one excluded GPU fixture → `SOLE-MEASURED`, "no margin is claimed", exclusion on the report.
6. **No measured:** fallback with CPU present → `NO-MEASURED-FALLBACK` (default); same field with CPU absent → `REFUSAL`, `chosen: NONE`.
7. **Manual respected:** single `gpu` fixed against a faster measured CPU (decision `MANUAL-FIXED`, GPU's UNMEASURABLE state reported, not hidden); co-work `cpu+gpu` fixed as written.
8. **Race ranks members only:** race `cpu,gpu` with a faster npu intruder in the input → the winner is a named member; the intruder never becomes best.
9. **Session keeping:** undecided session reports exactly that; `decide_once` stores; two reports byte-identical; a second `decide_once` is refused and changes nothing (`decisions_made` stays 1).

Groups 10–11 are the live runs (§6). Neighbouring suites rebuilt from this tree: `test_thread_topology` 10/10 PASS, `test_placement_harness` 10/10 PASS (§10).

## 6. The live run (MEASURED — harness mechanics; the choice outcome is this VM window's, not a verdict)

Machine state: VM (KVM), AMD EPYC 9D64 88-Core Processor, 4 vCPU, kernel 7.0.0-39-generic, MemAvailable ~0.7–1.1 GB, `CUDA_VISIBLE_DEVICES` unset, real inventory + default (auto) options, default `HarnessConfig`. **The VM was heavily contended throughout** — load average **11.54** at the chooser run (the VM had just rebooted; sibling work was live), 5.10 at the neighbouring thread-topology run, easing to 1.69 by the end. Full output filed as `j040_test_output.txt`.

**Filed live record (the chooser's own sweep):**

```
decision: DEFAULT-CONFIRMED -- the default itself was fastest (cpu threads=1 (serial),
  median 9258588 ns vs runner-up cpu threads=4 at 17663274 ns) but the win is not
  claimed: the best candidate's slowest counted round (66574932 ns) does not beat
  the runner-up's median, so their rounds interleave -- the default is kept as the default
chosen: cpu threads=1
best: cpu threads=1 median 9258588 ns; runner-up: cpu threads=4 median 17663274 ns;
  margin 90%; separation failed
candidates:
  cpu threads=1: median 9258588 (min 8219058, max 66574932, spread 58355874; rounds 5)
  cpu threads=2: median 29279619 (min 10484927, max 80548141, spread 70063214; rounds 5)
  cpu threads=4: median 17663274 (min 14927341, max 79121572, spread 64194231; rounds 5)
  gpu (auto): EXCLUDED -- inventory probe-failure reason, verbatim
  npu (auto): EXCLUDED -- parked-ledger reason, verbatim
device sweep cross-check: cpu median 16372419 ns (serial executor; NOT ranked)
```

**Live manual run:** `--prompt-on cpu` (via the resolve layer) → `MANUAL-FIXED`, chosen `cpu`, the device-sweep median (89,654,691 ns in that moment's contention) recorded as the named candidate's state, no ranking ran.

**Reading, honestly.** Three claims, kept separate:

1. **PROVEN (mechanics):** the chooser runs end-to-end over the real harness + trials on this machine; the field is complete (GPU/NPU excluded with the inventory's own reasons, never dropped); the ranked set is one executor's rungs; the record renders, the session keeps it verbatim, and a manual option fixes the choice live.
2. **MEASURED (this window's outcome):** the default was kept — not because nothing was faster by median (the serial rung *was* fastest, by 90% over the runner-up) but because a single 66.6 ms spike round in the winner's own five rounds broke separation. Under load 11.5 that is the rule working as pre-registered: it refused to convert a spiky sweep into a claimed win. The task named this outcome in advance — *if VM contention makes the outcome default-by-noise, that is a legitimate filed result, not a failure to hide* — and `DEFAULT-CONFIRMED` is that outcome's precise form here (the default was the fastest candidate, so the code is CONFIRMED rather than BY-NOISE; the withheld claim is the same).
3. **NOT PROVEN (any stable choice):** minutes later, the neighbouring `test_thread_topology` run's own prompt sweep on the same machine graded **all-cores fastest** (threads=4 median 25,850,405 ns vs serial 88,760,530 ns) — the opposite ordering from the chooser's sweep. That is J-039's flip finding demonstrated again inside this slice's own evidence, and it is exactly why the record claims a kept choice for the session and no stability beyond it. A stable prompt-placement verdict for any machine remains unproven until a quiet-machine sweep (§9) or J-045's re-trial cadence exists.

No comparison is made between the device-sweep cross-check median (16.37 ms) and any thread-rung median, per §2's executor rule; the manual run's 89.65 ms device median is likewise a different sweep at a worse contention moment, compared to nothing.

## 7. Host contract (as built, nothing faked)

A surface opening a session: resolves options (J-036), observes the inventory (J-037) and CPU facts, calls `choose_prompt_placement` once, stores the record in a `PromptPlacementSession`, and prints `session.report()` beside the placement `describe()` and the inventory `device_line()`. Consumption — actually running prompt passes at the chosen rung/device — does **not** exist yet: no session in the tree takes a placement, and this slice claims none. The natural wiring point is the same `aesir.mojo` comment block where J-036–J-039 recorded their contracts; when a session grows a prompt-placement parameter, this record is its input. Reply choice (J-041), draft-check choice (J-042), co-work execution (J-043), the learned file (J-044), and re-trials (J-045) each own their named next step.

## 8. Answered-locally records (clean-room)

- **Q: What margin makes a measured winner?** No census figure exists for a choice rule (the census documents that Janas *chooses* by measurement, not the threshold it uses — and reading its source for one is forbidden). Answered locally before measuring (§3): 10% of the winner's median **and** round separation (winner's max below runner's median) — both derived from Aesir's own J-039 evidence (verdict flips beyond a 5% band; spreads that dwarf medians under contention).
- **Q: What is the default when measurement does not prove a winner?** Answered locally: `cpu threads=1` — the one candidate that exists on every machine the inventory can describe, with no co-scheduling or topology assumption. (J-039's filed run also had serial fastest for prompt on this VM, but the default stands on the existence argument, not on that run — a default that needed a measurement would not be a default.)
- **Q: Are the device sweep's CPU numbers and the thread trials' numbers one ranking?** Answered locally from J-039 §6's own warning: no — different executors, not comparable; the device CPU timing is a labelled cross-check (§2). The ranked axis is the single-executor thread ladder.
- **Q: What does a manual option do to the thread axis?** Answered locally: nothing — a `--prompt-on cpu` names a device, not a thread count; the record states the thread axis stands where the session leaves it rather than inventing a coupling (§3).
- **Q: When nothing measures, choose or refuse?** Answered locally: fall back to the default when its device is present (the session can run exactly as it runs today — refusing would break working sessions over a measurement failure), refuse only when even the default's device is absent (§3). Both branches are unit-pinned (group 6).

## 9. NOT PROVEN list, and the deferred laptop leg

- **GPU / split (co-work) prompt choice** — no device executor and no split pass exist; candidates are carried excluded/unmeasurable-with-reason. Choice among them is NOT PROVEN until J-043 / Part IV build executors; nothing here fakes a number for them.
- **Stability of any choice** — single sweeps flip (§6, claim 3); the session record claims a kept choice, never a stable one. J-045 owns re-trials.
- **Any model placement verdict or tok/s claim** — the live proof ran the harness's prompt-shaped micro-workload, not a model prompt pass; a real model's prompt placement (batch shapes, memory pressure, cache interplay) is unmeasured.
- **Consumption by any session** — no surface calls the chooser yet (§7); at-open callability is proven by the entry point's shape and the live test calls.
- **The purplelongship leg — DEFERRED-WITH-REASON:** the 204 road's S-099 is live on the box (yield per coordination law) and this worker has no device route. It is also the leg that could earn a *quieter* choice: same recipe shape as J-039 §7 — confirm the 204 heartbeat is clear and no aesir/build process is live; fetch `yrsa/janas-j040` on-box; stage the pthread shim; build `test_prompt_placement` via the repo pixi env; run it **three times** with loadavg + Tctl recorded per run; file the three live records verbatim: a decision that holds in all three (same code, same chosen label) is the road's first stable-ish prompt choice, labelled MEASURED-INDICATIVE; disagreement is reported as the instability it is. Expected ladder on the recorded Ryzen 9 4900HS facts: [1, 4, 8, 16], derived on-box from its own facts.
- **The full counted suite (`run_all`) on this tree** — not run (memory gate), per the road's precedent; the standalone suites are the filed evidence.

## 10. Defects, environment incidents, tests and banking

**Defects.** No defect found in prior work: J-036's resolve, J-037's inventory reasons (carried verbatim into the live record), J-038's sweep and J-039's trials all behaved exactly as their contracts state — the neighbouring suites pass unchanged from this tree, and J-039's comparability warning *improved* this slice's design (§2) rather than being violated by it. This slice's own work needed no post-measurement fix: the first build compiled (only the tree's standing `alloc`/`alias` deprecation warnings) and the first run passed all 11 groups; no filed number comes from a superseded build.

**Environment incidents (recorded, nothing hidden).** (1) The VM had just rebooted when this slice ran (uptime measured in minutes; load 11.54 at the live run) — contention is part of §6's record, stated there. (2) The first build's staging under `/tmp` was lost mid-slice (the tmpfs did not survive); nothing was deleted by this slice — staging was rebuilt on the workspace overlay (`~/workspace/.verify-tmp/j040stage`) and all filed builds/runs come from it. MemAvailable ~0.7–1.1 GB throughout: lightest targets only, one build at a time, no inference.

**Unit tests PROVEN (VM, lightest target):** `test_prompt_placement.mojo` built standalone (recipe in `j040_test_output.txt`) and run on the VM: **11/11 groups PASS** — clear winner; within-noise by margin; within-noise by separation; default-fastest-unproven; sole measured; no-measured fallback + refusal; manual single + co-work; race members only; session keeping; live chooser (auto); live manual cpu. **Neighbouring suites rebuilt from this tree: `test_thread_topology` 10/10 PASS, `test_placement_harness` 10/10 PASS.** Full output filed as `j040_test_output.txt` beside this doc, sha-identical in the campaign copies. No inference ran; no other suite was rebuilt (memory gate), and none is claimed.

**Banking:** filed on `yrsa/janas-j040`: `aesir_engine/core/prompt_placement.mojo` (new), `aesir_engine/tests/test_prompt_placement.mojo` (new), the comment block in `aesir_engine/aesir.mojo`, this doc and `j040_test_output.txt` under `docs/janas/` — with sha-identical campaign copies of doc + test output in `~/workspace/model-tests/janas/`. Push by explicit refspec (foreground) with `git ls-remote` verification that the branch moved and origin/main stayed at `ba7ee09b`; the commit hash and ls-remote lines are recorded in the campaign state file entry for J-040 (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
