# J-055 — Whole-Layer Dense on GPU

**Slice:** J-055 (Part IV — The Accelerator Prompt: GPU and NPU prefill, J-053–J-070), Project Aesir Janas clean-room road.
**Roadmap text:** "Whole-layer dense on GPU. For dense models that fit, every layer of the prompt pass on the GPU, with the bit-agreement discipline Janas documents for Gemma (top-token agreement counts vs the CPU path, published per model)."
**Executed:** 2026-10-31 ~23:0x–23:1x EDT (continuation of the 22:5x dispatch; the first worker left the planning module untracked and untested at 23:03 EDT — this slice inherited it, inspected it in full, and completed the slice around it; §8). Inspection first-hand from this tree; the fit/sync/agreement accounting module unit-tested on the VM's lightest target; **no model inference and no CUDA ran anywhere**.
**Base:** worktree `~/workspace/aesir-janas-j055` on branch `yrsa/janas-j055`, from `yrsa/janas-j054` tip `aa38d643cb4de09e759e48c6e6be0c1ff10bb8e9` (origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`).
**Machine state (VM, stated for every number below):** KVM, 4 vCPU. MemAvailable ~1.4 GB at slice checks — **far below the 5,500 MB inference gate**, so no VM inference and no CUDA run was attempted. purplelongship was **not used at all** — the 204 road is live there and this slice yields under the coordination law. Every live GPU agreement count and every wall this slice's roadmap text calls for is therefore **DEFERRED-WITH-REASON** to the guarded recipe in §7 — never faked, never borrowed. Janas's published agreement counts are restated in §5 **only** as the discipline's documented form and to pin the counting arithmetic; they are Janas's numbers on Janas's machine, never Aesir's.

---

## 1. Verdict

**J-055 closes as an inspection + fit/agreement-accounting slice with its live leg DEFERRED-WITH-REASON** (the J-031/J-053/J-054 closure shape):

- The whole-layer question splits cleanly in two, and the split is this slice's headline (§2–§3): **at width 1, whole-layer dense on GPU already exists and is proven** — the tree's two CUDA sessions run every layer of a token on the device and synchronise once per token, so a width-1 prompt pass through them *is* whole-layer execution; it needs **no item from J-054's M-list**. What does not exist is the whole-layer **block** prompt pass (width > 1), and that is gated exactly by J-054's **M1 + M2 + M5** (M4 sets its launch floor, M6 is the same build for Gemma 4, M7 gates quoting any per-phase wall). **M3 (batched attention) does not gate whole-layer placement** — the attention kernels are already device-resident per row; M3 gates only the long-context ceiling (J-053 finding F2).
- What could honestly be built and proven tonight was built and proven (§4): `core/whole_layer_gpu.mojo` (inherited from the first worker, inspected in full, found complete and sound — §8) — a device-free fit/sync/agreement accounting layer: directory-true weight bytes + full-context KV + scratch + scores + reserve charged against a stated usable device budget, with the verdict (fits with headroom / no-fit with exact shortfall) stated in the plan; the spill partition named in-plan as the no-fit fallback, never reported as whole-layer. **8/8 unit-test groups PASS** on the VM's lightest target, with the J-054 neighbour suite rebuilt from this tree at **9/9 PASS**.
- The bit-agreement discipline is **defined** in §5 (the slice doc's half of the contract; the module keeps only its counting arithmetic): top-token agreement filed as **raw counts beside basis points, per model**, next to — never instead of — the road's teacher-forcing rank + logit gap grading on raw prompts. **No Aesir agreement count exists yet**: the live leg that produces the first one is §7, DEFERRED-WITH-REASON.
- The accounting (§6) lands on the road's filed figures exactly: on the stated 6 GiB card (usable 5,368,709,120 B, J-021), the Stheno 8B file is a whole-layer **no-fit at context 4,096** (shortfall 81,059,840 B on this module's zero-scratch lower bound; the engine's own filed charge refuses by 90,948,644 B — both accounts refuse) and a **fit at 2,048** (headroom 187,375,616 B) — which is precisely why J-021's comparator ran at 2,048.
- No defect was found in the inherited module or the inspected CUDA sessions (§8). J-053's F1 stays with owner J-058; F2's ceiling is carried by §3's M3 placement, not re-litigated here.

No README touched. Hailo untouched/parked. No Docker. The only Janas material engaged is the Part I census summary (J-005) already on file — behaviour only, per the clean-room law.

## 2. Inspection — whole-layer at width 1 already exists (PROVEN from the tree)

All references are this tree's, read first-hand this slice (the CUDA sessions re-read; J-054 §2's inspection stands and is not repeated).

| Piece | Shape, as filed in the code |
|---|---|
| `Llama3CUDASession.forward` (`core/llama3_cuda.mojo:387`) | Every layer of one token on the device — embedding, per-layer projections/norms/RoPE/KV writes, scores/softmax/attention kernels, head — then **one `context.synchronize()` per token**. A prompt pass at width 1 is therefore whole-layer by construction: no layer of any prompt token is ever computed on the CPU. |
| `Gemma4CUDASession.forward` (`core/gemma4_cuda.mojo:207`) | The same shape for Gemma 4: per-token embedding + PLE, per-layer device matvecs, per-token scores/softmax/attention, one synchronisation per token. Width 1 only — no tile, no batch form (J-054 §2). |
| The cost of the width-1 shape | J-053's count: one synchronisation per token, weight re-reads per token — the decode discipline extended over the prompt. Whole-layer *placement* is proven; whole-layer *block efficiency* is J-054's question, not this slice's. |
| The no-fit fallback (`core/dense_residency.mojo`, J-021) | The proven spill partition: front layers pinned GPU-resident, tail on the CPU, token-identity PROVEN on the Stheno file (J-021 §5). It is a **different shape** from whole-layer — a model that spills is not whole-layer, and §4's plan says so in its verdict name (`no_fit_spill_is_the_fallback`) so the two can never be conflated in a later citation. |
| Upload road (`core/cuda_upload.mojo`) | Weights uploaded once at open through 64 MiB synchronised staging and stay device-resident — the property whole-layer depends on; §4 prices the open upload through the same bound. |

## 3. Missing pieces, bound to J-054's M-list exactly

Whole-layer has two widths, and they bind differently — stating this binding is the slice's §3 deliverable:

- **Width 1 (the proven shape): needs NO M item.** It is the existing CUDA sessions' decode shape extended over the prompt. Its live agreement leg (§7, leg A) is runnable with today's sessions and is deferred only by tonight's machine state, not by any build.
- **Block width > 1 (the unbuilt shape): gated by M1 + M2 + M5.** M1 (general-width quantized GEMM) is the kernel the block pass stands on; M2 (batched layout/admission above width 4) gives it buffers; M5 (chunk-level session loop) gives it the host's chunk discipline. **M4** (batched per-row ops) sets the block shape's launch floor — it gates the block leg's *efficiency claim*, not its existence. **M6** is M1+M2+M4+M5 for the Gemma 4 session, a separate build with its own agreement row (§7). **M7** (prefill instrumentation, J-053 F3) gates quoting any per-phase wall for either shape; §7 therefore times from outside.
- **M3 (batched attention) does NOT gate whole-layer placement.** The scores/softmax/attention kernels are already device-resident and run per row inside both sessions today — a whole-layer block pass with per-row attention is still whole-layer (every layer on the GPU), exactly as the width-4 tile already is for projections. M3 gates only how far the block shape scales before its scores memory (J-054 §5: 268,435,456 B at width 256 on the 8B shape) and per-row call counts bind — the long-context ceiling, owned by J-053 F2 / J-068's 8k re-measurement, not by placement.

**What is NOT missing:** the fit decision itself (§4, built); the residency/upload road (§2); the agreement counting (§4–§5); the spill fallback for the no-fit case (J-021, proven).

## 4. What was built (PROVEN, VM, lightest target)

- **`aesir_engine/core/whole_layer_gpu.mojo`** (inherited, inspected in full, kept as sound — §8): `plan_whole_layer_fit(weight_bytes, kv_bytes_per_token, context_tokens, activation_scratch_bytes, scores_bytes, reserve_bytes, device_budget_bytes)` → `WholeLayerFit` stating every charge, the required total, headroom (negative = the exact shortfall), the verdict code + name, and the open-upload staging chunks. The KV charge is for the **full context the session will hold (prompt + generation)** — a fit that only holds until generation starts is not a fit. Plus `whole_layer_max_weights` (the exact inversion: largest weight bytes fitting beside a stated context; zero/negative stated, never clamped), `plan_whole_layer_syncs` (whole-layer vs per-layer-submission crossings at width 1 and block width), `agreement_basis_points` (§5's counting arithmetic — floor, never rounding), and `whole_layer_upload_chunks` restating the 64 MiB staging bound so the module stays device-free (the J-031/J-054 pattern). Garbage refused where detectable across all five entry points. The module executes nothing, creates no CUDA context, and contains no speed; its docstring carries the host contract (directory-true weights, profile KV, session-layout scratch, the sessions' own admission budget — never total VRAM).
- **`aesir_engine/tests/test_whole_layer_gpu.mojo`** (new): **8/8 groups PASS** (build + run output filed as `j055_test_output.txt`): a synthetic fit with exact headroom; the Stheno no-fit/fit pair on J-021's filed figures (§6); max-weights inversion (max fits at headroom 0, max+1 refused, negative allowance stated); sync counts with the ratio **exactly layers** at both widths (incl. Gemma E2B's 35-layer shape and a non-divisible 67/4 chunking); agreement basis points on Janas's filed Gemma counts (§5) incl. the floor-not-rounding pin; staging pricing cross-checked against J-031's filed counts (OLMoE resident 311,027,712 B → 5 chunks, body 3,900,702,720 B → 59 — both reproduced exactly); the full-context KV charge reproducing J-053's Gemma figure at 8,192 (150,994,944 B); and 14 refusals across all entry points. Build recipe: the filed Part III/IV recipe (`pixi run --manifest-path aesir_engine/pixi.toml mojo build`, thread_par shim, staging + TMPDIR on the workspace overlay).
- **Neighbour check:** `tests/test_gpu_block_prefill.mojo` (J-054) rebuilt from this tree: **9/9 PASS**. This slice changes no existing module — the plan module is additive — so no other suite is implicated; registration in `tests/run_all.mojo` is **not** done here, for J-031 §10's stated reason (the branch line's counted-run pin cannot be re-accounted without the counted run, which belongs to the on-box leg in §7).

## 5. The bit-agreement discipline (defined; the counts are §7's to produce)

Janas documents the discipline for Gemma (census J-005, behaviour only): whole-layer GPU execution is evidenced by **most-likely-token agreement** — over a stated token count, at how many positions does the GPU path's top token equal the reference path's top token — **published per model**. Janas's filed form, on 400 tokens per model, GPU vs llama.cpp with the CPU path's own count beside it: **12B GPU 367 / CPU 362; 26B 321 / 321; E2B 386 / 391; E4B 392 / 394**. Those are Janas's numbers on Janas's machine against llama.cpp; they are restated here only as the discipline's documented shape (and, in §4's tests, to pin the counting arithmetic: 367/400 = 9,175 bp, 386/400 = 9,650 bp, etc.). **No Aesir agreement count exists tonight.**

Aesir's discipline, as this road files it (binding on §7's leg and on any later citation):

1. **Per model, counts first.** For each model (sha-pinned file, pin filed with the row): run the whole-layer GPU path and Aesir's CPU path over the same raw prompts (no chat template anywhere), and at every graded position compare the two paths' top-1 tokens. File **agree / total as raw counts**, with `agreement_basis_points(agree, total)` beside them. A basis-point figure without its counts, a count without its total, or a row without its pin is not publishable.
2. **The CPU path is graded too.** Janas's own table shows why: its CPU counts (362–394 of 400) are themselves below perfect — two faithful floating-point paths disagree at some positions by reduction order alone. So each Aesir row files the GPU-vs-CPU agreement **and** the reference comparator row (item 3), and no row may present agreement < total as a defect by itself, nor agreement = total as proof of identity.
3. **Agreement never replaces the raw-oracle grade.** Beside the counts, every model row carries the road's standing grade: **ids first** (greedy generated ids from the GPU whole-layer path must equal the CPU path's token for token, or the row is a defect report, not a number), then **teacher-forcing rank + logit gap against the ggml CPU comparator on the raw prompt** (never `llama-cli --single-turn`; CPU-vs-CPU comparator; near-tie band rank ≤2 with sub-logit gap = faithful; step-0 boundary effects as their own verdict class).
4. **Per-model publication, no lending.** A count earned on Gemma E2B says nothing about E4B, Llama, or any other model; rows are filed per model exactly as Janas files them, and a model with no run has no row — not an borrowed one.

## 6. The accounting (exact arithmetic on stated inputs; no run, no wall)

Stated inputs: purplelongship's 6 GiB card usable budget **5,368,709,120 B** (J-021: the engine's own admission figure on that box; J-031 §5); Stheno `L3-8B-Stheno-v3.2-Q4_K_M.gguf` tensor-byte total **4,912,898,048 B** (J-021 §3; file 4,920,734,240 B, sha256 `8e98c195…fc4`); KV per token **131,072 B** (Llama 3 8B) and **18,432 B** (Gemma 4 E2B) from J-053 §5. Scratch/scores/reserve are stated **0** in the Stheno rows, so the module's required figure is a **lower bound** on the engine's own session charge — the comparison below keeps the two accounts distinct.

| Row | KV charge | Required | vs usable 5,368,709,120 B | Verdict |
|---|---|---|---|---|
| Stheno whole-layer @ ctx 4,096 | 536,870,912 | 5,449,768,960 | headroom **−81,059,840** | **NO-FIT** — spill is the fallback |
| Stheno whole-layer @ ctx 2,048 | 268,435,456 | 5,181,333,504 | headroom **+187,375,616** | **FITS** |
| Max weights beside ctx 2,048 (same shape) | 268,435,456 | — | allowance **5,100,273,664** | Stheno's 4,912,898,048 ≤ allowance ✓ |
| Gemma E2B KV @ full ctx 8,192 | **150,994,944** | — | == J-053's filed KV-written figure exactly | full-context charge ✓ |

- **Cross-check against the engine's own filed charge:** J-021 recorded the whole-GPU session at context 4,096 requiring **5,459,657,764 B** — refused against the same usable budget by **90,948,644 B**. The module's lower bound refuses by 81,059,840 B; the 9,888,804 B difference is the session's own scratch/scores/reserve charges, which the zero-stated row deliberately omits. Both accounts refuse at 4,096 and both fit at 2,048 — the module's verdicts agree with the engine's observed behaviour at both contexts, which is the accounting's validation.
- **Sync counts (the placement claim, counted not timed):** at 32 layers, a 1,024-token prompt costs 1,024 synchronised crossings whole-layer at width 1 (4 at block width 256) against 32,768 (128) for a per-layer-submission shape — a factor of **exactly layers** at either width, pinned by unit test (§4). What that factor is worth in wall time is §7's question; no wall is implied by a count.
- **Open upload:** weights cross once at open through the 64 MiB staging (Stheno's tensor total = 74 chunks by the module's pricing; the J-031 cross-check in §4 pins the pricing function itself against filed counts).

## 7. Deferred — the live agreement + wall leg (DEFERRED-WITH-REASON, exact recipe)

**Why deferred:** VM MemAvailable ~1.4 GB (gate: 5,500 MB) and no CUDA device for this path on the VM; purplelongship yielded to the 204 road, live there tonight — this worker did not use that box at all. The width-1 half of the leg needs **no build** (§3); it is deferred by machine state alone, and the recipe says so.

**Per-shape state tonight:**

| Shape / surface | State | Agreement / wall |
|---|---|---|
| Whole-layer width 1 — Llama 3 CUDA, Gemma 4 CUDA | Executor **exists and is proven** as decode; prompt-pass use is the same `forward` | Agreement counts: **NOT PROVEN** (no graded prompt leg run). Walls: **NOT PROVEN** |
| Whole-layer block (>1) — Llama 3 | Gated by M1+M2+M5 (J-054) | **NOT PROVEN** — no executor exists |
| Whole-layer block (>1) — Gemma 4 | Gated by M6 (J-054) | **NOT PROVEN** — no block form exists |

**Exact recipe** (purplelongship, quiet window, device-capable worker):

1. **Gate checks first:** read the 204 heartbeat (`~/workspace/model-tests/ROADMAP_204_STATE.md`), confirm no live run; record loadavg, Tctl, MemAvailable, GPU idle (VRAM ~1 MiB) at start/end. One heavy run at a time. Fetch `yrsa/janas-j055` on-box; verify tree sha against the banked tip.
2. **Leg A — width-1 agreement (no build required):** models sha-pinned, no substitutions — Stheno L3-8B Q4_K_M (sha256 `8e98c195…fc4`, full pin filed in the leg output) at context 2,048 (the §6 fit; a 4,096 attempt must refuse and the refusal is filed), plus the wave-pinned Gemma 4 E2B file. Prompts: J-053 §7's deterministic raw prompts at exactly 256 / 1,024 tokens, token-id lists filed.
3. **Grading per model (§5's discipline, in order):** ids first — GPU whole-layer greedy ids vs the CPU path's ids on the same file/prompt, token for token; then the agreement count — top-1 agreement of the GPU path vs the CPU path at every prompt+generated position, filed as agree/total + basis points per model; then teacher-forcing rank + logit gap vs the ggml **CPU** comparator on the raw prompt (never `llama-cli --single-turn`; near-tie band and step-0 class per §5.3).
4. **Walls (same leg, labelled separately):** per (model, prompt length): three repetitions, median filed with all raw walls; prefill wall and first-token latency recorded separately (J-053's split); the §4 sync counts must equal the run's observed crossings, or the difference is itself a finding. Cells under loadavg > 2 sustained or Tctl > 85 °C are MEASURED-INDICATIVE and do not close the grade.
5. **Leg B — block whole-layer (only after J-054 §6's build order lands M1→M2→M5, and M6 for Gemma):** repeat legs A.3–A.4 at widths {4, 32, 256}; each width files its own agreement row — a width-1 row never lends to a block width.
6. **Filing:** results in an addendum on the measuring slice's branch, machine state per run; `test_whole_layer_gpu` registration in `tests/run_all.mojo` + counted-run pin re-accounting happens in this leg (J-031 §10 pattern).

## 8. Findings and defects

- **Inherited module: complete and sound — no defect found.** The first J-055 worker's `core/whole_layer_gpu.mojo` (280 lines, left untracked at 23:03 EDT) was read in full this slice: it is not truncated (all five entry points + both structs complete), its header's M-list binding (§3) and host contract match the tree on re-inspection, it compiles clean under the filed pixi recipe, and every arithmetic claim in it is pinned by §4's new tests — including two cross-checks against other slices' filed numbers (J-031's 5/59 staging chunks; J-053's Gemma KV figure) that it reproduces **exactly**. It was kept verbatim; the slice's build work was the test suite, this doc, and the banking the first worker did not reach. Recorded plainly because the inheritance is part of the slice's record: the stall cost the road one keeper tick, no rework.
- **No correctness defect found** in the CUDA sessions or residency code inspected: the width-1 shapes, the engine's whole-GPU refusal at context 4,096, and the spill partition's separation from whole-layer are all deliberate, documented behaviour — and §6 shows the new accounting agreeing with the engine's observed fit/refusal at both contexts.
- **J-053 F1** (MoE head-per-prompt-token) untouched, owner J-058. **J-053 F2** is answered for this slice's question in §3: attention's per-row shape does not gate whole-layer *placement*; its ceiling binds the block shape's scale, owned by J-068. **J-053 F3 / M7** stands, carried to J-059.
- **Registration gap (pre-existing pattern, stated not hidden):** `test_whole_layer_gpu` is not registered in `tests/run_all.mojo`, per J-031 §10's reasoning; registration is a §7 recipe step on-box.

## 9. NOT PROVEN list

- Every Aesir whole-layer agreement count, on every model — no graded prompt leg has run (§7 leg A produces the first).
- Every whole-layer wall / tok/s / first-token latency, at width 1 and at every block width, on every arch.
- Whole-layer block execution in any form (M1/M2/M5 unbuilt; Gemma block = M6 unbuilt).
- That the width-1 whole-layer prompt pass's faithfulness grade equals its proven decode grade on long prompts (the decode proofs stand as filed; the prompt-shaped grade is §7's).
- Any whole-layer fit verdict for a model whose directory-true bytes have not been pinned — §6 grades only the Stheno file's filed figures and stated synthetic shapes.
- Any NPU whole-layer quantity (Hailo parked; J-061/J-062 own the design and gate brief — Janas's NPU whole placement is a different device road and lends nothing here).

## 10. Banking

Filed on branch `yrsa/janas-j055` (worktree `~/workspace/aesir-janas-j055`, base `aa38d643`): `docs/janas/J055_WHOLE_LAYER_GPU.md` (this doc), `docs/janas/j055_test_output.txt`; in the tree: `aesir_engine/core/whole_layer_gpu.mojo` (inherited, banked as inspected) and `aesir_engine/tests/test_whole_layer_gpu.mojo` (8 groups). Campaign copies of the doc + evidence in `~/workspace/model-tests/janas/`, sha-identical. Push by explicit refspec, foreground, with `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6`; the commit hash and ls-remote lines are recorded in the campaign state entry for J-055 and the slice worker's report (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
