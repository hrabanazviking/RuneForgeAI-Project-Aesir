# J-090 — Mixed Discipline

**Slice:** J-090 (Part VI — Long Context and the 8-Bit KV, J-087–J-098), Project Aesir Janas clean-room road.
**Roadmap text:** "Where 8-bit hurts (the layers/heads J-089 indicts), a mixed layout (sensitive parts at higher precision) tried and measured; kept only on evidence."
**Executed:** 2026-11-01 from ~12:35 EST, in fresh worktree `~/workspace/aesir-janas-j090` on branch `yrsa/janas-j090`, from the verified tip of `yrsa/janas-j089` (`2b9ce151ad97f8b291984f8e875f24c81e9dca46`, local == ls-remote at slice start). Origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`. The J-089 worktree and the canonical checkout were not worked in.
**Machine state (VM, stated for every number below):** KVM, 4 vCPU, kernel 7.0.0-39-generic. MemAvailable ~2.3 GB at the worktree step, ~1.2 GB at the staging build, ~0.9 GB at the final suite runs — **far below the 5,500 MB inference gate at every moment**, so no model inference ran anywhere; lightest compiles only, one at a time. Load average 1.6–6.9 across the slice (other campaigns); **no wall is filed anywhere in this slice**, so contention touches no number. purplelongship was **not used at all** — unreachable (last_seen 2026-11-01T02:07:13Z) and owned by the 204 road when it returns. /tmp healthy.
**Clean-room record:** no Janas material was consulted in this slice and no Janas source code was opened, in this slice or any other. The design questions J-088 left open (per-channel calibration, the mixed layout) are answered from Aesir's own tree and measurements, per the road's answered-locally rule.

---

## 1. The question — and the honest shape, stated up front

**Question.** Where 8-bit KV hurts — the layers/heads J-089 indicts — try a mixed layout (sensitive parts at higher precision), measure it, and keep it only on evidence.

**The input this slice actually received.** J-089 indicted **nothing**:

- At the synthetic level its verdict was **NO SYNTHETIC COST FOUND at 128..32,768** — attention deviation flat (max 0.00228–0.00234 at every length, worst rung 0.595× the bound), logit-proxy grade EXACT at every length, `first_cost_len=-1`.
- At the live model level its verdict was **NOT PROVEN in either direction** — no length indicted, no length cleared; the exact live recipe is filed in J-089 §7 for the J-098 gate.

So "where 8-bit hurts" currently has **no measured referent** — no layer, no head, no length. A slice that manufactured one would be inventing its own justification. What this slice does instead, in order:

1. **Prices every candidate mixed layout** through the J-087/J-088 accounting (§3) — exact arithmetic, so that any future indictment, synthetic or live, is judged against filed numbers, not improvised ones.
2. **States the keep rule before measuring** (§2) — kept only on a measured indictment, a measured restoration, and a price bound.
3. **Measures the one concentration question the synthetic machinery can honestly ask** (§5): in J-089's own exercise, disaggregated — is the (already sub-bound) deviation concentrated in particular heads, or in one tensor (K vs V), such that a mixed layout would have something to repair? And does the per-channel scale shape J-088 left open change the deviation picture on the same data?
4. **Applies the rule to the measurements** (§5) and records the verdict. A measured NOT KEPT is a complete outcome for this slice; the live form of the question is deferred with its recipe (§7).

## 2. Pre-registered rule (stated before measuring)

Stated in `aesir_engine/core/kv_mixed.mojo`'s header and in `docs/janas/j090_concentration.mojo`'s header, both committed (63d76ef1) **before** the concentration harness was first run. Let B = 0.003937006 (J-088's measured max single-element round-trip error — J-089's bound), H(L) the per-head attention max deviations at length L, M(L) their median.

**Indictment** — any one of:

- **(I1) Uniform:** J-089's synthetic rule fired (`first_cost_len != -1` in its filed output), or a live pair grades DIVERGENT under J-089 §7's pre-registered live costing rule.
- **(I2) Concentration:** at some length, max H(L) > B **and** max H(L) ≥ 2 × M(L) — the error both breaks the bound and lives somewhere specific.
- **(I3) Tensor:** at some length, the K-only or the V-only aggregate max deviation > B — one tensor alone breaks the bound.

**Keep** — a mixed layout is KEPT only if **all** of:

- **(R1)** an indictment above exists, at the level claimed;
- **(R2)** the candidate covering the indicted subset, exercised in the same measurement, restores max deviation ≤ B (for I2, the worst-head-at-f16 control of §5 is that exercise);
- **(R3)** the candidate's per-token overhead over uniform int8 is **strictly less than half** the per-token saving uniform int8 makes against f16 — the layout keeps more than half the saving it exists to protect. (Mechanical form: `mixed_keep_verdict` in `core/kv_mixed.mojo`.)

Otherwise the verdict is **NOT KEPT**, with the failing conjunct named. If no indictment exists, no mixed store, option, or default is built — a layout that repairs nothing measurable is not kept on speculation.

## 3. Candidate layouts, priced (PROVEN as exact arithmetic)

Defined through `core/kv_int8.mojo` / `core/kv_account.mojo`, so the endpoints cannot drift: zero upgrades == J-088's 67,584 B/token; all upgrades == J-087's f16 census price. Upgrading one tensor row ((layer, kv-head) pair, one of K/V) costs head_dim − 4 bytes/token (payload +head_dim, the row's f32 scale no longer needed): 124 B at head_dim 128, 60 B at 64. All figures per token; totals at the profile cap.

**Llama 3 8B shape (32 layers × 8 kv-heads × 128; f16 = 131,072 B/token):**

| Candidate | B/token | × f16 | Total @ 8,192 |
|---|---|---|---|
| Uniform int8 (J-088, the baseline) | 67,584 | 0.5156 | 553,648,128 |
| First layer at f16 | 69,568 | 0.5308 | 569,901,056 |
| First + last layers at f16 | 71,552 | 0.5459 | 586,153,984 |
| One kv-head (all layers) at f16 | 75,520 | 0.5762 | 618,659,840 |
| Half the layers at f16 | 99,328 | 0.7578 | 813,694,976 |
| K only at f16 (V stays int8) | 99,328 | 0.7578 | 813,694,976 |
| V only at f16 (K stays int8) | 99,328 | 0.7578 | 813,694,976 |
| Uniform f16 (J-087 baseline) | 131,072 | 1.0000 | 1,073,741,824 |

Two priced facts the rule will need, whichever way a future indictment falls:

- **The price boundary is real:** upgrading half the layers costs overhead 31,744 B/token; twice that *equals* the int8 saving (63,488) exactly. Under R3's strict less-than, the half-layers candidate is **not keepable at any indictment** — a candidate must stay well under half the model upgraded to be worth its complexity. The cheapest candidates (first layer, +1,984; one head, +7,936) pass R3 easily *if* an indictment ever names their subset.
- **K-only and V-only cost the same and sum exactly:** K-only + V-only = int8 + f16 (198,656 B/token) — the tensor split is a pure partition of the upgrade price, pinned in the tests.

**Qwen3 0.6B shape (28 × 8 × 128 — the J-089 §7 live-recipe model):** uniform int8 59,136 B/token (1,937,768,448 @ 32,768); first layer 61,120 (2,002,780,160 @ cap); one head 66,080; uniform f16 114,688. **Other shapes** (endpoints pinned in tests): Coder 7B int8 29,568 / f16 57,344; OLMoE int8 69,632 / f16 131,072, one head across all layers 71,552.

**Per-channel, priced beside (J-088's open shape):** the scale table is paid once, so it beats per-row scales only past a break-even context — **exactly head_dim tokens for every shape** (8B: 128 tokens, where both totals are 8,650,752 B; at 8,192 per-channel totals 537,133,056 vs per-row 553,648,128, saving 16,515,072 B; at 1 token per-channel costs 327,680 vs 67,584). The break-even is an identity, checked mechanically in `per_channel_break_even_context`, not an estimate. Whether per-channel *deviation* differs is §5's measurement, not this section's arithmetic.

## 4. What was built (PROVEN, VM, lightest target)

- **`aesir_engine/core/kv_mixed.mojo`** (new; pure module): mixed per-token/total pricing by upgraded-pair counts (K and V separate), whole-layer and whole-head convenience prices, overhead/saving splits, the per-channel break-even identity, and `mixed_keep_verdict` — §2's rule in mechanical form, with verdict codes `KEPT` / `NOT_KEPT_NO_INDICTMENT` / `NOT_KEPT_NOT_RESTORED` / `NOT_KEPT_PRICE` and refusals for endpoint "candidates" (a uniform layout judged as mixed is a category error, refused by name). **No store and no option surface are built** — by the rule's own terms, those are conditional on a KEPT verdict (§5's is not).
- **`docs/janas/j090_concentration.mojo`** (new; harness): J-089's ladder exercise disaggregated — per-head deviation for modes BOTH / K-only / V-only / per-channel-oracle, the worst-head-at-f16 restoration control, median and ratio per length, indictment flags under §2. Its BOTH aggregate must reproduce J-089's filed ladder exactly (validation gate, §5).
- **Tests — `test_kv_mixed`: 6/6 groups PASS** (filed in `j090_test_output.txt`): endpoints reproducing both uniform accountings on four shapes; the §3 candidate table pinned literally; K/V additivity and per-layer monotonicity; the 0.6B prices; the break-even identity (two shapes, totals agreeing at break-even, per-channel saving at 8,192); the keep-verdict mechanics with each conjunct isolated — **including the price boundary**: indicted + restored + half-layers still grades NOT_KEPT_PRICE, because twice the overhead equals the saving and R3 is strict; and 10 refusals.

## 5. Numbers — the concentration measurement (SIMULATED, deterministic)

From `docs/janas/j090_concentration.mojo` (filed in `j090_test_output.txt`; **two runs byte-identical**). Shape: J-089's exactly — 1 layer, 8 kv-heads, head_dim 128, J-089's synth values/offsets/queries, at 128 / 256 / 2,048 / 32,768 positions. Per-channel scales are **oracle-calibrated** (each channel's scale from the whole sequence — an upper bound on per-channel quality, never an append-time claim).

**Validation gate: PASS, exactly.** The BOTH aggregate reproduces J-089's filed ladder at all four lengths digit-for-digit (max 0.0022833496 / 0.0023426115 / 0.0022938848 / 0.0022866875; means likewise), and the inline reference matches `attention_f32_head` at 256 with max difference **0.0** (CROSSCHECK line). The disaggregation is therefore a reading of J-089's own measured exercise, not a new exercise with new numbers.

| Length | Head max range (8 heads) | Median head max | Max/median | K-only max | V-only max | Worst-head-f16 control max |
|---|---|---|---|---|---|---|
| 128 | 0.002114–0.002283 | 0.0022377074 | 1.020 | 0.00066804886 | 0.0020695925 | 0.0022693276 |
| 256 | 0.002152–0.002343 | 0.0022704303 | 1.031 | 0.0005851835 | 0.0021027327 | 0.0023158789 |
| 2,048 | 0.002105–0.002294 | 0.0022224486 | 1.032 | 0.0005814731 | 0.002039522 | 0.0022880137 |
| 32,768 | 0.002097–0.002287 | 0.0022255778 | 1.027 | 0.00058341026 | 0.0020333529 | 0.0022859573 |

(K-only / V-only columns are aggregate maxima across heads, exactly as filed in the CONC lines of `j090_test_output.txt`; per-head lines for every head and mode are filed there too, and the inspect script checks this table against those lines mechanically.)

**Reading — what the disaggregation actually shows, no more:**

- **The deviation has no address.** Every head, at every length, sits in 0.00210–0.00234 — the max/median ratio is 1.020–1.032 against a concentration threshold of 2.0, and no head is anywhere near the bound B (the worst head reaches 0.595× B, the same fraction as the aggregate, because the aggregate *is* just the worst of near-identical heads). The worst head changes identity by length (3, 1, 1, 7) — there is no persistently sensitive head for a mixed layout to name.
- **Removing the worst head changes almost nothing.** The restoration control (worst head exact, seven at int8) lowers the aggregate max by 0.03–1.14% depending on length — the "fix" for a subset cannot restore what the subset does not own. This is the control's real content: even if a per-head indictment were someday claimed on data of this shape, R2 would fail for the one-head candidate, because the remaining heads sit at the same deviation.
- **What asymmetry exists lives in the tensor split, far under the bound.** V-only deviation (max 0.00190–0.00210) runs ~3.1–3.6× K-only (max 0.00058–0.00067): quantizing K alone barely moves the output (its error passes through the softmax, which re-normalizes a convex combination), while V's error enters the output weighted directly. Filed as a reading of this exercise, consistent with its construction — and both are far below B, so the split indicts nothing. Its forward value is narrow and real: *if* a live indictment ever lands, the first candidate to grade is a V-side upgrade (§3 prices it), not a layer or head upgrade.
- **Per-channel, on this data, is per-row.** Oracle-calibrated per-channel deviation is **digit-for-digit identical** to per-row at every head and length (chan_max == both_max, chan_mean == both_mean throughout the filed output). The reason is mechanical, and the inspect script proves it: the synthetic values are range-saturated — at 128 positions every (position, head) row slice **and** every channel attains maxabs 1.0, so every per-row scale and every per-channel scale is the same number (1/127) and the two "shapes" are one quantizer on this data. This grades the *exercise*, not the shapes: on real K/V, whose row ranges vary, per-channel and per-row scales genuinely differ, and which deviates less is **NOT PROVEN** either way (§9). J-088's per-channel refusal at use therefore stands unchanged: still priced (§3), still not built, its calibration question still open — now with the added knowledge that J-089's synthetic data cannot arbitrate it.

**Verdict under the pre-registered rule (§2), applied mechanically:**

- (I1) Uniform indictment: **no** — J-089's filed `first_cost_len=-1`; re-verified this slice by the inspect script from J-089's filed output.
- (I2) Concentration indictment: **no** — no head exceeds B at any length (max 0.00234 < 0.003937006), and the max/median ratio never exceeds 1.032 < 2.0. Both conjuncts fail.
- (I3) Tensor indictment: **no** — K-only max 0.00067 and V-only max 0.00210, both < B at every length.

**No indictment fires, so the mixed layout is NOT KEPT — `mixed_keep_verdict` grades every §3 candidate `NOT_KEPT_NO_INDICTMENT`, and per the rule nothing is built: no mixed store, no `--kv-precision` extension, no default change.** Uniform per-row int8 (J-088) remains the road's only 8-bit layout. This verdict is at the synthetic level only, exactly as J-089's no-cost verdict was; it neither claims nor implies anything about a real model (§7, §9).

## 6. Tests and inspect (PROVEN, VM, lightest target)

Filed as `j090_test_output.txt` (build recipe and machine state in its header):

- **`test_kv_mixed` (new): 6/6 groups PASS** (§4).
- **Neighbours rebuilt from this tree:** `test_kv_int8` (J-088) **8/8 PASS**; `test_kv_account` (J-087) **10/10 PASS**; `test_kv_faith` (J-089) **6/6 PASS** — unchanged.
- **Concentration harness: two runs byte-identical** (deterministic), exit 0 both; validation gate PASS (§5).
- **Inspect: `j090_inspect.py`** — checks the module's and harness's structure (rule stated in both headers, prices defined through the J-087/J-088 modules, synth byte-identical to J-089's), re-derives J-089's filed verdict (I1), parses the filed concentration lines and applies §2 mechanically (I2/I3, median/ratio recomputation, worst-head control recomputation, chan == both per length), re-derives the 128 rung per-head in Python (quantizer + attention, float64; deviations agree within 2×10⁻⁶), and proves the range-saturation fact behind the per-channel equality (every row slice and channel at maxabs 1.0). Its count is filed in `j090_inspect_output.txt`.

## 7. Deferred leg — the live mixed question (DEFERRED-WITH-REASON; recipe for the J-098 gate to re-cite)

**Why deferred:** the live question — does 8-bit KV hurt a real model somewhere a mixed layout can repair? — cannot be asked before J-089's live grade exists (no integrated session; this VM below its inference gate all tick; purplelongship unreachable). Grading a mixed layout against an unmeasured baseline would be grading a fiction twice over.

**The recipe, in dependency order** (steps 1–2 are J-089 §7's, restated because this leg stands on them):

1. **Integrate and grade, per J-089 §7 steps 1–6 exactly** — host path first, Qwen3 0.6B Q4_K_M pin re-verified, paired f16/int8 teacher-forced rows at 128 / 512 / 2,048 / 8,192 / 32,768, ggml CPU comparator check, never `llama-cli --single-turn`, mechanical `grade_kv_pair` filing, J-089's pre-registered live costing rule (DIVERGENT = costs; NEAR_TIE reported, not counted).
2. **If no length diverges:** the live answer matches the synthetic one — mixed stays NOT KEPT at model level too, and the J-098 gate records both levels closed on evidence.
3. **If a length diverges (a live I1 indictment):** attribute before upgrading — re-grade the pair with the int8 side's KV restricted per layer-group (the session integration of step 1 must expose per-layer precision selection for this diagnostic; if it does not, that exposure is the first build of this leg, priced by §3's module). The smallest layer/head/V-side subset whose f16 restoration returns the pair to FAITHFUL or NEAR_TIE is the indicted subset; if no proper subset restores it, the indictment is diffuse at model level and the honest live verdict is likewise NOT KEPT (named `NOT_KEPT_NOT_RESTORED` for every proper candidate; uniform f16 remains the fallback the user already has).
4. **Judge the covering candidate by §2's rule with live facts:** `mixed_keep_verdict(indicted=True, restored=<step 3's grade>, candidate/int8/f16 prices from §3 for the model's shape)`. Only a KEPT verdict builds the mixed store and its option selection, in a follow-on slice, with the live pair re-graded through the built store before it banks.
5. **Per-channel live form:** if step 3's attribution suggests scale-shape sensitivity, a per-channel store may be proposed only with a stated calibration (scales from the prompt's own f16 pass, or a held-out calibration prompt — never from the graded rows themselves), graded by the same pairs. Until then per-channel remains priced-not-built and refused at use, exactly as J-088 left it.
6. **Machine discipline:** as J-089 §7 step 7 (guarded idle gap on purplelongship or the VM behind its gate; one heavy run at a time; machine state filed with any wall).

## 8. Defects found

- **No defect found in prior work.** J-089's filed ladder reproduces digit-for-digit as this harness's BOTH aggregate at four lengths (§5 gate); J-088's accounting is reproduced by the new module's endpoints; J-087's census prices are untouched and all three neighbour suites pass unchanged.
- **Own-work defect, found and fixed in-slice:** the concentration harness's first build was refused by the compiler — it used the identifier `ref`, a reserved word in this Mojo (the same trap J-089 §8 recorded in its test file). Renamed (`want`) before any run; no filed number rested on the refused draft. The rule and the module were committed (63d76ef1) before the fix and are unchanged by it.
- **Doc care, recorded:** §5's table is not hand-trusted — the inspect script parses the filed CONC lines and checks every aggregate the table quotes (both/K-only/V-only maxima, medians, ratios, control) against them mechanically, so a transcription slip in the doc fails the inspect rather than shipping.

## 9. NOT PROVEN list

- **Model-level mixed discipline — NOT PROVEN in either direction.** No live pair exists to indict or clear any layer/head/tensor of any real model. The synthetic NOT KEPT verdict governs the synthetic level only; the live recipe is §7, re-citable at the J-098 gate.
- **Per-layer concentration.** The ladder has one layer; deviation compounding across a model's depth — the place a first/last-layer sensitivity would actually live — is invisible to this exercise by construction. §3 prices the layer candidates so the live leg (§7 step 3) starts from filed numbers.
- **Per-channel vs per-row on real data.** On J-089's synthetic data the two shapes are the same quantizer (range saturation, §5); on real K/V they differ, and which deviates less — and what a past-data calibration costs in deviation against the oracle bound — is NOT PROVEN.
- **That synthetic diffuseness transfers.** The synthetic rows take 17 distinct values with no outlier rows, no depth, no lm_head; a real model's error could concentrate where this exercise cannot look. §5's "no address" is a statement about this exercise.
- Any wall, tok/s, or dequant-cost figure for any mixed layout (none measured; no mixed store exists to measure).
- Janas's published mixed-precision or per-channel behaviour as evidence about Aesir — none is cited as such anywhere in this slice.

## 10. Banking

Filed on branch `yrsa/janas-j090` (worktree `~/workspace/aesir-janas-j090`, base `2b9ce151`): commits — design + pre-registered rule (module, tests, harness) first, then the harness reserved-word fix, this doc, the inspect script and the filed outputs. In the tree: `aesir_engine/core/kv_mixed.mojo` (new) and `aesir_engine/tests/test_kv_mixed.mojo` (6 groups); in `docs/janas/`: `J090_MIXED_DISCIPLINE.md` (this doc), `j090_concentration.mojo`, `j090_inspect.py`, `j090_inspect_output.txt`, `j090_test_output.txt`. **No existing module was modified** — the accounting is defined through J-087's census and J-088's store functions as they stand. Campaign copies of the doc + evidence in `~/workspace/model-tests/janas/`, sha-identical (verified by hash). Push by explicit refspec `git push origin <sha>:refs/heads/yrsa/janas-j090`, foreground, with `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`; the commit hashes and ls-remote lines are recorded in the campaign state entry for J-090 and the slice worker's report (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
