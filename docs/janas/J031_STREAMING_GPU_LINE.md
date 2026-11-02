# J-031 — Expert Streaming, GPU-Assisted

**Slice:** J-031 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "Expert streaming, GPU-assisted. Resident set on GPU, streamed experts computed where they land; the division measured against the CPU line (J-030)."
**Executed:** 2026-10-31 ~12:08–12:5x EDT. **Closure shape: CLOSED-WITH-DEFERRED-LEG — the division is designed in Aesir's terms, the planning/accounting layer is built and unit-tested on the VM's lightest target, and the live GPU leg is DEFERRED-WITH-REASON to the J-034 gate with the exact recipe in §9.** §6 states the blockers plainly. No GPU run happened this slice, no GPU number is claimed, and nothing below quotes a wall this slice did not measure.
**Base:** branch `yrsa/janas-j031` from `yrsa/janas-j030` tip `622959549e089651b6e6eee9c9aed87d9521a41a` (ls-remote verified before branching). Origin/main `ba7ee09b6b4d09967b571f2f39714e9119dc3772` untouched by this slice.
**No Janas material was used or needed** — this slice stands entirely on Aesir's own code (the MoE streaming stack and the dense CUDA line) and the J-015/J-017/J-021/J-030 records. Hailo untouched/parked. No README touched. No Docker. Nothing deleted to free disk (/tmp was 100 % full at slice start, pre-existing; scratch and TMPDIR went to the workspace overlay under `~/workspace/.verify-tmp/j031`).

