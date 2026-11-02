# J-039 — Thread Topology Trials

**Slice:** J-039 (Part III — Choosing What Runs Where, J-035–J-052), Project Aesir Janas clean-room road.
**Roadmap text:** "Thread topology trials. Per pass kind: all-cores vs performance-cores-only vs hybrid counts, measured on purplelongship (and the VM where the memory gate allows); the i9 lesson from Janas's docs (more threads can be slower) tested on Aesir's own hardware, not assumed."
**Executed:** 2026-10-31 ~14:47–15:05 EDT. **Closure shape: ladder + threaded trial harness built and unit-proven; live trials MEASURED on the VM (seven sweeps per kind) with an honestly unstable verdict under this VM's contention (see §6 — no stable per-kind thread verdict is claimed from this machine in this window); the purplelongship leg is DEFERRED-WITH-REASON with an exact recipe (§7).** No model inference ran anywhere. The timings are **MEASURED harness mechanics** (J-038's micro-workload shapes, threaded) — not placement verdicts for any model (J-040–J-042 own choices, on real passes).
**Base:** branch `yrsa/janas-j039` in fresh worktree `~/workspace/aesir-janas-j039`, from `yrsa/janas-j038` tip `7441f063be15cd51138827fe6174845c0a8d4c33` (ls-remote verified at slice start). Origin/main untouched at `ba7ee09b6b4d09967b571f2f39714e9119dc3772` (ls-remote verified at banking, §11).
**Coordination:** purplelongship untouched — the 204 road's S-099 worker was dispatched ~14:3x EDT and is live there (204 heartbeat, checked at slice start), and this worker has no device route in any case; the laptop leg is deferred with reason + recipe (§7). VM MemAvailable ~0.9–1.5 GB during the runs — far below the 5,500 MB inference gate; these trials are light CPU micro-work, not inference, and the gate does not block them; lightest compiles only, one at a time.

---

## 1. Question and ground

**Question.** J-038 measured *device* candidates with a single-threaded workload and recorded the thread axis as this slice's: given a pass kind, which thread count should its CPU passes run at on this machine — and is Janas's documented i9 lesson (on a hybrid i9, *more threads can be slower*) true on Aesir's own hardware, or is it a property of Janas's machine that Aesir should not import?

**Ground, and only that ground.** The lesson and the sweep dimension are the filed census's J-003/J-008 rows (the bench "sweeps the configurations the engine may choose (threads × cores × GPU/NPU per pass kind)"). The pass kinds are J-035's role-primary taxonomy (prompt / draft-check / reply). The topology facts are J-037's `CpuFacts` and its rule that a performance/efficiency split exists only when the machine's own hybrid sysfs states it. The discipline (settle + rounds, median, hard bounds) is J-038's, reused. The threading vehicle is Aesir's own thread layer (`core/parallel.mojo`: `par_for` over the pthread shim, controlled by `AESIR_THREADS` / `AESIR_PAR_MIN_WORK` — the same knobs J-030 §3 recorded as existing but never run; this slice runs them at micro scale). Everything the census does not answer is answered from Aesir's own tree and measurements and recorded in §8. No Janas source was opened; none was needed.

## 2. Where the code lives, and why

The road's established pattern (J-036 §2, J-037 §3, J-038 §2): a small dedicated standalone module in `core/` plus a standalone lightest-target test suite, host contract in the module, a comment block in `aesir_engine/aesir.mojo`. This slice follows it exactly:

- **New module `aesir_engine/core/thread_topology.mojo`** (~700 lines): ladder derivation from `CpuFacts`, the threaded workload executor, the trial sweep under J-038's `HarnessConfig` discipline (reusing `summarize_timings`, `monotonic_ns`, `prepare_workload`, `run_workload_once` from `placement_harness` — no discipline is re-derived), the pre-registered verdict as a pure function, and the live-facts reader (cpuinfo + hybrid sysfs, read exactly as J-037's observer reads them).
- **Tests at `aesir_engine/tests/test_thread_topology.mojo`** (10 groups, §11).
- **A comment block in `aesir_engine/aesir.mojo`** beside J-036/J-037/J-038's, recording the entry point and the consumption gap. The module is not registered in `tests/run_all.mojo` (the J-031/J-036/J-037/J-038 precedent: registration rides with a counted run the VM's memory gate does not permit; the standalone suite is the filed evidence).

