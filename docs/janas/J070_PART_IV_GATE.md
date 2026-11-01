# J-070 — Part IV Gate: Prefill Evidence Pack

**Slice:** J-070 (Part IV — The Accelerator Prompt, J-053–J-070), Project Aesir Janas clean-room road.
**Roadmap text:** "Part IV gate. Prefill evidence pack; the NPU conditional slices' states (done or deferred-with-reason) recorded in the concordance."
**Executed:** 2026-11-01 ~03:34–03:50 EST for the re-verification runs; doc assembled the same tick.
**Base:** branch `yrsa/janas-j070` in fresh worktree `~/workspace/aesir-janas-j070`, from `yrsa/janas-j069` tip `2904fd9ccad966fefb7de0f10551dc824b9905d3` (verified by `git ls-remote` at gate start: remote `yrsa/janas-j069` == that hash; no remote `yrsa/janas-j070` existed before this slice). Origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5` (ls-remote verified at gate start and at banking, §8).
**Machine state (VM, stated for every number below):** KVM, 4 vCPU, kernel 7.0.0-39-generic. MemAvailable ~1.5 GB at gate start, ~0.88 GB at gate end; load average 8.68 at start, 1.25–8.69 across the runs — far below the 5,500 MB inference gate at every moment. No model inference ran anywhere; lightest compiles only, one at a time. purplelongship was not used at all — unreachable tonight and yielded to the 204 road under the coordination law in any case.

---

## 1. Gate verdict

**Part IV CLOSED-WITH-DEFERRED-LEGS.**

- The full Part IV test surface was **rebuilt and re-run from this gate tree, first-hand, at this gate**: all 14 distinct Part IV test modules plus 4 neighbour suites (J-031's MoE GPU plan, J-037's device inventory, J-048's placement pressure, Part II's expert cache) — **18/18 modules exit 0, 0 FAIL lines, 171 test groups PASS** (§2, `j070_test_output.txt`). Every module's group count exactly matches the count its own slice filed.
- The **doc census passes**: all 17 slice docs (J-053–J-069) and all 17 filed test outputs in this tree are **sha256-identical** to their campaign copies in `~/workspace/model-tests/janas/` (§2).
- The **NPU conditional slices' states are recorded in the concordance (§4)**, as the roadmap text requires: J-063, J-064, and J-065 each stand **DEFERRED-WITH-REASON** on the closed J-062 gate — none done, none upgraded by this gate's accounting.
- Every Part IV deferred leg is re-cited in §5 with its recipe pointer. None is claimed anywhere in this gate. Part IV built the prefill *accounting and design* layer entire — plans, verdicts, protocols, and honesty machinery, all unit-proven — and measured **no new prefill wall, tok/s, or faithfulness grade**: every live leg needs hardware or a quiet machine this gate does not have, and each is deferred with its exact recipe rather than faked under contention.

No README touched. Hailo untouched/parked (no finish-line branch contact, no chip run or probe). No Docker. No Janas source opened — this gate needed no Janas material at all; it re-verifies Aesir's own filed Part IV evidence (clean-room law unengaged).

## 2. Re-verification at the gate (PROVEN)

Build line (the slices' own filed recipe): `cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o <staging>/libaesir_par.so -lpthread` (exit 0), then per module `pixi run --manifest-path aesir_engine/pixi.toml mojo build -I . -I aesir_engine -Xlinker -L<staging> -Xlinker -laesir_par` (Mojo 1.0.0 via the tree's pixi env); runs with `LD_LIBRARY_PATH=<staging>`. Staging on the workspace overlay (`~/workspace/.verify-tmp/j070stage`), TMPDIR redirected there, nothing deleted. Full output: `j070_test_output.txt`.

| Module (slice) | Groups at gate | Filed by its slice | Result |
|---|---|---|---|
| `test_prefill_anatomy` (J-053) | 8 | 8 | ALL PASS, exit 0 |
| `test_gpu_block_prefill` (J-054) | 9 | 9 | ALL PASS, exit 0 |
| `test_whole_layer_gpu` (J-055) | 8 | 8 | ALL PASS, exit 0 |
| `test_split_prompt` (J-056) | 9 | 9 | ALL PASS, exit 0 |
| `test_prefill_overlap` (J-057) | 9 | 9 | ALL PASS, exit 0 |
| `test_moe_gpu_prefill` (J-058) | 10 | 10 | ALL PASS, exit 0 |
| `test_prompt_progress` (J-059) | 10 | 10 | ALL PASS, exit 0 |
| `test_prefill_grade` (J-060) | 10 | 10 | ALL PASS, exit 0 |
| `test_npu_prompt_prep` (J-061) | 10 | 10 | ALL PASS, exit 0 |
| `test_npu_gate_evidence` (J-062; re-run also as J-063/J-064/J-065's evidence) | 10 | 10 | ALL PASS, exit 0 |
| `test_vulkan_port_surface` (J-066) | 10 | 10 | ALL PASS, exit 0 |
| `test_igpu_account` (J-067) | 11 | 11 | ALL PASS, exit 0 |
| `test_prefill_at_8k` (J-068) | 7 | 7 | ALL PASS, exit 0 |
| `test_cold_start_account` (J-069) | 11 | 11 | ALL PASS, exit 0 |
| **Part IV subtotal** | **132 groups** | | **14/14 modules, 0 failures** |
| `test_moe_gpu_plan` (J-031 neighbour) | 7 | 7 | 7 PASS lines, exit 0 |
| `test_device_inventory` (J-037 neighbour) | 9 | 9 | ALL PASS, exit 0 |
| `test_placement_pressure` (J-048 neighbour) | 14 | 14 | ALL PASS, exit 0 |
| `test_expert_cache` (Part II neighbour) | 9 | 9 (J-034 gate) | 9 PASS lines, exit 0 |
| **Total** | **171 groups** | | **18/18 modules, 0 failures** |

**Doc census (PROVEN):** for every slice J-053–J-069, the doc and the filed test output in this tree were sha256-compared against the campaign copies in `~/workspace/model-tests/janas/` at this gate: **17/17 docs MATCH, 17/17 outputs MATCH**. The concordance in §4 therefore rests on the same bytes the keeper harvested, not on copies that drifted.

**Gate-process defect, found and fixed in scope:** this gate's first runner attempt invoked the build loop from a background shell whose PATH lacked `~/.pixi/bin`; every module failed instantly with `pixi: command not found` (exit 127) and produced no binary and no number. Diagnosed from the log, fixed by exporting the pixi path in the runner, and the full suite re-ran clean from scratch. The discarded attempt is noted in the header of `j070_test_output.txt` itself. No Part IV artefact, number, or prior slice record was implicated — the defect was in this gate's harness invocation only (the same class the J-052 gate recorded).

**No defect was found in any Part IV module, test, or prior slice record at this gate.** Three record-level items the slices flagged for this gate are resolved or carried explicitly in §6.

## 3. The prefill design, as built (Part IV's as-built summary)

What Part IV actually built, in the order a prompt meets it:

- **The anatomy (J-053).** Where prompt time goes, by construction, per arch × 256/1,024/4,096/8,192 tokens: the host engine's chunked batched prefill (cap 256, pure-prefill chunks skip the LM head), the CUDA width-1 sessions and the one width-4 tile, the MoE width-1 `step()` with no pure-prefill form. `core/prefill_anatomy.mojo` prices pass plans, KV bytes, causal pairs, and MACs exactly. Three findings own the rest of the part: **F1** the MoE session pays the full LM head on every prompt token (~9.6 % waste; owned by J-058), **F2** attention batches nowhere (the long-context ceiling), **F3** no prefill instrumentation on the host path (owned by J-059 + the §7 legs).
- **The GPU block plan (J-054).** The proven GPU path is decode-shaped everywhere; the prefill-shaped pieces that do not exist are named exactly (M1–M7, M1 = the general-width quantized GEMM). `core/gpu_block_prefill.mojo` plans chunks as batch GEMM work with exact traffic/sync accounting; widths above 4 are marked UNBUILT inside every plan.
- **Whole-layer GPU (J-055).** At width 1, whole-layer dense on GPU already exists and is proven (the two CUDA sessions); the block form is gated exactly by M1 + M2 + M5. `core/whole_layer_gpu.mojo` is the fit/sync/agreement account.
- **Split prompt (J-056) — accounted REJECTION.** Where both parents exist, a block-halves split ties them on MACs and weight bytes and is strictly worse on crossings and join bytes; where the whole-GPU parent is absent the question is NOT GRADED. `core/split_prompt.mojo` carries the pre-registered survival rule in pure form.
- **Prefill/decode overlap (J-057) — accounted REJECTION on every existing shape.** The stall the roadmap imagines removing does not exist as a phase in Aesir's loops (tokenisation, KV allocation, and weight upload all happen once, before the chunk loop); NOT GRADED on the unbuilt block executor. `core/prefill_overlap.mojo`.
- **MoE prompt on GPU (J-058).** Accounted **SURVIVAL** for the planned GPU chunk form under the divisions that place experts on the device (FULL and expert-cache, on J-031's division), HEAD_ONLY for the width-1 GPU form, carried REJECTION for the resident-only split. `core/moe_gpu_prefill.mojo`. F1's fix shape (head-skipping `step_prefill`, `step` byte-identical for decode) is specified here; its live grading is §5 item 6.
- **Long-prompt watching (J-059).** `core/prompt_progress.mojo`: watched only at ≥ 1,024 tokens and ≥ 4 chunks, records only at chunk boundaries on 10 % steps — at most 10 records at any width — with CLI and server-stream render forms and host contracts for both surfaces. This is F3's recorded-form answer (J-057's O2).
- **The faithfulness battery (J-060).** The protocol is defined and its verdict rule pre-registered and proven as a pure account (`core/prefill_grade.mojo`): ids first, then teacher-forcing rank + logit gap against the ggml CPU comparator on the raw prompt — never `llama-cli --single-turn` — with comparator-artifact classes named in advance. Exactly two graded cells exist in the record, both OLMoE CPU width-1, re-verified through the account.
- **The NPU line (J-061–J-065).** J-061 designs the NPU prompt pass in full (binding, copy sets per form, forbidden passes, one-time preparation priced by `core/npu_prompt_prep.mojo`, progress in J-059's discipline) — host-side only, silicon-agnostic at the account layer. J-062 files the gate brief: the gate belongs to the Hailo finish-line campaign, is **CLOSED**, and opens only on Volmarr's decision recorded on that campaign's own record plus gate block G1–G4 (including prompt-graph evidence — text-on-chip alone proves a reply-shaped computation, not a prompt graph); `core/npu_gate_evidence.mojo` evaluates the checklist mechanically (tonight: gate 0/4, J-063 start block 0/8). J-063/J-064/J-065 each recorded their own **DEFERRED-WITH-REASON** on that closed gate (§4).
- **The Vulkan question (J-066) — written verdict: DEFER.** Rule pre-registered before the verdict; the port surface is accounted exactly (40 kernel families + 2 sessions + 8 infra = 50 items, `core/vulkan_port_surface.mojo`); the spike did not run (no Vulkan device on the VM; purplelongship is NVIDIA and unreachable). Reopen: landed non-NVIDIA hardware + a named consumer (§5 item 13). No Vulkan code, shader, or stub was committed, deliberately.
- **iGPU awareness (J-067).** `core/igpu_account.mojo` teaches the placement layer the iGPU's real shape: a kind distinct from discrete, its budget an allowance from the ONE system pool under J-048's order (never additive), the prefill tax priced in contended bytes with zero copy bytes, and a mechanical claim verdict.
- **Prefill at 8k (J-068).** The J-053 table's 8,192-token row re-derived with all of Part IV's work in (`core/prefill_at_8k.mojo`): attention crosses half on exactly one filed profile (Qwen3 0.6B, 51.61 %); every other profile sits at 11–20 % — and J-053 §3.4's contrary prose sentence is corrected (§6). Two cells stand REFUSED-BY-CONTEXT, not deferred (OLMoE at 8,192 — file context 4,096; Llama 3 CUDA at 8,192 — session fit check).
- **Cold-start honesty (J-069).** `core/cold_start_account.mojo`: the four cold components (open, compile, preparation, cache-cold) kept separate, a run classifier, and a claim verdict that mechanically refuses a cold-first run published as a warm figure. Its audit re-labels the road's only measured prefill walls as cold-first (A1), amends every deferred median-of-3 recipe (A2, §6), and names the serve first-request gap (A5, §6).

**The standing gap every Part IV slice records, stated once for the part:** no executor behind any of these accounts was built in Part IV, and no live session consumes a plan yet. The accounts are the filed evidence; the builds they name (M1 above all) and the wirings are later work, roaded per slice in §5. Nothing in Part IV fakes a wall.

## 4. Concordance — every Part IV slice, its final state and banked tip

Branch chain verified at this gate by `git ls-remote` (each branch's remote tip == the next slice's recorded base; origin/main == `605562f6b919a0f58fa6decd0b45a83cdc41a6d5` throughout).

| Slice | Final state | Banked branch @ tip |
|---|---|---|
| J-053 Prefill anatomy | CLOSED-WITH-DEFERRED-LEG (by-construction baseline PROVEN; all walls deferred, §5.1) | `yrsa/janas-j053` @ `47a2bad9` |
| J-054 GPU block prefill | CLOSED-WITH-DEFERRED-LEG (block-plan layer PROVEN; live GPU legs deferred, §5.2) | `yrsa/janas-j054` @ `aa38d643` |
| J-055 Whole-layer GPU | CLOSED-WITH-DEFERRED-LEG (width-1 whole-layer PROVEN to exist; live agreement/wall deferred, §5.3) | `yrsa/janas-j055` @ `2327a911` |
| J-056 Split prompt | CLOSED-WITH-DEFERRED-LEG (accounted verdict REJECTED where both parents exist, NOT GRADED where the whole-GPU parent is absent; live leg deferred, §5.4) | `yrsa/janas-j056` @ `54473afe` |
| J-057 Prefill/decode overlap | CLOSED-WITH-DEFERRED-LEG (accounted verdict REJECTED on every existing shape, NOT GRADED on the unbuilt block executor; live leg deferred, §5.5) | `yrsa/janas-j057` @ `220534d1` |
| J-058 MoE prompt GPU | CLOSED-WITH-DEFERRED-LEG (accounted SURVIVAL for FULL + expert-cache divisions, HEAD_ONLY width-1, resident-only REJECTED; live leg deferred, §5.6) | `yrsa/janas-j058` @ `cdcdd83d` |
| J-059 Long-prompt watching | CLOSED-WITH-DEFERRED-LEG (progress account PROVEN; live demonstration deferred, §5.7) | `yrsa/janas-j059` @ `759becd9` |
| J-060 Prefill faithfulness battery | CLOSED-WITH-DEFERRED-LEG (protocol + grading account PROVEN; live battery deferred, §5.8) | `yrsa/janas-j060` @ `af903eb0` |
| J-061 NPU prompt design | CLOSED (design + preparation account PROVEN, host-side; its live leg is gated, owned by J-062's brief — §5.9) | `yrsa/janas-j061` @ `8b8bec4f` |
| J-062 NPU prompt gate brief | CLOSED (brief filed; the gate is named, CLOSED, and not crossed) | `yrsa/janas-j062` @ `3ff7bb48` |
| J-063 NPU first light (CONDITIONAL) | **DEFERRED-WITH-REASON** — the J-062 gate is closed (§5.10) | `yrsa/janas-j063` @ `bc326b38` |
| J-064 NPU split-block (CONDITIONAL) | **DEFERRED-WITH-REASON** — same gate (§5.11) | `yrsa/janas-j064` @ `17330f0e` |
| J-065 NPU contention rule (CONDITIONAL) | **DEFERRED-WITH-REASON** — same gate (§5.12) | `yrsa/janas-j065` @ `fca9760c` |
| J-066 Vulkan question | CLOSED (written verdict DEFER; port account PROVEN; spike NOT RUN — reopen recipe §5.13) | `yrsa/janas-j066` @ `1fb27731` |
| J-067 iGPU awareness | CLOSED-WITH-DEFERRED-LEG (iGPU account PROVEN; live measurement deferred, §5.14) | `yrsa/janas-j067` @ `8e05ff6c` |
| J-068 Prefill at 8k | CLOSED-WITH-DEFERRED-LEG (8k table re-derived PROVEN; live 8k legs deferred, §5.15) | `yrsa/janas-j068` @ `1caf56f1` |
| J-069 Cold-start honesty | CLOSED-WITH-DEFERRED-LEG (separation account PROVEN; live cold-vs-warm legs deferred, §5.16) | `yrsa/janas-j069` @ `2904fd9c` |

**Counts:** 17 slices — **3 CLOSED** (J-061, J-062, J-066), **11 CLOSED-WITH-DEFERRED-LEG**, **3 DEFERRED-WITH-REASON whole-slice** (the NPU conditional trio). The roadmap's J-070 requirement is met on its own terms: the conditional slices are recorded here as deferred-with-reason, not done — the gate was closed when each was reached, each filed its own deferral on its own first-hand gate re-verification (J-063/J-064/J-065 §3: evaluator + neighbour rebuilt, 10/10 + 10/10 PASS — re-verified again at this gate, §2), and the road continued, never faked, never forced.

## 5. Deferred legs re-cited at this gate (all NOT PROVEN / DEFERRED-WITH-REASON)

None of these ran at this gate. Common causes, stated once and applying where named: **(a)** purplelongship is yielded — the 204 road owns that box and it was unreachable at this gate in any case; several legs additionally need a guarded idle gap there; **(b)** the VM is below its own 5,500 MB inference gate (MemAvailable 0.88–1.5 GB during this gate) and has no GPU; **(c)** the Hailo finish-line gate is closed and parked — nothing on this road opens it; **(d)** several legs need executor code later work owns, as noted per leg. **Binding amendment on every median-of-3 recipe below (J-069 A2, §6):** a recipe's first repetition is a cold-first run — it is filed separately under J-069's account, and any median is taken over the warm repetitions only.

1. **J-053 baseline walls.** Every prefill wall / tok/s / first-token latency at 256/1,024/4,096/8,192, every arch and surface. Recipe: J-053 doc §7 (quiet purplelongship window, sha pins incl. OLMoE `8c310f14…f3f`, exact-token prompt shapes, ids-first + teacher-forcing rank/gap raw-oracle grading, machine state per run; A2 amendment above). Blocked by (a) + (b).
2. **J-054 live block prefill.** Per-arch faithfulness grading + every GPU wall for the block form. Recipe: J-054 doc §6 — the M1–M7 builds first (M1 general-width quantized GEMM above all), then the guarded on-box legs. Blocked by (a) + (b) + (d).
3. **J-055 live agreement + wall.** The whole-layer block form's bit-agreement counts and walls. Recipe: J-055 doc §7 (needs M1 + M2 + M5). Blocked by (a) + (b) + (d).
4. **J-056 live split leg.** Recipe: J-056 doc §7. The accounted verdict already stands REJECTED where both parents exist; a live leg can only revisit it on shapes that do not exist tonight. Blocked by (a) + (b) + (d).
5. **J-057 live overlap leg.** Recipe: J-057 doc §7. REJECTED on every existing shape; the unbuilt block executor is the only NOT-GRADED shape. Blocked by (a) + (b) + (d).
6. **J-058 live MoE GPU prefill leg.** Recipe: J-058 doc §7 — includes F1's grading: the head-skipping `step_prefill` form graded on the J-030 id set before any wall is quoted, `step` byte-identical for decode. Blocked by (a) + (b) + (d).
7. **J-059 live long-prompt watching leg.** Recipe: J-059 doc §7 — a watched read demonstrated live on the CLI and server-stream surfaces per the host contracts; carries F3's in-engine phase timers with it. Blocked by (a) + (b).
8. **J-060 live faithfulness battery.** Recipe: J-060 doc §7 — the defined matrix run live, graded under its own pre-registered rule (ids first, then teacher-forcing rank + logit gap vs the ggml CPU comparator, raw-oracle discipline). Blocked by (a) + (b) + (d) for the unbuilt forms.
9. **J-061 gated live leg.** The designed NPU prompt pass executed. Recipe: J-061 doc §9 — conditional in full on J-062's gate opening; nothing in the recipe is runnable while the gate is closed. Blocked by (c).
10. **J-063 first light.** Reopen conditions: J-063 doc §7 — gate block G1–G4 filed on the finish-line record + Volmarr's recorded decision opening the gate + this road's start block S1–S8 (all 12 missing items as filed in J-063 §4). Blocked by (c).
11. **J-064 split-block.** Reopen conditions: J-064 doc §7 — item 10's conditions plus D1 (J-063's dense-whole cell graded FAITHFUL or NEAR_TIE in J-060's matrix) and D2 (the split executor, N5). Blocked by (c).
12. **J-065 contention rule.** Reopen conditions: J-065 doc §7 — items 10–11 plus D3 (`live_copies_exist`: live NPU copies inside a live J-048 pool). Blocked by (c).
13. **J-066 Vulkan spike (the DEFER's reopen).** Recipe: J-066 doc §7 — one prefill kernel both ways (the width-1 block matvec at kind 12 over device-resident Q4_K bytes) on landed non-NVIDIA hardware with a named consumer; the spike must state the Vulkan-vs-HIP choice for AMD hardware, not presume it (the tree pre-positions neither). Blocked by: no non-NVIDIA GPU in hand (the ROG Flow Z13 has not landed).
14. **J-067 live iGPU leg.** Recipe: J-067 doc §7 — on a machine with only an integrated GPU: inventory truth check first (kind = integrated, claimed device figure == the system pool's bytes), then prefill placement measured under the account. Carries the inventory kind-probe widening (§6). Blocked by: no iGPU machine in hand.
15. **J-068 live 8k legs.** Recipe: J-068 doc §7 — every 8,192-token wall and faithfulness grade, per arch/surface, graded under J-060's battery (its step 6); the NPU 8k row exists only as a §7 step if the J-062 gate ever opens. Blocked by (a) + (b) (+ (c) for the NPU row).
16. **J-069 live cold-vs-warm legs.** Recipe: J-069 doc §7 — C1–C4 as measured times per surface, every figure classified through `core/cold_start_account.mojo`; step 5 is the A5 serve witness (identical request twice against a fresh native serve instance, both `timings_ms` records filed verbatim), and the A5 fix (cold marker + component fields on the first request's record) rides with that leg's wiring step. Blocked by (a) + (b).
17. **The full counted suite (`run_all`) on this tree.** Not run at this gate, per the standing Part II/III gate precedent (VM memory gate); the standalone suites re-run in §2 are the filed evidence.

## 6. Concordance deltas and the flagged record items

Against `DELTA_TABLE.md` (the Concordance frozen at J-014; grades below are this gate's report, the keeper amends the table):

| Row | Subject | Part IV outcome |
|---|---|---|
| 17 | GPU prompt products per quant type | **PARTIALLY RESOLVED.** The block-plan layer is built and PROVEN (J-054); the per-quant prompt *products* are not built — M1 (general-width quantized GEMM) does not exist even for CUDA (J-066 §3). Live product behaviour NOT PROVEN (§5.2). |
| 18 | Whole-layer dense GPU prompt path | **PARTIALLY RESOLVED, advanced.** Width-1 whole-layer PROVEN to already exist (J-055); the prefill-shaped block form is gated by M1 + M2 + M5 and deferred (§5.3). |
| 19 | Whole-pass GPU on discrete cards + VRAM expert tier | **PARTIALLY RESOLVED.** The tier accounting stands (J-031) and J-058's accounted SURVIVAL covers the FULL + expert-cache divisions; no live wall exists (§5.6). |
| 20 | GPU self-check at open + wrong-shader diagnostics | **PARTIALLY RESOLVED.** The grading surface the row needs is defined and proven as an account (J-060's battery + verdict rule); no live self-check runs at open and the live battery is deferred (§5.8). |
| 22 | Vulkan GPU backend | **RE-GRADED at this gate: DECIDED — DEFER; not built.** The frozen row's "PARTIAL" is stale and must not be read as *partially built*: the tree holds exactly one line mentioning Vulkan (`cli/hardware.mojo:44`, "not implemented") plus two proposal documents. J-066 decided the question on a pre-registered rule; reopen at §5.13. This resolves the stale-claim risk J-066 §8 flagged for this gate. |
| 23 | NPU prompt reading (dense whole layers, 8-bit copies) | **DESIGN RESOLVED (PROVEN as an account, J-061); EXECUTION DEFERRED-WITH-REASON (J-063, §5.10).** No NPU prompt figure exists on any silicon. |
| 24 | NPU split-block co-processing | **DEFERRED-WITH-REASON (J-064, §5.11).** The design's split-block copy set is named (J-061); nothing executed. |
| 25 | NPU resident-products placement (large/MoE) | **DESIGN RESOLVED (J-061 — routed experts never copied); its contention application DEFERRED-WITH-REASON (J-065, §5.12).** |
| 26 | NPU preparation pass + progress + compiled-graph cache | **RESOLVED as an account (PROVEN, J-061).** Preparation priced exactly, graph-cache hit writes 0 and charges the footprint in full, progress in J-059's discipline. The pass itself runs only behind the gate (§5.9). |
| 27 | NPU memory-contention closure rule | **PART IV HALF DEFERRED-WITH-REASON.** Part III's half was resolved as planning logic at the J-052 gate (J-048); the NPU-specific application is J-065, deferred on the closed gate (§5.12). J-061's account prices copies under J-048's order in the meantime. |

All other Concordance rows are untouched by Part IV.

**Flagged items the slices named for this gate — disposition:**

- **J-053 §3.4 prose correction (flagged by J-068 §8) — CARRIED AND RESOLVED as the record's reading.** J-053's sentence claiming attention MACs overtake projection MACs on every profile between 1,024 and 4,096 tokens is contradicted by J-053's own §5 numbers and by J-068's re-derivation (at 8,192, five of six profiles are projection-dominated, 11–20 % attention share; only Qwen3 0.6B crosses half). The numbers were never wrong; the sentence was. No J-053 file is edited (prior slices' docs are not rewritten by later slices); the correction lives in J-068 §8 and in this concordance, cited by number. No later slice may quote the sentence.
- **J-067 inventory kind-probe gap (flagged by J-067 §8) — CARRIED as a named delta.** J-037's probe is nvidia-smi-class only and cannot state an *integrated* kind; a non-NVIDIA card lands as *unclaimed*. Widening it (a vendor-neutral shared-memory probe + a kind field on `GpuFacts`) is roaded to §5.14's leg, where hardware exists to verify the probe against — widening it tonight would ship an unverifiable probe. No defect in built code: the probe is correct for the machines it was built on; this is an absence with a named owner.
- **J-069 A1/A2/A5 — ANSWERED at this gate, as J-069 §7 step 7 requires.** **A1** (the J-022/J-023/J-030 MoE walls are cold-first walls published without a cold label): the re-labelling stands as the record's reading — those walls are cold-first figures; their comparisons were like-for-like, so no number changes. **A2** (median-of-3 recipes mix a cold first repetition): the amendment is binding on every recipe in §5, stated there once. **A5** (native serve `timings_ms` cannot distinguish its first, cold-first request and carries no C1–C3): a named surface gap, not a filed-number defect — no road figure rests on a serve first-request timing; its witness leg and fix are §5.16.
- **J-068's build-warning note — carried, not fixed.** Building `test_igpu_account` emits a docstring-style warning on its line 1 (lowercase summary start) in a J-067 file. It is a warning, not an error; it affects no number (this gate's §2 run reproduced it and passed 11/11). Recorded here as a one-line tidy owed to J-067's test file, deliberately not edited by this gate so the gate tree's test files stay byte-identical to the slices that filed them.

## 7. Honesty ledger of this gate

- Every number in §2 was produced by runs this gate executed on the gate tree; the output is filed beside this doc (`j070_test_output.txt`). Group counts were tallied from the runs' own `ALL PASS` / PASS lines, and each matches the count its slice filed — that match is itself part of the re-verification. The one discarded harness attempt (§2) produced no numbers and is recorded in the evidence file's own header.
- §4's states are taken from the slice docs and the campaign state file, cross-checked against the live `git ls-remote` branch chain at this gate — not carried on trust from any single source.
- No live leg ran at this gate, and none is implied. §5 is the complete list of legs owed to this gate as recorded in the slice docs (J-053–J-069) and the state file. In particular: **no prefill wall, tok/s, first-token latency, or faithfulness grade for any Part IV form is claimed by this gate** — Part IV's measured record remains exactly the prior legs its slices re-cite (the OLMoE 67-token evidence in J-053 §6, cold-first per A1).
- The NPU trio's deferrals were not upgraded by accounting: the J-062 evaluator re-run at this gate (§2) reproduces the closed-gate evaluation on this tree; the gate itself was not approached, probed, or crossed, and the finish-line branch was never touched.
- The 204 road owns purplelongship; this gate used no purplelongship route and ran nothing heavy anywhere. VM MemAvailable stayed below the 5,500 MB inference gate throughout, so no VM inference was attempted.
- One gate-harness defect (§2) was found and fixed in scope; no Part IV defect was found. Per the never-leave-a-bug rule, §5's legs and §6's named items (the kind-probe widening, the A5 fix, the one-line docstring tidy) are recorded with owners and recipes — absences and gaps with named next steps, not silent drops.

## 8. Banking

Filed on branch `yrsa/janas-j070` (worktree `~/workspace/aesir-janas-j070`, base `2904fd9c`): this doc and `j070_test_output.txt` — both under `docs/janas/`, with sha-identical campaign copies in `~/workspace/model-tests/janas/`. Push is by explicit refspec (`git push origin HEAD:refs/heads/yrsa/janas-j070`, foreground) with `git ls-remote` verification that the branch == the local tip and origin/main stayed at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`; the commit hash and the ls-remote lines are recorded in the campaign state file entry for J-070 and in the gate worker's report (a doc cannot contain its own commit hash). No README touched.
