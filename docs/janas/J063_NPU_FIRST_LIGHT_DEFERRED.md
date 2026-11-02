# J-063 — NPU Prompt: First Light (CONDITIONAL) — DEFERRED-WITH-REASON

**Slice:** J-063 (Part IV — The Accelerator Prompt: GPU and NPU prefill, J-053–J-070), Project Aesir Janas clean-room road.
**Roadmap text:** "NPU prompt: first light (CONDITIONAL). Only if J-062's gate has opened by the time this slice is reached: the smallest dense model's prompt pass on the Hailo, graded against CPU. If the gate is closed, this slice records itself DEFERRED-WITH-REASON and the road continues — never faked, never forced."
**Verdict of this slice: DEFERRED-WITH-REASON.** The gate is closed. No NPU execution was attempted, faked, or forced. This document is the deferred record the roadmap prescribes for exactly this state, filed properly so the road continues to J-064.
**Executed:** 2026-11-01 ~01:05–01:2x EST. Gate re-evaluated first-hand from this tree through J-062's evaluator, rebuilt and re-run on the VM's lightest target; **no chip was probed, no device work of any kind ran, no finish-line branch was touched, and no model inference ran anywhere**.
**Base:** worktree `~/workspace/aesir-janas-j063` on branch `yrsa/janas-j063`, from `yrsa/janas-j062` tip `3ff7bb488de5d7e9cb1775ffdc2e951c3f96736b` (verified by `git ls-remote` at slice start: remote `yrsa/janas-j062` == that hash; origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`).
**Machine state (VM, stated for every number below):** KVM, 4 vCPU. MemAvailable ~0.60–1.24 GB during the slice (691,296 kB at the slice-start check; 603,288 kB after the gate-evidence run) — **far below the 5,500 MB inference gate**, so no VM inference was attempted; lightest compiles only, one at a time. purplelongship was **not used at all** — unreachable/offline per the 204 road's heartbeat (~01:52 EDT, fifteenth consecutive tick reporting it unreachable) and in any case yielded to that road under the coordination law. **Hailo stays parked:** no finish-line branch contact, no chip run, no probe — this slice records the deferral the roadmap orders; it does not cross, lean on, or pre-open the gate.

---

## 1. Verdict

**J-063 closes DEFERRED-WITH-REASON — the gate is closed, and the slice's honest closure is this record:**

- **The conditional is stated exactly (§2):** J-063 may execute only if J-062's gate has opened by the time the slice is reached. It has not.
- **The gate was re-verified first-hand in this slice, not trusted from J-062's filing (§3):** J-062's gate-evidence evaluator (`core/npu_gate_evidence.mojo`, via `tests/test_npu_gate_evidence.mojo`) was rebuilt from *this* tree and re-run on the VM's lightest target — **10/10 groups PASS**, with the J-061 neighbour suite (`test_npu_prompt_prep`) rebuilt from this tree at **10/10 PASS**. Tonight's true record — the empty record, built only from artefacts read first-hand in J-062 §7 and re-confirmed here (no opening decision recorded in any record this road can read; J-037's PARKED inventory line standing; the shared record still stating text-on-chip not achieved) — evaluates through that account to **closed at every level**: gate present **0/4**, first missing `decision_recorded`; J-063 start present **0/8**, first missing `executor_session_path`; J-064 not ready; J-065 not ready. The output is filed as `j063_test_output.txt` beside this doc.
- **Exactly which items remain missing is stated item by item (§4): all 12** — the gate block G1–G4 and the start block S1–S8, each with its J-062 §8 ground. Nothing has been filed toward any of them since J-062 closed; no item is closer tonight than it was then.
- **What J-063 would do if the gate opened is stated in full (§5),** so a later worker needs no other document to execute it: the smallest dense model's prompt pass on the Hailo under J-061's design, graded by teacher-forcing rank + logit gap against the ggml CPU comparator on the raw prompt — never `llama-cli --single-turn`.
- **What remains NOT PROVEN is listed without softening (§6):** any NPU execution, wall, tok/s, first-token latency, preparation time, thermal/power figure, or faithfulness — on any silicon, at any shape.
- **Reopen conditions are stated exactly (§7):** the gate block and the start block complete, in J-062's order — Volmarr's decision recorded on the finish-line campaign's own record, on filed evidence. No other event reopens this slice.
- **J-064 and J-065 remain separately deferred on their own slices (§8):** this record defers J-063 only. Each of J-064/J-065, when reached, records its own DEFERRED-WITH-REASON on its own slice, citing J-062 and this record; neither is closed, executed, or prejudged here.
- **No new code was built.** A deferred record requires none (§9): the only execution in this slice is the re-run of J-062's evaluator and its J-061 neighbour, which is the re-verification evidence itself. Anything more — an executor stub, a binding skeleton — would pad the slice with shapes that prove nothing and pre-empt S1/S2 behind a closed gate.

No README touched. Hailo untouched/parked. No Docker. Janas material consulted: **none in this slice** — the work stands entirely on this road's own filed records (J-061's design, J-062's brief, J-037's inventory line, the campaign state file); no Janas source, and nothing fetched.

## 2. The conditional — the roadmap's own terms

The roadmap writes J-063 as a conditional slice, and its condition is the whole slice:

> "Only if J-062's gate has opened by the time this slice is reached: the smallest dense model's prompt pass on the Hailo, graded against CPU. If the gate is closed, this slice records itself DEFERRED-WITH-REASON and the road continues — never faked, never forced."

Three consequences follow from the text itself, and this slice honours all three:

1. **The gate that decides is J-062's gate, as J-062 specified it** — the gate block G1–G4 filed on the Hailo finish-line campaign's ledger plus Volmarr's recorded decision to open this road's NPU line (J-062 §2, §4), *and* this road's own start block S1–S8 (J-062 §5), which makes an opened gate executable honestly. J-062's account conjoins the two blocks for J-063's readiness; neither block alone suffices, and J-062's suite pins that (its "start block without the gate" group: nothing ready at any level).
2. **A closed gate is a complete outcome, not a failed slice.** The roadmap's prescribed act under a closed gate is a record — this document — after which "the road continues". The deferral is therefore filed with the same care, evidence, and banking as an executed slice: the gate re-verified first-hand (§3), the missing items named (§4), the would-be execution specified (§5), and the reopen conditions stated (§7).
3. **Nothing may be faked or forced.** No part of the execution half — no preparation, no prompt pass, no grade, no wall — may be simulated, approximated on other silicon, or borrowed from the census's Intel figures and filed as this slice's result. §6 holds that line explicitly.

## 3. Gate re-verification — first-hand evidence from this tree

J-062 filed tonight's record as the empty record evaluating closed at every level. This slice does not take that filing on trust: it re-derives the verdict from this tree, in three steps.

**Step 1 — the record's grounds, re-confirmed.** The empty record is built only from artefacts actually read (J-062 §6's host contract). Its grounds, as filed in J-062 §7 and standing unchanged in every record this road can read tonight: J-037's inventory reports the NPU — the Hailo-10H, the only NPU in Aesir's ledgers — as **PARKED**, reported from the ledger, not probed; the Janas ledger crosscheck states "Hailo only, and parked by law (finish-line campaign owns the chip; **text-on-chip still not achieved there**)"; no opening decision is recorded anywhere this road can read; the finish-line ledger itself is **not readable from this tree** (this road has never checked out, read, or otherwise touched branch `yrsa/finish-line-roadmap`, and no finish-line state file sits in this road's campaign records — J-062's addressee note, held again here). Campaign state at slice start agrees: J-062 CLOSED with the gate named, not crossed, and J-063 dispatched explicitly as this conditional deferral. No artefact filed since J-062 closed presents any G- or S-item. The record tonight is therefore still the empty record — not by assumption, but because no filing exists that could set any item.

**Step 2 — the evaluator, rebuilt and re-run from this tree.** `aesir_engine/tests/test_npu_gate_evidence.mojo` (the suite for `core/npu_gate_evidence.mojo`) was built on the VM's lightest target from the `yrsa/janas-j063` tree (cc thread_par shim, exit 0; pixi Mojo 1.0.0 build, exit 0; staging `~/workspace/.verify-tmp/j063stage`, TMPDIR redirected there) and run: **10/10 groups PASS, exit 0** — including, as its first group, exactly tonight's empty record: gate closed at every level, gaps named. The J-061 neighbour suite `test_npu_prompt_prep.mojo`, rebuilt from this tree the same way, also passes **10/10, exit 0** — the design whose execution this slice defers, re-verified at the point of deferring. Full output: `docs/janas/j063_test_output.txt` (campaign copy sha-identical in `~/workspace/model-tests/janas/`).

**Step 3 — the verdict, in the evaluator's own terms.** On tonight's record the account returns: gate **CLOSED** (present **0/4**, first missing **`decision_recorded`**); J-063 **not ready** (start present **0/8**, first missing **`executor_session_path`**); J-064 **not ready**; J-065 **not ready**. This is the same verdict J-062 filed, now re-proven on this slice's own build — the keeper's harvest and any later tick read the same verdict from the same account, from a fresh run.

**Coordination and machine state at re-verification:** `git ls-remote` at slice start — remote `yrsa/janas-j062` == `3ff7bb488de5d7e9cb1775ffdc2e951c3f96736b`, origin/main == `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`. The 204 road's heartbeat (~01:52 EDT) reports purplelongship **unreachable** for the fifteenth consecutive tick and its S-103 line unverifiable while offline — yielded to in any case; this slice ran no heavy run anywhere. VM MemAvailable stayed far below the 5,500 MB inference gate throughout (see header); lightest compiles only, one at a time.

## 4. What remains missing — all 12 items, exactly

Per J-062 §8, J-063 needs the gate block **and** the start block complete. Tonight **all 12 items are missing** — the same state J-062 §7 recorded, re-confirmed in §3 above. Each item is stated with the artefact that would satisfy it (J-062 §4–§5); nothing here amends J-062's checklist.

**Gate block — the finish-line ledger must present (G1–G4):**

| Item | Missing tonight because |
|---|---|
| **G1 `decision_recorded`** — Volmarr's decision to open this road's NPU line, recorded on the finish-line campaign's own record | No opening decision is recorded in any record this road can read; the standing lines record the opposite (parked by law). This is the account's first missing gate item |
| **G2 `chip_toolchain_identity`** — silicon (the Hailo-10H, with board/host), compiler, driver/runtime versions, filed by the finish-line campaign | No finish-line filing naming silicon/toolchain versions exists in this road's records; J-037 names the chip only as a parked ledger entry, with no toolchain identity |
| **G3 `text_on_chip_evidence`** — the finish-line campaign's own completion criterion, filed as a run record (model sha-pinned, prompt, generated ids, what ran on the chip) | The shared record states it directly: text-on-chip still not achieved there |
| **G4 `prompt_graph_evidence`** — a compiled prompt-shaped graph (≥ 64-token block) executing on the chip: compilation record, host↔chip transfers stated, output tensors returned and filed/checksummed, preparation completing | No prompt-shaped graph has executed on any silicon for Aesir; J-061 is a design, and this gap is exactly J-062 §3's prompt-graph gap |

**Start block — this road's own evidence (S1–S8):**

| Item | Missing tonight because |
|---|---|
| **S1 `executor_session_path`** — a runnable NPU executor/session path in the tree, smoke record filed (J-061 N1) | No NPU session, kernel, or device call exists anywhere in the tree for any silicon. This is the account's first missing start item |
| **S2 `toolchain_binding_decision`** — exactly one compiler stack named and bound, forced by G2 once G2 exists (J-061 N2) | Neither binding exists or is decided; by J-062 §5's design the decision waits on G2, which is itself missing |
| **S3 `copy_builder_graded`** — the per-row 8-bit copy builder, built and graded standalone (J-061 N3) | Q8_0 block reading and the SmoothQuant matrix path are neighbours, not this builder |
| **S4 `preparation_completes`** — J-061's preparation consumed by a real open path, completing cold and on a graph-cache hit (J-061 N4) | The preparation *account* is built and proven (re-verified §3); no open path consumes it, so no preparation has ever completed |
| **S5 `faithfulness_leg_ready`** — the J-060 battery leg for the NPU cells executable: ggml CPU comparator oracle + driver on the grading box, pre-registered form filed | J-060's live battery is itself deferred (its B-ORACLE/B-DRIVER unbuilt on any box tonight); every NPU cell is NOT_GRADED in its matrix |
| **S6 `contention_planner_run`** — J-048's rule applied through `core/placement_pressure` itself to the NPU copies on the live pool of the grading machine | J-061 §7 ran the real planner on *filed shapes* (a design price, PROVEN as an account); no live pool on a grading machine has been charged |
| **S7 `thermal_power_machine_reporting`** — leg filings carrying load, host temperature, chip thermal/power behaviour, MemAvailable at start/end | No leg exists to file machine state for; no thermal/power fact about the chip's host is filed anywhere this road can read |
| **S8 `reproducibility_pack`** — every leg filing naming model by full sha256, hardware by G2's identity, machine state by S7, tree by commit hash | No leg filings exist to carry the four facts |

**Downstream items (not J-063's, recorded for completeness):** D1 `dense_whole_graded`, D2 `split_executor_exists`, D3 `live_copies_exist` are likewise all absent tonight — they gate J-064/J-065, not this slice (§8).

## 5. What J-063 would do if the gate opened

Filed in full, so the reopening worker (§7) executes from this record and J-062 without re-deriving anything. The order is J-061 §9's build order, which J-062 §11 confirms stands (the S1–S8 numbering is a checklist order, not a build order):

1. **Build, in dependency order:** the per-row 8-bit copy builder first, graded standalone (S3 — copies dequantized back against the opened file's directory matrices, per-row error bounds filed) *before* any session consumes it; then the toolchain binding decided and bound in code (S2 — the single stack G2 identifies; J-061's account layer stays silicon-agnostic above it); then the executor/session path (S1 — dense-whole form first, per J-061 §3: every block matrix of every layer copied as 8-bit + per-row scale, embedding and LM head never copied, norms carried at f32; reply and draft-check never taken, by J-036's parse refusal, J-061's by-construction planner refusal, and the pass law generally).
2. **Prepare (S4):** J-061's one-time preparation consumed by the real open path for the J-063 model — copies built, one graph compiled per NPU layer, progress records emitted through J-061 §6's account — completing **cold** and on a **graph-cache hit** (0 bytes written, footprint still charged in full), for the smallest dense model (the J-061 design's filed dense shape is Qwen3-0.6B; the executing worker re-pins the model file by full sha256 at the leg, per S8).
3. **Run the first light:** the smallest dense model's **prompt pass on the Hailo** — prompt blocks at or above the census's 64-token floor, at the host's chunk discipline (cap 256, J-061 §3), pure-prefill discipline (the NPU form returns hidden states; the host pays the LM head exactly once per prompt; synchronisation once per block, never per token).
4. **Grade it, under raw-oracle discipline (S5's pre-registered form):** **ids first** — the NPU form's ids against the same architecture's host reference form, token for token, any divergence bisected as a defect — then **teacher-forcing rank + logit gap on the raw prompt**, against the **ggml CPU comparator only** (CPU engine vs CPU comparator), with the four-condition comparator check filed per cell (ggml CPU oracle; raw prompt both sides, no template rendering; tokenization counts equal; BOS handling identical), step-0 boundary effects named as their own verdict class, and the pass bar **FAITHFUL or NEAR_TIE** (rank ≤ 2 **and** sub-logit gap — both conjuncts binding). **`llama-cli --single-turn` is never a comparator on this road** — it template-renders the prompt, a different input. Until the cell grades, the NPU form stays **NOT_GRADED** in J-060's matrix.
5. **File every leg under S6/S7/S8 discipline:** the contention planner run through `core/placement_pressure` itself on the grading machine's live pool, verdict filed; machine state (load, host temperature, the chip's thermal/power behaviour as the G2 toolchain reports it, MemAvailable) at start and end of every run, so a wall filed beside a hot or loaded machine is labelled by its own filing; and every filing naming its model by full sha256, its hardware by G2's identity, and its tree by commit hash.

**What even a successful execution would then prove — and only that:** one dense model's prompt pass executing on the named chip, with its cell's faithfulness grade as measured. No wall, tok/s, or preparation time is a *target* of the leg (§6, J-062 §9): the numbers are whatever the measured runs file, labelled by their machine state.

## 6. NOT PROVEN list

Everything in this list stands exactly as J-062 §12 left it; this slice's deferral changes none of it, and nothing in this slice may be cited against any item:

- **Any NPU execution** — no prompt pass, generation step, or graph of any shape has run on any NPU for Aesir. No chip was probed or run in this slice.
- **Any wall or speed** — prompt tok/s, first-token latency, per-block time, or any comparison against the host batched / CUDA forms, for every NPU form at every shape.
- **Any preparation time**, cold or graph-cached. (The census's 7.5–53 s figures are Janas's published numbers on Intel silicon; J-062 §4's silicon warning forbids citing them as Hailo expectations — different silicon, different vendor, different compiler road.)
- **Any faithfulness** — every NPU cell stays NOT_GRADED in J-060's matrix until a J-063 battery leg grades it; a graph that *runs* (G4) is not a graph that is *faithful*, and the 8-bit copies are an approximation by construction whose rank/gap cost only the battery measures. The 8-bit activation mode is a separate ungraded cell again (J-061 §8).
- **Any fit or capacity claim** — that a given model's copies fit the chip's memory, or that any form earns its footprint.
- **Any thermal or power figure** for the chip or its host, at any load.
- **That any Aesir-reachable NPU can hold or run these forms at all** — no device in Aesir's ledgers tonight states usable NPU memory, a driver, or a toolchain (S1/S2); G4 is unfiled for any model, layer, or block shape.
- **The gate's state inside the finish-line ledger itself** — whether that ledger contains anything beyond what the shared record shows is NOT PROVEN from this tree, by design (J-062 §11): the gate does not open on unverifiable state either way, and G1 exists precisely to close that gap procedurally.
- **Session consumption of the gate account** — no surface calls `evaluate_npu_gate` yet; callability is proven by the suite's entry points (re-proven §3), and the keeper's harvest remains its first intended consumer.
- **The full counted suite (`run_all`) on this tree** — not run (memory gate), per the road's precedent; the standalone suites re-run in §3 are the filed evidence, and registration rides with a counted leg (J-062 §6).

## 7. Reopen conditions

J-063 reopens — and only reopens — when **all** of the following hold, in this order (J-062 §2):

1. The finish-line ledger presents the **gate block G1–G4** as filed artefacts: chip/toolchain identity with versions (G2), the text-on-chip run record (G3), and prompt-graph evidence (G4) — a compiled prompt-shaped graph executing on the chip, transfers stated, outputs returned, preparation completing.
2. **Volmarr decides** to open this road's NPU line. The parked state is his law; only his word lifts it — not this road's keeper, not a worker, not a test result.
3. The decision is **recorded on the finish-line campaign's own record** (G1), citable by path from this road.
4. This road completes its own **start block S1–S8**, filed as artefacts per §4–§5.

A reopened J-063 then executes §5 exactly as filed. Until all four hold, every statement of the form "the gate is open" is false on this road's evidence, J-063 stays deferred, and any later tick that re-checks the gate re-runs §3's evaluation rather than presuming a change. The standing sentence for any filing that cites this record (J-062 §9): **OPEN means the evidence to start measuring exists. It is not a measurement.**

## 8. J-064 and J-065 — separately deferred, on their own slices

This record defers **J-063 only**. The other two conditional slices of Part IV stand as J-062 §8 left them — each **DEFERRED-WITH-REASON** while the gate is closed, each to record its own deferral on its own slice when the road reaches it, citing J-062 and this record. Neither is closed, banked, executed, or prejudged by anything here:

- **J-064 — NPU prompt: split-block (CONDITIONAL, same gate).** Needs everything J-063 needs, **plus D1 `dense_whole_graded`** (J-063's dense-whole cell graded FAITHFUL or NEAR_TIE — a split form built on an ungraded whole form would have no reference shape to bisect against) **plus D2 `split_executor_exists`** (J-061 N5: block halves computed concurrently with a hidden-state join per layer). Tonight: missing all 12 items plus D1 and D2. Its slice, when reached, files its own DEFERRED-WITH-REASON record if the gate is still closed.
- **J-065 — NPU contention rule (CONDITIONAL, same gate).** Needs everything J-063 needs, **plus D3 `live_copies_exist`** — real NPU copies occupying a real pool beside a real expert cache on a named machine, because its subject is J-048's rule under *live* contention, and J-061 §7's abstract planner price (PROVEN as an account, re-verified §3) is explicitly not this evidence. Tonight: missing all 12 items plus D3. Its slice, when reached, files its own DEFERRED-WITH-REASON record if the gate is still closed.

N6 (resident-products call-site binding) and N8 (chooser measurability) gate later form legs, not these slices' starts — the same scoping J-061 §4 and J-062 §8 record.

## 9. What was built — and why nothing more

**No new code.** A deferred record requires none, and the slice deliberately adds none:

- The slice's only execution is the **re-verification** (§3): J-062's evaluator and its J-061 neighbour, rebuilt from this tree and re-run — 10/10 + 10/10 PASS, output filed as `j063_test_output.txt`. That re-run *is* the evidence this closure stands on; it modifies no module.
- No account code was added. J-062's evaluator already expresses tonight's verdict exactly (the empty record, first gaps named at both levels); a J-063-specific account would duplicate a proven account to say the same thing. If a future reopening needs new code, it is S1–S3's build (§5), executed then — not scaffolding filed now behind a closed gate.
- An executor stub or binding skeleton was considered and refused, for J-062 §6's stated reason: shapes that prove nothing, filed early, pre-empt S1/S2's real decisions (the binding is *forced by G2*, which does not exist; a stub would pretend otherwise).

## 10. Answered-locally records (clean-room)

- **Q: Does J-063's deferral also defer J-064/J-065?** Answered locally: **no** (§8). The roadmap writes each conditional slice with its own deferral act ("this slice records itself DEFERRED-WITH-REASON"), and J-062 §8 scopes each slice's needs separately (J-064/J-065 each need items beyond J-063's twelve). One record closing three slices would bank two slices' closures without their own gate re-verification at their own reach points. Each defers on its own slice.
- **Q: Must the gate be re-evaluated at J-063, or is J-062's filing sufficient?** Answered locally: **re-evaluated** (§3). J-062's verdict was true when filed; a conditional slice reached later must establish the gate's state *at its reach point*, first-hand, because the gate's whole design is that it can change only by filed evidence — and only a fresh evaluation can show whether such evidence has appeared. The re-run costs one lightest-target build and removes any doubt about staleness.
- **Q: Is a deferred slice "closed"?** Answered locally, following the road's own usage (J-062's deferred-needs record and the keeper's dispatch of this slice): the slice **closes as DEFERRED-WITH-REASON** — its prescribed act under a closed gate is complete and banked, the frontier advances, and the slice **reopens** only under §7's conditions. Deferred is a closure state with named reopen conditions, not an open item left hanging and not a completion claim about the execution half.
- Janas material: none consulted in this slice (see §1). No design question arose that required the census; the slice stands on this road's own records. No Janas source was opened, at any point, by this road.

## 11. Findings and defects

- **No defect found** in the work inspected or re-run: J-061's preparation account (neighbour suite 10/10 from this tree), J-062's gate-evidence account (own suite 10/10 from this tree, its empty-record group returning exactly the verdict both docs file), and the records this slice rests on (J-037's parked-ledger honesty, J-060's verdict rule, J-048's planner) all behave exactly as their contracts state. The gate's continued closure is a **state**, not a defect in any slice: the chip is parked by law, and the conditional slices were written to defer under exactly this state.
- **No discrepancy between J-062's filing and tonight's re-verification:** gate 0/4 (first missing `decision_recorded`), start 0/8 (first missing `executor_session_path`), J-064/J-065 not ready — identical in both slices, from independent builds of the same account on successive trees. The state file's stale Position header (still headed at J-034) is a pre-existing campaign-records lag noted by the keeper's dispatch of this slice, not a finding of this slice; the tail entries are the true record, and this slice appends to the tail without rewriting the header, per its instructions.

## 12. Banking

Filed on branch `yrsa/janas-j063` (worktree `~/workspace/aesir-janas-j063`, base `3ff7bb48`): `docs/janas/J063_NPU_FIRST_LIGHT_DEFERRED.md` (this doc) and `docs/janas/j063_test_output.txt`. No code files added or modified. Campaign copies of the doc + test output in `~/workspace/model-tests/janas/`, sha-identical. Push by explicit refspec, foreground, with `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6`; the commit hash and ls-remote lines are recorded in the campaign state entry for J-063 and the slice worker's report (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