**Entry point:** `run_thread_trials(facts, pass_kind, workload, config) -> ThreadSweep` — callable at model open OR on demand; it sets Aesir's thread knobs per rung and unsets them when the sweep ends, on every path including raises. **This slice wires it into no live session path** — no session consumes a thread verdict yet; consumption and choice are J-040–J-042.

## 3. The ladder, derived from the machine's own facts

Candidates are derived from J-037 `CpuFacts` and nothing else, de-duplicated by count and sorted ascending:

| Rung | Count source |
|---|---|
| serial | 1, always |
| half the cores | physical cores ÷ 2 (physical when cpuinfo states it, else the logical count — the basis is recorded on the ladder) |
| all physical cores | distinct (physical id, core id) pairs |
| all logical processors | a distinct rung only when it differs from physical (SMT) |
| performance cores only | **only** when the machine itself states a hybrid split (both sysfs cpulists, counted verbatim — J-037's road) |

Where no split is stated, the ladder records performance/efficiency as **NOT APPLICABLE-WITH-REASON** — a P/E rung is never guessed from a model name, a core count, or another machine's shape. A hybrid machine's perf+eff total is its all-logical rung, labelled as such; the distinct hybrid rung is perf-only. Derivation is unit-proven on fixtures for the VM shape [1, 2, 4], a stated hybrid [1, 6, 8 perf-only, 12], SMT [1, 4, 8 physical, 16 logical], small machines ([1, 2], [1]), and topology-poor facts (physical unstated → rungs stand on the logical count, basis stated).

**This VM's ladder (live facts, PROVEN):** `1 (serial), 2 (half the cores), 4 (all cores (physical == logical))` — basis: physical core count stated by cpuinfo (4); performance/efficiency NOT APPLICABLE-WITH-REASON (no split stated; `/sys/devices/cpu_core` + `/sys/devices/cpu_atom` do not exist on this VM, host-checked). So on this machine the roadmap's "performance-cores-only vs hybrid counts" has no candidate to trial, and none was invented: the i9's *mechanism* (a P/E split) is not present here and is **not tested** by anything in this slice — what is tested is the lesson's *shape* (can more threads be slower) on uniform cores (§6).

## 4. The threaded executor, and its identity proof

The trial reuses J-038's exact workload shapes (reply 1 × (1024 → 512) reps 4; prompt 16 × (512 → 256) reps 2; same deterministic LCG data, prepared once per sweep). The threaded round computes the same product partitioned by output columns through `par_for` (each output element independent, fixed per-element reduction order — the GEMM kernels' own contract), materialises the output, and accumulates the checksum serially in the serial path's exact order. Two consequences are enforced, not hoped:

- **Checksum identity:** every threaded round's checksum must equal the J-038 serial workload's checksum **exactly**, at every thread count, or the sweep raises (a thread count that changed the arithmetic would be a defect, never a timing). Held in every round of every run in §6.
- **Chunk proof:** `par_for` returns the chunk count used; every filed round records it, and it equals the rung's thread count in every round (the proof the rung's threads really ran — the knob is also read back directly in the test suite: `par_thread_count()` follows `set_thread_knobs`, and clearing restores the online-CPU default).

Trials set `AESIR_PAR_MIN_WORK=1` per rung, stated plainly: the engine's small-work engagement threshold exists to protect real small passes from thread overhead; a trial that let it silently serialise a rung would file serial timings under threaded labels. The threshold is part of the measurement design, recorded here and in the module header — not hidden.

## 5. The verdict rule, pre-registered

