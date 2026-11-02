# J-068 — Prefill at 8k

**Slice:** J-068 (Part IV — The Accelerator Prompt, J-053–J-070), Project Aesir Janas clean-room road.
**Roadmap text:** "The J-053 table re-measured at 8,192 with all of this part's work in: reading speed and faithfulness, per arch."
**Executed:** 2026-11-01 ~02:4x–02:5x EST, by a continuation worker. Inspection first-hand from this tree; the 8,192-token table re-derived as an account and unit-tested on the VM's lightest target; **no model inference and no 8k live leg ran anywhere** — the live legs close DEFERRED-WITH-REASON with the exact recipe in §7, per the J-053/J-067 pattern.
**Continuation note (honest provenance):** the first J-068 worker (dispatched ~02:22 EST) wrote the accounting module, the test file, and the inspect script + output at 02:28–02:29 EST and then stalled; no test had been run, no doc, no campaign copies, no commits existed. The continuation worker verified every inherited file first-hand before banking it: the inspect script was re-run (output byte-identical to the filed copy), every figure in the inherited test file was independently recomputed in Python (all exact — §5), and the slice + neighbour suites were built and run from this tree (§6). Nothing inherited was taken on trust.
**Base:** worktree `~/workspace/aesir-janas-j068` on branch `yrsa/janas-j068`, from `yrsa/janas-j067` tip `8e05ff6c1979af6e6e1b5463087d105ec0dac3fc` (verified by `git ls-remote` at slice start; origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`; no remote `yrsa/janas-j068` existed before this slice).
**Machine state (VM, stated for every number below):** KVM, 4 vCPU. MemAvailable ~0.67–1.08 GB across the run — **far below the 5,500 MB inference gate**, so no VM inference was attempted. purplelongship was **not used at all** — unreachable tonight (204 road state: device offline, last seen 2026-11-01T02:07:13Z), its S-103 owns the box in any case, and this slice yields under the coordination law.
**Clean-room record:** no Janas material was consulted in this slice; every quantity derives from Aesir's own tree, profiles, and filed Part IV accounts. No Janas source code was opened, in this slice or any other.

---

## 1. Verdict

**J-068 closes as an accounting + re-derivation slice whose live legs are DEFERRED-WITH-REASON** (the J-053/J-067 closure shape):

- The J-053 baseline table's 8,192-token row is **re-derived per arch/surface with all of Part IV's work in** (§2–§4): pass counts, KV bytes, causal pairs, projection/attention MACs, attention shares, context-cap verdicts, and the MoE head-waste account (F1) — each number is exact arithmetic on the filed profiles, replayed by a unit-tested accounting module, `core/prefill_at_8k.mojo`, **7/7 test groups PASS** (§6), with the J-053 neighbour suite rebuilt at **8/8 PASS** and the J-067 neighbour at **11/11 PASS**.
- The per-arch headline (§3): **attention does not dominate at 8k on most profiles.** Only one filed profile crosses half — Qwen3 0.6B at 51.61% (5,161 bp). Every other filed profile sits at 11–20%. "Attention dominates at 8k" is a per-arch arithmetic fact, not a universal law of long prompts — and the re-derivation corrects J-053's §3.4 prose, which claimed attention overtakes projections "on every profile" between 1,024 and 4,096 tokens: J-053's own §5 numbers never supported that sentence (at 8,192, five of six profiles are still projection-dominated). The numbers were right; the sentence was not. This doc follows the numbers.
- **No reading speed and no faithfulness at 8k is claimed anywhere in this doc.** The roadmap's "re-measured" wording is answered honestly: what can be re-derived without a live run is re-derived exactly (§2–§4); the walls, tok/s, first-token latencies, and faithfulness grades that a re-measurement would produce are **DEFERRED-WITH-REASON** to the guarded recipe in §7, to be re-cited at the J-070 Part IV gate. Arithmetic is never presented as a measured wall or tok/s.
- Part IV's work changes the 8k row in exactly the ways §4 names, and in no others: J-054's block plan prices the GPU 8k pass (7,168 batched GEMM calls vs 786,432 per-row attention calls — attention still per-row, F2 stands); J-055's whole-layer account says width-1 whole-layer already exists and block whole-layer is gated by J-054's M1+M2+M5; J-056's split account rejects the split where both parents exist (ties on MACs and weight bytes) and does not grade it where the whole-GPU parent is absent; J-057's overlap account rejects the overlap on every shape that exists tonight (the imagined stall is not a phase in Aesir's loops); J-058's MoE chunk form survives under the FULL / expert-cache divisions and pays the head once — cutting F1's waste to zero at 8k; J-059's watching account prices the 8k read at 32 chunks / 10 expected records on the host width; J-060's battery supplies the pre-registered grading rule the §7 legs will run under; J-061–J-065's NPU states contribute nothing executable at 8k (design + closed gate + three conditional deferrals); J-066's Vulkan DEFER contributes no backend; J-067's iGPU account contributes the shared-pool budget/tax shape for a future iGPU 8k leg, and no speed claim.
- **One context refusal is in the row, not beside it:** OLMoE's file context is 4,096, so an 8,192-token OLMoE prompt is **REFUSED-BY-CONTEXT** — its 8k cells are arithmetic projections only (the stream projection in §4 is labelled SIMULATED, and the J-058 8k case is a refusal case in its own test file). Llama 3 at exactly its 8,192 cap fits the prompt but leaves no room to generate (24-token reserve → no-generation-room verdict); Qwen3's 32,768 cap fits with room.

No README touched. Hailo untouched/parked (no finish-line branch contact, no chip run; Part IV's NPU slices are design/deferred only). No Docker. No defect was found in the inherited module or test file — but see §8 for the one prose correction and the one pre-existing build warning, both recorded rather than silently passed over.

## 2. What was built — the 8k account

**`aesir_engine/core/prefill_at_8k.mojo`** (new, inherited from the first worker, inspected in full by the continuation worker). It composes J-053's own accounting (`core/prefill_anatomy`) at exactly 8,192 tokens and adds the three quantities the 8k row needs that no earlier module states:

- **`attention_share_bp` / `attention_dominates`:** attention's share of (projection + attention) MACs in basis points (floored), computed per arch from the row's own totals; dominance is share strictly above 5,000 bp. Both totals are the row's own — never a blanket claim. Zero/negative totals are refused, not divided.
- **`context_verdict` (+ `context_verdict_name`):** FITS / FITS_NO_GENERATION_ROOM / REFUSED_BY_CONTEXT for one prompt against one cap and one generation reserve. A prompt equal to the cap fits as a fill but leaves no room to generate; a prompt above the cap is refused, mirroring the sessions' own fit checks.
- **`head_waste_macs`:** LM-head MACs spent on discarded results — every head pass beyond the first, at the stated per-pass figure. The planned MoE chunk form (J-058) pays the head once, so its waste is zero by this same account.
- **`plan_8k_row` / `EightKRow`:** one arch/surface row at exactly 8,192 tokens — passes, pure-prefill passes, LM-head passes, KV bytes written, causal pairs per layer, attention MACs, projection MACs total, attention share, head waste. A positive `window` prices sliding-window attention pairs (a single-class row; hybrid models compose their classes per class, as J-053's Gemma 4 row does). Any length other than 8,192 is refused here — other lengths are J-053's table, not this slice's.

**Host contract** (in the module docstring, binding): shape inputs come from the opened model's own profile/directory exactly as in J-053's contract; the row is stated for exactly 8,192 tokens. The module executes nothing, times nothing, and contains no speed.

## 3. The 8,192-token table — by-construction cells (PROVEN)

Pass plans (passes / pure-prefill / LM-head) at 8,192, from J-053's table re-derived through this slice's module (replayed by the tests):

| Surface | 8,192 |
|---|---|
| Host batched, cap 256 | 32 / 31 / 1 |
| Host per-token · CUDA width-1 | 8,192 / 8,191 / 1 |
| CUDA tile-4 (Llama 3.2 3B only) | 2,051 / 2,050 / 1 |
| MoE width-1 (`step`) | 8,192 / 0 / **8,192** |

Per-arch quantities at 8,192 (all arithmetic re-derived first-hand; full generated table in `j068_inspect_output.txt`):

| Arch (profile source) | Proj. MACs /token | KV B /token | KV written @8,192 | Attn MACs @8,192 | Head MACs (×1) | Attn share | Dominates? |
|---|---|---|---|---|---|---|---|
| Llama 3 8B (`dense_gqa_profile`, 32L, q 4096) | 6,979,321,856 | 131,072 | 1,073,741,824 B | 8,797,166,764,032 | 525,336,576 | 1,333 bp (13.33%) | No |
| Llama 3.2 3B (28L, q 3072) | 2,818,572,288 | 131,072 | 1,073,741,824 B | 5,773,140,688,896 | 394,002,432 | 2,000 bp (20.00%) | No |
| Qwen3 0.6B (28L, q 2048) | 440,401,920 | 114,688 | 939,524,096 B | 3,848,760,459,264 | 155,582,464 | 5,161 bp (51.61%) | **Yes — the only one** |
| Qwen2.5 Coder 7B (28L, q 3584) | 6,525,288,448 | 57,344 | 469,762,048 B | 6,735,330,803,712 | 544,997,376 | 1,119 bp (11.19%) | No |
| Gemma 4 E2B hybrid (35L; dense part only — PLE projections excluded, J-053 §9) | 1,238,630,400 | 18,432 | 150,994,944 B | 2,390,413,541,376 (see split) | 402,653,184 | 1,906 bp (19.06%) | No |
| OLMoE (16L, q 2048, **routed** MACs) | 1,075,838,976 | 131,072 | 1,073,741,824 B | 2,199,291,691,008 | 103,022,592 (×N on MoE width-1 — F1) | 1,997 bp (19.97%) | No |

- **Causal pairs per layer at 8,192:** 33,558,528 (full causal, N(N+1)/2). Quadratic share vs 4,096: 3.9995× for 2× tokens. Gemma 4's local-layer class (window 512): 4,063,488 pairs/layer. Gemma 4 E2B attention split: 28 local layers = 466,033,311,744 MACs; 7 global layers = 1,924,380,229,632 MACs; total 2,390,413,541,376.
- **Why Qwen3 0.6B alone crosses half:** its projection total is an order of magnitude smaller than the dense 7–8B rows (440,401,920 MACs/token vs 6.5–7.0×10⁹) while its attention total is not proportionally smaller (28 layers × q 2048 over the same 33,558,528 pairs). Dominance at 8k is a ratio of two profile quantities, and small models cross it first. Nothing about this row says a 0.6B prompt is "attention-bound" in wall terms — that is a §7 measurement question.
- **Qwen3.5 row (structural, as in J-053):** same host chunk plans as the dense rows; per-token MACs are file-derived (no pinned profile exists to quote); its DeltaNet layers add a per-row sequential recurrence cost that does not shrink with batch width. Its 8k wall recipe (§7) must report the SSM share separately, or the row is not comparable to the dense rows.

## 4. Part IV's work, in the 8k row

Each slice's filed 8k evaluation, re-read from this tree's test files by `j068_inspect.py` (assertions in the script, not prose):

| Slice | Filed 8k evaluation | What it changes in the 8k row |
|---|---|---|
| J-054 GPU block prefill | Llama 3 8B shape, width 256: 32 chunks, 7,168 batched GEMM calls, 786,432 per-row attention calls, scores 256 MiB at full context | Batching cuts weight re-reads by the chunk width and syncs from one-per-token to one-per-chunk; attention kernel calls stay per-row and dominate the call count ~110:1. A block-prefill wall win, if it comes, comes from weight traffic and sync counts, not attention, until the fused batched-attention kernel (M3) is built. Widths above 4 are UNBUILT in the plan itself. |
| J-055 whole-layer GPU | Width-1 whole-layer dense on GPU already exists (both CUDA sessions run every layer per token, one sync per token); block whole-layer gated by J-054's M1+M2+M5; M3 gates only the long-context ceiling | The 8k width-1 GPU row is executable in shape today; the 8k block row is a plan, not an executor. Faithfulness for block widths above the proven shapes: NOT PROVEN. |
| J-056 split prompt | Accounted verdict: REJECTION where both parents exist (split ties both parents on total MACs and weight-read bytes, by construction); NOT GRADED where the whole-GPU parent is absent | No split 8k row is claimed as a win. The join price (hidden-state boundary transfers, bytes, crossings) is accounted; the live join-cost leg is §7's. |
| J-057 prefill/decode overlap | Accounted verdict: REJECTION on every shape that exists tonight; NOT GRADED on the unbuilt GPU block executor | The imagined stall is not a phase in Aesir's loops (every surface tokenises the whole prompt before stepping). No overlap 8k row is claimed. |
| J-058 MoE prompt on GPU | Planned GPU chunk form SURVIVES under the FULL and expert-cache divisions; width-1 GPU form graded HEAD_ONLY; resident-only split carried as REJECTION | The chunk form pays the head once at 8k: F1 waste 843,858,051,072 MACs → 0. Per-row attention calls and KV bytes conserved across forms. Its 8k case under OLMoE's 4,096 cap is a REFUSAL case in its test file — the chunk form's 8k leg runs on a model whose cap admits it, or not at all. |
| J-059 long-prompt watching | Host-width read at 8,192: 32 chunks, records_expected = 10 (watched: ≥1,024 tokens and ≥4 chunks) | The 8k read's progress surface is priced: 10 boundary records over 32 chunks on the host width. The CLI/server host contracts are recorded; the live leg (records actually emitted during a real 8k read) is §7's. |
| J-060 faithfulness battery | Battery DEFINED, verdict rule PRE-REGISTERED and PROVEN as a pure account; filed grades re-verified through it; live battery DEFERRED | §7's legs grade under J-060's rule: ids first, then teacher-forcing rank + logit gap vs the ggml CPU comparator on the raw prompt (never `llama-cli --single-turn`; near-tie band and step-0 class as standing). |
| J-061–J-065 NPU | J-061 design (host-side, full); J-062 gate brief (gate closed, opened only by Volmarr's recorded decision); J-063/J-064/J-065 each CLOSED-WITH-DEFERRED-REASON on the closed gate | No NPU 8k row exists: no NPU executor, no live copy, no NPU wall/tok/s/prep-time/thermal/faithfulness figure on any silicon. The NPU 8k leg, if the gate ever opens, is a §7 step, not a row tonight. |
| J-066 Vulkan | Written verdict: DEFER (port surface 50 items accounted; spike not run — no Vulkan/CUDA device on the VM, purplelongship NVIDIA + unreachable) | No Vulkan 8k row exists. Reopen needs landed non-NVIDIA hardware + a named consumer (J-066 §7). |
| J-067 iGPU | Account built: kind distinct, budget as an allowance from the ONE system pool (never additive), prefill tax in contended bytes with zero copy bytes, mechanical claim verdict; live leg DEFERRED | An iGPU 8k leg, when an iGPU machine lands, is budgeted against the shared pool with the floor held and priced in contended bytes — and claims no speed win without §7's measurement. No iGPU 8k figure exists tonight. |

**OLMoE stream projection at 8k, SIMULATED:** at the J-030 filed mean rate (32,948,699,136 B / 91 stepped tokens), an 8,192-token prompt projects to 2,966,107,069,473 B — arithmetic only. The file's context cap refuses the run, and the rate comes from a mixed prefill+decode leg, so prompt-only routing may differ. It is filed here so the J-070 gate can grade the §7 leg against it, not as a number any run produced.

## 5. Verification — the inherited figures recomputed, not trusted

Before any suite ran, the continuation worker recomputed every figure in the inherited test file independently in Python from the profile dims and J-053's accounting (pairs = N(N+1)/2; attention MACs = layers × pairs × q_width × 2; share = floored basis points). **All exact, no figure changed:**

- Llama 3 8B: proj 57,174,604,644,352; attn 8,797,166,764,032; share 1,333 bp. 3B tile-4 row: proj 23,089,744,183,296; attn 5,773,140,688,896; share 2,000 bp; passes 2,051 (replayed by the tile loop in the inspect script).
- OLMoE: proj 8,813,272,891,392; attn 2,199,291,691,008; share 1,997 bp; head waste 103,022,592 × 8,191 = 843,858,051,072; chunk-form waste 0.
- Qwen3 0.6B: proj 3,607,772,528,640; attn 3,848,760,459,264; share 5,161 bp (dominates). Gemma 4 E2B: proj 10,146,860,236,800; hybrid attn 2,390,413,541,376 (local 466,033,311,744 + global 1,924,380,229,632); share 1,906 bp. Coder 7B: proj 53,455,162,966,016; attn 6,735,330,803,712; share 1,119 bp.
- Windowed pairs: 512 × 8,192 − 512 × 511 / 2 = 4,063,488. Stream projection: 8,192 × 32,948,699,136 // 91 = 2,966,107,069,473 B.
- The inspect script's re-run output is byte-identical to the filed `j068_inspect_output.txt` (diff clean), including its profile-cap reads from this tree and its three Part IV test-file assertions (J-054, J-058, J-059).

**No defect was found in the inherited module or test file.** The inherited code's refusal discipline (7/7 invalid-input refusals) and the module's docstring contract (exactly 8,192 tokens; shapes from the opened model's own profile) both behave as stated.

## 6. Tests (PROVEN, VM, lightest target)

Filed as `j068_test_output.txt` (build recipe and machine state in its header):

- **`test_prefill_at_8k` (new): 7/7 groups PASS** — host-batched Llama 3 8B row at 8,192 (share 1,333 bp); width-1 passes 8,192 / tile-4 passes 2,051; MoE width-1 row with F1 head waste exact and chunk-form waste zero; attention shares per arch with dominance per-arch; sliding-window pairs 4,063,488; context verdicts (OLMoE refused, Llama exact-fill with reserve → no-generation-room, Qwen fits); 7/7 invalid-input refusals.
- **Neighbours rebuilt from this tree and re-run:** `test_prefill_anatomy` (J-053) **8/8 PASS**; `test_igpu_account` (J-067) **11/11 PASS** — the 8k account changes no existing module (it is additive; no existing module was modified). Registration in `tests/run_all.mojo` is **not** done here, for J-031 §10's stated reason (the branch line's counted-run pin cannot be re-accounted without the counted run, which belongs to an on-box leg).

## 7. The live legs — DEFERRED-WITH-REASON, exact recipe

**Why no live leg ran (stated plainly):** the VM is far below the 5,500 MB inference gate (MemAvailable ~0.67–1.08 GB) and has no GPU of any kind; purplelongship is unreachable tonight (204 road: device offline, last seen 2026-11-01T02:07:13Z) and is yielded to the 204 road's S-103 in any case. A wall, tok/s, or faithfulness figure produced without a device-capable machine would be fabricated, so none is. **This is the J-053 §7 recipe specialised to 8,192 tokens and Part IV's work — run it on purplelongship in a quiet window, or on any device-capable machine, exactly as written, and re-cite it at the J-070 Part IV gate either way:**

1. **Gate checks first:** read the 204 road's heartbeat (`~/workspace/model-tests/ROADMAP_204_STATE.md`) and confirm no live run on the box; record loadavg, Tctl, MemAvailable, GPU idle (VRAM ~1 MiB) at leg start and end. One heavy run at a time. Fetch branch `yrsa/janas-j068` on-box by git; verify the tree sha matches the banked tip.
2. **Models (sha-pinned, no substitutions):** the wave-pinned Llama 3.2 3B, Qwen3-0.6B, and Gemma 4 E2B files from the laptop's model store (record each file's full sha256 in the leg output before running — a wall without its pin is not a baseline cell); OLMoE-1B-7B Q4_K_M, sha256 `8c310f14…f3f` (full pin in J-015/J-022), for the refusal leg only — its 8,192 cell stays REFUSED-BY-CONTEXT, and its live leg runs at 4,096 minus generation.
3. **Prompt shapes:** deterministic prompts of **exactly 8,192 tokens**, produced by encoding fixed prose with the model's own tokenizer and truncating/extending by repetition to the exact count; file the token-id lists with the leg. Raw prompts only — no chat template on the graded legs (template rendering is a comparator artifact class, never a graded input).
4. **Context refusals (do not force):** OLMoE at 8,192 is REFUSED-BY-CONTEXT (file context 4,096); Llama 3 CUDA at 8,192 is REFUSED-BY-CONTEXT on the session fit check (prompt + response must fit the 8,192 cap) — its 8,192 wall, if wanted, is a *host-surface* leg at exactly context length, labelled as such; Qwen3 at 8,192 fits with generation room under its 32,768 cap.
5. **Runs, per (arch, surface):** host legs with `AESIR_PREFILL_BATCH` ∈ {256, 1} (both rows — the cap is a graded variable); CPU legs under `CUDA_VISIBLE_DEVICES=` stated in the log; CUDA legs on the admitted profiles only (tile-4 only where `effective_prefill_batch` admits it); the J-058 chunk form leg on a cap-admitting MoE model if one exists by then, else the chunk form stays unexecuted and its 8k row stays accounted-only; the J-059 watching leg records the actual boundary-record count during a real 8k read against the priced 10. Three repetitions per cell, median filed with all three raw walls; per cell record **prefill wall** (tokenize→last prompt position filled), **first-token latency** (prompt start→first sampled token, i.e. fill + one head + sampler), and decode wall for 24 generated tokens as the separation witness. Generate with greedy/temperature-0 settings matching the comparator leg.
6. **Grading (raw-oracle discipline, J-060's battery):** ids first — generated ids must equal the same-surface per-token run's ids token for token, or the cell is a defect report, not a number. Then teacher-forcing rank + logit gap against the ggml **CPU** comparator on the raw prompt (never `llama-cli --single-turn`; CPU-vs-CPU comparator only; step-0 boundary effects named as their own verdict class, per J-060's charter). The 8k attention-share table (§3) is graded against the measured walls as a *reading* of the wall, never as the wall itself: a wall that contradicts the MAC split by more than the stated exclusions (J-053 §9: norms, RoPE, biases, sampler, embeddings, dequantisation, Gemma 4 PLE projections, Qwen3.5 DeltaNet recurrence) is a finding, not a rounding.
7. **Filing:** walls land in an addendum doc on the measuring slice's branch with machine state per run; cells measured under loadavg > 2 sustained or Tctl > 85 °C are classed MEASURED-INDICATIVE and do **not** fill the baseline — the cell stays deferred until a quiet run fills it. The J-070 gate re-cites this section's deferred legs in full, with the J-058 chunk-form, J-059 watching-count, J-067 iGPU-budget, and (if the gate has opened) J-061–J-065 NPU items each answered or re-deferred on their own evidence.

## 8. Findings and defects

- **J-053 §3.4 prose corrected (numbers unchanged):** the sentence claiming attention MACs "overtake projection MACs between 1,024 and 4,096 tokens on every profile" is contradicted by J-053's own §5 numbers and by this slice's re-derivation — at 8,192, five of six filed profiles are still projection-dominated (11–20% attention share), and only Qwen3 0.6B crosses half. The J-053 table's numbers were never wrong; the sentence over-generalised them. This doc follows the numbers, and the J-070 gate's concordance should carry the correction so no later slice re-quotes the sentence. No J-053 file was edited in this slice (prior slices' docs are not rewritten by later slices; the correction lives here, cited by number).
- **No defect found in the inherited J-068 code or tests:** all figures recomputed exact (§5), all suites PASS first run (§6), the inspect re-run byte-identical. The first worker's stall cost time, not correctness — the inherited files were complete and sound.
- **One pre-existing build warning, recorded not hidden:** building `test_igpu_account` emits a docstring-style warning on its line 1 (lowercase summary start). It is a warning on a J-067 file, not an error, and not this slice's to fix silently — the J-070 concordance may carry it as a one-line tidy, or leave it; it affects no number.
- **No defect found in the Part IV accounts re-read for §4:** J-054's 7,168 / 786,432 figures, J-058's 8k refusal case, and J-059's 32-chunk / 10-record figures all assert exactly in this tree's test files (the inspect script's assertions).

## 9. Answered-locally / exclusions (clean-room)

- No Janas material was consulted; every quantity above derives from Aesir's own tree, profiles, and filed measurements. Nothing was answered from Janas documentation, so no clean-room question arose in this slice.
- **Stated exclusions from the §3 MAC accounting** (inherited from J-053 §9, so the table is never over-read): Gemma 4's per-layer-input projections and post-norms (a real per-token cost on both its surfaces, uncounted here — the E2B proj row is a lower bound); Qwen3.5's DeltaNet recurrence + conv (sequential per row); norms, RoPE, biases, and sampler cost on all rows (small, per-token, surface-similar); embedding lookups (row reads); quant dequantisation (priced by *passes* in J-053 §3.3's weight-traffic shape, not by MACs).

## 10. NOT PROVEN list

- **Every 8,192-token prefill wall / tok/s / first-token latency, on every arch and surface** — DEFERRED-WITH-REASON to §7's recipe (VM below the inference gate; purplelongship unreachable and yielded). The §3 table is arithmetic, not a measurement, and must never be quoted as a wall.
- **Every 8,192-token faithfulness grade** (ids-first agreement, teacher-forcing rank/gap) for any new leg — DEFERRED-WITH-REASON to §7 step 6 under J-060's battery. The only faithfulness evidence in the record remains the prior legs re-cited in J-053 §6 (OLMoE 67-token legs, ids + counters identical across three legs).
- Per-phase wall splits at 8k (how much of any real wall is attention vs projections vs stream vs head) — no instrumentation exists to measure them (J-053 F3; J-059's progress layer prices records, not phases).
- Batched-vs-per-token bit-identity **on this tree state at 8,192 tokens** (stated in `forward_pass_batched`'s docstring, proven on earlier trees; §7's ids-first grading re-proves it per leg).
- The MoE stream projection's prompt-only accuracy at 8k (the rate comes from a mixed prefill+decode leg; prompt-only routing may differ) — and, a fortiori, any 8k MoE wall, since the cap refuses the run.
- Qwen3.5 pinned quantities at 8k (no fixed profile exists in the tree to pin them to).
- Any NPU prefill quantity at 8k (the Hailo is parked; J-062's gate is closed; J-063–J-065 are deferred on it).
- Any Vulkan or iGPU 8k wall/tok/s/faithfulness figure (J-066 DEFER; J-067 live leg deferred; no such backend or machine in hand).
- That the 8k attention-share table predicts any measured wall's split — the split is a MAC ratio; walls add weight traffic, sync counts, dequantisation, and (on MoE) stream bytes, all of which §7 grades separately.

## 11. Banking

Filed on branch `yrsa/janas-j068` (worktree `~/workspace/aesir-janas-j068`, base `8e05ff6c`): `docs/janas/J068_PREFILL_AT_8K.md` (this doc), `docs/janas/j068_inspect.py`, `docs/janas/j068_inspect_output.txt`, `docs/janas/j068_test_output.txt`; in the tree: `aesir_engine/core/prefill_at_8k.mojo` (new accounting module) and `aesir_engine/tests/test_prefill_at_8k.mojo` (7 groups). **No existing module was changed.** Campaign copies of the doc + evidence files in `~/workspace/model-tests/janas/`, sha-identical. Push by explicit refspec, foreground, with `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6`; the commit hash and ls-remote lines are recorded in the campaign state entry for J-068 and the slice worker's report (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
