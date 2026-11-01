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

*(§§1–8 are filed below from the build, under this protocol.)*