**Headline: the GPU division is now an exact byte-level plan, and its first finding is that OLMoE does not need it — it fits.** Aesir's streamed MoE session is still CPU-only by construction (§1, re-verified first-hand this slice), and every CUDA session in the tree is a dense-profile session that admits no MoE architecture (§2). What this slice builds is the layer the live leg must stand on: `core/moe_gpu_plan.mojo`, a device-free planning/accounting module that divides an MoE model between host and GPU from directory-true sizes and a stated usable device budget — resident set to the device first, then KV/activation/reserve, the remainder as a whole-expert device cache under the J-018 byte discipline — and accounts each token's host↔device traffic exactly per division. On the road's stated machine (OLMoE's measured sizes; purplelongship's usable device budget 5,368,709,120 B from J-021) the plan's verdict is **FULL_GPU**: resident (311,027,712 B) + allowances (352,321,536 B) + the whole expert body (3,900,702,720 B) = 4,564,051,968 B, leaving 804,657,152 B of headroom — for this model the streamed-GPU question degenerates to whole-model residency, exactly the degenerate case J-017 §4.3 names. The division that matters is the expert-cache division, and it belongs to the bigger-than-device class (J-032's target), where the accounting shows the honest price: **a device-cache miss re-pays the streamed bytes as an upload** — at the CPU line's measured 362,073,616.9 B/token (J-030 §4), GPU assistance does not shrink the byte traffic, it doubles the legs it travels (disk→host, host→device) unless the device cache's own hit rate spares it. Whether any division beats the CPU line's wall (idle 0.4113 s/token) is **NOT PROVEN** — §9 files the exact guarded recipe that measures it at J-034.

---

## 1. Inspection I — the MoE streaming stack has no GPU path (re-verified first-hand)

Inspected this slice in the J-031 tree (J-030 tip + this slice's commits):

- **`aesir_engine/core/moe_session.mojo`** (the streamed session): its docstring states the maths — "attention, norms, and GEMMs are the engine's existing **host primitives**, the same ones the dense TransformerBlock uses." The resident set is read through the `GGUFSeer` mmap; routed experts are served only through `ExpertCache` (host `List[UInt8]` payloads) + `StreamReader` (explicit pread). A text search of the module finds no occurrence of `cuda`, `gpu`, `vulkan`, or `device`. Its GEMM is `core/compute.mojo`'s `gemm_f16`, whose own docstring states: "This function does not execute CUDA, Tensor Core, or MMA instructions."
- **`core/expert_cache.mojo`** and **`core/stream_reader.mojo`**: likewise no CUDA/GPU reference — host memory bookkeeping and `pread` + `posix_fadvise` (J-030 §1, confirmed unchanged in this tree).
- **The vehicle** `aesir_engine/tests/test_olmoe_stream.mojo` takes no device argument, and both run scripts export `CUDA_VISIBLE_DEVICES=` (J-030 §1). J-022 recorded GPU idle at 1 MiB during its runs.

**Conclusion of §1 (PROVEN from the tree):** there is no GPU path in the MoE stack to switch on, tune, or measure. J-031 is a build-the-division slice, not a flip-a-flag slice — which is why its honest deliverable is the planning layer plus a deferred execution leg, and why §2 inventories what a build can reuse.

## 2. Inspection II — Aesir's existing GPU machinery, and what it can and cannot do for MoE

The tree's proven GPU machinery is real and substantial — and it is all dense-shaped:

| Machinery | What it is | MoE verdict |
|---|---|---|
| `core/llama3_cuda.mojo` — `Llama3CUDASession` | Persistent CUDA session for admitted **dense GQA** profiles (`PackedGGUF` + `DenseGQAProfile` admission). Whole file (or a compacted front, for spill) uploaded once into one `DeviceBuffer[uint8]` via `core/cuda_upload.mojo`; activations in a float32 device buffer; KV in an f16 device buffer; per-layer matvec + norm + rope + tiled attention + silu kernels; device-side sampler. | **Shape reusable, session not.** Admission is dense-GQA-only; there is no MoE profile, no router, no expert dimension anywhere in it. |
| `core/gemma4_cuda.mojo` | Same pattern for admitted dense Gemma 4 profiles. | Same verdict. |
| `core/packed_projection.mojo` — `block_matvec_kernel[12/13/14]`, `four_matvec_kernel` | Warp-per-row quantized matvec over device-resident bytes for GGML kinds 12 (Q4_K), 13 (Q5_K), 14 (Q6_K), columns divisible by 256, reduction order matching the scalar reference. | **The expert kernels exist.** OLMoE's slabs are gate/up Q4_K (kind 12) and down Q4_K/Q6_K by layer (kinds 12/14), at shapes gate/up [1024 rows × 2048 cols], down [2048 × 1024] — columns divisible by 256 in both. An expert's three projections are exactly three calls of this shape *if* the slabs are device-resident at known offsets. |
| `core/gemma4_kernels.mojo` — `matvec_kernel`, `packed_matvec_kernel`, `norm_kernel`, `argmax_kernel`, embedding | Generic-kind matvec, RMSNorm, argmax over device buffers. | Reusable shapes for router/head/argmax duties; unproven at OLMoE's exact shapes. |
| `core/cuda_upload.mojo` — `upload_cuda_bytes[_at]` | Bounded pinned staging: 64 MiB staging buffer (`MAX_UPLOAD_STAGING_BYTES` = 67,108,864), one device synchronisation per chunk, destination sub-buffer copies. | **The upload road exists** — priced by §5. It is a whole-file-at-open road today; per-miss slab uploads through it are the live leg's build (§9), with the per-chunk synchronisation as the named cost. |
| `core/cuda_compute.mojo` — `CUDAF16GemmExecutor` | Generic F16 GEMM executor. | **Not reusable for experts:** it refuses quantized tensors by contract ("must be plain F16") and uploads/downloads through per-element host loops. OLMoE's slabs are K-quants; the dense line's quantized matvec (above) is the road, not this executor. |
| `core/llama3_spill.mojo` + `core/dense_residency.mojo` (J-021) | Proven split execution: front layers device-resident, CPU tail, hidden state crossing **once per token**; the split stated through the residency plan. | **The crossing discipline to copy:** a division that crosses the hidden vector once per token (or never) is viable; one that crosses per layer is priced in §5 and rejected as the default shape. |
| `core/dense_residency.mojo` / `core/expert_cache.mojo` plans | Byte-exact residency planning (device budget → front prefix; free memory → cache budget) with statistics in one vocabulary. | **The pattern `moe_gpu_plan.mojo` extends** to the MoE division (§3–§4). |

**What does not exist (the live leg's build list, named exactly):**

1. **No MoE device admission.** `dense_gqa_profile_for` / `gemma4_profile_for` admit only their dense families; `olmoe` is admitted by no CUDA session. The MoE session's loader is `GGUFSeer`; the CUDA sessions' is `PackedGGUF` — two loader worlds with no bridge for MoE tensors.
2. **No device expert cache.** `ExpertCache` payloads are host buffers owned by `moe_session.mojo`'s `payloads` dict. There is no device-side payload store, no upload-on-miss path, and no device residency accounting for experts.
3. **No OLMoE block maths on device.** Router GEMM (F32 router, [64 × 2048]), top-k selection, softmax, full-width Q/K RMSNorm (OLMoE's norm vectors are hidden-wide — the dense path's per-head-dim Q/K norm is a different application of a similar kernel), NeoX RoPE (the dense rope kernel carries a neox flag — shape-plausible, unproven at 16 heads × 128), MHA attention at 16/16 heads, and the expert accumulation loop have no device implementation. Each is kernel-shaped work over existing patterns; none is a flag.
4. **No per-miss upload batching.** The session's per-layer `advise_willneed` batching (J-019 discipline) has no device-side analogue yet; uploading slab-by-slab through the 64 MiB staging would pay one synchronisation per slab chunk — at the CPU line's ≈95 misses/token (§5) that is ≈285 synchronisations/token before batching, a cost the design (§3) removes by batching each layer's miss set into one staged upload.

## 3. The division, designed in Aesir's terms

`plan_moe_gpu_division` (built, §4) divides by budget, in this order — the accelerator-first law's order, applied to residency:

1. **Resident set to the device first** (J-017 D1/D7, §2.4's named candidate): embeddings (+ untied head), attention, norms, routers, shared experts where present — directory-true bytes, never counted against any expert budget.
2. **Allowances charged next, and stated:** the KV allowance for the configured context, an activation allowance, and a device reserve (the dense CUDA session's own default reserve is 268,435,456 B).
3. **The remainder is the device expert cache budget**, spent on whole experts only (J-017's atomic unit): a remainder smaller than the largest pair buys **no** device cache — partial experts compute nothing.
4. **If resident + allowances exceed the usable device budget, the plan is the CPU line** — stated in the plan itself, allocating nothing. A GPU division that cannot hold its resident set is not a division.

The four divisions and their execution shapes:

| Division | Resident | Experts | Layer stack | Per-token crossings |
|---|---|---|---|---|
| `CPU_ONLY` | host | host cache, host compute (the J-030 line) | host | 0 |
| `RESIDENT_GPU` | device | host cache, host compute | **split per layer** | 2 × layers hidden crossings |
| `RESIDENT_GPU_EXPERT_CACHE` | device | device cache; miss → staged upload → compute where it lands | device | 1 + miss-layers upload batches |
| `FULL_GPU` | device | whole body device-resident | device | 1 |

Two design decisions, recorded with their reasons:

- **`RESIDENT_GPU` is designed in order to be priced, not to be built first.** Splitting the stack per layer (attention/router on device, expert FFN on host) is the naive reading of "resident set on GPU", and §5 prices it at 32 hidden crossings/token for OLMoE. The spill line's proven discipline — cross once per token or never — rejects it as the default shape; it survives in the plan because a future placement engine (Part III) should see its cost stated, not discover it.
- **One cache, device-resident — not two caches.** Under the expert-cache division the `ExpertCache` accounting stays exactly as built (host-side metadata, the fsketch policy, byte budget), and the payloads land on the device instead of in host buffers. A second, independent host cache for the same experts would double-pay RAM for bytes the device already holds and make the two caches' statistics incomparable with the J-016 vocabulary. Bypassed experts (policy refusal) stream disk→host scratch→upload→compute→discard: they pay the upload without earning residency, which is the honest price of computing where they land, and it is counted in the token's transfer account like any other miss.

**Faithfulness grading (binding on the live leg):** first gate — generated ids equal the CPU line's ids token for token (the J-030 §5 set: `187, 187, 510, 1708, 5967, 6225, 327, 247, 33848, 562, 68, 1658, 13, 253, 760, 581, 323, 6574, 1475, 15, 733, 369, 247, 10086`, the ids J-022 §7.3 proved faithful). Second gate — teacher-forcing rank + logit gap against the ggml CPU comparator on the raw prompt, near-tie band rank ≤2 with sub-logit gap = faithful; comparator artifacts are a verdict class, checked before the engine is suspected. Any id divergence is a defect to bisect (J-022's bisection precedent), never a number to file quietly. Threading/batch variation on device must be bit-stable by the same argument `par_for` gives the CPU line: the kernels' reduction order is fixed per shape (the block matvec's warp reduction is the scalar reference's order, per its own docstring).

## 4. What was built (PROVEN, VM, lightest target)

- **`aesir_engine/core/moe_gpu_plan.mojo`** (new): the division planner (`plan_moe_gpu_division` → `MoeGpuPlan` with `division`, device resident/expert budgets, mean-derived pair capacity labelled indicative, `device_total_bytes()`), the per-token transfer accountant (`plan_moe_gpu_token_transfers` → `MoeGpuTokenTransfers`: expert/hidden/token bytes per direction + synchronised crossings; disagreeing miss facts refused, per-token expert traffic under FULL refused), and the open-upload pricer (`moe_gpu_upload_chunks`, restating `cuda_upload`'s 64 MiB staging bound so the module stays device-free). Pure arithmetic: no device calls, no OS calls, nothing faked. The module docstring carries the host contract (directory-true inputs, usable-budget sampling, statistics-sourced token facts, the grading discipline).
- **`aesir_engine/tests/test_moe_gpu_plan.mojo`** (new): **7/7 groups PASS** on the VM's lightest target (Mojo 1.0.0 via the tree's pixi environment; binary built with `-I aesir_engine`, run directly): full-residency derivation on the stated card, device-cache derivation + the largest-pair boundary (remainder == largest pair ⇒ cache division with 1 pair; one byte less ⇒ resident-only with 0), resident-only remainder reporting, CPU-only refusal stated in the plan, per-token transfer accounting per division (including the cold-token identity upload == streamed, §5), staging-chunk pricing, and input refusals. All model numbers in the tests are the J-015/J-017/J-021 record restated (§5's table), so the arithmetic is checked against the road's own measurements.
- **`aesir_engine/core/moe_session.mojo`**: docstring-only addition of the J-031 host contract (the session still computes on the host; the plan module, grading discipline, and this doc's recipe are named; no GPU claim may be made from the module until the live leg lands). Verified: the module compiles through its full import graph on the VM (the build's only terminal error is the expected "module does not contain a 'main' function" for a library unit; one pre-existing warning in `loader/gguf.mojo`, untouched). No execution code in the session changed — the same posture as J-024's session edit.
- **No regression in the neighbouring suite:** `tests/test_expert_cache.mojo` rebuilt from this tree and run on the VM: **9/9 groups PASS**.
- **Registration note (stated, not hidden):** the new test is **not** registered in `tests/run_all.mojo` this slice — see §10, item 2. It runs standalone on the lightest target, as the road's replay harnesses do; registration is a named step of the §9 recipe, where the counted run that must accompany it can actually execute.

## 5. The accounting, against the CPU line (all arithmetic on filed measurements)

Stated inputs (every figure traced): OLMoE resident **311,027,712 B** and expert body **3,900,702,720 B** over 1,024 pairs (mean pair **3,809,280 B** exactly; largest pair **4,079,616 B**; cold ceiling **487,587,840 B/token**) — J-015/J-017, MEASURED. Usable device budget **5,368,709,120 B** — the engine's own admission figure for purplelongship's 6 GiB card (J-021: a 5,459,657,764 B requirement was refused against it), MEASURED on that box. KV allowance **67,108,864 B** — arithmetic on stated dims (context 512 × 16 layers × K+V × 2048-wide × f16; OLMoE is 16/16-head MHA, head_dim 128 — J-015), an *allowance input*, not a KV census (J-087 owns that). Activation allowance **16,777,216 B** — a named planning allowance. Reserve **268,435,456 B** — the dense CUDA session's default. CPU line (J-030 §4, re-verified there): idle prefill 2.3894 tok/s, decode 2.5563 tok/s, wall/token **0.4113 s**; streamed **32,948,699,136 B over 91 tokens = 362,073,616.9 B/token**; misses 8,641 (≈94.96/token); hit 0.258156 — all MEASURED / MEASURED-INDICATIVE as classed in J-030.

**Division outcomes on the stated machine** (planner output, unit-test-pinned):

| Device budget | Division | Device expert budget | Pairs (at mean) | Device total |
|---|---|---|---:|---:|
| 5,368,709,120 (the stated card) | **FULL_GPU** | 3,900,702,720 (the body) | 1,024 | 4,564,051,968 |
| 2,147,483,648 (illustrative smaller device) | RESIDENT_GPU_EXPERT_CACHE | 1,484,134,400 | 389 | 2,147,483,648 |
| 667,428,863 (fixed + largest − 1) | RESIDENT_GPU | 4,079,615 (unspendable remainder) | 0 | 667,428,863 |
| 663,349,247 (fixed − 1) | CPU_ONLY | 0 | 0 | 0 |

**Per-token transfers** (accountant output; hidden = 2048 × f16 = 4,096 B per crossing):

| Token | Division | H2D expert | Hidden traffic | Crossings | Total |
|---|---|---:|---:|---:|---:|
| Any | CPU_ONLY | 0 | 0 | 0 | 0 |
| Any | RESIDENT_GPU | 0 | 131,072 B (65,536 each way, 16 layers) | 32 | 131,080 B |
| Cold (streamed = ceiling) | EXPERT_CACHE | **487,587,840** | 0 | 17 | 487,587,848 B |
| At the CPU line's mean (streamed 362,073,616.9 B) | EXPERT_CACHE | **362,073,616.9** | 0 | 1 + miss-layers (≤17) | ≈362,073,625 B |
| Warm | EXPERT_CACHE / FULL_GPU | 0 | 0 | 1 | 8 B |

**Open-time uploads** (through the existing 64 MiB staging, one synchronisation per chunk): resident set 311,027,712 B → **5 chunks**; expert body 3,900,702,720 B → **59 chunks**; the FULL division's whole open upload is 4,211,730,432 B in 64 synchronised chunks.

**Reading of the tables, with classes:** the byte figures are exact arithmetic on the filed measurements — **MEASURED inputs, exact derivation**. Three conclusions the accounting licenses, and no more:

1. **For OLMoE on the stated card, streaming is not the GPU question** — the model fits whole (headroom 804,657,152 B). A live OLMoE GPU leg is therefore a *whole-model device session* leg (the §9 recipe's leg (a)), whose honest comparator is the CPU line's wall and whose first gate is token identity. The expert-cache division becomes the operative shape only when the model outgrows the device — J-032's class.
2. **GPU assistance does not reduce streamed bytes; at best it relocates compute.** Under the cache division every miss byte travels twice (disk→host by pread, host→device by staged upload). The division can only win on wall if device compute on resident + landed experts outruns the CPU line by more than the upload legs cost — a wall question, **NOT PROVEN**, and the reason no tok/s figure appears in this doc.
3. **The resident-only split is the worst shape on the table** despite its tiny byte count: 32 synchronisations/token and a stack split at every layer, against the spill line's proven cross-once discipline. Bytes are not the only currency; crossings are counted precisely so this stays visible.

Illustrative only (labelled, not a measurement): at an *assumed* 12 GB/s host↔device rate, the mean-token upload leg would add ≈30 ms against the CPU line's 411.3 ms/token — small *if* the bandwidth were real and the uploads perfectly overlapped. The bandwidth on this box for this path has never been measured; the figure is arithmetic on an assumption and may not be quoted as a result. The §9 recipe measures the real thing.

## 6. No live leg ran this slice — stated plainly, with the timeline

- **This worker has no device route to purplelongship** (the same posture recorded by the J-024/J-028/J-029/J-030 workers): it cannot verify on-box processes, build on-box with the proven recipe, or run a guarded leg. A GPU leg it cannot guard, build, or verify would be exactly the unmeasured claim this road forbids.
- **Coordination:** the 204 road's S-095 completed on purplelongship at 11:46 EDT during the J-030 window and its keeper **dispatched S-096 at ~12:02 EDT** (204 state file, 12:0x entry) — minutes before this slice's dispatch (~12:06 EDT). At that dispatch check the box was idle (GPU 1 MiB), but S-096's worker owns the next move there and its current on-box state cannot be verified from here; contention cannot be excluded, and the coordination law is to yield when a live run cannot be ruled out.
- **The VM cannot substitute:** it has no CUDA device for this path (every dense GPU proof on this road ran on purplelongship), and its MemAvailable measured this slice at ≈3,090 MB (`free -m`) — below the 5,500 MB inference gate. No VM inference was attempted.
- **The build itself is multi-piece** (§2's list: MoE device admission, device expert payload store, OLMoE device block maths, per-miss upload batching). This slice builds the planning layer those pieces must satisfy and files their exact recipe; pretending the whole session could be built *and* honestly graded inside one keeper tick, on a box the worker cannot reach, would be the inflation this road's honesty classes exist to prevent.

## 7. What the live leg must prove (grading design, pre-registered)

Identical configuration to the CPU line (J-030 §2): OLMoE Q4_K_M pin `8c310f14…f3f`, 67-id lighthouse prompt, context 512, 24 generated tokens — plus the device-side conditions: leg (a) FULL division (whole model device-resident, the §5 outcome on the stated card); leg (b), if the harness can cap the device expert budget, the EXPERT_CACHE division at the host cache's own 536,870,912 B budget for direct comparability with the CPU line's counters. Per leg: machine state (loadavg, Tctl, MemAvailable, `nvidia-smi` VRAM/utilisation) at start/end; **first gate token identity** vs the §3 id set (any divergence = defect to bisect); then teacher-forcing rank/gap vs the ggml CPU comparator; walls reported as MEASURED-INDICATIVE single runs beside the CPU line's 0.4113 s/token, never as baselines. The division *loses honestly* if its wall/token exceeds the CPU line's under the same conditions — that outcome is a result, and the recipe (§9) says to file it as one.

## 8. Honesty ledger

- **PROVEN:** the MoE stack's CPU-only construction (§1 — code inspection this slice, no GPU reference in session/cache/reader, `gemm_f16`'s own no-CUDA docstring, `CUDA_VISIBLE_DEVICES=` in the run scripts); the dense line's admission boundary (§2 — every CUDA session is dense-profile-shaped; `olmoe` admitted by none); the planning layer's arithmetic (§4 — 7/7 unit groups PASS on the lightest target, inputs pinned to the filed measurements; neighbouring expert-cache suite 9/9 PASS from this tree); the session module's compilation through its import graph after a docstring-only edit.
- **MEASURED:** every input figure in §5 (J-015/J-017/J-021/J-030 records, re-cited with their classes); the VM's MemAvailable this slice.
- **MEASURED-INDICATIVE:** nothing new — no wall was measured this slice. The CPU line's walls keep J-030's class wherever cited.
- **SIMULATED:** nothing. The §5 tables are exact arithmetic on measured inputs, not simulations of runs.
- **NOT PROVEN:** any GPU wall, tok/s, or speed ratio for any division; host↔device bandwidth on purplelongship for this path; that the §2 kernels reproduce OLMoE's maths at OLMoE's shapes (kernel-shape plausibility is not a grade); the expert-cache division on any real model (its operative class is J-032's, unmeasured); prefill-shaped (batched) MoE GPU work (the dense four-token prefill pattern has no MoE analogue built — Part IV's J-058 owns that question); any other model, device, or budget than the stated ones.

## 9. Deferred to the J-034 gate — the live GPU leg, exact recipe

For a device-capable worker, in a verified clean gap (204 heartbeat checked **and** on-box guard: no 204 worker processes at leg start, per the J-023 guard discipline):

1. **Build the device pieces** (§2's list, in dependency order): (a) an OLMoE device profile/admission beside the dense profiles (directory-true tensor map from the opened file; refuse any other MoE arch by name, as the host session does); (b) device residency for the resident set via the existing `upload_cuda_bytes` staging (expect 5 synchronised chunks for OLMoE's resident set); (c) the expert FFN on device from `block_matvec_kernel` kinds 12/14 at the §2 shapes, with the router/top-k/softmax and full-width Q/K norm beside the dense norm/rope/attention kernels — each kernel graded standalone against the host primitive on the same inputs before any session runs; (d) the device expert payload store: `ExpertCache` accounting unchanged, payloads in device buffers, misses uploaded **batched per layer's miss set** through the staging (never slab-by-slab), bypassed experts uploaded to a scratch region and discarded; (e) session glue mirroring `moe_session.mojo`'s step order exactly, with the division taken from `plan_moe_gpu_division` and the token's transfer account logged from the cache's own statistics via `plan_moe_gpu_token_transfers`.
2. **Register the planning tests:** add `tests/test_moe_gpu_plan.mojo` to `tests/run_all.mojo` as `memory.moe_gpu_plan` beside `memory.expert_cache`, re-account the `ledger.finish` pin from the counted run's own output (see §10 item 2 — the pin on this branch line already lags origin/main), and run the counted run on-box under `CUDA_VISIBLE_DEVICES=` as the battery requires.
3. **Run the §7 legs** on the §7 configuration: (a) FULL division; (b) EXPERT_CACHE division at 536,870,912 B if the harness caps the device budget. Log `nvidia-smi` at start/end (the FULL leg must show the model's device residency; a leg that silently ran on host is a failed leg, not a slow one). Grade ids first, then rank/gap; file full logs; report walls as MEASURED-INDICATIVE beside the CPU line's table (J-030 §4) and this doc's §5 accounting — including the upload bytes the transfer log proves were paid.
4. **File results beside this doc** and re-cite §5's three conclusions: confirmed, refined, or refuted by measurement — each is written to be testable, and a refutation is a result.

## 10. Defects and gaps found

1. **The accelerator-first gap itself (J-022's record) — addressed by design, not yet by execution.** The MoE session's CPU-only state was the known gap J-031 owns. This slice closes the *design and accounting* half and defers the *execution* half with reasons (§6) and a recipe (§9). It is recorded here so the deferral is a tracked road, not a quiet drop: **J-034's gate must re-cite this item.**
2. **Counted-run pin lag on this branch line (pre-existing; NOT introduced by this slice, NOT fixed here).** This branch line's `tests/run_all.mojo` still carries `ledger.finish(277)` while origin/main carries `ledger.finish(278)` — S-092 re-accounted the pin on main after the J-021 dense-residency case landed without one. Whether this line's true case count is 278 cannot be settled without the counted run, which this slice cannot execute (VM memory gate; the battery's device steps belong on-box). This slice therefore does **not** register its new test in `run_all` (registering without the counted run would widen an unmeasured gap) and names registration + pin re-account as step 2 of the §9 recipe, where both can be done against a real counted run.
3. **No defect found in the MoE or dense-GPU code by this slice's inspection.** The §2 gaps are absences (no MoE admission, no device expert store), recorded as the build list — not misbehaving code. The neighbouring suites rebuilt and re-run this slice pass in full (§4).

## 11. Artefacts

Filed beside this doc in `docs/janas/`: this document; `j031_plan_test_output.txt` (the planning suite's filed output, 7/7 PASS). In the tree: `aesir_engine/core/moe_gpu_plan.mojo` (the planning/accounting layer), `aesir_engine/tests/test_moe_gpu_plan.mojo` (7 groups), and the docstring host-contract addition in `aesir_engine/core/moe_session.mojo`. Campaign copies of this doc and the test output live in `~/workspace/model-tests/janas/`, sha-identical. The evidence this slice stands on (J-015/J-017/J-021/J-030 docs and the J-022/J-023 artefacts) already stands filed under its own slices.
