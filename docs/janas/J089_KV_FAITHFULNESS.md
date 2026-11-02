# J-089 — KV Faithfulness

**Slice:** J-089 (Part VI — Long Context and the 8-Bit KV, J-087–J-098), Project Aesir Janas clean-room road.
**Roadmap text:** "KV faithfulness. 8-bit vs 16-bit KV graded by teacher-forcing rank/gap across context lengths; the lengths where 8-bit starts to cost truth are found and published, not hidden."
**Executed:** 2026-11-01 from ~12:0x EST, in fresh worktree `~/workspace/aesir-janas-j089` on branch `yrsa/janas-j089`, from the verified tip of `yrsa/janas-j088` (`4c89ea7421a6b4c4c3d6ef2da69f0be7b7553d65`, local == ls-remote at slice start). Origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`. The J-087/J-088 worktrees and the canonical checkout were not worked in.
**Machine state (VM, stated for every number below):** KVM, 4 vCPU, kernel 7.0.0-39-generic. MemAvailable ~0.84 GB at the first test build, ~1.06 GB at the ladder run, ~1.19 GB at the final suite runs — **far below the 5,500 MB inference gate at every moment**, so no model inference ran anywhere; lightest compiles only, one at a time. Load average 2.9–15 across the slice (other campaigns); **no wall is filed anywhere in this slice**, so contention touches no number. purplelongship was **not used at all** — unreachable (last_seen 2026-11-01T02:07:13Z) and owned by the 204 road when it returns. /tmp healthy.
**Clean-room record:** no Janas material was consulted in this slice and no Janas source code was opened, in this slice or any other. The grading discipline is Aesir's own raw-oracle discipline (the roadmap's, and J-060's account in this tree).

---

## 1. The question — and the honest shape, stated up front

**Question.** Grade J-088's 8-bit KV against the 16-bit baseline by teacher-forcing rank/gap across context lengths, and publish the lengths where 8-bit starts to cost truth.

**The expected shape, decided from evidence before building:** a live grade needs (a) J-088's store integrated into a live session — J-088 §7 deferred exactly that, with the recipe — and (b) a machine that may run inference. This tick the VM is far below its inference gate and purplelongship is unreachable, so **the live legs are DEFERRED-WITH-REASON (§7) and the model verdict is NOT PROVEN in either direction: no context length is indicted, and none is cleared, at model level.** What this slice proves instead:

1. **The grading harness the live legs will use** (§4): the missing reduction from paired logit rows to (rank, gap) records, as a tested pure component — so that when a live pair exists, grading is mechanical, not improvised.
2. **The synthetic level, graded across the ladder** (§5): J-088's deterministic synthetic exercise extended from 256 to 128 / 256 / 512 / 2,048 / 8,192 / 32,768 positions — attention-output deviation plus a clearly-labelled logit-**proxy** deviation graded by the new harness — under a verdict rule pre-registered before measuring (§2). Every number in §5 is **SIMULATED** (deterministic synthetic data). None of it is model faithfulness, and §5 says so at the table, not in a footnote.

## 2. Pre-registered rules (stated before measuring)

**Harness definitions** (in `core/kv_faith.mojo`'s header, committed before the ladder was built or run): the forced token of a step is the **reference row's top token** (argmax, ties to the lowest index); **rank** is its 0-based rank under the test row, counting only strictly-greater logits (the tf_oracle convention — rank 0 is a test-row maximum, ties share it); **gap** is the test row's own shortfall for the forced token (test top logit − forced token's test logit), in milli-logits, rounded half-up. The verdict rule is **not** restated: pair verdicts compose through J-060's `grade_prefill_cell` (near-tie band rank ≤ 2 AND gap < 1,000 milli, both conjuncts, sub-logit strict). A positive rank with a sub-milli gap is **refused** at the filing resolution, exactly as J-060 refuses such a record — never silently reclassified.

**Synthetic verdict rule** (in `docs/janas/j089_ladder.mojo`'s header, before its first run): let A(L) be the attention max abs deviation at length L, and B = 0.003937006 be J-088's measured max single-element round-trip error (half the widest row's scale). **(V1)** 8-bit *costs at the synthetic level* at the first L where A(L) > B, or the proxy step at L is DIVERGENT under the near-tie rule. **(V2)** Growth A(32,768)/A(128) is reported descriptively, no threshold attached. If no length fires (V1), the verdict is **NO SYNTHETIC COST FOUND at 128..32,768** — a statement about the synthetic exercise only.

**Validation gate for the ladder:** the 256 rung is the identical exercise J-088 filed, so it must reproduce J-088's FAITH_ATTN numbers exactly (max 0.0023426115, mean 0.0011660499518484357); and the ladder's inline reference attention (rows regenerated, not held — holding them at 32,768 positions would cost ~256 MB this VM does not have) must match the module's `attention_f32_head` at that rung. Either failure voids the ladder, not the rule.

## 3. Inspection — what the tree already had (PROVEN from the tree)

- **J-060's `core/prefill_grade.mojo`** is the road's verdict account: per-step (rank, gap) records → step classes → cell verdicts, with the comparator-artifact and step-0-boundary classes. But it consumes *records*: its own header states the tree had "no in-tree grading code" turning run outputs into them beyond the on-box tf_oracle and offline log re-parsers. **The logit-row → record reduction was the missing piece** — and the trap this inspection avoided was writing a second verdict rule beside J-060's. J-089 builds only the reduction and composes through the account.
- **J-088's `core/kv_int8.mojo`** provides the store, the per-row quantizer, and the synthetic exercise (one shape: 256 positions, 8 heads × 128 dims). Its `read_k`/`read_v` are labelled "grading/test surface" — and its §5.2 numbers are explicitly "not a faithfulness grade of any model: that is J-089's teacher-forcing rank/gap work". Its §7 recipe point 4 names the grading gate every integrated path must pass: J-089's rank/gap on the raw prompt, CPU engine vs CPU comparator, never `llama-cli --single-turn`.
- **No live session constructs the int8 store** (J-088 §6's inspect asserted it of that tree; nothing since changed it) — so no live pair of logit rows exists to grade, from any arch, at any length. Combined with this tick's machine state (§ header), the live leg's deferral is a fact about the tree and the machines, not a choice.

## 4. What was built — the grading harness (PROVEN, VM, lightest target)

**`aesir_engine/core/kv_faith.mojo`** (new; pure module in the road's grain — no device, no session, produces no logits):

- `grade_kv_step(ref_row, test_row) -> KvStepGrade` — one forced step reduced under §2's definitions: `ref_top`, `test_top`, `rank`, `gap_milli`, `top_agrees` (diagnostic only; the verdict never rests on it alone).
- `grade_kv_pair(ref_rows, test_rows, comparator_valid) -> GradeSummary` — every step reduced, the records handed to `grade_prefill_cell`. `comparator_valid` is the caller's explicit statement (CPU comparator only, raw prompt, no template/BOS/backend artifact); with it false the pair grades COMPARATOR_ARTIFACT whatever the rows say, per J-060. An empty pair grades NOT_GRADED.
- **Refusals, by name:** empty or width-mismatched rows, step-count mismatch, NaN or infinite logits, and the sub-milli positive-rank gap (at milli resolution that step is ungradeable; the harness refuses rather than calling it exact).
- **Host contract** (module header): rows in step order, same vocabulary width per step; file the returned GradeSummary verbatim beside the rows' provenance (model pin, prompt, context length, each side's KV precision).

**Tests — `test_kv_faith`: 6/6 groups PASS** (filed in `j089_test_output.txt`): exact and near-tie steps (including the J-022 witness shape as a row pair — rank 1, gap 108 — and half-up gap rounding pinned at 0.0625 → 63 milli); **the near-tie band edges** (rank 2 + gap 999 IN; rank 2 + gap 1000 OUT — sub-logit is strict; rank 3 + gap 30 OUT; rank 2 + gap 1138 OUT, J-022 pre-fix step 17's shape); ties (first-maximum argmax; a tied maximum shares rank 0 / gap 0); pair verdicts FAITHFUL / NEAR_TIE / DIVERGENT (first divergent step named) / STEP0_BOUNDARY; pair honesty (empty NOT_GRADED; invalid comparator overrides perfect rows; **the J-022 post-fix pattern reproduced through logit rows: 23 exact + 1 near-tie grades NEAR_TIE with counts intact**); and the six refusals.

## 5. Numbers — the synthetic ladder (SIMULATED, deterministic)

From `docs/janas/j089_ladder.mojo` (filed in `j089_test_output.txt`; **two runs byte-identical**). Shape: J-088's exactly — 1 layer, 8 kv-heads, head_dim 128 (the 8B per-layer geometry), J-088's `synth` values and offsets, J-088's per-head queries, one final-position query per head. The **proxy** is a fixed deterministic 64-wide linear read-out of the concatenated attention outputs (weights in [−1, 1], formula in the harness header): a read-out of attention outputs, **named PROXY in every line — it is not a model logit, not a model's lm_head, and its grade is a synthetic diagnostic.**

| Length | Attn max dev | Attn mean dev | Proxy max dev | Proxy mean dev | Proxy rank / gap | Proxy class |
|---|---|---|---|---|---|---|
| 128 | 0.0022833496 | 0.0011304808 | 0.011664987 | 0.0040126530 | 0 / 0 | EXACT |
| 256 | 0.0023426115 | 0.0011660500 | 0.013811767 | 0.0037731790 | 0 / 0 | EXACT |
| 512 | 0.00232175 | 0.0011631195 | 0.014031529 | 0.0037646736 | 0 / 0 | EXACT |
| 2,048 | 0.0022938848 | 0.0011581607 | 0.014677465 | 0.0039132438 | 0 / 0 | EXACT |
| 8,192 | 0.0022944808 | 0.0011602670 | 0.014742017 | 0.0039603692 | 0 / 0 | EXACT |
| 32,768 | 0.0022866875 | 0.0011612232 | 0.014760971 | 0.0039518573 | 0 / 0 | EXACT |

(Means in the filed output carry full precision; the table rounds the last digit.)

**Validation gate: PASS, exactly.** The 256 rung reproduces J-088's filed FAITH_ATTN (max 0.0023426115, mean 0.0011660499518484357) digit for digit, and the inline reference matches `attention_f32_head` with max difference **0.0** (CROSSCHECK line). An independent Python re-derivation of the 128 and 256 rungs (in `j089_inspect.py`) agrees within 2×10⁻⁶ on every deviation figure and exactly on rank/gap/tops.

**Reading — what the ladder actually shows, no more:**

- **Attention deviation is FLAT across 128..32,768.** Max stays in 0.00228–0.00234 at every length; mean in 0.00113–0.00117; growth A(32,768)/A(128) = **×1.001**. This is the shape the construction predicts — per-row quantization error does not depend on position count, and an attention output is a convex combination of V rows whose scores are perturbed per-element — but it is reported as a *measured* flatness of this exercise, not as the prediction restated.
- **Proxy deviation grows early, then plateaus.** Proxy max rises +26 % from 128 to 2,048 (0.011665 → 0.014677) and only +0.6 % further to 32,768 (0.014761); proxy mean is flat (0.00376–0.00401). At every length the proxy's reference top token remains the int8 side's top token with gap 0 — the proxy grade is EXACT throughout.
- **Verdict under the pre-registered rule (§2): NO SYNTHETIC COST FOUND at 128..32,768** — no length's attention deviation exceeds the single-element bound B = 0.003937006 (the worst rung reaches 0.595 × B), and no proxy step is divergent, or even near-tie. `first_cost_len = -1` in the filed output.

**The caveats that bound this verdict, stated at the table:** the synthetic rows take only 17 distinct values; there is one layer, one query per head, and no compounding through a model's depth, no lm_head, no real prompt structure, no outlier K/V rows of the kind real models are known to carry — the exercise cannot see any effect that lives in those places. **The lengths where 8-bit starts to cost a real model truth are therefore NOT PROVEN — not found, and not ruled out — by this slice.** §7 files the exact live recipe that can find them.

## 6. Tests and inspect (PROVEN, VM, lightest target)

Filed as `j089_test_output.txt` (build recipe and machine state in its header):

- **`test_kv_faith` (new): 6/6 groups PASS** (§4).
- **Neighbours rebuilt from this tree:** `test_kv_int8` (J-088) **8/8 PASS**; `test_kv_account` (J-087) **10/10 PASS** — unchanged.
- **Ladder: two runs byte-identical** (deterministic), exit 0 both.
- **Inspect: `j089_inspect.py` — 31/31 checks PASS, exit 0** (filed as `j089_inspect_output.txt`): re-derives the 128/256 rungs independently in Python (quantizer, attention, proxy, grade; deviations agree within 2×10⁻⁶, grades exact), parses the filed ladder lines and checks the table, the validation gate, and the verdict's consistency with the pre-registered rule, and greps the harness's structure (composition through J-060, no second near-tie rule).

## 7. Deferred leg — the live KV-faithfulness grade (DEFERRED-WITH-REASON; recipe for the J-098 gate to re-cite)

**Why deferred:** (i) no live session integrates J-088's store (J-088 §7 deferred the integration itself, for the same machine reasons); grading an unintegrated path would be grading a fiction. (ii) The VM stayed far below the 5,500 MB inference gate all tick (MemAvailable 0.84–1.19 GB) and purplelongship is unreachable and 204-owned when it returns. Both reasons are expected to lift; neither is waived.

**The recipe, in dependency order:**

1. **Integrate, host path first** — J-088 §7 steps 1–3 in their order (host `mimir_well` path, then dense CUDA, then Gemma 4 CUDA), each path behind the `--kv-precision` option with f16 the default, exactly as filed there. A path that has not run live does not enter this recipe.
2. **First session and model:** the host path, with the smallest sha-pinned model whose profile cap reaches the full ladder — **Qwen3 0.6B Q4_K_M** (28 × 8 × 128, profile cap 32,768; J-087 §4.1). Re-verify the file's sha256 against the wave catalogue pin at run time before any run; do not grade an unpinned file. (A second witness at the 8B shape, cap 8,192, grades lengths to 8,192 only and is filed as such.)
3. **Pair construction, per length L ∈ {128, 512, 2,048, 8,192, 32,768}:** one raw prompt of exactly L tokens (prompt text drawn from the road's existing prompt corpus, concatenated and truncated to the exact token count, count verified on both runs; **no chat template, no BOS manipulation** — the raw prompt, per the discipline). Run the session twice over it, teacher-forcing the prompt's own tokens, recording the full logit row at every position: once with `--kv-precision f16` (reference), once with `--kv-precision int8` (test). Same binary, same machine state class (idle, stated), back to back.
4. **Comparator check before any pair verdict:** the reference run's ids are graded against the **ggml CPU comparator** through the 204 road's tf_oracle on the raw prompt (CPU engine vs CPU comparator only; **never `llama-cli --single-turn`**). Only a reference that itself grades FAITHFUL or NEAR_TIE under J-060's account may serve; otherwise the cell files COMPARATOR_ARTIFACT with its kind named and is re-run, not debated.
5. **Grade mechanically:** per length, `grade_kv_pair(reference_rows, int8_rows, comparator_valid=True)` from `core/kv_faith.mojo`; file the GradeSummary verbatim plus the per-step records beside the model pin, prompt identity, and machine state. Positions grade in order; a divergence confined to step 0 lands in STEP0_BOUNDARY and is re-graded with the boundary handled explicitly (J-060's disposition) before any costing verdict.
6. **The live costing rule, pre-registered here for that leg:** 8-bit *costs truth at length L* iff the pair verdict at L is DIVERGENT (comparator valid, step-0 disposition applied). NEAR_TIE is inside the road's faithful band — reported per length, never counted as cost; FAITHFUL is cost-free at that length. The first costing length, if any, is published with its full per-step record; if no length diverges, the filing says exactly that, per length, with worst rank/gap per length.
7. **Machine discipline:** purplelongship in a guarded idle gap (204 state heartbeat checked first; yield to a live 204 run) or the VM behind MemAvailable > 5,500 MB; one heavy run at a time; walls, if filed, carry the machine state and are never baselines under contention. The clean dequant re-measurement of J-088 §7 step 5 rides the same window.
8. **Registration:** with the counted live run, register `test_kv_faith` in `tests/run_all.mojo` and re-account the pin (J-031 §10's rule) — the same step J-088 §7 point 6 files for `test_kv_int8`.

## 8. Defects found

- **No defect found in prior work.** J-088's filed synthetic numbers reproduce exactly at the ladder's 256 rung (§5 gate); J-060's account composes with the new reduction on every test pattern, including its own filed J-022 witness; J-087's accounting is untouched and its neighbour suite passes unchanged.
- **Duplication trap avoided by inspection (recorded, not a defect):** the slice's first design sketch restated a verdict rule inside the new module. §3's inspection found J-060's account already owns that rule; the built module composes through it and contains no near-tie constant of its own (the inspect script asserts this mechanically).
- **Own-work defect, found and fixed in-slice:** the test file's first draft used the identifier `ref`, a reserved word in this Mojo — the compiler refused it before any run; renamed (`refs`), suite passes 6/6. No filed number rested on the refused draft.

## 9. NOT PROVEN list

- **Model faithfulness of 8-bit KV at any context length — NOT PROVEN in either direction.** No live pair was graded (no integrated session; no inference-capable machine this tick). No length is indicted; no length is cleared. The live recipe is §7, re-citable at the J-098 gate.
- **That the synthetic flatness (§5) transfers to real models.** The ladder's rows take 17 distinct values, in one layer, with no depth compounding, no lm_head, no real prompts, and no outlier rows; a real model's deviation growth across lengths is exactly what §7 measures and this slice does not.
- **The proxy as evidence about logits.** The proxy is a fixed linear read-out of attention outputs, built to exercise the grading harness on graded-shaped data at each length. Its EXACT grades are synthetic diagnostics, never model grades.
- Any wall, tok/s, or dequant-cost figure (none measured; J-088 §5.3's indicative range stands as-is, its clean re-measurement rides §7 step 7).
- Per-channel scales and the mixed layout (J-090's questions, untouched); the context ladder's walls and memory (J-091/J-093); KV + drafts (J-095).
- Janas's published 8-bit/long-context numbers as evidence about Aesir — none are cited as such anywhere in this slice.

## 10. Banking

Filed on branch `yrsa/janas-j089` (worktree `~/workspace/aesir-janas-j089`, base `4c89ea74`): in the tree, `aesir_engine/core/kv_faith.mojo` (new) and `aesir_engine/tests/test_kv_faith.mojo` (6 groups); in `docs/janas/`: `J089_KV_FAITHFULNESS.md` (this doc), `j089_ladder.mojo`, `j089_inspect.py`, `j089_inspect_output.txt`, `j089_test_output.txt`. **No existing module was modified** — the harness composes through J-060's account and J-088's store as they stand. Campaign copies of the doc + evidence in `~/workspace/model-tests/janas/`, sha-identical (verified by hash). Push by explicit refspec `git push origin HEAD:refs/heads/yrsa/janas-j089`, foreground, with `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`; the commit hashes and ls-remote lines are recorded in the campaign state entry for J-089 and the slice worker's report (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
