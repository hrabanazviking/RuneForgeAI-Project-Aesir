# J-038 — The Measurement Harness (Placement)

**Slice:** J-038 (Part III — Choosing What Runs Where, J-035–J-052), Project Aesir Janas clean-room road.
**Roadmap text:** "Short, bounded micro-runs per pass kind per candidate configuration, run at model open or on demand; settle + rounds discipline borrowed from the documented bench method, re-derived for Aesir's passes."
**Executed:** 2026-10-31 ~14:15–14:35 EDT. **Closure shape: harness built + unit-proven + live proof runs on the VM (CPU candidates only — the VM inventory states the GPU absent and the NPU parked).** The timings filed here are **MEASURED harness mechanics**; they are not placement verdicts for any model (J-040–J-042 own choices, on real passes). No model inference ran anywhere.
**Base:** branch `yrsa/janas-j038` in fresh worktree `~/workspace/aesir-janas-j038`, from `yrsa/janas-j037` tip `cb92af6d4e3996bb3c4417e0589a7f46e03b7b4c`. Origin/main untouched at `ba7ee09b6b4d09967b571f2f39714e9119dc3772` (ls-remote verified at banking, §10).
**Coordination:** purplelongship untouched — the 204 road's S-098 was live there at the keeper's 14:02/14:12 EDT heartbeats (grade phase), no idle gap existed, and this slice needs no laptop run by design (VM CPU proof suffices for harness mechanics). VM MemAvailable ~0.5–1.0 GB during the runs — far below the 5,500 MB inference gate; lightest compiles only.

---

## 1. Question and ground

**Question.** J-036's options say what a user *asks for*; J-037's inventory says what the machine *offers*; J-036's own §10 recorded that nothing yet *measures* — auto-choice is unbuilt because there is no measurement step to choose from. What is the harness that, per pass kind and per candidate configuration the option names, runs short bounded micro-runs under a settle + rounds discipline, filtered through inventory truth, so J-040–J-042 can choose on numbers instead of guesses?

**Ground, and only that ground.** The bench method is the filed census's J-008 row (`janas-bench` "sweeps the configurations the engine may choose (threads × cores × GPU/NPU per pass kind), with settle (300 ms in the published runs) and rounds; writes the learned profile … and leaves a machine report"; published method `--prompt 1024 --gen 16 --rounds 2 --no-mtp --settle 300`) and the J-003b row (the engine "tries … device mixes on real first passes, keeps the fastest per pass kind"). The pass kinds are J-035's role-primary taxonomy, including its binding gap **G1 — no draft-check pass exists** (Part V owns it). The option forms are J-036's; the inventory truth and `require_device_present` are J-037's. Everything the census does not answer is answered from Aesir's own tree and measurements and recorded in §7. No Janas source was opened; none was needed.

## 2. Where the code lives, and why

The road's established pattern (J-036 §2, J-037 §3): a small dedicated standalone module in `core/` plus a standalone lightest-target test suite, with the host contract written in the module and a comment block in `aesir_engine/aesir.mojo`. This slice follows it exactly:

