# J-091 — Context Ladder

**Slice:** J-091 (Part VI — Long Context and the 8-Bit KV, J-087–J-098), Project Aesir Janas clean-room road.
**Roadmap text:** "Context ladder. Reading and writing measured at 1k / 4k / 8k / 16k / 32k on a dense mid-size model, CPU line and GPU line, KV at both precisions — the Janas long-context table rebuilt for Aesir, on Aesir's hardware, with llama-bench-class comparator numbers taken under the raw-oracle discipline (conditions stated where they cannot be identical)."
**Executed:** 2026-11-01 ~12:35–13:16 EST, in fresh worktree `~/workspace/aesir-janas-j091` on branch `yrsa/janas-j091`, from the verified tip of `yrsa/janas-j090` (`c50f9d93c5c2257d4133d169b86c8a14ab8f3626`, local == ls-remote at slice start). Origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`. The J-090 worktree and the canonical checkout were not worked in. Design + pre-registered rules committed FIRST @ `801483c7` (module + tests + harness), before any build or run of this slice.
**Machine state (VM, stated for every number below):** KVM, 4 vCPU, kernel 7.0.0-39-generic. MemAvailable ~0.5–1.7 GB across the slice (524,588 kB at the first check) — **far below the 5,500 MB inference gate at every moment**, so no model inference ran anywhere; lightest compiles only, one at a time. Load average up to ~11.8 (other campaigns); **no wall is filed anywhere in this slice**, so contention touches no number. purplelongship was **not used at all** — unreachable (last_seen 2026-11-01T02:07:13Z) and owned by the 204 road when it returns. /tmp healthy.
**Clean-room record:** no Janas material was consulted in this slice and no Janas source code was opened, in this slice or any other. Janas's published long-context table is its table on its machine: it names the rungs this ladder rebuilds, and none of its figures are quoted here as Aesir's.

---

## 1. The question — and the honest shape, stated up front

**Question.** Rebuild the long-context ladder for Aesir: reading (prefill) and writing (decode) at 1k / 4k / 8k / 16k / 32k on a dense mid-size model, on the CPU line and the GPU line, with KV at both precisions (f16 and J-088's 8-bit).

**The shape this slice can honestly take, decided from evidence before building.** A ladder *wall* needs a live run of a 7B model at up to 32k context. This tick neither machine can run one: the VM is far below its inference gate and purplelongship is unreachable. The standing Part VI pattern (J-088 §7, J-089, J-090) therefore governs: **build the ladder machinery and its accounting offline, prove the frame against every prior slice it touches, and file every live wall as DEFERRED-WITH-REASON with an exact recipe for the J-098 gate (§7).** What this slice proves is the ladder itself:

1. **The frame is filled with exact arithmetic** (§5): per rung — KV bytes held at both precisions, prefill work (causal pairs, attention MACs, projection MACs), and the write leg's KV-read traffic and attention MACs — all defined through J-087's census, J-088's store prices, and J-053's prefill account, so the ladder cannot drift from the road's own baselines. When the live legs run, their walls land in a table whose work columns are already pinned.
2. **Every cell carries a pre-registered verdict** (§2): ACCOUNTED (frame filled, wall deferred), CAP_REFUSED (a named tree cap refuses the run as constructed — a result, not a gap), or INTEGRATION_BLOCKED (the precision is not integrated on that line). The ladder's honest findings are in these verdicts: **the CPU line cannot run the 16k or 32k rungs at all today** (the host generation path caps KV allocation at 16,000 tokens), **the GPU line's 32k write leg is cap-refused as defined** (its session would need 32,896 > the profile's 32,768 cap), and **no int8 cell on either line can run** until J-088 §7's deferred integration lands.
3. **GPU placement is accounted through the tree's own admission arithmetic** (§5): whole-GPU through the 8k rung's session, spill-required from 16k — with the arithmetic cross-checked against the filed 2026-10-28 whole-model refusal at 16,384 (reproduced within 4 bytes, §5). The int8 counterfactual is priced through the same admission shape: it would hold the 16k session whole, and still spill at 32k.

**The witness model.** Qwen2.5-Coder-7B-Instruct-heretic **Q4_K_M** (mradermacher static repo), sha256 `8053aeda222ba79e865a6eddd268332fd4e4dbe406371318d6df1f9beae9502b`, 4,683,074,688 B — the wave crown (S-034 pin-verified; whole-GPU and spilled proofs on purplelongship, GPU_2060_STATE). Profile (this tree, `core/dense_gqa_profile.mojo`): 28 layers, hidden 3,584, ffn 18,944, 28 query heads, 4 kv heads, head_dim 128, vocab 152,064, **context cap 32,768**. It is the only dense mid-size profile whose cap reaches every rung (Llama 3 8B and Llama 3.2 3B cap at 8,192); Qwen3 0.6B also caps at 32,768 but is not mid-size. The ladder is filed for this one model, as the roadmap's singular "a dense mid-size model" asks.

## 2. Definitions and verdict rules (pre-registered)

Stated in `core/kv_ladder.mojo`'s header and committed (@ `801483c7`) before the harness was built or run.

- **Rungs:** prompt lengths 1024 / 4096 / 8192 / 16384 / 32768 tokens.
- **Reading** at rung L = prefill of a raw prompt of exactly L tokens. **Writing** at rung L = generation of **128 tokens** immediately after that prompt, greedy; the first generated token attends at context L, the last at L+127. One session serves both legs, so a rung's **session context** is L (read leg) or L+128 (write leg), and caps/admission are judged at the session context of the leg in question.
- **Cell verdicts** (mechanical form: `ladder_cell_verdict`, integration judged before caps):
  - **ACCOUNTED** — the frame is filled and no tree cap refuses the run as constructed. ACCOUNTED never means measured: the cell's wall is NOT PROVEN (deferred, §7).
  - **CAP_REFUSED** — a named cap refuses the run as constructed: on the CPU line, the host generation path's `MAX_RUNTIME_CONTEXT` (16,000; §3); on the GPU line, the profile context cap (32,768).
  - **INTEGRATION_BLOCKED** — the precision is not integrated into any live session on that line (J-088's store is a component; its §7 session integration is deferred). Judged first: an unintegrated precision cannot run at any length, and the cap that would bind after integration is filed beside it (§5).
- **GPU placement** (accounted, not measured): required bytes at the session context through the tree's own admission shape (§4) vs the filed usable VRAM of purplelongship's RTX 2060 (5,368,709,120 B, J-031) → WHOLE_GPU or SPILL_REQUIRED. The int8 placement is a **counterfactual** through the same shape at J-088's prices, labelled CF wherever it appears.
- **Comparator discipline for the deferred legs** (§7): llama-bench-class numbers are the comparator instrument (never the template-rendering chat path); the conditions that cannot be identical are stated in §7 step 5, not discovered afterwards.

## 3. Inspection — the lines, the caps, the integration state (PROVEN from the tree)

- **CPU line** = the host generation path: batched prefill (chunk cap 256 by default) through `AesirEngine._run_generation` (J-053 §2). Its KV allocation is `min(MAX_RUNTIME_CONTEXT, file context)` with `MAX_RUNTIME_CONTEXT = 16000` (`aesir_engine/aesir.mojo:32`, construction at `:1171`); the `forward_pass` overload clamps identically (`core/inference.mojo:1394`). The host `KVCache` is fixed-capacity and its append raises past capacity (J-087 §3.1). Consequence, mechanical: any session context above 16,000 is refused by construction on this line — the 16k rung misses the cap by 384 tokens, the 32k rung by 16,768. This is a cap the code chose on purpose (its docstring: never size a cache from a model's full trained context on a small host); the ladder records it, it does not relitigate it. Lifting it for a leg is a gate decision (§7 step 4).
- **GPU line** = the dense CUDA session (`core/llama3_cuda.mojo`), which serves every `DenseGQAProfile` including Coder; its KV buffer is f16 (§ J-087 §3.2), its context is validated to `2..profile.context_cap` (`validate_dense_gqa`), and admission is `llama3_memory_plan` (`core/inference_memory.mojo:132`): weights + kv_elements × 2 + activation elements × 4 + `sampling_device_bytes`. Coder's GPU prefill is **width-1** — the tile-4 form is admitted only for the exercised Llama 3.2 3B profile (`core/dense_buffers.mojo` `effective_prefill_batch`), so a Coder prompt pays L passes on this line (J-053's plan table). Spill (front layers on GPU, tail on CPU) is the session's proven over-VRAM shape for this exact file: whole-GPU at context 4,096 and spilled (27/28 layers) at 16,384, token-identical (GPU_2060_STATE, 2026-10-28).
- **Integration state:** no session or execution file imports `core.kv_int8` (or the new `core.kv_ladder`) in this tree — inspect-asserted mechanically (§6), the same checked fact J-088 §6 filed. Every int8 cell is therefore INTEGRATION_BLOCKED today, on both lines, at every rung.
- **Prior evidence re-cited, not re-measured:** the only live Coder walls in the record are the wave/S-034-class rows (e.g. whole-GPU @4096 decode ≈17.5 tok/s, spilled @16384 decode ≈10.2 tok/s, GPU_2060_STATE) at contexts far below the ladder's upper rungs and under the wave's own conditions. They are **not** ladder cells and are not entered as any rung's wall; the ladder's walls are all deferred (§7).

## 4. What was built (PROVEN, VM, lightest target)

- **`aesir_engine/core/kv_ladder.mojo`** (new; pure accounting in the road's grain): the rungs and the 128-token write leg; KV per-token/total at both precisions **defined through** `core/kv_account.mojo` (f16) and `core/kv_int8.mojo` (int8); prefill pairs/attention/projection/head MACs **defined through** `core/prefill_anatomy.mojo`; the decode context sum `Σ = 128·L + 8,128` and the traffic/attention priced on it; session contexts per direction; `ladder_cell_verdict` (§2's rule, integration first); `ladder_gpu_required_bytes` (the `llama3_memory_plan` shape: weights + KV + activation × 4 + sampling, the activation's fixed/per-context split taken from the profile's own `activation_elements`) and `ladder_gpu_placement`. No existing module was modified; no session is wired (the inspect asserts it). Registration in `tests/run_all.mojo` is **not** done, for J-031 §10's stated reason.
- **`docs/janas/j091_ladder.mojo`** (new; harness): prints the §5 table from the module for the Coder shape — one LADDER line per rung with every column, deterministic (two runs byte-identical, §6). It prints no wall, by design (its header says so).
- **Tests — `test_kv_ladder`: 8/8 groups PASS** (§6).

## 5. The ladder (ACCOUNTED frame; every wall NOT PROVEN)

Per-token prices (Coder shape): f16 **57,344 B/token** (J-087), per-row int8 **29,568 B/token** (J-088) — a 27,776 B/token saving, ratio 0.5156. Projection work is precision- and line-invariant: **6,525,288,448 MACs/token** + one head pass of 544,997,376 per prompt (and per generated token).

### 5.1 The frame — KV held, prefill work, write-leg traffic (exact arithmetic)

| Rung | KV f16 | KV int8 | Pairs /layer | Prefill attn MACs | Prefill proj MACs | Write ctx sum | Write KV-read f16 | Write KV-read int8 | Write attn MACs |
|---|---|---|---|---|---|---|---|---|---|
| 1,024 | 58,720,256 | 30,277,632 | 524,800 | 105,329,459,200 | 6,681,895,370,752 | 139,200 | 7,982,284,800 | 4,115,865,600 | 27,937,996,800 |
| 4,096 | 234,881,024 | 121,110,528 | 8,390,656 | 1,684,038,221,824 | 26,727,581,483,008 | 532,416 | 30,530,863,104 | 15,742,476,288 | 106,858,020,864 |
| 8,192 | 469,762,048 | 242,221,056 | 33,558,528 | 6,735,330,803,712 | 53,455,162,966,016 | 1,056,704 | 60,595,634,176 | 31,244,623,872 | 212,084,719,616 |
| 16,384 | 939,524,096 | 484,442,112 | 134,225,920 | 26,939,679,047,680 | 106,910,325,932,032 | 2,105,280 | 120,725,176,320 | 62,248,919,040 | 422,538,117,120 |
| 32,768 | 1,879,048,192 | 968,884,224 | 536,887,296 | 107,755,427,856,384 | 213,820,651,864,064 | 4,202,432 | 240,984,260,608 | 124,257,509,376 | 843,444,912,128 |

Readings, no more than the arithmetic says: KV held grows linearly (×32 across the ladder, halved-ish by int8 at every rung); prefill attention work grows quadratically (×1,024) and passes projection work between the 4k and 8k rungs (at 8,192 attention is 6.74e12 of 6.02e13 total prompt MACs — the share itself is J-092's question, filed there, not graded here); the write leg's KV-read traffic at 32k (241 GB f16 of by-construction touches for 128 tokens) is the quantity a wall will be read against — it is a traffic *shape* (caches sit between it and any device), never a measured byte count.

**Validation gates (all exact):** the f16 column reproduces J-087 §4.1's Coder row (57,344 B/token; 469,762,048 @8,192); the int8 column reproduces J-088's Coder price (29,568); attention MACs @8,192 reproduce J-053's filed Coder figure **6,735,330,803,712**; projection @8,192 reproduces J-068's filed **53,455,162,966,016**. The inspect script re-derives every cell of both §5 tables in Python and compares exactly (§6).

### 5.2 The verdicts — per line, precision, rung, direction

| Rung | CPU f16 read | CPU f16 write | CPU int8 (both dir.) | GPU f16 read | GPU f16 write | GPU int8 (both dir.) |
|---|---|---|---|---|---|---|
| 1,024 | ACCOUNTED | ACCOUNTED | INTEGRATION_BLOCKED | ACCOUNTED | ACCOUNTED | INTEGRATION_BLOCKED |
| 4,096 | ACCOUNTED | ACCOUNTED | INTEGRATION_BLOCKED | ACCOUNTED | ACCOUNTED | INTEGRATION_BLOCKED |
| 8,192 | ACCOUNTED | ACCOUNTED | INTEGRATION_BLOCKED | ACCOUNTED | ACCOUNTED | INTEGRATION_BLOCKED |
| 16,384 | **CAP_REFUSED** | **CAP_REFUSED** | INTEGRATION_BLOCKED | ACCOUNTED | ACCOUNTED | INTEGRATION_BLOCKED |
| 32,768 | **CAP_REFUSED** | **CAP_REFUSED** | INTEGRATION_BLOCKED | ACCOUNTED | **CAP_REFUSED** | INTEGRATION_BLOCKED |

Notes the table compresses: (a) behind CPU int8's block, the same 16,000 cap would refuse its 16k/32k cells the moment integration lands (proven mechanically in the tests with the hypothetical integrated fact: @8,192 ACCOUNTED, @16,384 CAP_REFUSED); (b) the GPU 32k write refusal is the session-context form only — §7 step 4 files the cap-adjusted prompt (32,640 + 128) under which that cell can run, named as adjusted wherever it is filed; (c) ACCOUNTED cells' walls are all NOT PROVEN / deferred (§7) — there is no measured wall in this table.

### 5.3 GPU placement (accounted through the tree's admission arithmetic)

Session context = rung + 128; usable 5,368,709,120 B; weights 4,683,074,688 B.

| Rung (session) | Required, f16 | Placement | Required, int8 (CF) | Placement (CF) |
|---|---|---|---|
| 1,024 (1,152) | 4,751,005,312 | WHOLE_GPU | 4,719,007,360 | WHOLE_GPU |
| 4,096 (4,224) | 4,927,510,144 | WHOLE_GPU | 4,810,184,320 | WHOLE_GPU |
| 8,192 (8,320) | 5,162,849,920 | WHOLE_GPU | 4,931,753,600 | WHOLE_GPU |
| 16,384 (16,512) | 5,633,529,472 | SPILL_REQUIRED | 5,174,892,160 | WHOLE_GPU |
| 32,768 (32,896) | 6,574,888,576 | SPILL_REQUIRED | 5,661,169,280 | SPILL_REQUIRED |

Cross-checks: at a pure 16,384 context the same arithmetic gives **5,626,175,104** required vs the filed whole-model refusal total **5,626,175,108** (GPU_2060_STATE, 2026-10-28) — agreement within **4 bytes** (the tolerance pre-stated in the module header is 16; the residual is the filed run's per-run device-weight conversion detail, which the file size does not state), and both figures exceed usable, so the refusal's direction is reproduced, not just its neighbourhood. The 4,096 whole-GPU placement agrees with the proven 2026-10-28 whole-GPU run at that context; the 16k spill placement agrees with its proven spilled run. The 32,768 session row is arithmetic over an **inadmissible** context (32,896 > cap) and is printed only to price the spill the cap-adjusted form (§7) would need; the read-only session at exactly 32,768 requires 6,567,534,208 — also SPILL_REQUIRED. The int8 column's one material finding: **8-bit KV would move the 16k session from spill to whole-GPU** (headroom 193,816,960 B under the counterfactual) — ACCOUNTED as arithmetic, its wall NOT PROVEN, its run INTEGRATION_BLOCKED.

## 6. Tests and inspect (PROVEN, VM, lightest target)

Filed as `j091_test_output.txt` (build recipe and machine state in its header):

- **`test_kv_ladder` (new): 8/8 groups PASS** — rungs + per-token endpoints reproducing J-087/J-088 mechanically; KV totals at all rungs both precisions; the work frame (@8,192 attention == J-053 filed, projection == J-068 filed); decode context sums and traffic; CPU verdicts (ACCOUNTED ×3 rungs, CAP_REFUSED ×2, both directions); GPU + int8 verdicts (GPU write @32,768 CAP_REFUSED; int8 INTEGRATION_BLOCKED in all 20 line×rung×direction cells as the tree stands; caps binding behind hypothetical integration in the stated order); GPU admission (required totals pinned per session context; the 16,384 cross-check within 4 B; the int8 counterfactual's 16k-whole / 32k-spill placements); 9 refusals.
- **Neighbours rebuilt from this tree:** `test_kv_mixed` (J-090) **6/6 PASS**; `test_kv_int8` (J-088) **8/8 PASS**; `test_kv_account` (J-087) **10/10 PASS**; `test_kv_faith` (J-089) **6/6 PASS** — unchanged.
- **Ladder harness: two runs byte-identical** (sha256 `b7c8f3c8…c2f5`), exit 0 both.
- **Inspect: `j091_inspect.py`** — checks the module's structure (prices/work defined through J-087/J-088/J-053; rule pre-registered in the header), the tree facts of §3 grepped first-hand (host cap and its allocation site, the forward_pass clamp, the Coder profile parsed, the CUDA cache's f16 dtype, the no-importer fact), **re-derives every field of every filed LADDER line in Python and compares exactly**, the §5.1 validation gates against J-087/J-088/J-053/J-068's filed numbers, the §5.3 refusal cross-check within its pre-stated tolerance, and this doc's deferred-recipe content. Its count is filed in `j091_inspect_output.txt`.

## 7. Deferred legs — the live ladder (DEFERRED-WITH-REASON; recipe for the J-098 gate to re-cite)

**Why deferred:** the VM stayed far below the 5,500 MB inference gate all tick (MemAvailable ~0.5–1.7 GB) and purplelongship is unreachable and 204-owned when it returns — no ladder wall could run on any box. The int8 legs are additionally blocked on J-088 §7's integration, and two CPU cells and one GPU cell are CAP_REFUSED as constructed (steps 4–5 handle them explicitly; nothing here waives a cap silently).

**The recipe, in dependency order:**

1. **Window and machine discipline:** purplelongship in a guarded idle gap (204 state heartbeat checked first; yield to a live 204 run) for the GPU line and the primary CPU line; the VM behind MemAvailable > 5,500 MB is an acceptable CPU-line substitute only (the crown's wave battery ran on the VM at ~5.15 GB RSS, S-045 — but no GPU line exists there). One heavy run at a time; per run file load, MemAvailable/VRAM, Tctl, and `nvidia-smi` state. Median of 3 runs per cell is the filed wall; a single run files as MEASURED-INDICATIVE.
2. **Re-pin before running:** sha256 of the Coder Q4_K_M file on the box must equal `8053aeda222ba79e865a6eddd268332fd4e4dbe406371318d6df1f9beae9502b` (4,683,074,688 B) before any leg; a file that does not verify does not run.
3. **Read legs (f16 first; int8 only after step 6):** per rung and line, one raw prompt of exactly L tokens from the road's prompt corpus (token count verified on the run; no chat template, no BOS manipulation). CPU line: host batched path, chunk cap stated (default 256). GPU line: dense CUDA session at the rung's session context, placement per §5.3 (whole through 8,192; spilled from 16,384 with `exec_layers` recorded), width-1 passes as the Coder profile admits. File the prompt-fill wall and the tok/s = L / wall; where the serve path cannot separate tokenize+admit from fill, file the serve wall and say so (J-053 §3's census stands: no phase timer exists).
4. **Write legs:** 128 greedy tokens after the same prompt; wall and tok/s = 128 / wall; first-token latency split out where the surface allows. **Cap-adjusted top rung (GPU):** the 32k write runs as prompt 32,640 + 128 generated (session context exactly 32,768) and is filed as the cap-adjusted form of the 32,768 cell, never as the unadjusted cell. **CPU 16k/32k cells (both directions, both precisions):** these stay CAP_REFUSED in the closed ladder unless the gate first lands an explicit cap decision — lift `MAX_RUNTIME_CONTEXT` for the leg, or drive the leg through an explicitly-sized cache — recorded as a decision with its own slice; the ladder does not presume it.
5. **Comparator (llama-bench-class, conditions stated where they cannot be identical):** on the same box and file, `llama-bench` pp at each rung and tg128 at each rung's context, default f16 KV. The conditions that cannot be made identical, stated in advance: llama-bench drives synthetic token ids through its own batching (its `-b`/`-ub` stated in the filing) with no tokenizer or template, while Aesir drives tokenized raw text through its own paths (batched host / width-1 CUDA); per-token work shapes are this slice's pinned counts on both sides, but token content and batching differ, so the comparison is filed as pp/tg-class numbers side by side, never as faithfulness evidence. For the int8 comparison, llama.cpp's `-ctk q8_0 -ctv q8_0` KV flags are llama.cpp's own quantization, **not** Aesir's per-row int8 construction — comparable as a class, named as different wherever quoted.
6. **Int8 legs:** only after J-088 §7's integration lands per line (host path for CPU, dense CUDA for GPU), each behind `--kv-precision` with f16 default, and each path's J-089 §7 paired grade (step 7) passed at the ladder's lengths before its walls are filed as ladder cells; until then int8 cells keep this slice's INTEGRATION_BLOCKED verdict in any gate table.
7. **Faithfulness of every Aesir row:** ids-first, then teacher-forcing rank + logit gap against the ggml CPU comparator on the raw prompt (CPU engine vs CPU comparator only; **never `llama-cli --single-turn`**), per J-089 §7 steps 4–6; a reference that fails files COMPARATOR_ARTIFACT with its kind named and is re-run, not debated. J-089's live KV grade and J-090's live mixed question ride this same window at the ladder's lengths.
8. **Registration:** with the counted live run, register `test_kv_ladder` in `tests/run_all.mojo` and re-account the pin (J-031 §10's rule).

## 8. Defects found

- **No defect found in prior work.** Every gate this slice grades against reproduced exactly: J-087's Coder census row, J-088's Coder int8 price, J-053's Coder attention figure, J-068's Coder projection total, and the GPU admission direction at 16,384. The 4-byte residual against the filed refusal total (§5.3) is a difference between a filed *run's* device-weight accounting and the *file size* this slice prices from — attributed in §5.3, inside the tolerance pre-stated before running, and not a defect in either record: the refusal itself (required > usable) holds under both figures.
- **Own-work defects, found and fixed in-slice (inspect script only; no filed number rested on any of them):** the inspect's first draft sought J-053's attention figure in its *inspect output* (which pins only proj/token + head for Coder) — corrected to J-053's doc table, where the figure is filed; its first no-importer check flagged the `kv_*` accounting family's own sibling imports — narrowed to session/execution files with the adjudication recorded in the script, following J-088 §8's precedent; and its first LADDER-line count expected one harness run where the filed output holds two — corrected to assert both runs and their byte-identity, which strengthens the determinism check it was reaching for.

## 9. NOT PROVEN list

- **Every ladder wall — reading and writing, every rung, line, and precision: NOT PROVEN.** No live run executed in this slice on any hardware. The §5 tables are exact arithmetic (PROVEN as arithmetic) and pre-registered verdicts over tree facts (PROVEN from the tree); they contain no speed.
- **Any tok/s figure for the ladder's cells**, including any derived by dividing §5's MAC counts by an assumed rate — no such figure is filed anywhere in this slice, and the wave-era Coder rows re-cited in §3 are prior evidence under other conditions, not ladder cells.
- **That §5.3's accounted placements predict live admission byte-for-byte** — the 16,384 cross-check supports the arithmetic within 4 B at that context; live admission at the other rungs (in particular the spilled 32k session's `exec_layers`) is the §7 legs' to file.
- **The int8 counterfactual as a run** — its admission figures are arithmetic over J-088's prices through the f16 session's admission shape; no int8 session exists on either line (INTEGRATION_BLOCKED), and its faithfulness at ladder lengths is J-089 §7's deferred grade.
- **Decode KV-read traffic as measured bytes** — §5.1's write-leg figures are the by-construction touch shape of the tree's attention loops; device caches sit between the shape and any real byte count.
- Janas's published long-context numbers as evidence about Aesir — none are cited as such anywhere in this slice.

## 10. Banking

Filed on branch `yrsa/janas-j091` (worktree `~/workspace/aesir-janas-j091`, base `c50f9d93`): commits — design + accounting + harness first (@ `801483c7`, pre-registered), then this doc, the inspect script and the filed outputs. In the tree: `aesir_engine/core/kv_ladder.mojo` (new) and `aesir_engine/tests/test_kv_ladder.mojo` (8 groups); in `docs/janas/`: `J091_CONTEXT_LADDER.md` (this doc), `j091_ladder.mojo`, `j091_inspect.py`, `j091_inspect_output.txt`, `j091_test_output.txt`. **No existing module was modified.** Campaign copies of the doc + evidence in `~/workspace/model-tests/janas/`, sha-identical (verified by hash). Push by explicit refspec `git push origin <sha>:refs/heads/yrsa/janas-j091`, foreground, with `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`; the commit hashes and ls-remote lines are recorded in the campaign state entry for J-091 and the slice worker's report (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