Stated before any number was measured (it is the module header's text, and a pure function `grade_thread_results` unit-tested on injected medians): for one pass kind, let BEST be the measured rung with the lowest median and ALL the measured rung with the most threads. **I9 LESSON CONFIRMED** for the kind when BEST uses fewer threads than ALL and ALL's median exceeds BEST's by more than **5%** of BEST's median (the noise band — a smaller median gap on a shared machine is not evidence). **ALL-CORES FASTEST** when ALL is BEST; **WITHIN NOISE** when BEST is narrower but the gap is inside the band. The rule grades one sweep; §6 reports every sweep run, because on this machine the sweeps disagree — and that disagreement is the result.

## 6. The VM trials (MEASURED — mechanics and run records; verdict stability NOT PROVEN)

Machine state: VM (KVM), AMD EPYC 9D64 88-Core Processor, 4 vCPU, kernel 7.0.0-39-generic, MemAvailable ~0.9–1.5 GB, **load average 2.5–8.6 across the runs (1-min / 5-min / 15-min readings between 2.54/6.15/7.25 and 6.57/8.57/8.10)** — the VM was heavily oversubscribed by sibling campaign work throughout; that contention is part of every number below. Default config (settle 1, measured 5, bounds 2,000 ms / 10,000 ms). Full output of one complete run plus three further filed runs: `j039_test_output.txt` (10/10 groups PASS in every run; seven complete sweeps per kind were executed in total — three console runs and the four filed runs).

**Filed run (medians, ns):**

| Kind | 1 thread | 2 threads | 4 threads (all) | Verdict (§5 rule) |
|---|---|---|---|---|
| reply | 29,829,729 | 37,757,790 | 78,755,508 | CONFIRMED — all-cores slower by 164% |
| prompt | 23,485,025 | 24,866,932 | 40,241,161 | CONFIRMED — all-cores slower by 71% |
| draft-check | UNMEASURABLE-WITH-REASON (G1) at every rung — no pass exists to thread | | | not graded |

**All seven sweeps (medians in ms, 1 / 2 / 4 threads; verdict per §5):**

| Run | reply medians | reply verdict | prompt medians | prompt verdict |
|---|---|---|---|---|
| 1 | 13.54 / 12.07 / 11.21 | ALL FASTEST | 10.30 / 16.15 / 9.44 | ALL FASTEST |
| 2 | 8.60 / 11.60 / 7.19 | ALL FASTEST | 8.85 / 8.89 / 9.99 | CONFIRMED (+12%) |
| 3 | 8.83 / 7.81 / 9.63 | CONFIRMED (+23%) | 10.54 / 5.21 / 4.75 | ALL FASTEST |
| 4 (filed) | 29.83 / 37.76 / 78.76 | CONFIRMED (+164%) | 23.49 / 24.87 / 40.24 | CONFIRMED (+71%) |
| 5 | 11.53 / 11.98 / 12.06 | WITHIN NOISE | 9.28 / 9.84 / 26.70 | CONFIRMED (+187%) |
| 6 | 23.79 / 30.63 / 50.73 | CONFIRMED (+113%) | 16.36 / 10.78 / 20.51 | CONFIRMED (+90%) |
| 7 | 14.50 / 22.37 / 32.12 | CONFIRMED (+121%) | 11.91 / 14.41 / 11.01 | ALL FASTEST |

Tallies — reply: ALL FASTEST ×2, WITHIN NOISE ×1, CONFIRMED ×4. Prompt: ALL FASTEST ×3, CONFIRMED ×4. Spreads are enormous throughout (individual rounds of 50–215 ms against ~5–30 ms medians — the oversubscription arriving mid-sweep).

**Reading, honestly.** Three distinct claims, kept separate:

1. **PROVEN (mechanics):** the ladder derives correctly from live facts; threaded rounds execute at the rung's real thread count (chunk proof); threaded arithmetic is bit-identical to serial at every count; the bounds hold live (a 1 ns budget bound-stops every rung with zero counted rounds); draft-check is unmeasurable-with-reason, never proxied.
2. **MEASURED (run records):** in this window, more-threads-slower outcomes are real and frequent on this VM — all-cores lost in 8 of 14 kind-sweeps, by up to +187% — and they cluster in the heavier-contention runs (4–7), while the lightest runs (1–3) split both ways. A consistent mechanism explains the pattern (interpretation, labelled as such): a 4-thread round on a 4-vCPU host with load ≈ 6–8 needs four vCPUs co-scheduled at once, so contention taxes width itself. Serial medians also swing 3× between runs (8.6–29.8 ms for reply), so no absolute median here is a machine baseline.
3. **NOT PROVEN (the verdict the roadmap wants):** no *stable* per-kind thread verdict exists from this VM in this window — the same binary, shapes, and rule flip verdicts run to run, so neither "all-cores wins" nor "the i9 lesson holds" may be claimed as a property of Aesir on this hardware. The lesson's shape is confirmed as *possible and common under contention*; its i9 mechanism (P/E hybrid) is absent here and untested. The discriminating measurement needs a quiet machine — §7's leg, on 8 physical cores with no sibling load, is where a stable verdict can be earned. J-040/J-041 must not consume any single sweep above as a choice input.

One comparison expressly not made: this slice's serial-rung medians are not comparable to J-038's serial medians (7.35 ms reply / 9.74 ms prompt) — the threaded round materialises its output and pays a serial checksum pass the J-038 round does not, and the contention moments differ. The honest base for each sweep is its own serial rung.

## 7. The purplelongship leg — NOT PROVEN / DEFERRED-WITH-REASON, with recipe

The roadmap names purplelongship first for these trials, and it is the machine that can settle §6's open verdict: Ryzen 9 4900HS (campaign record, J-015: 16 threads, RTX 2060 Max-Q — GPU unused by this slice), 8 physical cores by that part's SMT shape, no P/E split expected. It was **not** run: the 204 road's S-099 worker was dispatched ~14:3x EDT and is live there (yield per coordination law — never contend, never stack), and this worker has no device route to the box in any case. No laptop number is claimed or dressed up.

**Expected ladder (derivation, not measurement):** the module derives the ladder on-box from the box's own live inventory facts, whatever they state; on the recorded facts (16 logical threads) the expected ladder is [1, 4 (half of 8 physical), 8 (all physical), 16 (all logical / SMT)] with performance/efficiency NOT APPLICABLE-WITH-REASON unless the box's own sysfs states a split. If the on-box facts differ, the ladder follows the facts.

**Recipe (exact, for the first guarded idle gap):** (1) confirm the 204 heartbeat is clear and no aesir/tf_oracle/build process is live on the box; record loadavg + Tctl; (2) fetch branch `yrsa/janas-j039` on-box; stage the shim (`cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o <staging>/libaesir_par.so -lpthread`); build `mojo build -I . -I aesir_engine -Xlinker -L<staging> -Xlinker -laesir_par aesir_engine/tests/test_thread_topology.mojo` via the repo pixi env; (3) run the binary **three times** with `LD_LIBRARY_PATH=<staging>`, loadavg + Tctl recorded per run; (4) file the three outputs verbatim beside this doc and grade stability across the three: a per-kind verdict that holds in all three is the road's first stable thread verdict; (5) if the three disagree on a quiet box, report that — the instability is then a property of the shapes, not of contention, and J-040/J-041 inherit it as stated.

## 8. Answered-locally records (clean-room)

- **Q: Which thread counts are "the" candidates?** The census names the sweep dimension (threads × cores) but no ladder Aesir could re-check without opening source. Answered locally (§3): serial / half / all-physical / all-logical, plus perf-only only when the machine states a split — every count traceable to the inventory's facts.
- **Q: How is a thread count applied to a pass?** Answered locally from Aesir's own tree: the engine's documented knobs (`AESIR_THREADS` chunk count in `core/parallel.par_for`, J-030 §3) — the same surface a user or session would use, not a test-only path. The engagement threshold is set to 1 during trials for the stated reason (§4).
- **Q: What gap makes "more threads slower" a finding rather than noise?** No census figure exists. Answered locally before measuring (§5): 5% of the best median, applied to median-of-5 — and §6 then showed even that discipline cannot stabilise a verdict under this VM's contention, which is reported rather than argued away.
- **Q: Does the i9 lesson transfer to a machine with no hybrid split?** Answered locally: the lesson's *mechanism* does not transfer (no split exists here, §3); its *shape* was tested anyway, because contention can tax width on any machine — and did (§6, claim 2).

## 9. NOT PROVEN list

- **Any stable per-kind thread verdict on any machine.** The VM sweeps flip (§6); the laptop leg is deferred (§7). J-040/J-041 own choices and must earn them on real passes with a stable measurement.
- **The purplelongship trials** — deferred with reason and recipe (§7), including the expected ladder, which is a derivation, not a measurement.
- **Performance-only / hybrid trials anywhere** — no machine available to this slice states a split; the perf-only rung is proven only on injected fixtures (test group 2).
- **The i9 mechanism itself** (P/E-core scheduling effects) — absent on both machines in this road's reach; neither confirmed nor refuted.
- **Any model placement or speed claim.** These are harness micro-workload mechanics; threaded rounds of real model passes (and their interaction with `AESIR_PAR_MIN_WORK` at production settings) are unmeasured.
- **Consumption by any session.** No surface calls `run_thread_trials` yet (§2); at-open/on-demand callability is proven by the entry point's shape and the live test calls.
- **The full counted suite (`run_all`) on this tree** — not run (memory gate), per the road's precedent; the standalone suites are the filed evidence.

## 10. Defects

- **No defect found in prior work:** J-036's options, J-037's inventory (its live line reproduced verbatim by the neighbouring suite rebuilt from this tree), and J-038's harness (its serial checksum is this slice's identity reference, and its suite passes unchanged, §11) all behaved exactly as their contracts state. J-030's record that the `AESIR_THREADS` knob existed un-run is closed by use here, at micro scale, as designed.
- **This slice's own first build:** one compile error (a `List` field copy needs an explicit `.copy()` in this toolchain) — fixed before any number was measured; every filed number is from the fixed build. The `alloc` deprecation warnings match the tree's own existing style (`core/compute.mojo` uses the same form).