- **New module `aesir_engine/core/placement_harness.mojo`** (~770 lines): candidate enumeration + classification, the bench discipline as a pure accounting function, the pass-shaped micro-workloads, the clock, and the sweep entry point. It imports only J-036's `placement_options` and J-037's `device_inventory` (plus the stdlib FFI clock, in `core/generation_control.mojo`'s `clock_gettime` shape at nanosecond precision).
- **Tests at `aesir_engine/tests/test_placement_harness.mojo`** (10 groups, §10).
- **A comment block in `aesir_engine/aesir.mojo`** beside J-036's and J-037's, recording the entry point and the consumption gap. The module is not registered in `tests/run_all.mojo` (the J-031/J-036/J-037 precedent: registration rides with a counted run the VM's memory gate does not permit; the standalone suite is the filed evidence).

**Entry point, stated plainly:** `run_placement_measurement(options, inventory, pass_kind, workload, config) -> SweepResult` — a pure function of its inputs. A surface may call it **at model open OR on demand**; it is the same call either way, and the hard bounds in §3 are what make the at-open call safe. **This slice wires it into no live session path** — no session consumes a measurement yet, and the `aesir.mojo` comment says so; consumption and choice are J-040–J-042.

## 3. The bench discipline, re-derived for Aesir's passes

Janas's documented discipline is a settle *time* (300 ms) plus rounds. Aesir's micro-runs are single passes far shorter than 300 ms, so a fixed settle time would either dominate the run or never bite. The settle is therefore re-derived as **rounds**, and the rest of the discipline follows from Aesir's own conditions:

| Element | Aesir's rule (as built) | Derivation |
|---|---|---|
| Settle | **≥1 settle round per candidate, executed and timed, its timing DISCARDED** (default exactly 1; `HarnessConfig` refuses 0) | The settle absorbs first-touch costs — page faults, cold caches, first allocation — which are properties of the process, not of the candidate. Janas's 300 ms settle exists to reach steady state before timing; one full pass-shaped round is Aesir's steady-state unit. |
| Measured rounds | **Default 5** (config refuses <3) | Janas's published 2 rounds cannot support a median and leave a shared-VM spike nowhere to go. Five is the smallest count whose median discards two outliers. |
| Summary statistic | **MEDIAN** of the measured rounds, with min / max / spread (max − min) reported beside it | Stated choice: the median is robust to the scheduling spikes a shared VM throws into individual rounds — §6's prompt sweep contains a 44.6 ms round among ~9 ms rounds, and the median (9.74 ms) is unmoved, where the mean would have reported ~16 ms and the minimum would have reported the luckiest round as the candidate's speed. The spread is reported so the noise is never hidden by the robust statistic. The median of an even count is the mean of the two middle rounds. |
| Per-candidate bound | **Default 2,000 ms**, checked between rounds against the live clock (settle wall counts toward it) | A round in flight always finishes — the workloads are themselves bounded — so the bound can be overshot by at most one round. A candidate stopped by the bound is reported **BOUND-STOPPED with the rounds that stand** (summary over the counted rounds when ≥1), never silently truncated. |
| Per-sweep bound | **Default 10,000 ms**, checked between candidates | When it is reached, every remaining measurable candidate is reported bound-stopped with zero rounds and that reason. Together with the per-candidate bound this is the guarantee that a harness call at model open **cannot hang**: worst case ≈ sweep bound + one round. |
| Workload identity | Every round's workload **checksum must agree exactly**, or the sweep raises | Candidates in a sweep run bit-identical work (one prepared data set, deterministic integer-generated, §5). A checksum change means the workload is not deterministic and its timings must not be reported — surfaced as a defect, never averaged away. |

The discipline itself is a pure function, `account_rounds(settle_durations, measured_durations, config) -> RoundAccount`, so it is unit-testable on injected timings; the live runner applies exactly its budget rule between rounds against the live clock (both paths are tested, §10 groups 2/4 and 9/10).

## 4. Candidate enumeration and filtering

Given the resolved option for one pass kind, enumeration produces the **whole field the option named** — nothing is silently dropped, ever:

| Option form | Candidates enumerated |
|---|---|
| `auto` | One single-device candidate per device in the kill-shrunk auto field (cpu, then gpu if not killed, then npu if not killed) |
| single device | That one candidate |
| race list (`a,b[,c]`) | One single-device candidate **per member** — race members are measured singly and reported as race candidates |
| co-work (`a+b`) | The one co-work candidate, as written |

Each candidate is then classified in a fixed order, so the recorded reason is always the strongest true one:

1. **Draft-check first.** If the pass kind is draft-check, every candidate is **UNMEASURABLE-WITH-REASON** naming J-035 gap G1 and Part V (J-071/J-072): there is no pass to measure, and no synthetic proxy is measured in its name.
2. **Inventory truth.** Each named device is checked through J-037's `require_device_present`; on refusal the candidate is **EXCLUDED**, recorded with the refusal's own text (which carries the inventory entry's reason verbatim — e.g. the GPU's probe failure, the NPU's parked ledger state). For co-work, an absent member excludes the whole candidate with that member's reason.
3. **Co-work execution.** A co-work candidate whose devices are all present is **UNMEASURABLE-WITH-REASON**: no real split workload exists in the tree, and a split timing faked by running one device twice would be a fabricated number. J-043 owns co-work execution.
4. **Device executor.** A present GPU/NPU single candidate is **UNMEASURABLE-WITH-REASON**: the harness's workload executor is the CPU one — the only device whose pass-shaped micro-workloads exist in the tree today. Device executors ride with the slices that build device pass execution (J-043 / Part IV). The record says "the device is present, the measurement is not claimed" — a different fact from exclusion, and never blurred with it.
5. Otherwise (a present CPU single candidate for prompt/reply) the candidate is **MEASURABLE** and runs.

Hand placements that name killed devices never reach this harness — J-036's resolve already refused them with reasons; `auto` under a kill simply enumerates the shrunken field (§3 of J-036).

## 5. The workloads

The caller supplies the pass-shaped micro-workload as a `WorkloadSpec`; the harness ships the two shapes that exist honestly in the tree today — plain Float32 matrix products, the arithmetic shape every Aesir pass is built from, at the taxonomy's widths:

- **Reply** (`WORKLOAD_REPLY`): a **width-1** matrix-vector product — rows == 1 is enforced by construction (a wider "reply" workload is refused: J-035 defines reply as exactly 1). Proof shape: 1 × (1024 → 512), 4 reps per round.
- **Prompt** (`WORKLOAD_PROMPT`): a **batched** matrix product — rows ≥ 2 enforced (a width-1 "prompt" workload is refused; that is the reply workload). Proof shape: 16 × (512 → 256), 2 reps per round.

The data is prepared **once per sweep** from a deterministic 32-bit LCG over integers, so it is bit-identical on every machine and every run: candidates differ only in placement, never in work. There is deliberately **no draft-check workload** (§4 rule 1) and **no split workload** (§4 rule 3). These are harness workloads, not model passes — their timings grade the harness, not a model (§6's honesty label).

## 6. The harness's own proof runs (VM, MEASURED — mechanics only)

Machine state: VM (KVM), AMD EPYC 9D64 88-Core Processor, 4 vCPU, kernel 7.0.0-39-generic, MemAvailable ~0.5–1.0 GB at run time, `CUDA_VISIBLE_DEVICES` unset, no `nvidia-smi` on PATH, NPU parked by campaign law. Default config (settle 1, measured 5, bounds 2,000 ms / 10,000 ms), default (auto) options, the VM's **real** inventory from `observe_device_inventory()`. Full output filed as `j038_test_output.txt`:

**Reply sweep** (workload 1 × (1024 → 512), reps 4):

```
reply cpu (auto): median 7347490 ns (min 6940739, max 7670164, spread 729425; rounds 5, settle 1 discarded)
reply gpu (auto): EXCLUDED -- … no GPU probe answered: nvidia-smi failed …; /sys/class/drm lists no card device
reply npu (auto): EXCLUDED -- … Hailo NPU is parked by Aesir's campaign law …; reported from the ledger, not probed, never run by this road
sweep total 74998043 ns
```

**Prompt sweep** (workload 16 × (512 → 256), reps 2):

```
prompt cpu (auto): median 9744541 ns (min 8873372, max 44637367, spread 35763995; rounds 5, settle 1 discarded)
prompt gpu (auto): EXCLUDED -- (same inventory reason as above)
prompt npu (auto): EXCLUDED -- (same ledger reason as above)
sweep total 93261373 ns
```

**Live bound proof:** with a 1 ns per-candidate budget, the reply CPU candidate ran its settle round and stopped before any measured round — `BOUND-STOPPED … reached after 0 measured round(s)`, summary count 0, sweep total 17,847,856 ns. The bound is enforced live, not only in the accounting function.

Reading of the numbers, honestly: the CPU medians (~7.3 ms reply round, ~9.7 ms prompt round) are the cost of *these micro-workloads on this contended VM* — **MEASURED as harness mechanics, and nothing more**. The prompt sweep's max round (44.6 ms, ~4.6× its median) is a shared-VM scheduling spike, and it is the median choice's justification demonstrated live (§3). No placement verdict for any model, device, or pass kind is stated or implied by this section.

## 7. Answered-locally records (clean-room)

- **Q: Settle as time or as rounds?** The census documents Janas's settle (300 ms in the published runs) but not a derivation Aesir could re-check without opening source. Answered locally (§3): rounds — Aesir's micro-runs are far shorter than 300 ms, so the steady-state unit is one full round, discarded.
- **Q: Which summary statistic — and how many rounds?** The census's published method uses `--rounds 2` and does not state a summary statistic Aesir can adopt. Answered locally from this VM's measured noise (§6): 5 rounds, median primary, min/max/spread beside it.
- **Q: What bounds make an at-open harness safe?** No census figure exists (Janas's harness runs as a bench tool, `--settle 300` is a settle, not a bound). Answered locally (§3): per-candidate 2,000 ms + per-sweep 10,000 ms defaults, enforced between rounds/candidates, overshoot ≤ one round, bound-stops reported with the rounds that stand.
- **Q: Should a present device without an executor be measured by running the CPU workload under its name?** Answered locally: never — that would file a CPU timing as a GPU/NPU measurement. It records UNMEASURABLE-WITH-REASON (§4 rule 4), distinct from inventory exclusion.

## 8. NOT PROVEN list

- **Any placement verdict for any model or pass kind.** This slice measured its own micro-workloads on one VM's CPU. Choices belong to J-040 (prompt), J-041 (reply), J-042 (draft-check, when the pass exists).
- **Any GPU or NPU measurement.** No device executor exists in the harness; on this VM the GPU is absent and the NPU parked, so no device candidate could measure in any case. GPU-present enumeration is proven only against injected inventory fixtures (test groups 5–7).
- **Thread-topology candidates** (the census's threads × cores sweep dimension) — J-039 owns thread trials; this harness's candidate axis is device placement only, and its CPU workload is single-threaded scalar arithmetic by design (it grades placement mechanics, not threading).
- **Consumption by any session.** No surface calls `run_placement_measurement` yet (§2); at-open/on-demand callability is proven by the entry point's shape and the live test calls, not by a session integration that does not exist.
- **The purplelongship leg of anything in this slice** — not run (coordination, header); the harness is machine-agnostic and its laptop proof rides with the first slice that needs it there (J-039/J-040).
- **The full counted suite (`run_all`) on this tree** — not run (memory gate), per the road's precedent; the standalone suites are the filed evidence.

## 9. Defects

- **Found and fixed in scope (this slice's own first build):** the harness's first default workload shapes (reply 1 × (2048 → 1024) reps 8; prompt 32 × (1024 → 512) reps 2) produced rounds of ~200–380 ms on this VM — a full default sweep would have run ~2 s per candidate, hard against the 2,000 ms per-candidate bound, so a slower moment could bound-stop the proof run itself. The shapes were reduced before any number was filed (reply 1 × (1024 → 512) reps 4; prompt 16 × (512 → 256) reps 2 → ~7–10 ms medians, §6). Every filed number is from the fixed shapes; the first build's numbers appear nowhere as evidence.
- **No defect found in prior work:** J-036's resolved surface and J-037's inventory behaved exactly as their contracts state — `require_device_present`'s refusal text carries the inventory reason verbatim into the harness's EXCLUDED records (visible in §6), and the neighbouring suites rebuilt from this tree pass unchanged (§10).

## 10. Tests and banking

**Unit tests PROVEN (VM, lightest target):** `test_placement_harness.mojo` built standalone (`mojo build -I . -I aesir_engine`, pixi Mojo 1.0.0 via the j021 env's `pixi run --manifest-path`) and run on the VM: **10/10 groups PASS** — summary statistics on injected timings (odd/even median, min/max/spread, empty + negative refused); settle discarded + round counting (a 999,999,999 ns settle round leaves the summary's max at the measured rounds' 110 ns); candidate filtering against inventory (auto field: cpu measurable, gpu/npu excluded with their reasons; hand-named absent device excluded; race expands per member); time-bound accounting (settle 400 + rounds of 400 under a 1,000 ns budget counts exactly 2, bound-stopped) + config refusals (settle 0, rounds <3, candidate budget > sweep budget); draft-check unmeasurable (G1/Part V named, sweep measures nothing); co-work unmeasurable (J-043 named; absent member excluded first); present-device-no-executor unmeasurable; workload shape refusals + checksum determinism; live micro-runs (§6); live bound enforcement. **Neighbouring suites rebuilt from this tree: `test_device_inventory` 9/9 PASS, `test_placement_options` 10/10 PASS.** Full output filed as `j038_test_output.txt` beside this doc, sha-identical in the campaign copies. No inference ran; no other suite was rebuilt (memory gate), and none is claimed.

**Banking:** filed on `yrsa/janas-j038`: `aesir_engine/core/placement_harness.mojo` (new), `aesir_engine/tests/test_placement_harness.mojo` (new), the comment block in `aesir_engine/aesir.mojo`, this doc and `j038_test_output.txt` under `docs/janas/` — with sha-identical campaign copies of doc + test output in `~/workspace/model-tests/janas/`. Push by explicit refspec (`git push origin HEAD:refs/heads/yrsa/janas-j038`, foreground) with `git ls-remote` verification that the branch moved and origin/main stayed at `ba7ee09b`; the commit hash and ls-remote lines are recorded in the campaign state file entry for J-038 (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
