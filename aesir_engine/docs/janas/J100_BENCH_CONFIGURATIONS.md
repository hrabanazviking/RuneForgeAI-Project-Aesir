# J-100 — The Bench That Measures Configurations

**Slice:** J-100 (Part VII — The Tool Family, J-099–J-118), Project Aesir Janas clean-room road.
**Roadmap text:** "The bench that measures configurations. Aesir's `bench` grows the Janas shape: it sweeps the configurations the placement engine may choose (threads × devices × pass kinds), with settle and rounds, and prints the machine report — the single most useful artefact a new machine can produce (docs/hardware.md's lesson)."
**Owns (J-099 census):** row **T08** — "put the J-038 harness's sweep behind a user-facing `bench` command (threads × devices × pass kinds, settle + rounds)." Row **T09** (the `--report` artefact with filed examples) is **J-101's**, not this slice's: J-100 delivers the sweep and the machine report it prints to the terminal; it does not grow `--report` and files no J-101 examples.
**Base:** branch `yrsa/janas-j100` in fresh worktree `~/workspace/aesir-janas-j100`, from `yrsa/janas-j099` tip `ceec2765b35a4733f728d1cb26891499cb51d094` (ls-remote verified at slice start: remote `yrsa/janas-j099` == that hash, remote `yrsa/janas-j100` absent — the duplicate guard; origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`).
**Clean-room record:** no Janas material was consulted in this slice beyond the road's own already-filed clean-room records — the J-099 census (row T08 and its neighbours), the J-038 harness doc (which files the census's J-008 bench row: the documented bench "sweeps the configurations the engine may choose (threads × cores × GPU/NPU per pass kind), with settle (300 ms in the published runs) and rounds"), and this roadmap's text. No Janas source code was opened, in this slice or any other. Every design question those records do not answer is answered from Aesir's own architecture and recorded as answered-locally in §7.

---

## 0. Protocol (committed first, before any code was built)

This section was committed before the bench module, the CLI command, or any test existed. It states the sweep space, what settle and rounds mean mechanically, what the machine report contains, and the verdict rule for the slice; everything after §0 is filed under these rules and no others.

### 0.1 The sweep space, stated before building

The bench sweeps exactly the configurations the placement engine may choose, as Parts III filed them — no axis is invented here:

- **Pass kinds (J-035, role-primary):** `prompt`, `draft-check`, `reply` — three kinds, in that order.
- **Device axis (J-036 options × J-037 inventory, measured by J-038):** for each kind, the candidates `enumerate_candidates` produces under the **default resolved options** (every kind `auto`, no kills): one single-device candidate per device in the auto field — `cpu`, `gpu`, `npu` on an unkilled machine. Each candidate carries J-038's classification verbatim: **MEASURABLE** (present CPU single), **EXCLUDED** with the inventory's own refusal text (absent device), or **UNMEASURABLE-WITH-REASON** (draft-check always — J-035 gap G1; co-work; a present device with no executor). The bench bench-marks under `auto` because `auto` is the field the placement engine itself chooses among; hand placements are J-047's refusal surface, not a bench axis.
- **Thread axis (J-039):** the ladder `derive_thread_ladder` derives from the machine's own `CpuFacts` — serial, half the cores, all cores, plus all-logical (SMT) and performance-only rungs only when the machine states them. On this VM the expected ladder is **[1, 2, 4]** (4 vCPU, no stated hybrid split — the performance/efficiency record is NOT APPLICABLE-WITH-REASON, never invented).
- **Cells:** the cross product, kind × device candidate × thread rung — on this VM **3 × 3 × 3 = 27 cells**, every one enumerated and reported; none is silently dropped. A cell is **measured** only where a real executor exists for it: today that is exactly the CPU cells of `prompt` and `reply` (2 kinds × 1 device × 3 rungs = **6 measured cells**), whose medians come from J-039's threaded executor (each threaded round's checksum asserted identical to the serial workload's). Every other cell carries its classification and reason **per rung** — the reason is the device's or the kind's, stated identically at each rung it blocks, so the table shows the whole field the engine may choose from, including the parts it may not choose today and why.

### 0.2 Settle and rounds, mechanically

The bench discipline is J-038's `HarnessConfig`, reused whole — this slice re-derives nothing:

- **Settle:** `settle_rounds` (default **1**, config refuses 0) rounds are executed and timed per candidate/rung, and their timings are **discarded** — they absorb first-touch costs (page faults, cold caches, first allocation) that are properties of the process, not of the configuration. (Janas's documented settle is a 300 ms time; J-038 §3 re-derived it as rounds for Aesir's far shorter micro-runs, and this slice stands on that derivation.)
- **Rounds:** `measured_rounds` (default **5**, config refuses < 3) rounds are timed and counted per candidate/rung. The reported statistic is the **median**, with min / max / spread (max − min) beside it so the noise is never hidden by the robust statistic.
- **Bounds:** per-candidate **2,000 ms** and per-sweep **10,000 ms** hard bounds, checked between rounds and between candidates (a round in flight always finishes, so overshoot is at most one round). The bounds apply **per kind-sweep** (one device sweep and one thread sweep per kind — six harness sweeps in a full bench); the bench prints each sweep's total and the bench total, so the whole run's wall is accounted, never implied to fit inside one sweep bound. A candidate stopped by a bound is reported **BOUND-STOPPED with the rounds that stand**, never silently truncated.
- **Workloads:** J-038's pass-shaped micro-workloads, unchanged — reply 1 × (1024 → 512) reps 4; prompt 16 × (512 → 256) reps 2; deterministic LCG data prepared once per sweep, bit-identical for every candidate. These are harness mechanics: **their timings are not placement verdicts for any model** (J-040–J-042 own choices, on real passes), and the report says so on its face.

### 0.3 The machine report, stated before building

`bench` prints one stable, sendable text report (the form a user can paste and a developer can act on):

1. **Header:** `aesir bench — machine report`, the bench discipline line (settle discarded / measured rounds / median), and the honesty line (micro-workload timings, harness mechanics, not placement verdicts).
2. **Machine lines:** J-037's `device_line()` verbatim (every device kind quantified or refused-with-reason on one line) and J-039's ladder `describe()` verbatim (rungs, basis, performance/efficiency status).
3. **Per kind, in taxonomy order:** the J-038 device sweep's own report lines, the J-039 thread sweep's own report lines (including its graded i9-lesson verdict where it grades), the **cell table** (one line per cell of §0.1: measured with median/min/max/spread/rounds, or its classification + reason), and the **fastest measured cell** line for the kind (or "no measured cell" with the reason that is true for every cell of that kind).
4. **Footer:** cells enumerated / measured counts, bench total wall, and the closing honesty line (what was not measured and why, in one breath).

The report is a pure render of the sweep results (`machine_report()` over a `BenchReport`): same results, same text, on every machine. J-101 grows `--report` (the filed artefact form + per-model tables + examples) on top of this render; nothing in J-101's scope is built here.

### 0.4 The CLI surface

A new command module `cli/bench.mojo` with `dispatch_bench`, wired into `cli/commands.mojo`'s dispatch beside `hardware`/`compute`, and one help line:

```
aesir bench [--settle N] [--rounds N] [--pass prompt|reply|draft-check]
```

No `--pass` runs all three kinds. Unknown options, duplicate options, a missing value, `--settle 0`, or `--rounds` below 3 raise the usage error (the `HarnessConfig` refusals stand behind them). Placement options are **not** bench flags in this slice: the bench sweeps the default `auto` field (§0.1); a flag that narrowed the field would need its own slice's evidence, and none is smuggled in. `--report` is refused as an unknown option — it is J-101's, and silently accepting it here would fake that slice.

### 0.5 Where the code lives, and why

The road's established pattern (J-036 §2, J-037 §3, J-038 §2, J-039 §2): a small dedicated standalone module in `core/` plus a standalone lightest-target test suite, the host contract written in the module, and a comment block in `aesir_engine/aesir.mojo`:

- **New module `aesir_engine/core/bench_configurations.mojo`:** the bench config (a validated wrapper over `HarnessConfig`), the pure cell enumeration over (options, inventory, facts), the sweep runner composing J-038's `run_placement_measurement` + J-039's `run_thread_trials` per kind, the fastest-cell grading as a pure function, and the `machine_report()` render. It imports only the Part III modules it composes.
- **New CLI module `aesir_engine/cli/bench.mojo`:** argument parsing + live observation (inventory, CPU facts) + the run + the print. It imports the core bench module only — never the engine facade — so the command stays buildable at the lightest target.
- **Tests at `aesir_engine/tests/test_bench_configurations.mojo`**, in the tree's test style, standalone lightest target, not registered in `tests/run_all.mojo` (the J-031/J-036–J-039 precedent: registration rides with a counted run the VM's memory gate does not permit; the standalone suite is the filed evidence).
- **A comment block in `aesir_engine/aesir.mojo`** beside J-036–J-039's, recording the entry point and the consumption gap (no session consumes a bench report yet; choice remains J-040–J-042's, learned-file persistence J-044's).
- **A filed driver `docs/janas/j100_bench.mojo`** that calls `dispatch_bench` with its own argv — the lightest-target executable proof of the CLI module, and the vehicle for the live smoke in §0.6(d).

### 0.6 Verdict rule for this slice (pre-registered)

The slice **passes** iff all of the following hold, each filed:

(a) **Unit suite:** `test_bench_configurations` builds at the lightest target and every group PASSes — including the enumeration cross-product on fixtures (VM-shaped facts + absent-GPU/parked-NPU inventory ⇒ 27 cells, exactly 6 measurable, draft-check all-unmeasurable, GPU/NPU reasons verbatim), the config refusals, the fastest-cell grading on injected results (measured-only, ties keep the first cell in table order, a kind with no measured cell grades "no measured cell"), and the report render's load-bearing lines.
(b) **Neighbours unchanged:** `test_placement_harness` (J-038) and `test_thread_topology` (J-039) rebuilt from this tree PASS with exactly their filed group counts (10 and 10).
(c) **Inspect:** `docs/janas/j100_inspect.py` re-derives every load-bearing claim in this doc from the tree (module/CLI/dispatch/help/facade literals, the cell arithmetic, the filed outputs' tallies) and PASSes; every FAIL is disposed in the doc, never hidden.
(d) **Live smoke (gated):** the bench driver runs **once** on the VM with default config (the small/short configuration: ~10 ms rounds, six harness sweeps, seconds of wall) **only if** MemAvailable > 5,500 MB at the moment of the run; its printed machine report is filed verbatim in the test output. If the gate fails at run time, the live leg is **DEFERRED-WITH-REASON** in the doc with this exact recipe, and the slice closes on (a)+(b)+(c). No live sweep runs on purplelongship in this slice (the 204 road owns it; yielded). Any number the smoke prints is **MEASURED harness mechanics** on the stated machine state — never a placement verdict, never a model speed.

**Honesty classes.** Enumeration, classification, grading, and rendering are **PROVEN** by the unit suite where it passes. Live timings are **MEASURED** harness mechanics under the machine state stated beside them. Anything not run is **NOT PROVEN** and named in §6.

**No README is touched. Hailo stays parked (no finish-line branch contact, no chip run or probe). No Docker. Nothing is deleted to free disk.**

---

## 1. Headline

**Aesir has a `bench` command.** `aesir bench [--settle N] [--rounds N] [--pass prompt|reply|draft-check]` sweeps the whole field the placement engine may choose — **27 cells (3 pass kinds × 3 device candidates × 3 thread rungs)** on this VM — under J-038's settle + rounds discipline, and prints the machine report: the machine's device line and thread ladder, per kind the device sweep, the thread sweep with its graded verdict, the cell table with every cell's timing or its exact reason, and the kind's fastest measured cell. **Unit suite 8/8 groups PASS; neighbours J-038 10/10 and J-039 10/10 PASS rebuilt from this tree; the filed driver builds.** Exactly **6 cells measure** (CPU × prompt/reply × the three rungs); the other 21 carry their reasons — GPU/NPU excluded by this VM's inventory, draft-check unmeasurable at every rung (G1). The live driver smoke against the VM's *real* inventory is **DEFERRED-WITH-REASON** (§5): MemAvailable fell below the 5,500 MB gate before it could run; the sweep itself ran end-to-end inside the test suite over fixture inventory at ~5,666 MB (§4), and the exact smoke recipe is filed.

## 2. What was built

- **`aesir_engine/core/bench_configurations.mojo`** (new): `BenchConfig` (the discipline over J-038's `HarnessConfig`, refusals inherited), `enumerate_bench_cells` (the pure cross product, classifications verbatim from J-038's `enumerate_candidates`, rungs from J-039's `derive_thread_ladder`), `run_bench_sweep` (per kind: J-038's `run_placement_measurement` + J-039's `run_thread_trials`, then the CPU cells filled rung-by-rung from the thread sweep — a bound-stopped rung fills as BOUND-STOPPED with the rounds that stand), `fastest_cell_index` (pure grading: measured cells only, lowest median, ties keep table order, −1 when a kind has none), and `BenchReport.machine_report()` (the stable render of §0.3; also exposed as the free function `machine_report(report)`).
- **`aesir_engine/cli/bench.mojo`** (new): `dispatch_bench` — parses `--settle` / `--rounds` / `--pass` (duplicates, missing values, unknown options, and non-positive counts all refused with usage; **`--report` refused as unknown — it is J-101's**), resolves the default placement options, observes the real inventory (`observe_device_inventory`) and CPU facts (`observe_cpu_facts`), runs the sweep, prints the report (with `--pass`, the machine header plus that kind's section only). `bench_main()` adapts real argv for the filed driver. The module imports the core layers only, never the engine facade, so it builds at the lightest target.
- **Wiring:** `cli/commands.mojo` imports `dispatch_bench`, routes `bench` beside `hardware`/`compute`, and the general help lists it (the reserved `llama-bench` compatibility name is untouched and stays a separate surface). `aesir_engine/aesir.mojo` gains the J-100 comment block beside J-036–J-039's, recording the entry point and the consumption gap.
- **Tests:** `aesir_engine/tests/test_bench_configurations.mojo` (8 groups, §6). **Driver:** `docs/janas/j100_bench.mojo` (builds; its live run is §5's deferred leg). Not registered in `tests/run_all.mojo` (the standing precedent; §0.5).

## 3. The sweep as it ran (suite live group, fixture inventory)

The test suite's live group ran `run_bench_sweep` end-to-end over the VM-shaped fixtures (CPU present; GPU absent with a fixture reason; NPU parked from the ledger; ladder [1, 2, 4]) — the full printed report is filed verbatim in `j100_test_output.txt`. Its shape, honestly read:

- **Prompt:** device sweep CPU median **9,565,064 ns**; thread medians 10,198,074 (1) / 13,445,438 (2) / 19,795,257 (4) — J-039's rule grades **I9 LESSON CONFIRMED** (all-cores slower by 94%).
- **Reply:** device sweep CPU median **8,543,441 ns**; thread medians 10,900,108 (1) / 15,538,619 (2) / 9,535,540 (4) — graded **ALL-CORES FASTEST**.
- **Draft-check:** every sweep line and all 9 cells UNMEASURABLE (G1); fastest line: none.
- **Totals:** 27 enumerated, 6 measured; bench total 1,352,266,834 ns (~1.35 s).

**Reading of the numbers, honestly:** these are **MEASURED harness mechanics** on a heavily contended VM (load average ~5.5–7.2 from sibling campaigns; individual rounds of 60–82 ms against ~9–20 ms medians — spreads of 53–70 ms). The two thread verdicts above are one run's grades under that contention; per J-039's own finding on this machine (seven sweeps, verdicts disagreeing run to run), **verdict stability is NOT PROVEN** and no per-kind thread or placement conclusion is drawn from them. What the run proves is the bench's mechanics: the whole field enumerated, the measurable cells measured with checksums asserted inside J-039's executor, every other cell reasoned, the report rendered whole.

## 4. Machine state for every number

VM (KVM), AMD EPYC 9D64 88-Core Processor, 4 vCPU, kernel 7.0.0-39-generic. MemAvailable ~5,666 MB (5,532,448 kB) at the test-suite runs — above the 5,500 MB gate — falling to ~5,094 MB (4,974,828 kB) by the smoke decision. No inference ran anywhere; lightest compiles only, one at a time. purplelongship not used at all (the 204 road owns it; yielded per coordination law).

## 5. Deferred leg — the live driver smoke (DEFERRED-WITH-REASON)

**What:** one run of the built driver `j100_bench` (real `observe_device_inventory` + `observe_cpu_facts` on this VM, default config), printing the machine report from the machine's own truth rather than fixtures. **Why deferred:** §0.6(d)'s gate — MemAvailable must exceed 5,500 MB at the moment of the run; it measured 4,974,828 kB (~5,094 MB) at decision time and was falling under sibling-campaign load. The driver **builds (exit 0)**; only its live run waits. **Exact recipe:** in a window with MemAvailable > 5,500 MB (check `grep MemAvailable /proc/meminfo` immediately before), run `LD_LIBRARY_PATH=~/workspace/.verify-tmp/j100stage ~/workspace/.verify-tmp/j100build/j100_bench` (rebuild per the header of `j100_test_output.txt` if the staging is gone), file its stdout verbatim as an addendum to `j100_test_output.txt`, and record the run in the state file. Expected shape: the §3 report with the VM's real GPU-absence reason (nvidia-smi probe text) in place of the fixture's. J-101's filed VM example may discharge this leg if it runs the same default bench on the VM under the gate — the keeper/J-101 worker should cite this deferral there either way.

## 6. Tests and inspect

**Unit suite PROVEN (VM, lightest target):** `test_bench_configurations` **8/8 groups PASS**, build exit 0, run exit 0 — config defaults + refusals (settle 0, rounds < 3); kind order (prompt, draft-check, reply); enumeration on VM fixtures (**27 cells: 6 pending-measured, 12 excluded with the inventory's reasons verbatim, 9 draft-check unmeasurable naming G1**); enumeration on GPU-present fixtures (27 cells: GPU cells turn UNMEASURABLE-with-reason — 15 unmeasurable, only the parked NPU's 6 excluded); fastest-cell grading on injected cells (lowest median, kinds separate, excluded cell with a fake low median ignored, ties keep table order, no-measured-kind grades −1); the report render on an injected report (header, device line, ladder line, fastest line, footer counts, honesty line); CLI refusals (six malformed invocations, incl. `--report`); and the live sweep over fixtures (no cell left pending, all 6 CPU cells resolved measured-or-bound-stopped, draft-check fastest = none). **Neighbours rebuilt from this tree: `test_placement_harness` 10/10 PASS, `test_thread_topology` 10/10 PASS** — exactly their filed counts. Full output: `j100_test_output.txt`. **Inspect:** `j100_inspect.py` re-derives the load-bearing claims from the tree (module/CLI/dispatch/help/facade literals, the 27/6 arithmetic, the filed tallies, no README in the slice diff); its output is filed as `j100_inspect_output.txt` and every FAIL, if any, is disposed in §7.

## 7. Defects

- **Found and fixed in scope (this slice's own test, first run):** the suite's first run exited 1 at 7/8 groups — the live group expected the report's draft-check fastest line to read "(draft-check)", but the tree's `pass_name()` (J-036) names the kind **"drafts"**, so the rendered line is "fastest measured cell (drafts): none". The expectation was corrected to the tree's vocabulary (the report follows the tree, not the test). The same pass widened the CLI: `--pass` now accepts **"drafts"** as a spelling beside "draft-check" (both name the one kind; the refusal cases are unchanged). Every filed number is from the fixed suite's run; the first run's failure is recorded in `j100_test_output.txt`'s header, not hidden.
- **Inspect's own first run: 41/42, one FAIL disposed here.** The check "core module refuses --report scope" asserted the literal `--report` never appears in `bench_configurations.mojo` — it matched the module header's *prose* sentence recording that J-101 grows `bench --report` (a scope statement, not flag logic). The check was over-broad, not the module wrong: it now asserts the quoted flag literal `"--report"` (the form a parser would carry) is absent, and the re-run is clean. No filed claim rested on the first run.
- **No defect found in prior work:** J-038's harness and J-039's trials behaved exactly as their contracts state inside the composition — enumeration reasons carried verbatim into the cells, threaded checksums asserted by J-039's executor on every counted round of §3's run, and both neighbour suites pass unchanged from this tree.

## 8. Answered-locally records (clean-room)

- **Q: Under which placement options does the bench sweep — `auto`, or every hand placement too?** The filed census row names the sweep dimension as "the configurations the engine may choose". Answered locally (§0.1): the default resolved options (every kind `auto`, no kills) — `auto` *is* the engine's choice field; hand placements are single named configurations a user already chose, guarded by J-047's refusal surface, not a bench axis. A field-narrowing bench flag is future work for a slice with its own evidence, not smuggled in here.
- **Q: Where do a cell's timings live when the device axis and the thread axis were measured by two different sweeps?** Answered locally (§0.1, §2): the cell table is the cross product's *record*; a CPU cell's median is its rung's J-039 thread-sweep median (the only threaded executor), and J-038's device sweep is printed as its own section beside it (its CPU line is the serial-executor measurement of the same workload). The two numbers are never blended into one cell, and the report shows both, labelled.
- **Q: One bench bound, or J-038's per-sweep bounds?** Answered locally (§0.2): J-038's bounds stand per kind-sweep (six sweeps in a full bench); the bench prints each sweep total and the bench total, so no reader can mistake the whole run for one bounded sweep.

## 9. NOT PROVEN list

- **The live driver smoke on real inventory** — DEFERRED-WITH-REASON (§5, recipe filed).
- **Any placement verdict, for any model, device, or pass kind** — the bench measures J-038's micro-workloads; choices remain J-040–J-042's, on real passes.
- **Thread-verdict stability on this VM** — one run's grades under heavy contention (§3); J-039's instability finding stands.
- **Any GPU/NPU cell measurement** — no device executor exists (J-038 §4 rule 4 stands); on this VM the GPU is absent and the NPU parked in any case. GPU-present enumeration is proven only against fixtures (test group 4).
- **Consumption of a bench report by any session, choice, or the learned file** — no surface consumes one yet (§2); the comment block in `aesir.mojo` says so.
- **`bench --report`, per-model read/write tables, filed examples** — J-101's, untouched here by design.
- **The full counted suite (`run_all`) on this tree and the full CLI binary build (`main.mojo`)** — not run (memory gate, the road's standing precedent); the bench command is proven through its own lightest-target driver build, and `commands.mojo`'s three-line wiring is inspect-verified.
- **purplelongship** — nothing in this slice ran there (coordination); the bench is machine-agnostic and its laptop proof rides with J-101's filed examples.

## 10. Banking

Filed on `yrsa/janas-j100`: `aesir_engine/core/bench_configurations.mojo` (new), `aesir_engine/cli/bench.mojo` (new), the dispatch + help wiring in `aesir_engine/cli/commands.mojo`, the comment block in `aesir_engine/aesir.mojo`, `aesir_engine/tests/test_bench_configurations.mojo` (new), and under `docs/janas/`: this doc, `j100_inspect.py`, `j100_inspect_output.txt`, `j100_test_output.txt`, `j100_bench.mojo` — with sha-identical campaign copies of the doc, inspect script + output, test output, and driver in `~/workspace/model-tests/janas/`. Protocol committed first (§0 + inspect script, before any code). Push by explicit refspec (foreground git only) with `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6`; the commit hashes and ls-remote lines are recorded in the campaign state file entry for J-100 (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
