# J-088 — 8-Bit KV

**Slice:** J-088 (Part VI — Long Context and the 8-Bit KV, J-087–J-098), Project Aesir Janas clean-room road.
**Roadmap text:** "8-bit KV. Keys and values stored at 8 bits with per-row/per-channel scales (the shape Janas documents), as an engine option beside the existing precision; dequant cost measured inside attention."
**Executed:** 2026-11-01 from ~11:46 EST, in fresh worktree `~/workspace/aesir-janas-j088` on branch `yrsa/janas-j088`, from the verified tip of `yrsa/janas-j087` (`09bc5552ede24e49fc3dccd3b49c55e2eb49b060`). Origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5` (ls-remote verified at banking, §10). The J-087 worktree was not worked in.
**Machine state (VM, stated for every number below):** KVM, 4 vCPU, kernel 7.0.0-39-generic. MemAvailable ~2.5–3.1 GB during builds and 1.4–2.7 GB during bench runs — **below the 5,500 MB inference gate at every moment**, so no model inference ran anywhere; lightest compiles only, one at a time. The VM was **contended throughout** (load average 3.4–13.0 on 4 vCPU from other campaigns); every wall below carries that weather and is labelled accordingly. purplelongship was **not used at all** — unreachable (last_seen 2026-11-01T02:07:13Z) and owned by the 204 road when it returns. /tmp healthy.
**Clean-room record:** the design is taken from J-087's census of Aesir's own tree plus the roadmap's one-line shape ("per-row/per-channel scales", Janas's documented behaviour as recorded in Part I). No Janas material was consulted in this slice and no Janas source code was opened, in this slice or any other.

---

## 1. The design, stated up front

**Question.** Build the 8-bit KV J-087 priced: keys and values at 8 bits with scales, beside the existing f16 precision (and the one f32 path), selected by an explicit option, with quantize-on-append and dequantize-inside-attention — and measure what the dequant costs inside attention and what the quantization costs in faithfulness, on synthetic data at module level.

**Choices (the module header of `core/kv_int8.mojo` records the same):**

- **Scale shape — per-row is built; per-channel is priced and refused at use.** One f32 scale per (layer, K-or-V, kv-head, **position**) row, covering that row's `head_dim` elements, `scale = maxabs / 127`. This is exactly the shape J-087 §7 projected, so the built store's price must reproduce J-087's **67,584 B/token** for the Llama 3 8B shape mechanically — and it does (§5), because the module's accounting is *defined through* `kv_account.mojo`'s projection function: the two cannot drift apart. The per-channel shape (one f32 scale per (layer, K/V, kv-head, channel), paid **once** for the whole cache) is priced by a separate accounting function, but it is **not built**: a channel scale cannot be known at append time without a calibration pass, so building it honestly belongs to J-090's mixed-discipline work. A resolved selection naming int8 + per-channel is **refused at use with the reason**, never silently run as per-row.
- **Layout mirrors the host cache** (J-087 §3.1): K and V in separate buffers, row-major `[layer][position][kv_width]`; scales in separate buffers `[layer][position][kv_head]` per tensor. Fixed capacity: append raises past capacity — no wrap, no eviction, exactly the host shape. A later session integration therefore changes element type and append/read paths, not geometry.
- **Semantics.** `append()` quantizes on append — the original values are never stored. The attention path dequantizes **inside** its score and output loops, element by element as each K/V element is consumed; no dequantized row is materialised by attention. `read_k`/`read_v` (whole-row dequantize) exist only as the grading/test surface for J-089 and are labelled as such in the code.
- **The option surface, in the road's established shape (J-036/J-083):** `--kv-precision f16|int8` (env `AESIR_KV_PRECISION`) and `--kv-scale per-row|per-channel` (env `AESIR_KV_SCALE`); precedence cli > env > default; **the default is f16** — an int8 default would silently change every faithfulness grade the tree stands on. Scan/resolve/validate live in the new module; both `--flag value` and `--flag=value` forms are accepted; unknown flags inside the `--kv` namespace, missing values, and duplicates are refused by name.
- **Scope, honestly bounded.** No live session's execution code changes in this slice. J-087 found three distinct live layouts (host f16, dense CUDA f16, Gemma 4 CUDA f32); wiring any of them to int8 storage without a live run to exercise it — impossible under this tick's machine limits (VM below the inference gate, purplelongship unreachable) — would be claiming an integration that was never run. What is built and proven is the real component: store + quantizer + option surface + accounting + an attention exercise that runs the dequantize-inside-attention path end to end. The exact session-integration recipe is filed in §7 for J-089/J-098 to re-cite.

## 2. Verdict for this slice

**The 8-bit KV exists as a real, tested engine component (PROVEN at module level).** `core/kv_int8.mojo` provides the int8 store with per-row f32 scales, quantize-on-append, dequantize-inside-attention, the `--kv-precision`/`--kv-scale` option surface beside f16, and accounting that **reproduces J-087's baseline exactly** (8B shape 67,584 B/token = 0.5156 × f16, scales priced, §5). Faithfulness on deterministic synthetic vectors is measured (§5): K/V round-trip max error **0.003937** — exactly half the largest row scale, the quantizer's bound, over 524,288 elements — and attention-output deviation max **0.002343** vs the unquantized reference. Dequant cost inside attention was measured three times (§5): the int8/reference wall ratio came out **0.977 / 1.718 / 0.849** — under this VM's contention that spread is machine weather, so **no stable dequant-overhead figure is claimed**; the honest reading is that the cost is not separable from noise at this shape on this machine in this tick, and §7 files the clean re-measurement. Unit tests **8/8 groups PASS**; the J-087 neighbour suite rebuilt from this tree **10/10 PASS**; inspect **30/30 PASS** (§6). **Live-session integration is DEFERRED-WITH-REASON** (§7), and teacher-forcing faithfulness grading is J-089's, untouched here. No defect was found in prior work (§8).

## 3. Inspection — the paths J-087 left (PROVEN from the tree)

From J-087's census (§§3–4 of its doc, re-read first-hand this slice): the **host KVCache** (`core/mimir_well.mojo`, f16, two separate `[layer][position][kv_width]` tensors, fixed capacity) serves every host session; the **dense CUDA** cache is one f16 device buffer (per-layer K block then V block); the **Gemma 4 CUDA** cache is **f32** per owning layer with 512-slot local rings — the path where int8 saves most (4 bytes → 1 per element, priced in §5); `PagedKVCache` wraps the host cache and has no production user. J-087 §3.5: no 8-bit KV existed anywhere. This slice adds the component beside all of them and changes none of them — the inspect script asserts mechanically that no session/execution file imports `core.kv_int8` in this tree (§6), so the deferred state is a checked fact, not a claim.

## 4. What was built

**`aesir_engine/core/kv_int8.mojo`** (new; pure-module pattern of `core/kv_account.mojo` / `core/expert_cache.mojo` — no device opened, no session touched):

- **The quantizer:** `kv8_row_scale` (maxabs/127; a zero row stores scale 1.0 and all-zero codes and round-trips exactly), `kv8_quantize` (round-to-nearest, clamped to [−127, 127], never wrapping), `kv8_dequantize`.
- **`Int8KVStore`:** separate `List[Int8]` K/V buffers + separate `List[Float32]` scale buffers in the host layout of §1; `append` (quantize-on-append, per-head scales), `read_k`/`read_v` (grading surface), `bytes_per_token()`/`total_bytes()` computed from the store's own buffers and pinned equal to the accounting functions in the tests.
- **Attention:** `attention_int8_head` — single-head attention over the store with dequantization inside both loops (score dot-product and output mix), max-subtracted softmax, 1/√head_dim score scale (the tree's form); `attention_f32_head` — the identical math over plain rows, the unquantized reference the int8 path is exercised against.
- **Accounting:** `kv8_bytes_per_token` (defined through J-087's `kv_int8_projected_per_token`, so the census and the component cannot drift), payload/scales splits, totals, `kv8_per_channel_total_bytes` (the priced-not-built shape), and savings vs the f16 and f32 baselines.
- **The option surface:** `scan_kv_args`, `kv_env_inputs`, `resolve_kv_precision` (cli > env > default f16), `validate_kv8_selection` (f16 always usable; int8+per-row usable; int8+per-channel refused at use with the reason).

**`docs/janas/j088_bench.mojo`** (new): the measurement harness of §5 — fixed shape (1 layer, 8 kv-heads, head_dim 128, 256 positions), deterministic synthetic values that are multiples of 1/8 in [−1, 1] and therefore **exactly representable in f16**: the reference rows hold exactly the values an f16 cache would hold, so the exercise compares int8 against the f16 path's values, computed by the module's unquantized reference attention (f32 containers — the container width difference is stated in §5's reading). No existing module was modified. Registration in `tests/run_all.mojo` is **not** done, for J-031 §10's stated reason (the branch line's counted-run pin cannot be re-accounted without the counted run).

## 5. Numbers

### 5.1 Accounting — closes against J-087 (exact arithmetic, PROVEN as arithmetic)

Per-row int8: payload = layers × 2 × kv_heads × head_dim × 1 B; scales = layers × 2 × kv_heads × 4 B per token. No other per-token metadata exists in the store (the struct's fields are O(1) in context — the census convention of J-087).

| Shape (J-087 §4) | f16 B/token | **int8 B/token** | Ratio | Saving vs f16 | int8 total @ cap |
|---|---|---|---|---|---|
| Llama 3 8B (32×8×128) | 131,072 | **67,584** | 0.5156 | 63,488 | 553,648,128 @8,192 (f16: 1,073,741,824) |
| Llama 3.2 3B / Qwen3 0.6B (28×8×128) | 114,688 | **59,136** | 0.5156 | 55,552 | 484,442,112 @8,192; 1,937,768,448 @32,768 (Qwen3 cap) |
| Qwen2.5 Coder 7B (28×4×128) | 57,344 | **29,568** | 0.5156 | 27,776 | 968,884,224 @32,768 |
| OLMoE (16 layers, kv_dim 2048 as 32×64) | 131,072 | **69,632** | 0.5312 | 61,440 | 285,212,672 @4,096 |

The 8B row **reproduces J-087 §7's projection exactly** (65,536 payload + 2,048 scales = 67,584) — the identity is pinned in the unit tests against `kv_account.mojo`'s own projection function, and re-derived independently by `j088_inspect.py`. The OLMoE ratio differs because its head geometry (64-wide heads) carries relatively more scales.

Against the **f32** baseline (the Gemma 4 CUDA path's precision): the 8B shape at f32 costs 262,144 B/token, so int8 would save **194,560 B/token** there (ratio 0.2578). Priced for Gemma 4's own global-owning sub-shapes (the only parts that grow per token on that path): E4B global (4 layers × 2 heads × 512) f32 32,768 → int8 **8,256** B/token; E2B global (3 × 1 × 512) f32 12,288 → int8 **3,096** B/token. These are sub-shape prices, not Gemma totals — the local rings are fixed costs whose int8 form belongs to the deferred kernel integration (§7).

**Per-channel (priced, not built):** the 8B shape's scale table is 262,144 B paid once; total at 8,192 = **537,133,056 B** (vs per-row 553,648,128) — the per-channel shape wins at long context and loses at short (at 1 token it costs 327,680 B vs per-row's 67,584), which is the trade J-090 will grade.

### 5.2 Faithfulness exercise — synthetic vectors (MEASURED, VM, deterministic)

From `j088_bench.mojo` (filed in `j088_test_output.txt`; **byte-identical across all three runs** — the exercise is deterministic):

- **K/V round-trip** (quantize-on-append → dequantize, every stored element of the bench shape): 524,288 elements, **max abs error 0.003937006, mean abs error 0.001852707**. The max is exactly scale/2 for the widest rows (scale = 1/127 ≈ 0.007874) — the quantizer sits at its theoretical bound, neither better nor worse.
- **Attention output** (int8 path vs unquantized reference, all 8 heads × 128 dims): **max abs deviation 0.0023426115, mean abs deviation 0.0011660500** over 1,024 outputs.

These numbers bound the **quantizer and the attention exercise on synthetic data only**. They are not a faithfulness grade of any model: that is J-089's teacher-forcing rank/gap work under the raw-oracle discipline, and nothing here substitutes for it.

### 5.3 Dequant cost inside attention — measured, honestly unstable (MEASURED-INDICATIVE)

One attention step = one query token attending over 256 positions × 8 kv-heads at head_dim 128; 20 warmup steps, then 200 measured steps per path, same process, same synthetic data:

| Run | Machine state | int8 ns/step | reference ns/step | Ratio |
|---|---|---|---|---|
| 1 | load 11.35/8.22/7.05, MemAvailable 2,600,496 kB | 4,421,193 | 4,522,309 | 0.977 |
| 2 | load 4.32/7.48/7.06, MemAvailable 1,534,500 kB | 14,540,057 | 8,459,273 | 1.718 |
| 3 | load 3.44/7.07/6.94, MemAvailable 1,446,476 kB | 11,319,690 | 13,324,916 | 0.849 |

The per-step walls themselves move ~3× between runs — contention from other campaigns dominates everything at this shape. **Verdict: the dequant cost is NOT separable from machine weather on this VM in this tick (NOT PROVEN as a stable figure).** The indicative reading, no more: across three runs the int8 path landed between 0.85× and 1.72× of the reference (median ≈ 0.98), i.e. there is no evidence of a large dequant penalty at this shape, and no honest basis for claiming parity or a speedup either. Two stated caveats: the reference computes over f32 containers (4 B/element reads) while a live f16 cache reads 2 B/element, so a live comparison could shift against int8 by the read-width difference; and this is a scalar module-level loop, not any session's kernel. The clean re-measurement is filed in §7.

## 6. Tests and inspect (PROVEN, VM, lightest target)

Filed as `j088_test_output.txt` (build recipe and machine state in its header):

- **`test_kv_int8` (new): 8/8 groups PASS** — codes/names; accounting reproducing J-087 (incl. the identity against the census projection function, per-shape pins, totals at caps); per-channel accounting; quantizer bounds (round-trip ≤ scale/2, row max exact at code 127, clamping, zero row exact); store append/read with buffer accounting closing; the attention exercise (within 0.05 of the reference; the bench measures the true deviation at 0.0023); the option surface (default f16, cli > env > default, both flag forms); refusals (8 cases incl. int8+per-channel at use and the typo'd-flag refusal).
- **Neighbour rebuilt from this tree:** `test_kv_account` (J-087) **10/10 PASS** — unchanged.
- **Inspect: `j088_inspect.py` — 30/30 checks PASS, exit 0** (filed with its output): store/quantizer/attention structure grepped from the module; option names and the f16 default grepped; every §5.1 figure recomputed in Python from the census shapes and checked against both the test pins and J-087's filed projection; the deferred-integration fact asserted (no session/execution file imports the module — the check searches import-shaped references only; its first, looser form's two hits were J-087's own `kv_int8_projected_per_token` name, adjudicated as false positives and recorded in the script, §8).

## 7. Deferred leg — session integration + clean dequant measurement (DEFERRED-WITH-REASON; recipe for J-089 / J-098 to re-cite)

**Why deferred:** the VM stayed below the 5,500 MB inference gate all tick (MemAvailable 1.4–3.1 GB) and purplelongship is unreachable and owned by the 204 road when it returns — no live session run was possible on any box, and an unexercised session integration must not be claimed (the J-031/J-067 precedent this road has followed throughout).

**The recipe, in dependency order:**

1. **Host path first** (smallest, safest): add an int8 variant beside `KVCache` in `core/mimir_well.mojo` wrapping `Int8KVStore`'s layout (or generalise the store into the well), selected where sessions construct their cache — the construction sites are J-087 §3.1's table (`aesir.mojo` generation, `inference.mojo` forward_pass, `moe_session.mojo`, `llama3_spill.mojo`). The host attention readers (`get_k_slice`/`get_v_slice` consumers) switch to dequantize-inside-attention per head, in `attention_int8_head`'s form. The option reaches construction through `resolve_kv_precision` (one resolver for CLI and server, per the module's host contract).
2. **Then the dense CUDA path:** the device buffer becomes int8 + a scales buffer in the per-layer K-block/V-block layout; `llama3_kernels`' cache store/attention kernels dequantize in-kernel. Grade per J-060's prefill battery form.
3. **Then Gemma 4 CUDA (the biggest saving, §5.1):** the f32 cache buffer becomes int8 + scales, local rings included (ring slot arithmetic unchanged — it indexes rows, and each row gains its scale); `gemma4_kernels`' `cache_kernel` quantizes on write and its attention kernel dequantizes inside.
4. **Grading gate for every path:** J-089's teacher-forcing rank + logit gap, 8-bit vs this census's f16 baseline, on the raw prompt, CPU engine vs CPU comparator — never `llama-cli --single-turn`. A path whose grade fails does not ship as an option; it ships as a recorded refusal.
5. **Clean dequant-cost re-measurement:** re-run `j088_bench.mojo` (a) on the VM in a verified idle window (load < 1, MemAvailable stated) and (b) on purplelongship behind the 204-road heartbeat check, 3 runs each, median filed; then the same measurement inside a live session's attention (step 1's path) at 1k/4k/8k positions for J-091's ladder. Only those numbers may replace §5.3's indicative range.
6. **Registration:** with a counted run on a live path, register `test_kv_int8` in `tests/run_all.mojo` and re-account the pin (J-031 §10's rule).

## 8. Defects found

- **No defect found in prior work.** J-087's baseline reproduced exactly on every figure this slice grades against (§5.1, §6); `kv_account.mojo`'s accounting and J-087's test wording ("int8 is projection-only") describe that module's own scope, which this slice extends rather than contradicts — `kv_account` remains the census, `kv_int8` is the component, and the component's price is defined through the census so the two cannot disagree.
- **Own-work defect, found and fixed in-slice:** `j088_inspect.py`'s first deferred-integration check searched the bare string `kv_int8` and flagged `core/kv_account.mojo` + `tests/test_kv_account.mojo` — both name J-087's `kv_int8_projected_per_token`, not this module. The check was tightened to import-shaped references, the false positives and their adjudication are recorded in the script itself, and the final inspect passes 30/30. No filed number rested on the loose form.

## 9. NOT PROVEN list

- **Any live-session behaviour of the int8 KV** — no session constructs, appends to, or attends over the int8 store in a running model anywhere; the integration is DEFERRED-WITH-REASON with the §7 recipe. No tok/s, wall, or memory figure for any live path is claimed.
- **A stable dequant-cost figure** — §5.3's three runs spread 0.849–1.718 under contention; the cost is not separable from machine weather on this VM in this tick. The clean re-measurement is §7 step 5.
- **Model faithfulness of 8-bit KV** — §5.2 bounds a quantizer on synthetic vectors. Teacher-forcing rank/gap of a real model at 8-bit vs f16 KV, and the context lengths where 8-bit starts to cost truth, are J-089's whole question and are NOT PROVEN here in either direction.
- The per-channel scale shape as a working store (priced in §5.1, refused at use; building it needs a calibration story — J-090's question), and the mixed-precision layout (J-090).
- That a running process's resident bytes match §5.1's totals byte-for-byte (allocation arithmetic, PROVEN as arithmetic; live memory measurement belongs to J-091/J-093).
- Any GPU/NPU KV behaviour at int8 (the CUDA integrations are §7 steps 2–3; the Hailo stays parked and untouched by law).
- Janas's published 8-bit/long-context numbers as evidence about Aesir — none are cited as such anywhere in this slice.

## 10. Banking

Filed on branch `yrsa/janas-j088` (worktree `~/workspace/aesir-janas-j088`, base `09bc5552`): `docs/janas/J088_8BIT_KV.md` (this doc), `docs/janas/j088_inspect.py`, `docs/janas/j088_inspect_output.txt`, `docs/janas/j088_test_output.txt`, `docs/janas/j088_bench.mojo`; in the tree: `aesir_engine/core/kv_int8.mojo` (new) and `aesir_engine/tests/test_kv_int8.mojo` (8 groups). **No existing module was changed.** Campaign copies of the doc + evidence in `~/workspace/model-tests/janas/`, sha-identical (verified by hash). Push by explicit refspec `git push origin HEAD:refs/heads/yrsa/janas-j088`, foreground, with `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`; the commit hashes and ls-remote lines are recorded in the campaign state entry for J-088 and the slice worker's report (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
