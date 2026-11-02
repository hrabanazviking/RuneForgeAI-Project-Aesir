# J-054 — GPU Block Prefill

**Slice:** J-054 (Part IV — The Accelerator Prompt: GPU and NPU prefill, J-053–J-070), Project Aesir Janas clean-room road.
**Roadmap text:** "GPU block prefill. Prompt blocks executed on the GPU as batch GEMM work (extending Aesir's proven GPU path from decode-shaped to prefill-shaped), CPU keeping what it does better; faithfulness graded per arch."
**Executed:** 2026-10-31 ~22:45–22:5x EDT. Inspection first-hand from this tree; the block-plan module built and unit-tested on the VM's lightest target; **no model inference and no CUDA ran anywhere**.
**Base:** fresh worktree `~/workspace/aesir-janas-j054` on branch `yrsa/janas-j054`, from `yrsa/janas-j053` tip `47a2bad9b3cbdaf768b92a8aec4df8b4a0f91a93` (verified by `git ls-remote` at slice start; origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`).
**Machine state (VM, stated for every number below):** KVM, 4 vCPU. MemAvailable ~0.72–1.0 GB at every check — **far below the 5,500 MB inference gate**, so no VM inference and no CUDA run was attempted. purplelongship was **not used at all** — the 204 road's S-103 is live there and this slice yields under the coordination law. Every wall and every per-arch faithfulness grade this slice's roadmap text calls for is therefore **DEFERRED-WITH-REASON** to the guarded recipe in §6 — never faked, never borrowed.

---

## 1. Verdict

**J-054 closes as an inspection + block-plan slice** (the J-031/J-053 closure shape):

- The proven GPU path was inspected first-hand (§2): it is **decode-shaped everywhere**. What exists is a width-1 matvec session per arch plus one width-4 projection tile on one profile. The pieces a prefill-shaped (multi-row batched) GPU block execution requires that **do not exist yet are named exactly in §3 (M1–M7)** — the slice's primary deliverable, in J-031's manner.
- What could honestly be built and proven tonight was built (§4): `core/gpu_block_prefill.mojo`, a device-free block-plan/accounting module in the Part III/IV host-contract style — which chunks of a prompt go to the GPU as batch GEMM work, which work stays per-row or on the CPU, exact weight-traffic / activation / scores byte accounting through the existing 64 MiB staging bound, and synchronisation-crossing counts per chunk shape — **9/9 unit-test groups PASS** on the VM's lightest target, with the J-053 neighbour suite rebuilt from this tree at **8/8 PASS**. Admission is stated inside every plan: widths 1 and 4 are the proven shapes; **every width above 4 is marked UNBUILT in the plan itself**, so no later code can quote a plan as an executable claim.
- The plan prices J-053's ceiling honestly (§5): batching the projections cuts weight re-reads by exactly the chunk width and synchronisations from one-per-token to one-per-chunk, but **attention kernel calls stay per-row and dominate the call count at every baseline length** (F2) — at 8,192 tokens, 786,432 per-row attention calls against 7,168 batched GEMM calls on the Llama 3 8B shape. A block-prefill wall win, if it comes, comes from weight traffic and sync counts, not from attention, until M3 is built.
- **Faithfulness graded per arch: NOT PROVEN for every arch at every block width above the proven shapes** (§6, per-arch table). No GPU number is claimed anywhere in this doc.
- No correctness defect was found in the GPU/decode/prefill code inspected (§7). J-053's F1 (MoE head-per-prompt-token) stays with its owner J-058 and was not absorbed here.

No README touched. Hailo untouched/parked. No Docker. No Janas material was consulted — this slice is Aesir-internal (clean-room law unengaged).

## 2. Inspection — how the proven GPU decode path is shaped (PROVEN from the tree)

All references are this tree's, read first-hand this slice.

| Piece | Shape, as filed in the code |
|---|---|
| `Llama3CUDASession.forward` (`core/llama3_cuda.mojo:387`) | One token: embedding kernel, `run_layer` per layer, optional head+sampler, then **one `context.synchronize()` per token, with or without logits**. Cross-once-per-token is the decode discipline — and the prefill cost J-053 §3.8 counted. |
| `Llama3CUDASession.prefill_four` (`:435`) + `project_four` (`:422`) | The only batched GPU form in the tree. Per layer: norms per token, then **projections batched across the tile** via `four_matvec_kernel` (kinds 12/13/14, columns divisible by 256, else a per-token fallback loop), biases per token, then **RoPE, KV-cache write, scores, softmax and attention all per token inside the tile** (the code's own comment: "Only this token's causal positions are read even inside a tile"), SiLU per token, down-projection batched. **One synchronisation per tile.** |
| Tile admission (`core/dense_buffers.mojo`, `effective_prefill_batch`) | Batch must be 0/1/4; **4 is admitted only for the exercised Llama 3.2 3B profile** (llama, hidden 3072, 28 layers) and refused by name for every other profile. `DenseBufferLayout` sizes scratch as `stride × batch`, with **one shared scores buffer** (`heads × context` f32) and shared logits — a layout built for tiles whose attention is sequential, not for simultaneous rows. |
| `Gemma4CUDASession.forward` (`core/gemma4_cuda.mojo:207`) | Width 1 only: per-token embedding + per-layer-input (PLE) embedding/projection, per-layer matvecs, per-token scores/softmax/attention, one synchronisation per token. **No tile, no batch form, no batched layout exists on this surface.** |
| Quantized kernels (`core/packed_projection.mojo`) | `block_matvec_kernel[kind]` (width 1) and `four_matvec_kernel[kind]` (width 4), kinds 12 (Q4_K) / 13 (Q5_K) / 14 (Q6_K), block bytes 144/176/210, columns divisible by 256, warp reduction in the scalar reference's order. **No kernel takes a general row count M.** |
| F16 GEMM executor (`core/cuda_compute.mojo`, inventoried in J-031 §2) | `CUDAF16GemmExecutor` is a true GEMM shape — and **refuses quantized tensors by contract** ("must be plain F16"), uploading/downloading through per-element host loops. It is not a GEMM road for GGUF K-quant weights as it stands. |
| Upload staging (`core/cuda_upload.mojo`) | `upload_cuda_bytes[_at]`: bounded pinned staging, `MAX_UPLOAD_STAGING_BYTES` = 67,108,864 (64 MiB), **one device synchronisation per chunk**. In the proven sessions weights are uploaded **once at open and stay device-resident**, so decode and tile prefill pay no per-token weight transfer — the property block prefill must preserve. |
| Host batched prefill (J-053 §2) | The CPU already chunks at `AESIR_PREFILL_BATCH` (default 256): pure-prefill chunks return before the LM head; the head is paid once. **The GPU has no analogue of this chunk discipline at any width above 4.** |

## 3. The missing pieces, named exactly (the build list for the live leg)

In dependency order, as J-031 named MoE's:

- **M1 — A general-width quantized GEMM kernel.** A `block_gemm_kernel[kind]` taking M rows (M = chunk width) over device-resident K-quant bytes, reduction order bit-matching the scalar reference per row (the matvec kernels' own discipline), for kinds 12/13/14 at columns divisible by 256. Widths 1 and 4 must fall out of it bit-identically to `block_matvec_kernel` / `four_matvec_kernel`, or the width-1/4 proofs do not transfer. *This is the slice's namesake build; everything below stands on it.*
- **M2 — A batched buffer layout above width 4.** `DenseBufferLayout` with batch = chunk width (activation scratch = width × stride, priced in §5), plus admission widening in `effective_prefill_batch` — today widths other than 0/1/4 are refused and 4 is one-profile-only. Gemma 4 needs the equivalent layout from nothing (its session's buffers are single-token X/N/Q/… slots, and its PLE state is per-token per-layer).
- **M3 — Batched attention (J-053 finding F2, owned here).** A scores/softmax/attention form that takes M query rows at once with per-row causal bounds. The sizing fact is already priced (§5): simultaneous rows need width × heads × context f32 scores (256 MiB at width 256 on the 8B shape at context 8,192) against today's single shared heads × context buffer — so M3 is a kernel + a memory decision (tiled/flash-style scores or a capped width), not a loop change. Until M3 lands, §5's per-row counts are the honest ceiling for any block-prefill wall.
- **M4 — Batched per-row ops.** Inside today's tile, norms, RoPE, KV-cache writes, biases and SiLU still launch per token. At chunk widths these launches (not their arithmetic) become the floor; each needs a row-batched form or a fused form, graded per op.
- **M5 — A chunk-level session loop.** The GPU analogue of the host's `_run_generation` chunk discipline: iterate chunks, pure-prefill chunks return before the head, the final chunk pays the head once, one synchronisation per chunk, interrupted-prefill reset rules matching the sessions' existing contracts, prefix-reuse interplay (Llama 3 CUDA's `begin_turn` reuse branch) stated. No such loop exists on either CUDA session.
- **M6 — Gemma 4 block form entire.** M1+M2+M4+M5 for the Gemma 4 session, plus its PLE projections batched per chunk (J-053 §9 already excludes PLE from the dense MAC rows as an uncounted real cost). There is no partial Gemma block path to extend; it is a build, and its faithfulness grade (§6) is a separate row, not a rider on Llama's.
- **M7 — Prefill instrumentation (J-053 finding F3, carried).** No in-engine per-chunk/per-phase timers exist on the host or GPU paths; §6's recipe therefore times from outside. J-059 owns the watching surface; until then no per-phase wall split may be quoted for block prefill either.

**What is NOT missing:** weights residency and its upload road (open-time, 64 MiB staging, §2); the per-row attention kernels themselves (correct, proven, and reused by M3's grading as the comparator shape); the host chunk discipline to mirror (J-053); the accounting (§4).

## 4. What was built (PROVEN, VM, lightest target)

- **`aesir_engine/core/gpu_block_prefill.mojo`** (new): `plan_gpu_block_prefill(prompt_tokens, chunk_width, layers, weight_bytes, stride_elements, heads, context_capacity)` → `GpuBlockPlan` stating: chunks / pure-prefill chunks / final chunk width, LM-head passes (1 — the host discipline), sync crossings (chunks), batched GEMM calls (chunks × layers × 7 projections), per-row attention kernel calls (tokens × layers × 3 — F2 counted, not hidden), weight-read bytes at the chunk width vs at width 1, activation scratch bytes (width × stride × f32), the scores bytes a truly batched attention would need (width × heads × context × f32), and the **admission code** (width 1 proven / width 4 tile-proven / anything else UNBUILT). Plus `gpu_block_upload_chunks`, restating the 64 MiB staging bound so the module stays device-free (the J-031 pattern). Garbage refused where detectable: non-positive shapes, chunk width 0, and **a prompt longer than the stated context capacity** (mirroring the sessions' own fit refusals). The module executes nothing, creates no CUDA context, and contains no speed; its docstring carries the host contract and the CPU-keeps/GPU-takes division.
- **`aesir_engine/tests/test_gpu_block_prefill.mojo`** (new): **9/9 groups PASS** (build + run output filed as `j054_test_output.txt`): baseline chunk plans at 256/1,024/4,096/8,192; width-1 identity with the proven decode shape; the width-4 block shape; the weight-traffic pass-count effect; the F2 call counts; scratch + scores sizing; staging pricing cross-checked against J-031's filed counts (OLMoE resident 311,027,712 B → 5 chunks, body 3,900,702,720 B → 59 — both reproduced exactly); admission codes; refusals. Build recipe: the filed Part III/IV recipe (`pixi run --manifest-path aesir_engine/pixi.toml mojo build`, thread_par shim, staging + TMPDIR on the workspace overlay) — used from the start, per J-052's lesson that the direct mojo binary fails without pixi activation.
- **Neighbour check:** `tests/test_prefill_anatomy.mojo` (J-053) rebuilt from this tree: **8/8 PASS**. This slice changes no existing module — the plan module is additive — so no other suite is implicated; registration in `tests/run_all.mojo` is **not** done here, for J-031 §10's stated reason (the branch line's counted-run pin cannot be re-accounted without the counted run, which belongs to the on-box leg in §6).

**The CPU-keeps / GPU-takes division the plan encodes** (the roadmap text's "CPU keeping what it does better", made exact): CPU keeps tokenisation + admission, the chunk loop, sampling, and — until M3/M4 exist — the per-row ops' *launch discipline* is GPU-side but per-row in shape, which the plan counts rather than hides. GPU takes, per chunk, the seven projections per layer as batch GEMM work over weights that stay device-resident (zero per-chunk weight transfer; the open upload is priced once by `gpu_block_upload_chunks`).

## 5. The accounting (exact arithmetic on stated inputs; no run, no wall)

Stated inputs: Llama 3 8B profile shape (32 layers, 32 heads, context 8,192, `DenseBufferLayout` stride 51,200 f32 elements by `dense_buffers.mojo`'s layout arithmetic); weight bytes are a **stated synthetic 1,000,000 B** in the unit tests so the pass-count arithmetic is checked without inventing a file size — the ratios are width arithmetic and hold for any directory-true weight figure a caller supplies.

| Prompt | Width-256 chunks (syncs) | Batched GEMM calls | Per-row attention calls (F2) | Weight reads vs width-1 |
|---|---|---|---|---|
| 256 | 1 | 224 | 24,576 | 1× vs 256× |
| 1,024 | 4 | 896 | 98,304 | 4× vs 1,024× |
| 4,096 | 16 | 3,584 | 393,216 | 16× vs 4,096× |
| 8,192 | 32 | 7,168 | 786,432 | 32× vs 8,192× |

- **Weight traffic scales with chunks, not tokens** — at width 256 the saving factor over the decode shape is exactly 256, the same mechanism as the host's one measured chunk effect (J-053 §6, S-033: 7 passes → 1, walls −9–14 %, ids bit-identical; class MEASURED-INDICATIVE, prior road). Whether the GPU effect matches the host's is a wall question — **NOT PROVEN**.
- **Scratch sizing at width 256 (8B shape):** activation scratch 52,428,800 B per chunk (256 × 51,200 × 4) — affordable; **batched-attention scores would need 268,435,456 B** (256 × 32 × 8,192 × 4) against today's single shared 1,048,576 B scores buffer — the concrete reason M3 is a design decision, and why this plan caps its honest claim at the projections.
- **Tile-shape nuance (recorded, not a defect):** the block plan at width 4 chunks ⌈N/4⌉ (256 → 64; 67 → 17, final width 3), while the proven tile loop files 67 passes at 256 and 19 at 67 (J-053 §5) because it reserves the prompt's last tokens to width-1 singles that carry the head discipline. The delta is the final-chunk convention — M5's loop adopts the host convention (final chunk carries the head), and the difference is stated here so the two counts are never conflated.

## 6. Deferred — per-arch faithfulness grading + every GPU wall (DEFERRED-WITH-REASON, exact recipe)

**Why deferred:** VM MemAvailable ~0.72–1.0 GB (gate: 5,500 MB) and no CUDA device for this path on the VM; purplelongship yielded to the 204 road's live S-103 — this worker did not use that box at all. No honest light path exists tonight: a kernel that cannot run cannot be graded, and compiling M1 without a device proves syntax, not faithfulness.

**Per-arch state tonight (the grading table's honest fill):**

| Arch / surface | Block width available | Faithfulness grade |
|---|---|---|
| Llama 3 8B (CUDA) | 1 (proven decode shape) | Block (>1): **NOT PROVEN** — no kernel exists (M1) |
| Llama 3.2 3B (CUDA) | 1, and 4 for projections only (proven tile) | Width-4 tile: prior proofs stand as filed in the 204 record; **this road has graded no new leg**. Width >4: **NOT PROVEN** |
| Gemma 4 E2B / E4B (CUDA) | 1 only | Block (>1): **NOT PROVEN** — no block form exists (M6) |
| Host archs (llama/qwen/gemma2-class/granite/qwen3.5 twins) | host chunks to 256 (CPU) | GPU block: **NOT PROVEN** — no GPU session admits them; out of this slice's executor scope, named so the row is not silently absent |
| OLMoE (MoE) | — | Owned by J-058 (binds J-053 F1); not graded here |

**Exact recipe for the measuring leg** (purplelongship, quiet window, device-capable worker):

1. **Gate checks first:** read the 204 heartbeat (`~/workspace/model-tests/ROADMAP_204_STATE.md`), confirm no live run; record loadavg, Tctl, MemAvailable, GPU idle (VRAM ~1 MiB) at start/end. One heavy run at a time. Fetch `yrsa/janas-j054` on-box; verify tree sha against the banked tip.
2. **Build in dependency order:** M1 (general-width quantized GEMM, widths 1/4 proven bit-identical against the existing kernels on identical inputs before any session runs) → M2 (layout + admission) → M5 (chunk loop) → M4 (batched per-row ops, as needed) → M6 (Gemma, separately). M3 (batched attention) is attempted only with its scores-memory decision stated in advance; a leg without M3 is graded as a projections-only block leg and labelled as such.
3. **Models (sha-pinned, no substitutions):** the wave-pinned Llama 3.2 3B and Llama 3 8B files and the Gemma 4 E2B file from the laptop store; record each file's full sha256 in the leg output before running — a wall without its pin is not a cell.
4. **Prompt shapes:** J-053 §7's — deterministic prompts of exactly 256 / 1,024 / 4,096 tokens (8,192 where the surface's fit check admits it; Llama CUDA at 8,192 stays REFUSED-BY-CONTEXT per J-053), token-id lists filed, raw prompts only (no chat template on graded legs).
5. **Runs:** per (arch, width ∈ {1, 4, 32, 256}): three repetitions, median filed with all raw walls; per cell record prefill wall (tokenize→last prompt position filled), first-token latency separately (J-053's split), and the plan's by-construction columns from `core/gpu_block_prefill.mojo` — which must equal the run's observed chunk/sync/head counts, or the difference is itself a finding.
6. **Grading (raw-oracle discipline, per arch):** ids first — block-prefill generated ids must equal the same surface's width-1 ids token for token, or the cell is a defect report, not a number. Then teacher-forcing rank + logit gap against the ggml **CPU** comparator on the raw prompt (never `llama-cli --single-turn`; CPU-vs-CPU comparator; near-tie band rank ≤2 with sub-logit gap = faithful; step-0 boundary effects as their own verdict class). Each arch files its own row; no arch's grade lends to another.
7. **Filing:** results in an addendum on the measuring slice's branch, machine state per run; cells under loadavg > 2 sustained or Tctl > 85 °C are MEASURED-INDICATIVE and do not close the grade.

## 7. Findings and defects

- **No correctness defect found** in the GPU, decode, or prefill code inspected this slice: the tile's admission restriction, the width-1 Gemma shape, the per-token synchronisation, and the F16 executor's quantized-tensor refusal are all deliberate, documented contract behaviour. The §3 items are **absences** (the build list), recorded with owners — M1/M2/M5 this slice's leg (§6), M3 owned here as J-053 F2's named question and answered with the §5 counts (the answer: projections-only block prefill cannot win on attention, and its call-count ceiling is now exact), M4/M6 §6, M7/F3 carried to J-059.
- **J-053 F1 is untouched by design** (MoE head-per-token; owner J-058). **J-053 F2 is this slice's to answer** and is answered by construction in §5: attention does not batch, the counts are pinned by unit test, and M3 is specified with its memory price. **J-053 F3** (no prefill instrumentation) stands, carried as M7.
- **Registration gap (pre-existing pattern, stated not hidden):** `test_gpu_block_prefill` is not registered in `tests/run_all.mojo`, per J-031 §10's reasoning; registration + counted-run pin re-accounting is a §6 recipe step on-box.

## 8. NOT PROVEN list

- Every GPU block-prefill wall / tok/s / first-token latency, at every width above 1, on every arch.
- Faithfulness of any block width above the proven shapes, per arch (§6 table) — including whether M1's future kernel is bit-identical at widths 1/4 (a build-time gate in the recipe, not a fact tonight).
- That the host's measured chunk effect (S-033) reproduces on the GPU path at any size.
- Batched attention in any form (M3): its design, its memory shape, and its numerics.
- Gemma 4 block prefill in any form (M6); Qwen3.5's sequential DeltaNet rows under any GPU block form (its recurrence does not shrink with width, J-053 §5 — a block leg for that family must report the SSM share separately or not be quoted).
- Any NPU prefill quantity (Hailo parked; J-061/J-062 own the design and gate brief).

## 9. Banking

Filed on branch `yrsa/janas-j054` (worktree `~/workspace/aesir-janas-j054`, base `47a2bad9`): `docs/janas/J054_GPU_BLOCK_PREFILL.md` (this doc), `docs/janas/j054_test_output.txt`; in the tree: `aesir_engine/core/gpu_block_prefill.mojo` (new) and `aesir_engine/tests/test_gpu_block_prefill.mojo` (9 groups). Campaign copies of the doc + evidence in `~/workspace/model-tests/janas/`, sha-identical. Push by explicit refspec, foreground, with `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6`; the commit hash and ls-remote lines are recorded in the campaign state entry for J-054 and the slice worker's report (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
