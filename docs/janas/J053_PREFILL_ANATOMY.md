# J-053 — Prefill Anatomy: Where Prompt Time Goes in Aesir Today

**Slice:** J-053 (Part IV — The Accelerator Prompt: GPU and NPU prefill, J-053–J-070), Project Aesir Janas clean-room road.
**Roadmap text:** "Prefill anatomy. Where prompt time goes in Aesir today, per architecture, at 256 / 1,024 / 4,096 / 8,192 tokens: the baseline table every later slice is graded against."
**Executed:** 2026-10-31 ~22:27–22:45 EDT (VM clock 2026-11-01 02:27–02:45 UTC). Inspection first-hand from this tree; the accounting module built and unit-tested on the VM's lightest target; **no model inference ran anywhere**.
**Base:** fresh worktree `~/workspace/aesir-janas-j053` on branch `yrsa/janas-j053`, from `yrsa/janas-j052` tip `7ea89f6638d867bff0d1967b2bddddbc838b8c34` (verified by `git ls-remote` at slice start; origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`).
**Machine state (VM, stated for every number below):** KVM, 4 vCPU, kernel 7.0.0-39-generic. MemAvailable ~1.4–1.6 GB at every check — **far below the 5,500 MB inference gate**, so no VM inference was attempted. Load average ~16 at slice start, easing to ~2–5 by the end; either way, walls under any contention are not baselines and none are filed here. purplelongship was **not used at all** — the 204 road's S-103 is live there and this slice yields under the coordination law. Every per-length wall the baseline table ultimately needs is therefore **DEFERRED-WITH-REASON** to the guarded recipe in §7 — never faked, never borrowed.

---

## 1. Verdict

**J-053 closes as an inspection + accounting slice** (the J-029/J-051 closure shape, with a built artefact in the J-031/J-040 style):

- The prefill path was inspected first-hand on **every surface that serves a prompt today** (§2): the host engine's chunked batched path and its per-token fallback, the Llama 3 CUDA session (width-1 and tile-4), the Gemma 4 CUDA session (width-1), and the streamed OLMoE session (width-1). *Where prompt time goes, by construction*, is answered per phase in §3.
- The baseline table's **frame** is built and its **by-construction cells are filled with exact arithmetic** (§4–§5): pass counts per surface, KV bytes written, causal attention pairs, projection/attention/LM-head MACs — per architecture × 256 / 1,024 / 4,096 / 8,192 tokens. These quantities are **PROVEN by construction** (they are counts of what the code executes, replayed by a unit-tested accounting module, `core/prefill_anatomy.mojo`, **8/8 test groups PASS**, §6) and cannot drift when later slices measure walls against them.
- The table's **wall cells are honestly empty tonight**: the only measured prefill walls in the road's record are re-cited in §6 as prior evidence with their slice, hardware, and conditions (the OLMoE 67-token legs and the S-033 chunk comparison). All other wall cells are **DEFERRED-WITH-REASON** with the exact guarded recipe in §7, including two cells that are not deferred but **refused by context** (OLMoE at 8,192 — its file context is 4,096; Llama 3 CUDA at 8,192 — the session's fit check needs prompt + response inside an 8,192 cap).
- One genuine inefficiency was discovered in the prefill path and is recorded as a named finding with an owner (§8, F1): **the streamed MoE session pays the full LM head + a vocab-wide argmax scan on every prompt token** — 256 head passes for a 256-token prompt where every other surface pays exactly 1. No correctness defect was found in any prefill path.

No README touched. Hailo untouched/parked (no finish-line branch contact, no chip run; Part IV's NPU slices are later and conditional). No Docker. No Janas source opened — this slice needed no Janas material at all; it is about Aesir's own tree (clean-room law unengaged).

## 2. The executors: which code serves a prompt, per architecture

All line numbers are this tree's, machine-verified by `j053_inspect.py` (filed beside this doc; output `j053_inspect_output.txt`).

| Surface | Entry that owns prefill | Width discipline | Archs it serves |
|---|---|---|---|
| **Host engine, batched** | `AesirEngine._run_generation` (`aesir_engine/aesir.mojo:1070`) → `_forward_batch` (`:871`), chunk cap from `_prefill_batch_cap` (`:843`): `AESIR_PREFILL_BATCH`, default **256**, clamped by arena workspace | chunks of 2…256; every chunk but the last is pure prefill (`is_prefill=True`: fills KV/SSM state, returns before the LM head); the final chunk also samples the first token | all host archs (below) |
| **Host engine, per-token** | `_run_generation`'s fallback loop over `_forward_position` (cap ≤ 1, or a 1-token prompt) | width 1; pure prefill for all but the last prompt token | all host archs |
| **Llama 3 CUDA session** | `Llama3CUDASession.begin_turn` (`core/llama3_cuda.mojo:496`) → `forward` (`:387`) / `prefill_four` (`:435`) | width 1, plus **width-4 tiles** where admitted: `prefill_batch == 4` is admitted only for the exercised Llama 3.2 3B profile (`core/dense_buffers.mojo:17`); a tile runs while ≥ 4 tokens remain before the last | `llama` profiles 8B (32L/4096) and 3.2 3B (28L/3072) — CUDA admission is profile-strict (`core/dense_gqa_profile.mojo`) |
| **Gemma 4 CUDA session** | `Gemma4CUDASession.begin_turn` (`core/gemma4_cuda.mojo:287`) → `forward` (`:207`) | width 1 only — no batched or tile form exists on this surface | `gemma4` E2B (35L) and E4B (42L) profiles (`core/gemma4_profile.mojo`) |
| **Streamed MoE session** | `MoEStreamSession.step` (`core/moe_session.mojo:552`) — the session's only forward entry; a prompt is N calls driven by the host harness | width 1 only; **no pure-prefill form exists** (§8 F1) | `olmoe` only — any other arch is refused by the session's own contract |

**Host arch dispatch** (`_forward_batch` / `_forward_position` over `core/inference.mojo`): the generic dense path (`forward_pass` `:1068` / `forward_pass_batched` `:1232`, blocks `TransformerBlock.forward` `:281` / `forward_batched` `:639`) serves the GGUF-config families the loader reads (llama, qwen2, qwen3, gemma2-class modifiers, granite-class residual scaling — the block's arch modifiers are at `inference.mojo:105–118`); Gemma 4 has its own pair (`forward_pass_gemma4` `:1917` / `forward_pass_gemma4_batched` `:1984`, block twin `:1770`) with per-layer-input (PLE) embeddings; Qwen3.5 has its own pair (`forward_pass_qwen35` `:2802` / `forward_pass_qwen35_batched` `:2725`, block twin `:2482`) — a hybrid: full-attention layers batch like the dense path, while DeltaNet layers batch their projections but keep the conv1d + delta-rule recurrence **strictly sequential per row** (the batched twin's own docstring). Qwen3.5 has no fixed profile constants in the tree (its shapes are file-derived at load), so its table row in §5 is structural, not pinned to one variant.

**Prefix reuse note:** the Llama 3 CUDA session can skip already-cached prompt prefixes (`begin_turn`'s reuse branch, exact token/position equality), and the host has a prompt-prefix module from earlier work — reuse changes *which* tokens are prefilled, not the per-token anatomy below; the baseline table is stated for cold prompts (J-069 owns cold-vs-warm separation).

## 3. Where prompt time goes, by construction

Per phase, for a prompt of N tokens on a model of L layers:

1. **Tokenize + admit (host/CPU, all surfaces).** Chat templating and BPE encoding of the prompt text; admission checks (context fit). O(N) small work; no timer exists for it anywhere (§7's instrumentation census) — it is inside every "prefill" wall the serve path reports.
2. **Embedding.** Host batched: one batched lookup for the chunk (`_embed_tokens`). Host per-token / CUDA / MoE: one row lookup per token (Gemma 4 CUDA additionally embeds the per-layer-input vector and runs its projection per token). Cost per token is a hidden-wide row read — never the dominant term, but on width-1 surfaces it is paid inside every pass.
3. **Per-block work — the dominant term, and the one whose shape differs by surface.** Per token per layer the dense projections + FFN cost `2·hidden·q + 2·hidden·kv + 3·hidden·ffn` MACs (§5 pins this per profile). **This total is surface-invariant**: batched and per-token paths execute the same products (`forward_batched` is `forward` with three named deltas — row-wise Q/K norms, `append_block`, per-row attention). What batching changes is not MACs but **passes**: each pass re-reads / re-decodes the weight blocks it touches, so weight traffic scales with pass count (§5's weight-pass shape), which is precisely the mechanism behind the one measured chunk effect in the record (§6, S-033: chunk 32→256 on a 213-token prompt = 7 passes → 1 pass, walls −9–14 %, ids bit-identical). On the CUDA tile-4 path the sharing is narrower: projections batch across the tile (`project_four`), but norms, RoPE, KV cache writes, and the scores/softmax/attention kernels still run **per token inside the tile** (`prefill_four`'s inner loops).
4. **Attention — the quadratic term, unbatched everywhere.** In every batched form in the tree, attention itself runs **once per row** with that row's own causal bound (`TransformerBlock.forward_batched` delta 3; the Qwen3.5 and Gemma 4 twins state the same). Total causal pairs per layer are N(N+1)/2 regardless of surface (§5) — at 8,192 tokens that is 33,558,528 pairs/layer, and attention MACs overtake projection MACs between 1,024 and 4,096 tokens on every profile in §5. Gemma 4's local layers cap the span at the 512 sliding window (4,063,488 pairs/layer at 8,192); its global layers pay full causal. On the CUDA sessions the scores+softmax+attention kernels are likewise per token (count = position+1), so a CUDA prompt's attention work grows quadratically exactly as the host's does.
5. **KV writes.** Every prompt token writes K and V once per owning layer: bytes/token are profile arithmetic (§5) — 131,072 B/token for both Llama 3 8B and OLMoE (by different shapes: 32×1024-wide vs 16×2048-wide), 18,432 B/token for Gemma 4 E2B (only 15 of its 35 layers own KV; the rest share). The host writes via `KVCache.append_block` (`core/mimir_well.mojo:990`, a single flat copy per chunk per layer) vs `append` per token on width-1 paths; allocation is fixed-capacity and is *not* a per-prompt cost (J-087 owns the KV census).
6. **The MoE stream (OLMoE only) — disk traffic is a prefill phase.** Each token routes top-8 of 64 experts per layer; on a cache miss the expert's three slabs are read from disk through the J-018/J-019 stream path before its FFN can run. At the J-030 filed mean rate (362,073,616.9 B per stepped token), a prompt's projected stream traffic dwarfs its KV writes by ~2,700× (§5) — on this surface, "prefill time" *is* mostly expert streaming + the per-token head (F1), not attention, until contexts far beyond the file's 4,096 cap.
7. **LM head + sampling hand-off — paid once, except where it isn't.** Pure-prefill passes return before the head on the host (batched and per-token), and both CUDA sessions pass `need_logits` only on the last prompt token (verified by raw-codepoint readback of the two masked lines, `llama3_cuda.mojo:559` and `gemma4_cuda.mojo:332` — the display-layer masking note from J-035 applies). The first sampled token therefore costs one head (hidden×vocab MACs, §5) plus the sampler — that is the *first-token latency* split the table's wall recipe (§7) must report separately from the prompt-fill wall. **The MoE session is the exception (F1):** `step()` always runs the final norm, the output projection, and a full vocab argmax scan, so a MoE prompt pays the head N times and discards N−1 of the results.
8. **Synchronisation (CUDA surfaces).** Width-1 CUDA prefill synchronises the device **once per token** (`forward` ends each token with a context synchronise, with or without logits); a tile-4 pass synchronises once per tile. At 8,192 tokens that is 8,192 vs 2,051 synchronisations before any kernel time is counted — a by-construction cost the J-054/J-055 slices exist to remove, and the reason pass counts are a graded column of the baseline table, not a curiosity.

## 4. The baseline table — frame

Every later Part IV slice grades against this frame. Columns, per **architecture × surface × prompt length (256 / 1,024 / 4,096 / 8,192)**:

| Column | Class tonight | Source |
|---|---|---|
| Passes (total / pure-prefill / LM-head) | **PROVEN by construction** | §5, replayed by `core/prefill_anatomy.mojo` |
| KV bytes written | **PROVEN by construction** (exact arithmetic on profile dims) | §5 |
| Causal pairs + attention MACs | **PROVEN by construction** | §5 |
| Projection (+ routed, for MoE) MACs | **PROVEN by construction** | §5 |
| MoE streamed bytes (OLMoE rows) | **SIMULATED** projection of a MEASURED rate | §5 (J-030 rate) |
| Prefill wall / tok/s | **DEFERRED-WITH-REASON** (one re-cited prior cell, §6) | recipe §7 |
| First-token latency split (fill wall vs head+sample) | **DEFERRED-WITH-REASON** | recipe §7 |
| Faithfulness (ids-first; teacher-forcing rank/gap vs CPU comparator) | **DEFERRED-WITH-REASON** for new legs; prior OLMoE grade re-cited | §6, recipe §7 |

Grading rule inherited by J-054…J-068: a later slice's wall is only comparable when its row states the same surface, cap, model pin, prompt shape, and machine state as the §7 recipe — and its by-construction columns must equal this table's, or the difference is itself a finding.

## 5. The baseline table — by-construction cells (PROVEN)

Pass plans (passes / pure-prefill / LM-head), all surfaces × all lengths — generated by `j053_inspect.py`, pinned by the module's unit tests:

| Surface | 256 | 1,024 | 4,096 | 8,192 |
|---|---|---|---|---|
| Host batched, cap 256 | 1 / 0 / 1 | 4 / 3 / 1 | 16 / 15 / 1 | 32 / 31 / 1 |
| Host per-token · CUDA width-1 | 256 / 255 / 1 | 1,024 / 1,023 / 1 | 4,096 / 4,095 / 1 | 8,192 / 8,191 / 1 |
| CUDA tile-4 (Llama 3.2 3B only) | 67 / 66 / 1 | 259 / 258 / 1 | 1,027 / 1,026 / 1 | 2,051 / 2,050 / 1 |
| MoE width-1 (`step`) | 256 / 0 / **256** | 1,024 / 0 / **1,024** | 4,096 / 0 / **4,096** | 8,192 / 0 / **8,192** |

Per-arch quantities (full generated table in `j053_inspect_output.txt`; headline rows):

| Arch (profile source) | Proj. MACs /token | KV B /token | KV written @8,192 | Attn MACs @256 → @8,192 | Head MACs (×1) |
|---|---|---|---|---|---|
| Llama 3 8B (`dense_gqa_profile`) | 6,979,321,856 | 131,072 | 1,073,741,824 B | 8,623,489,024 → 8,797,166,764,032 | 525,336,576 |
| Llama 3.2 3B | 2,818,572,288 | 131,072 | 1,073,741,824 B | 5,659,164,672 → 5,773,140,688,896 | 394,002,432 |
| Qwen3 0.6B | 440,401,920 | 114,688 | 939,524,096 B | 3,772,776,448 → 3,848,760,459,264 | 155,582,464 |
| Qwen2.5 Coder 7B | 6,525,288,448 | 57,344 | 469,762,048 B | 6,602,358,784 → 6,735,330,803,712 | 544,997,376 |
| Gemma 4 E2B (`gemma4_profile`; dense part only — PLE projections excluded, §9) | 1,238,630,400 | 18,432 | 150,994,944 B | see layer-class split below | 402,653,184 |
| OLMoE (J-015 dims; **routed** MACs: attn proj + router + top-8 experts) | 1,075,838,976 | 131,072 | 1,073,741,824 B | 2,155,872,256 → 2,199,291,691,008 | 103,022,592 (×N on the MoE surface — F1) |

- **Gemma 4 E2B attention at 8,192, by layer class** (the honest form — a single full-causal figure would overstate a hybrid model): 28 local layers (window 512, q width 2,048) = 466,033,311,744 MACs; 7 global layers (full causal, q width 4,096) = 1,924,380,229,632 MACs; total 2,390,413,541,376. At ≤ 512 tokens the window never binds and local layers are full-causal.
- **OLMoE streamed bytes, SIMULATED** at the J-030 mean rate (32,948,699,136 B / 91 stepped tokens): 256 → 92,690,845,921 B; 1,024 → 370,763,383,684 B; 4,096 → 1,483,053,534,736 B; 8,192 → 2,966,107,069,473 B *(this last cell is arithmetic only — the file's context cap refuses the run, §7)*. These are projections of a measured rate over a *mixed prefill+decode* leg; real prompt-only bytes are routing-dependent and only the §7 leg measures them.
- **Qwen3.5 row (structural):** same host chunk plans as the dense rows; per-token MACs are file-derived (no pinned profile exists to quote); its DeltaNet layers add a per-row sequential recurrence cost that does **not** shrink with batch width — the one place in the tree where a batched chunk still contains an O(N) serial chain per layer. Its baseline wall recipe (§7) must therefore report the SSM share separately, or the row is not comparable to the dense rows.

## 6. Re-cited prior evidence (the only measured walls in the record)

Entered **only** as re-citations, labelled with slice, hardware, and conditions — clearly separated from everything above, and **not** baseline-grade (single runs, thermally varying box):

| Cell | Figure | Source & conditions |
|---|---|---|
| OLMoE, streamed CPU, 67-token prompt (512 MiB cache) | prefill **28.04 s = 2.3894 tok/s**; decode 9.39 s (2.5563 tok/s) | J-023 idle leg, re-verified in J-030 §4. purplelongship (Ryzen 9 / RTX 2060 idle, `CUDA_VISIBLE_DEVICES=`), OLMoE Q4_K_M pin sha256 `8c310f14…f3f`, in S-093's cooldown wake. Class: **MEASURED-INDICATIVE**. Ids + counters identical across three legs; faithfulness PROVEN there (teacher-forcing rank 0 at 23/24, step-23 rank 1 / gap 0.108 vs the ggml CPU comparator, raw prompt) |
| OLMoE, same, under live contention | prefill **47.32 s** (post-fix verification run) | J-022 §7.3 run: S-093 live throughout (load ~13–15, Tctl to 83.1 °C). **MEASURED-INDICATIVE** — the standing demonstration that contention moves this wall ~1.7× with identical ids/counters |
| Host batched, Oprius-i1 1.1B, 213-token prompt | chunk 32 → 256 cut walls **9–14 %**, ids bit-identical | S-033 evidence as recorded in `_prefill_batch_cap`'s docstring (`aesir.mojo:843`). **MEASURED-INDICATIVE** (prior road, recorded in-tree); its pass-count reading (7 → 1 passes) is §5's PROVEN part |
| OLMoE per-token stream rate | 362,073,616.9 B/token mean; cold ceiling 487,587,840 B/token | J-030 §4 (MEASURED counters, identical across three legs) / J-015 exact ceiling (MEASURED dims) |

No other prefill wall exists in the road's record for any arch, surface, or length. In particular there is **no** measured CUDA prefill wall, no host dense wall at any baseline length, and no wall at 256/1,024/4,096/8,192 tokens for any row — those cells are §7's, and any document quoting one from elsewhere is quoting a number this road has not measured.

## 7. The deferred measurement leg — exact guarded recipe

**Why deferred:** the VM is below the 5,500 MB inference gate (MemAvailable ~1.4–1.6 GB) and purplelongship is owned by the 204 road's live S-103. **Run this on purplelongship in a quiet window, or on any device-capable machine, exactly as written:**

1. **Gate checks first:** read the 204 road's heartbeat (`~/workspace/model-tests/ROADMAP_204_STATE.md`) and confirm no live run on the box; record loadavg, Tctl, MemAvailable, GPU idle (VRAM ~1 MiB) at leg start and end. One heavy run at a time. Fetch branch `yrsa/janas-j053` on-box by git (sparse checkout is the proven route); verify the tree sha matches the banked tip.
2. **Models (sha-pinned, no substitutions):** OLMoE-1B-7B Q4_K_M, sha256 `8c310f14…f3f` (full pin in J-015/J-022), for the MoE rows; the wave-pinned Llama 3.2 3B, Qwen3-0.6B, and Gemma 4 E2B files from the laptop's model store (record each file's full sha256 in the leg output before running — a wall without its pin is not a baseline cell).
3. **Prompt shapes:** deterministic prompts of **exactly** 256 / 1,024 / 4,096 / 8,192 tokens, produced by encoding fixed prose with the model's own tokenizer and truncating/extending by repetition to the exact count; file the token-id lists with the leg. Raw prompts only — no chat template on the graded legs (template rendering is a comparator artifact class, never a graded input).
4. **Context refusals (do not force):** OLMoE lengths stop at 4,096 minus generation (file context 4,096) — the 8,192 MoE cell stays **REFUSED-BY-CONTEXT**; Llama 3 CUDA at 8,192 is **REFUSED-BY-CONTEXT** on the session fit check (prompt + response must fit the 8,192 cap) — its 8,192 wall, if wanted, is a *host-surface* leg at exactly context length, labelled as such.
5. **Runs:** per (arch, surface, length): host legs with `AESIR_PREFILL_BATCH` ∈ {256, 1} (both rows — the cap is a graded variable); CPU legs under `CUDA_VISIBLE_DEVICES=` stated in the log; CUDA legs on the admitted profiles only (tile-4 only where `effective_prefill_batch` admits it). Three repetitions per cell, median filed with all three raw walls; per cell record **prefill wall** (tokenize→last prompt position filled), **first-token latency** (prompt start→first sampled token, i.e. fill + one head + sampler), and decode wall for 24 generated tokens as the separation witness. Generate with greedy/temperature-0 settings matching the comparator leg.
6. **Grading (raw-oracle discipline):** ids first — generated ids must equal the same-surface per-token run's ids token for token, or the cell is a defect report, not a number. Then teacher-forcing rank + logit gap against the ggml **CPU** comparator on the raw prompt (never `llama-cli --single-turn`; CPU-vs-CPU comparator only; step-0 boundary effects named as their own verdict class, per J-060's charter).
7. **Filing:** walls land in an addendum doc on the measuring slice's branch with machine state per run; cells measured under loadavg > 2 sustained or Tctl > 85 °C are classed MEASURED-INDICATIVE and do **not** fill the baseline — the cell stays deferred until a quiet run fills it.

## 8. Findings (defects and inefficiencies — none left silent)

- **F1 — MoE prefill pays the LM head per token (inefficiency, PROVEN by construction).** `MoEStreamSession.step` (`moe_session.mojo:552`) has no pure-prefill form: every prompt token pays the final norm + output projection (103,022,592 MACs at OLMoE's shape) + a 50,304-wide argmax scan, and the harness discards all but the last result. At 4,096 tokens that is ~4.2×10¹¹ MACs of pure waste — the head adds ~9.6 % on top of *every* prompt token's entire routed layer work (103,022,592 against 1,075,838,976 MACs/token), spent on answers that are thrown away. It is not a correctness defect (the returned ids are the proven ones), and this slice does **not** patch the proven session's only entry point blind. **Recorded as the immediate next item for the MoE prompt line, owned by J-058** (MoE prompt on GPU) with J-054's shape as the pattern: add a `step_prefill(token)` form that skips the head (mirroring `is_prefill` semantics), keep `step` byte-identical for decode, and grade by the J-030 id set before any wall is quoted.
- **F2 — Attention does not batch, on any surface (structural, PROVEN by construction).** Batched forms batch the GEMMs; attention remains a per-row kernel loop (§3.4). This is correct (it is what makes batched ≡ per-token bit-identical) but it caps what J-054/J-055 can win at long lengths, where attention MACs dominate (§5). Named here so those slices are graded against the real ceiling, not a hoped one. Owner: J-054 (GPU block prefill) — a fused batched-attention kernel is its named question, to be answered with measurements, not assumed.
- **F3 — No prefill instrumentation on the host path (gap, PROVEN by inspection).** The only prefill/decode timing split in the tree is the native serve path's `timings_ms` (`cli/native_serve.mojo:516–543`: monotonic-ms around the Llama 3 CUDA session's turn, split into `prefill` / `decode`) — Llama-CUDA-serve only. The host engine prints prompt token counts and nothing else; no surface reports per-chunk, per-phase, or per-layer times; the placement harness's prompt workload (J-038) is a micro-workload, not a model pass. §7's recipe therefore measures from outside (wall around the session call), and **J-059 (long-prompt watching) + the §7 leg own adding in-engine phase timers** — until then, any per-phase wall split quoted for Aesir is invented, and this doc quotes none.

**Defect check on the rest of the prefill path:** every surface behaves as its contracts state (the batched single-device refusal, the tile admission restriction, the interrupted-prefill reset rules are deliberate, documented behaviour). No correctness defect was found.

## 9. Answered-locally / exclusions (clean-room)

- No Janas material was consulted; every quantity above derives from Aesir's own tree, profiles, and filed measurements. Nothing was answered from Janas documentation, so no clean-room question arose in this slice.
- **Stated exclusions from the §5 MAC accounting** (so the table is never over-read): Gemma 4's per-layer-input projections and post-norms (a real per-token cost on both its surfaces, uncounted here — the E2B proj row is a lower bound); Qwen3.5's DeltaNet recurrence + conv (sequential per row, §5 note); norms, RoPE, biases, and sampler cost on all rows (small, per-token, surface-similar); embedding lookups (row reads, §3.2); quant dequantisation (priced by *passes* in §3.3's weight-traffic shape, not by MACs).

## 10. NOT PROVEN list

- **Every prefill wall / tok/s / first-token latency at every baseline length, on every arch and surface** — DEFERRED-WITH-REASON to §7's recipe (VM below the inference gate; purplelongship yielded to the 204 road). The §6 re-citations are prior evidence, not baseline cells.
- Per-phase wall splits (how much of any real wall is attention vs projections vs stream vs head) — no instrumentation exists to measure them (F3).
- The MoE stream projection's prompt-only accuracy (the rate comes from a mixed prefill+decode leg; prompt-only routing may differ).
- Batched-vs-per-token bit-identity **on this tree state** (stated in `forward_pass_batched`'s docstring, proven on earlier trees; §7's ids-first grading re-proves it per leg).
- Qwen3.5 pinned quantities (no fixed profile exists in the tree to pin them to).
- Any NPU prefill quantity — the Hailo is parked; J-061/J-062 own the design and the gate brief, and nothing here crosses that gate.

## 11. Banking

Filed on branch `yrsa/janas-j053` (worktree `~/workspace/aesir-janas-j053`, base `7ea89f66`): `docs/janas/J053_PREFILL_ANATOMY.md` (this doc), `docs/janas/j053_inspect.py` + `j053_inspect_output.txt`, `docs/janas/j053_test_output.txt`; in the tree: `aesir_engine/core/prefill_anatomy.mojo` (new accounting module) and `aesir_engine/tests/test_prefill_anatomy.mojo` (8 groups). Campaign copies of the doc + evidence files in `~/workspace/model-tests/janas/`, sha-identical. Push by explicit refspec (`git push origin HEAD:refs/heads/yrsa/janas-j053`, foreground) with `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6`; the commit hash and ls-remote lines are recorded in the campaign state file entry for J-053 and in the slice worker's report (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
