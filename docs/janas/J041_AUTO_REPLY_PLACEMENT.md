# J-041 — Auto Choice for Reply Passes

**Slice:** J-041 (Part III — Choosing What Runs Where, J-035–J-052), Project Aesir Janas clean-room road.
**Roadmap text:** "Decode placement measured (incl. the integrated-GPU question: single tokens to the GPU only when measurement says yes)."
**Executed:** 2026-10-31 ~15:40–16:00 EDT. **Closure shape: the reply-pass auto-chooser is BUILT and unit-PROVEN (decision rule on synthetic sets, session keeping, manual supremacy at this slice's level), with a live run over the real J-038 harness + J-039 thread trials on the VM filed as MEASURED mechanics — outcome DEFAULT-BY-NOISE under contention (§6). The integrated-GPU question is answered honestly: NO GPU reply executor exists in this tree, so GPU candidates are EXCLUDED / UNMEASURABLE-WITH-REASON with verbatim reasons on every record — single tokens go to the GPU only when a measured GPU reply executor exists and clears the same hurdles, which is NOT PROVEN today and is faked nowhere in this slice.** No model inference ran anywhere.
**Base:** branch `yrsa/janas-j041` in fresh worktree `~/workspace/aesir-janas-j041`, from `yrsa/janas-j040` tip `b2dcd1aab6f9036a6944368a91a2d603ee2a42cd` (ls-remote verified at slice start). Origin/main stood at `ba7ee09b6b4d09967b571f2f39714e9119dc3772` at slice start (ls-remote verified); during the slice it advanced to `605562f6b919a0f58fa6decd0b45a83cdc41a6d5` by an external merge push (merges of the older `yrsa/janas-j015/j016/j017` branches; `ba7ee09b` verified ancestor of the new tip) — **not by this slice**, which pushes only its own branch refspec (§10).
**Coordination:** purplelongship untouched — the 204 road's S-099 is live there (verified first-hand this slice: `~/workspace/model-tests/ROADMAP_204_STATE.md` records S-098 closed and the S-099 SmolLM2 worker dispatched and live) and this slice yields per coordination law; §9 files the deferred laptop leg's recipe. VM MemAvailable ~0.73–0.97 GB during the runs — far below the 5,500 MB inference gate; the chooser's live proof is harness micro-work, not inference, and the gate does not block it; lightest compiles only, one at a time.

---

## 1. Question and ground

**Question.** J-040 built the prompt kind's chooser. The reply kind — single-token decode, width exactly 1 (J-035's taxonomy) — differs from prompt in the way that matters for placement: a prompt pass pays its placement's fixed costs once per batched chunk, while a reply pass pays them again for **every token generated**, and its per-pass work (a width-1 matrix-vector product) is the smallest of the three kinds. How does the engine choose a reply placement by measurement, keep it for the session instead of re-deciding it per token, report what it chose and why — and when, if ever, do single tokens go to the GPU?

**Ground, and only that ground.** The pass taxonomy is J-035's (reply is the single-token decode kind, token band 1). The option forms, precedence, and reply legality are J-036's — including its standing fact that **the NPU never takes a reply pass**: an explicit reply option naming the NPU is refused at parse, whole. The inventory truth and its refusal text are J-037's. The measurement discipline (settle discarded, median of 5, hard bounds) and candidate honesty (excluded / unmeasurable-with-reason, never silently dropped) are J-038's, inherited verbatim; J-038 also records the executor fact this slice's GPU answer stands on: **the harness's only workload executor is the CPU one — no GPU reply executor exists**. The thread ladder, its single threaded executor, and its **central honesty finding — per-kind verdicts flip between sweeps under contention, reply sweeps included** — are J-039's; J-039 §6's comparability warning (medians from different executors are not one ranking) binds this slice exactly as it bound J-040. The chooser pattern, record shape, and session keeping are J-040's. No Janas source was opened; none was needed — Janas's docs say nothing extra about decode thresholds that this slice may cite, and every design question the census does not answer is answered locally in §8.

## 2. Where the code lives, and the honest shape of the choice space

The J-040 pattern, reply-shaped — a small dedicated standalone module in `core/` plus a standalone lightest-target test suite, host contract in the module, a comment block in `aesir_engine/aesir.mojo`:

- **New module `aesir_engine/core/reply_placement.mojo`** (~800 lines): the measurement record, the pre-registered decision rule as a pure function, the session holder, the stable report, and the live entry point that builds measurements from J-038 (reply kind) + J-039 (reply kind).
- **Tests at `aesir_engine/tests/test_reply_placement.mojo`** (11 groups, §10).
- **A comment block in `aesir_engine/aesir.mojo`** beside J-040's, recording the entry point and the consumption gap. The module is not registered in `tests/run_all.mojo` (the J-031/J-036–J-040 precedent: registration rides with a counted run the VM's memory gate does not permit; the standalone suite is the filed evidence).

**Entry points:** `decide_reply_choice(measurements, option, source, default_available) -> ReplyChoiceRecord` (pure; the rule), `choose_reply_placement(options, inventory, facts, config) -> ReplyChoiceRecord` (live: measure the reply kind, then decide), `ReplyPlacementSession.decide_once(record)` + `report()` (session keeping). **This slice wires the chooser into no live session path** — no session consumes a reply placement yet, and the `aesir.mojo` comment says so; the record + report are the deliverable a CLI/server surface prints later, per the host contract in the module header.

**The choice space, honestly.**

| Candidate | State today | Where the fact comes from |
|---|---|---|
| CPU at a thread-ladder rung (1 / 2 / 4 on this VM) | **MEASURABLE — the rankable set** | J-039's trials for the reply kind: one threaded executor on the reply-shaped workload, medians comparable within the sweep |
| CPU as a device (J-038 reply sweep) | measured, but **cross-check only, never ranked** | J-038's serial executor differs from J-039's threaded one; J-039 §6 proved their serial medians are not comparable |
| GPU single (the integrated-GPU question) | EXCLUDED on this VM (absent, probe's verbatim reason); UNMEASURABLE-WITH-REASON where present | J-037 inventory; J-038: **no GPU workload executor exists in the harness yet** — there is no GPU reply measurement to rank, on any machine, today |
| NPU single | Never a legal explicit reply option (J-036 refuses it at parse); in the auto field EXCLUDED on this road (parked ledger, by law) | J-036 legality; J-037 inventory — reported, never probed, never run |
| Split (`a+b` co-work) | UNMEASURABLE-WITH-REASON where both members present; EXCLUDED where a member is absent | J-038; co-work execution is J-043 — a split timing faked by running one device twice would be a fabricated number |

So the chooser's real work today is the same shape as J-040's, on the reply kind: rank the CPU thread rungs under a rule that distrusts single sweeps, carry the rest of the field as records with reasons, fix manual choices without ranking against them, and keep whatever comes out for the session. When a GPU reply executor lands (J-043 / Part IV), its candidate enters the same record shape and must clear the same rule — the integrated-GPU answer is a gate, not a verdict against the GPU: nothing here pre-judges a future measured GPU reply win in either direction.

## 3. The decision rule — pre-registered

**This rule was written into the module header and this section before any J-041 live number was measured** (the module and this doc's §3 were authored before the first J-041 test build ran; the filed live numbers in §6 come from after). `decide_reply_choice` is the rule as a pure function, unit-tested on injected measurements (§10, groups 1–8).

**Adoption, with reasons stated.** The rule is **J-040's rule, adopted unchanged in its numbers** — same session default, same 10% margin, same separation hurdle, same decision codes. Three reasons, all from Aesir's own evidence:

1. **Comparability across kinds.** One rule means a prompt choice and a reply choice are claims of the same strength, and the learned file (J-044) stores one rule shape, not a per-kind dialect nobody measured the need for.
2. **The evidence base is the same.** J-039's reply sweeps flipped verdicts beyond a 5% band exactly as its prompt sweeps did (reply tallies in J-039 §6: all-fastest ×2, within-noise ×1, lesson-confirmed ×4 across seven runs) — the 10% band's justification (wider than 5% because verdicts flip beyond 5%) applies to reply with the same force.
3. **Reply-specific caution is already encoded, where it belongs.** Decode's per-token fixed-cost argument (§1) argues against *lowering* hurdles for reply, never for raising them on unmeasured instinct: inventing a second, larger margin without quiet-machine reply evidence would be an unmeasured number dressed as caution. The separation hurdle — a winner whose own rounds interleave the runner-up's median is not chosen — is precisely the per-token-latency guard: it refuses to switch every generated token to a candidate whose bad rounds are worse than the runner-up's typical round.

Where reply genuinely differs from prompt, the difference is recorded, not hidden: the **default stands on two grounds instead of one** — `cpu threads=1` exists wherever the inventory states a CPU present (J-040's existence argument) *and* the reply pass's own shape favours it (smallest parallelisable work, fixed thread-wake costs paid per token; §1). A threaded reply win therefore has to be *proven* by the hurdles, which is the rule working as designed.

- **Session default: `cpu threads=1` (serial).**
- **Manual first.** A single-device or co-work reply option **fixes** the choice (decision `MANUAL-FIXED`). The chooser never ranks against it and never substitutes a faster measured candidate — manual supremacy is J-047's slice; this slice's binding duty is the weaker one the task states: auto never overrides an explicit non-auto option. The named candidate's own measured state (measured / excluded / unmeasurable, with its reason) rides on the record, so a manual choice that cannot execute today is reported as exactly that; open-time refusal of a hand placement remains J-047's work, as J-038 recorded. A device option does not fix a thread count, and the record says so. (An explicit reply option naming the NPU never reaches the chooser at all — J-036 refuses it at parse; §2.)
- **Auto and race rank the measured set** (a race ranks only its named members — a faster non-member measurement, if one were ever handed in, is ignored by the ranking; test group 8). Bound-stopped candidates (partial rounds) are recorded and **never ranked**.
- **Zero measured:** the default is chosen as `NO-MEASURED-FALLBACK` when the CPU is present, with every exclusion's reason on the record; when the CPU itself is absent the record is a `REFUSAL` — no choice, reasons stated.
- **Exactly one measured:** chosen as `SOLE-MEASURED` — last candidate standing, not a victory; no margin exists and none is claimed.
- **Two or more:** let BEST be the lowest median and RUNNER the second lowest. BEST is a `MEASURED-WIN` only when **both** hurdles clear: **(a) Margin:** (runner − best) exceeds **10%** of best's median; **(b) Separation:** best's slowest counted round (its max) is still below runner's median. If either hurdle fails, the **default is kept**: `DEFAULT-BY-NOISE` when a non-default candidate was fastest but did not clear the rule, `DEFAULT-CONFIRMED` when the default itself was fastest but the win is not claimed. The record states which hurdle failed, with the numbers.

**Session keeping.** `ReplyPlacementSession` decides **once**: `decide_once` stores the first record and refuses a second decision for the same session (the refusal names J-045's re-trial road). For reply this matters more, not less, than for prompt: a per-token re-decision would tax every generated token with measurement wobble, so there is no per-token decision to wobble. The report is a stable rendering of the stored record: two reports of one session are byte-identical (test group 9). Every report carries the stability line in the open: *this choice rests on a single sweep; choice stability under contention is NOT PROVEN (J-039)*.

## 4. The choice record and report

`ReplyChoiceRecord` carries: the resolved reply option (text + source), the decision code + a decision sentence with the numbers it rests on, the chosen label (or NONE on refusal), best / runner-up / margin % / separation outcome where they exist, **every** candidate as a measurement line (measured with median/min/max/spread/rounds; excluded and unmeasurable with their verbatim reasons; bound-stopped with the rounds that stand), the device-sweep cross-check note (labelled NOT ranked, with the executor reason), and the fixed session + stability lines. The full live record from §6 is filed verbatim in `j041_test_output.txt`.

## 5. What the synthetic tests prove (PROVEN, VM, lightest target)

`test_reply_placement` groups 1–9 are pure decision/session tests on injected measurements — no clock, no machine state:

1. **Clear winner chosen:** rungs 1000 / 400 / 900 ns → `MEASURED-WIN`, threads=2, margin 125%, separation ok.
2. **Within-noise (margin):** 1000 vs 960 → `DEFAULT-BY-NOISE`, default kept, text states "inside the 10% band".
3. **Within-noise (separation):** margin clears at 25% but the winner's max (1200) interleaves the runner's median (1000) → `DEFAULT-BY-NOISE`, separation recorded failed, "interleave" stated.
4. **Default fastest, unproven:** 900 vs 950 → `DEFAULT-CONFIRMED` — chosen is the default, text states the win is withheld ("kept as the default").
5. **Sole measured:** one measured rung + one excluded GPU fixture → `SOLE-MEASURED`, "no margin is claimed", exclusion on the report.
6. **No measured:** fallback with CPU present → `NO-MEASURED-FALLBACK` (default); same field with CPU absent → `REFUSAL`, `chosen: NONE`.
7. **Manual respected:** single `gpu` fixed against a faster measured CPU (decision `MANUAL-FIXED`, GPU's UNMEASURABLE state reported, not hidden); co-work `cpu+gpu` fixed as written.
8. **Race ranks members only:** race `cpu,gpu` with a faster npu intruder in the input → the winner is a named member; the intruder never becomes best. (The intruder is an injected pure-function fixture: an explicit reply race naming the NPU is refused at parse by J-036 and can never arise through the resolve layer — the pure rule's member-only guarantee is what is pinned here.)
9. **Session keeping:** undecided session reports exactly that; `decide_once` stores; two reports byte-identical; a second `decide_once` is refused and changes nothing (`decisions_made` stays 1).

Groups 10–11 are the live runs (§6). Neighbouring suites rebuilt from this tree: `test_prompt_placement` 11/11 PASS, `test_thread_topology` 10/10 PASS, `test_placement_harness` 10/10 PASS (§10).

## 6. The live run (MEASURED — harness mechanics; the choice outcome is this VM window's, not a verdict)

Machine state: VM (KVM), AMD EPYC 9D25 126-Core Processor (as this boot's cpuinfo states it), 4 vCPU, kernel 7.0.0-39-generic, MemAvailable ~0.73 GB at the chooser run, `CUDA_VISIBLE_DEVICES` unset, real inventory + default (auto) reply options, default `HarnessConfig`. **The VM was contended throughout** — load average **6.64** at the chooser run, rising to **11.14** by the end of the neighbour runs. Full output filed as `j041_test_output.txt`.

**Filed live record (the chooser's own sweep):**

```
decision: DEFAULT-BY-NOISE -- cpu threads=2 (half the cores) was fastest
  (median 10965928 ns vs runner-up cpu threads=4 at 14077045 ns) but did
  not clear the pre-registered rule: the best candidate's slowest counted
  round (74633560 ns) does not beat the runner-up's median, so their
  rounds interleave -- the session default is kept and the faster number
  is reported, not chosen
chosen: cpu threads=1
best: cpu threads=2 median 10965928 ns; runner-up: cpu threads=4 median
  14077045 ns; margin 28%; separation failed
candidates:
  cpu threads=1: median 18765027 (min 10836865, max 69619308, spread 58782443; rounds 5)
  cpu threads=2: median 10965928 (min 9299479, max 74633560, spread 65334081; rounds 5)
  cpu threads=4: median 14077045 (min 6351337, max 66004306, spread 59652969; rounds 5)
  gpu (auto): EXCLUDED -- inventory probe-failure reason, verbatim
  npu (auto): EXCLUDED -- parked-ledger reason, verbatim
device sweep cross-check: cpu median 11771007 ns (serial executor; NOT ranked)
```

**Live manual run:** `--reply-on cpu` (via the resolve layer) → `MANUAL-FIXED`, chosen `cpu`, the device-sweep median (7,920,401 ns in that moment's contention) recorded as the named candidate's state, no ranking ran.

**Reading, honestly.** Three claims, kept separate:

1. **PROVEN (mechanics):** the chooser runs end-to-end over the real harness + trials for the reply kind on this machine; the field is complete (GPU/NPU excluded with the inventory's own reasons, never dropped); the ranked set is one executor's rungs; the record renders, the session keeps it verbatim, and a manual option fixes the choice live.
2. **MEASURED (this window's outcome):** the default was kept — the threads=2 rung was fastest by median and cleared the margin hurdle (28% > 10%), but a single 74.6 ms spike round in its five rounds broke separation against the runner-up's 14.1 ms median. Under load 6.64 that is the rule working as pre-registered: it refused to switch every generated token of a session to a candidate whose worst counted round is 5× the runner-up's median. This is exactly the legitimate filed outcome the task named in advance for a contended VM.
3. **NOT PROVEN (any stable choice):** the neighbouring `test_thread_topology` run's own reply sweep minutes later produced the **same rung ordering** (threads=2 median 12,790,756 ns < threads=4 18,262,534 ns < threads=1 21,647,761 ns; its verdict graded the i9 lesson CONFIRMED for reply — all-cores slower by 42%). Two sweeps agreeing is recorded as observed, and it is **not** promoted to stability: J-039's seven-run record shows reply orderings flipping across windows on this class of machine, and two adjacent sweeps in one contention window do not repeal that. A stable reply-placement verdict for any machine remains unproven until a quiet-machine sweep (§9) or J-045's re-trial cadence exists.

No comparison is made between the device-sweep cross-check median (11.77 ms) and any thread-rung median, per §2's executor rule; the manual run's 7.92 ms device median is likewise a different sweep at a different contention moment, compared to nothing.

## 7. Host contract (as built, nothing faked)

A surface opening a session: resolves options (J-036), observes the inventory (J-037) and CPU facts, calls `choose_reply_placement` once, stores the record in a `ReplyPlacementSession`, and prints `session.report()` beside the placement `describe()` and the inventory `device_line()`. Consumption — actually running reply passes at the chosen rung/device — does **not** exist yet: no session in the tree takes a placement, and this slice claims none. The natural wiring point is the same `aesir.mojo` comment block where J-036–J-040 recorded their contracts; when a session grows a reply-placement parameter, this record is its input. Draft-check choice (J-042), co-work execution (J-043), the learned file (J-044), and re-trials (J-045) each own their named next step.

## 8. Answered-locally records (clean-room)

- **Q: Does decode's single-token shape change the decision rule's numbers?** No census figure exists for any choice threshold (the census documents that Janas *chooses* by measurement, not the thresholds it uses — and reading its source for one is forbidden). Answered locally before measuring (§3): J-040's 10% + separation adopted unchanged, for comparability, for the identical J-039 flip evidence on reply sweeps, and because the separation hurdle already encodes the per-token caution. The reply-specific difference is carried in the *default's justification* (existence + pass shape), not in invented new numbers.
- **Q: Should single tokens go to the (integrated) GPU?** Answered from Aesir's own tree, not from Janas: there is no GPU reply executor to measure with (J-038), so the honest answer today is *unmeasurable* — the candidate is carried excluded/unmeasurable-with-reason and enters ranking only when a measured GPU reply executor exists and clears the same hurdles. Architecturally, reply is the kind *least* likely to repay a per-token device launch (smallest work per pass, fixed costs paid per token, §1) — recorded as the reason no hurdle is lowered for it, never as a substitute for the missing measurement.
- **Q: Are the device sweep's CPU numbers and the thread trials' numbers one ranking?** Answered locally from J-039 §6's own warning: no — different executors, not comparable; the device CPU timing is a labelled cross-check (§2). The ranked axis is the single-executor thread ladder.
- **Q: What does a manual option do to the thread axis?** Answered locally (as J-040): nothing — a `--reply-on cpu` names a device, not a thread count; the record states the thread axis stands where the session leaves it rather than inventing a coupling (§3).
- **Q: Where does the NPU sit for reply?** Answered from J-036/J-037, not invented: explicitly named, it is refused at parse (never reaches the chooser); in the auto field it is enumerated by the harness and excluded by the inventory's parked-ledger reason. Both records are on every live record, verbatim.
- **Q: When nothing measures, choose or refuse?** Answered locally (as J-040): fall back to the default when its device is present, refuse only when even the default's device is absent (§3). Both branches are unit-pinned (group 6).

## 9. NOT PROVEN list, and the deferred laptop leg

- **GPU reply choice (the integrated-GPU question as a measurement)** — no GPU workload executor exists in the harness; the candidate is carried excluded/unmeasurable-with-reason. Choice of GPU for single tokens is NOT PROVEN until a GPU reply executor is built (J-043 / Part IV) and measured under this same rule; nothing here fakes a number for it, and nothing here rules a future measured GPU win out.
- **Stability of any choice** — single sweeps flip (§6, claim 3); the session record claims a kept choice, never a stable one. J-045 owns re-trials.
- **Any model placement verdict or tok/s claim** — the live proof ran the harness's reply-shaped micro-workload, not a model decode pass; a real model's reply placement (per-token weight traffic, KV-cache interplay, batch-1 latency on real weights) is unmeasured.
- **Consumption by any session** — no surface calls the chooser yet (§7); at-open callability is proven by the entry point's shape and the live test calls.
- **The purplelongship leg — DEFERRED-WITH-REASON:** the 204 road's S-099 is live on the box (verified in `ROADMAP_204_STATE.md` this slice; yield per coordination law) and this worker has no device route. It is also the leg that could earn a *quieter* choice and the road's only integrated-GPU-shaped question with real hardware behind it. Exact recipe: (1) confirm the 204 heartbeat is clear and no aesir/build process is live on the box; (2) fetch `yrsa/janas-j041` on-box into a fresh tree; (3) stage the pthread shim (`cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o <stage>/libaesir_par.so -lpthread`); (4) build `test_reply_placement` via the repo pixi env (`mojo build -I . -I aesir_engine -Xlinker -L<stage> -Xlinker -laesir_par`), run with `LD_LIBRARY_PATH=<stage>`; (5) run it **three times** with loadavg + Tctl recorded per run and file the three live records verbatim: a decision that holds in all three (same code, same chosen label) is the road's first stable-ish reply choice, labelled MEASURED-INDICATIVE; disagreement is reported as the instability it is. Expected ladder on the recorded Ryzen 9 4900HS facts: [1, 4, 8, 16], derived on-box from its own facts. **GPU reply executor prerequisite, named:** the laptop leg still cannot answer the integrated-GPU question — no GPU reply executor exists in the harness on any machine; that executor (a device-executor build in the J-043 / Part IV line) must land first, after which the same three-run recipe with the GPU candidate measurable is the first honest GPU reply measurement. If the leg ever runs a model, ids-first discipline applies (ids compared before any timing is believed).
- **The full counted suite (`run_all`) on this tree** — not run (memory gate), per the road's precedent; the standalone suites are the filed evidence.

## 10. Defects, environment incidents, tests and banking

**Defects.** No defect found in prior work: J-036's resolve (including its NPU-for-reply parse refusal, exercised by this slice's live paths), J-037's inventory reasons (carried verbatim into the live record), J-038's sweep for the reply kind and J-039's reply trials all behaved exactly as their contracts state — the neighbouring suites pass unchanged from this tree. This slice's own build needed one correction **before any number was filed**: the first draft of the live builder read the *prompt* option's source for the reply record (`options.prompt.source`); caught on first-hand re-read of the builder before the first build, fixed to `options.reply.source`, and every filed number comes from the fixed build. The first build then compiled (only the tree's standing `alloc`/`alias` deprecation warnings) and the first run passed all 11 groups.

**Environment incidents (recorded, nothing hidden).** (1) The VM is heavily contended (load 6.64 at the chooser run, 11.14 by the last neighbour run; MemAvailable ~0.73–0.97 GB) — contention is part of §6's record, stated there. (2) Staging was placed on the workspace overlay (`~/workspace/.verify-tmp/j041stage`) from the start, per J-040's /tmp-loss lesson; /tmp was not used and nothing was deleted by this slice. (3) The slice-start `git fetch` ran on degraded GitHub HTTPS and took ~11 s; it completed and the worktree was created from the ls-remote-verified j040 tip. (4) This boot's cpuinfo names the host CPU "AMD EPYC 9D25 126-Core Processor" where J-040's boot stated "9D64 88-Core" — reported as this boot states it; the chooser depends only on the 4-vCPU topology both boots agree on.

**Unit tests PROVEN (VM, lightest target):** `test_reply_placement.mojo` built standalone (recipe in `j041_test_output.txt`) and run on the VM: **11/11 groups PASS** — clear winner; within-noise by margin; within-noise by separation; default-fastest-unproven; sole measured; no-measured fallback + refusal; manual single + co-work; race members only; session keeping; live chooser (auto); live manual. **Neighbouring suites rebuilt from this tree: `test_prompt_placement` 11/11 PASS, `test_thread_topology` 10/10 PASS, `test_placement_harness` 10/10 PASS.** Full output filed as `j041_test_output.txt` beside this doc, sha-identical in the campaign copies. No inference ran; no other suite was rebuilt (memory gate), and none is claimed. (`test_device_inventory` was not rebuilt: this slice touches no inventory code, and the live record carries its reasons verbatim through the chooser's own live groups.)

**Banking:** filed on `yrsa/janas-j041`: `aesir_engine/core/reply_placement.mojo` (new), `aesir_engine/tests/test_reply_placement.mojo` (new), the comment block in `aesir_engine/aesir.mojo`, this doc and `j041_test_output.txt` under `docs/janas/` — with sha-identical campaign copies of doc + test output in `~/workspace/model-tests/janas/`. Push by explicit refspec (foreground) with `git ls-remote` verification that the branch moved to the local HEAD; origin/main is not written by this slice (it advanced externally during the slice, header note); the commit hash and ls-remote lines are recorded in the campaign state file entry for J-041 (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