## 11. Tests and banking

**Unit tests PROVEN (VM, lightest target):** `test_thread_topology.mojo` built standalone (build recipe in `j039_test_output.txt`, including the pthread-shim staging the thread layer requires) and run on the VM: **10/10 groups PASS in every one of the seven runs executed** — ladder from VM-shaped facts [1, 2, 4] with P/E not-applicable-with-reason; ladder on a machine-stated hybrid split [1, 6, 8 perf-only, 12]; ladder on SMT [1, 4, 8, 16]; de-duplication on small machines; topology-poor facts (basis stated); the verdict rule on injected medians (all-fastest / band edge / confirmed); threaded checksum identity vs serial at 1/2/4 threads with chunks == threads; the thread knobs set/read-back/clear; live trials (all rungs measured, 5 rounds + settle, chunks == threads); draft-check unmeasurable-with-reason (G1) + the live 1 ns bound. **Neighbouring suites rebuilt from this tree: `test_device_inventory` 9/9 PASS, `test_placement_harness` 10/10 PASS.** Full output filed as `j039_test_output.txt` beside this doc, sha-identical in the campaign copies. No inference ran; no other suite was rebuilt (memory gate), and none is claimed.

**Banking:** filed on `yrsa/janas-j039`: `aesir_engine/core/thread_topology.mojo` (new), `aesir_engine/tests/test_thread_topology.mojo` (new), the comment block in `aesir_engine/aesir.mojo`, this doc and `j039_test_output.txt` under `docs/janas/` — with sha-identical campaign copies of doc + test output in `~/workspace/model-tests/janas/`. Push by explicit refspec (foreground) with `git ls-remote` verification that the branch moved and origin/main stayed at `ba7ee09b`; the commit hash and ls-remote lines are recorded in the campaign state file entry for J-039 (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
