# J-101 — The Machine Report

**Slice:** J-101 (Part VII — The Tool Family, J-099–J-118), Project Aesir Janas clean-room road.
**Roadmap text:** "The machine report. `bench --report`: hardware inventory, per-model read/write table, device lines with refusal reasons, in a form a user can send and a developer can act on; filed examples from purplelongship and the VM."
**Owns (J-099 census):** row **T09** — "a `bench --report` artefact — hardware inventory + per-model read/write table + device lines with refusal reasons in one sendable file; no filed examples" (verdict at J-099: PARTIAL — the pieces exist, the artefact does not).
**Base:** branch `yrsa/janas-j101` in fresh worktree `~/workspace/aesir-janas-j101`, from `yrsa/janas-j100` tip `de9213cb372ecc141e1e8218db1da466dae13313` (ls-remote verified at slice start: remote `yrsa/janas-j101` absent — the duplicate guard; remote `yrsa/janas-j100` == that hash; origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`).
**Clean-room record:** no Janas material was consulted in this slice beyond the road's own already-filed clean-room records — the roadmap text, the J-099 census (row T09), and the J-100 doc (its §0.3 report shape, §0.4 CLI refusal, §5 deferred smoke, §9 scope line). No Janas source code was opened, in this slice or any other. Every design question those records do not answer is answered from Aesir's own architecture and filed records, and recorded as answered-locally in §7.

---

## 0. Protocol (committed first, before any code was built)

This section was committed before the report module, the CLI change, or any test existed. It states the artefact's shape, the per-model table's evidence rule (stated before building, per the slice's commission), the CLI composition rules, and the verdict rule for the slice; everything after §0 is filed under these rules and no others.

### 0.1 The artefact, stated before building

`bench --report` prints ONE sendable text artefact, built by extension on J-100's render — never a parallel render that could drift from it:

1. **A label line** naming what the artefact is and where its numbers come from (`live machine observation` for a CLI run on a real machine; a fixture example carries the word FIXTURE in its label — a fixture artefact is never filed or quoted as a live example).
2. **J-100's `machine_report()` text, verbatim** — the header, discipline and honesty lines, the hardware inventory (J-037's `device_line()` verbatim and J-039's ladder `describe()` verbatim), the per-kind sweeps, the cell table, and the footer. This section alone carries item (a) hardware inventory and the bench half of item (c).
3. **The per-model read/write table** (§0.2): one line per filed model row, each cell carrying its source and honesty class on the line itself.
4. **The device refusal summary:** J-037's `device_line()` verbatim again as one line, then each device entry's own `render()` on its own line — present devices quantified, absent devices carrying their exact refusal reason (J-037's entry text, never paraphrased). This is item (c) in the form a developer can act on: one device per line, reason attached.
5. **A closing honesty line:** what the artefact is not (not a placement verdict, not a model-speed claim beyond the filed rows' own classes).

The artefact is a pure render (`report_artefact()` over a `BenchReport` plus the filed model rows): same results, same text, on every machine.

### 0.2 The per-model read/write table — the evidence rule, stated before building

**Rule: a cell of this table may carry only (i) a number already proven or filed in this tree, cited on the line with its source slice and its honesty class, or (ii) an exact-arithmetic (ACCOUNTED) quantity from a filed accounting slice, cited the same way, or (iii) the words NOT PROVEN with the reason. No wall, rate, or latency is invented, simulated, or extrapolated for this table; a model with no filed number gets a NOT PROVEN row, not a plausible one.**

The rows filed under this rule (each re-read first-hand from its source doc in this slice):

- **OLMoE Q4_K_M** — read 2.389 tok/s / write 2.556 tok/s, purplelongship CPU+disk streaming line, **MEASURED-INDICATIVE** (single runs per leg; J-030 §4, re-verifying the J-022/J-023 legs; token identity across those legs PROVEN, the walls indicative).
- **Qwen2.5-Coder-7B-Instruct-heretic Q4_K_M** (the J-091 ladder witness, wave crown pin) — read and write walls **NOT PROVEN** at every rung (deferred, J-091 §7); the ACCOUNTED frame is cited on the row (KV f16 bytes at the ladder's ends; the CAP_REFUSED cells named).
- **Qwen3-Next-80B-A3B-Instruct Q4_K_M** — read and write **NOT PROVEN**: the file is refused before any stepping (no `qwen3next` loader/forward in the tree; J-032 blocker B2, roaded to J-123).

No other model is rowed: three rows with honest cells are the table; breadth without filed numbers would break the rule above.

### 0.3 The CLI surface

```
aesir bench [--settle N] [--rounds N] [--pass prompt|reply|draft-check] [--report]
```

- `--report` is a value-less flag. Alone, or composed with `--settle` / `--rounds` (the discipline it runs under), it runs the same default sweep J-100 runs and prints the §0.1 artefact instead of the bare machine report.
- **`--report` with `--pass` is refused, with the reason on the error:** the artefact is the whole machine (all three pass kinds, the full inventory, the model table); `--pass` narrows a bench to one kind. Accepting both would print a partial artefact under a whole-artefact name.
- A duplicate `--report` is refused like every duplicate bench option. Unknown options, missing values, `--settle 0`, and `--rounds` below 3 keep J-100's refusals.
- **Without `--report`, J-100's behaviour is byte-for-byte what it was** — same sweep, same render, same refusals — with exactly one exception, filed as this slice's in-scope collision (§0.5): the malformed-invocation set changes because `--report` alone is no longer malformed.

### 0.4 Where the code lives, and why

The road's established pattern (J-100 §0.5's shape, one layer up):

- **New module `aesir_engine/core/machine_report.mojo`:** the filed model rows (data, with their citations, under §0.2's rule), the model-table render, the device refusal summary render, and `report_artefact()` composing J-100's `machine_report()` with those sections. It imports only `core/bench_configurations` (the `BenchReport` it extends) and `core/device_inventory` (the entries it renders) — never the engine facade.
- **`aesir_engine/cli/bench.mojo`** grows the `--report` flag per §0.3 and calls the artefact render in report mode; nothing else in the CLI changes.
- **Tests at `aesir_engine/tests/test_machine_report.mojo`** (new, standalone lightest target, not registered in `tests/run_all.mojo` — the standing precedent), plus the J-100 suite's CLI-refusal group updated per §0.5.
- **A comment block in `aesir_engine/aesir.mojo`** beside J-100's, recording the entry point.
- **A filed driver `docs/janas/j101_bench.mojo`** — the same lightest-target vehicle as J-100's driver (it calls `bench_main()`, which passes real argv through), used for the gated live example in §0.6(d).

### 0.5 The J-100 test collision, faced head-on

J-100's suite group 7 (`test_cli_refusals`) asserts `dispatch_bench(["bench", "--report"])` is refused — that was J-100's correct scope guard, and J-101 lifting the refusal is exactly this slice's commission. The group is therefore updated in-scope: the `--report`-alone case is replaced by the `--report` + `--pass` incoherent-combination case (refused under §0.3), the group still refuses 6 malformed invocations, and its print line and the suite header record the change and its reason. No other J-100 expectation changes; the neighbour suites (`test_placement_harness`, `test_thread_topology`) are untouched and must pass at their filed counts (10/10, 10/10), and `test_bench_configurations` must pass at 8/8 groups with the updated group 7.

### 0.6 Verdict rule for this slice (pre-registered)

The slice **passes** iff all of the following hold, each filed:

(a) **Unit suite:** `test_machine_report` builds at the lightest target and every group PASSes — the filed rows under §0.2's rule (each row's source + class on its line; the NOT PROVEN rows carrying their reasons), the model-table render, the device refusal summary on fixture inventory (device line verbatim, per-entry reasons verbatim), the artefact render on an injected report (label, J-100 header, model section, refusal section), the CLI's report-mode refusals (parse-level: `--report`+`--pass` in either order, duplicate `--report`), and one full artefact over fixture inventory/facts from the live sweep.
(b) **Neighbours:** `test_bench_configurations` rebuilt from this tree PASSes at 8/8 groups with §0.5's updated group 7; `test_placement_harness` 10/10 and `test_thread_topology` 10/10 PASS rebuilt from this tree.
(c) **Inspect:** `docs/janas/j101_inspect.py` re-derives every load-bearing claim in this doc from the tree and PASSes; every FAIL is disposed in the doc, never hidden.
(d) **Filed examples, each gated separately:**
   - **VM live example:** the driver run once on this VM with `--report` (default discipline) **only if** MemAvailable > 5,500 MB at the moment of the run (checked immediately before). That run executes the same default bench sweep J-100's deferred smoke (§5 of its doc) was to run, with the artefact render on top; if it runs, this doc states explicitly whether it discharges J-100 §5's deferred leg. If the gate fails, the VM live example is **DEFERRED-WITH-REASON** with the exact recipe, and a fixture-rendered artefact from suite group (a)'s live-fixture group is filed instead, labelled FIXTURE on its face and in its filename.
   - **purplelongship example:** filed live **only if** the 204 road's state file shows no live run owning that box at run time and the run is the lightest report run. If a 204 run owns the box — as its state file is checked at slice start — the example is **DEFERRED-WITH-REASON** with the exact guarded, 204-yielding recipe. Nothing heavy runs on purplelongship in this slice in any case; no device access that could contend with a live 204 run is attempted.

**Honesty classes.** Enumeration, rendering, grading, and the filed rows' citations are **PROVEN** by the unit suite and the inspect where they pass. Live timings in any live example are **MEASURED** harness mechanics under the machine state stated beside them. Anything not run is **NOT PROVEN** and named in §6.

**No README is touched. Hailo stays parked (no finish-line branch contact, no chip run or probe). No Docker. Nothing is deleted to free disk.**

*(§§1–10 are filed below from the build, under this protocol.)*
