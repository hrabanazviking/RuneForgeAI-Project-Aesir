# J-087 — KV Precision Census (Aesir)

**Slice:** J-087 (Part VI — Long Context and the 8-Bit KV, J-087–J-098), Project Aesir Janas clean-room road.
**Roadmap text:** "KV precision census (Aesir). What Aesir's KV cache costs today per token per arch (bytes, layout, precision), measured from the tree; the baseline."
**Executed:** 2026-11-01 ~11:4x–12:1x EST, in the reserved worktree `~/workspace/aesir-janas-j087` on branch `yrsa/janas-j087`, from `yrsa/janas-j086` tip `e4c0f14c73ce6dfd744b1580a6e11ed3dd34d000` (verified clean at slice start; no remote `yrsa/janas-j087` existed before this slice). Origin/main untouched at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5` (ls-remote verified at slice start and at banking, §10). A previous J-087 worker was cancelled before producing anything; this execution started clean from the verified base and looked for no remains.
**Machine state (VM, stated for every number below):** KVM, 4 vCPU, kernel 7.0.0-39-generic. MemAvailable 612,012 kB at the inspect run, ~1.84 GB during the builds — **far below the 5,500 MB inference gate at every moment**, so no inference ran anywhere; lightest compiles only, one at a time. purplelongship was **not used at all** — unreachable (last_seen 2026-11-01T02:07:13Z) and owned by the 204 road when it returns, yielded to under the coordination law. /tmp healthy (~3 % used). No live memory measurement is claimed anywhere in this slice: every number is exact arithmetic over constants parsed from this tree, re-derived by `j087_inspect.py` (43/43 checks PASS, §6).
**Clean-room record:** this census is about Aesir's own tree; no Janas material was consulted or needed. No Janas source code was opened, in this slice or any other.

---

## 1. The question — and the one correction it carries

**Question.** Before Part VI builds an 8-bit KV (J-088), what does Aesir's KV cache actually cost today — per token, per architecture — in bytes, in what layout, at what precision? The answer must come from the tree's own constants and storage declarations, so J-088's saving (and its cost in truth, J-089) can be graded against a baseline that cannot drift.

**The correction.** Part I's gate recorded, as a headline finding, that **"Aesir's KV is f16."** Verified from the tree, that statement is **true of every KV path except one — and the exception is a whole session family**:

- Host KV everywhere, and the dense CUDA sessions' KV, are **f16** (§3.1, §3.2).
- The **Gemma 4 CUDA session's KV is f32** — its cache buffer is `DType.float32` (`core/gemma4_cuda.mojo:114`), its kernels read/write it as `Floats`, and the memory planner prices it at 4 bytes/element (`core/inference_memory.mojo:159`). Per element it costs exactly twice the f16 paths, and J-088's honest saving on that path is therefore twice as large as the headline suggests.

Any later citation of Part I's headline should carry this slice's correction: *Aesir's KV is f16 except the Gemma 4 CUDA cache, which is f32.*

## 2. Verdict for this slice

**The census is COMPLETE from the tree and is now executable.** Every KV storage in the engine is inventoried in §3 (four storages, three layouts, two precisions — and a fifth storage, `PagedKVCache`, that no session uses). Per-architecture per-token prices and cap totals are tabled in §4 with their arithmetic shown. A new pure accounting module, `core/kv_account.mojo` (§5), pins the census in code with a mechanical claim verdict; its suite passes 10/10 and the neighbours hold (§6). §7 states the exact baseline J-088 is graded against, including the 8-bit projection with its scale bytes priced (0.5156 of the f16 price for the 8B shape, not the naive 0.5). **One defect was found in prior work** — J-053's filed Llama 3.2 3B KV figure is wrong against its own profile — corrected on this record and pinned in the new suite (§8). Nothing live was measured, and §9 says so plainly.

## 3. Inspection — every KV storage in the tree (PROVEN from the tree)

All references are this tree's, read first-hand this slice; the structural facts are machine-checked by `docs/janas/j087_inspect.py` (§6).

### 3.1 The host cache — one cache for every host session

`core/mimir_well.mojo:882` `struct KVCache`: `k` and `v` are two separate `RuneTensor[f16]` buffers (`:889`), each allocated `num_layers × max_seq_len × hidden_dim` elements from the MimirWell, where the parameter named `hidden_dim` is in every caller the model's **kv_dim** (`GGUFModelConfig.kv_dim()` = head_dim × head_count_kv, `loader/gguf.mojo:229`). Layout is row-major **[layer][position][kv_width]**: `append` writes at offset `(layer_idx × max_seq_len + pos) × hidden_dim` (`:967`ff). K and V are **not interleaved**; the two tensors are separate allocations. The cache is **fixed-capacity**: `append` raises at `pos >= max_seq_len` (`:981`) — no wrap, no eviction, no truncation; every forward path likewise raises rather than truncating (the CUDA chat paths state it in words: "history was not truncated").

Callers (each takes this one cache, at the file's own geometry):

| Session / path | Construction | Layers sized | Context sized |
|---|---|---|---|
| Engine generation (all host archs) | `aesir.mojo:1172` | `block_count` (all) | `min(16000, file context)` — `MAX_RUNTIME_CONTEXT` (`aesir.mojo:32`) |
| `forward_pass` overload | `core/inference.mojo:1399` | caller's `num_layers` | file context (default 2048), capped at 16,000 (`inference.mojo:1394`) |
| Streamed MoE session (OLMoE) | `core/moe_session.mojo` KVCache construction | `block_count` (16) | caller-stated (J-022 legs: 512; file cap 4,096) |
| Spill tail (Llama 3 split) | `core/llama3_spill.mojo` | `block_count` (all — see §3.4) | caller-stated |
| `PagedKVCache` | `core/mimir_well.mojo:1054` | wraps a `KVCache` | page pool, default block 16 tokens (`:1084`) |

`PagedKVCache` is a page-table layer over the **same f16 storage** (physical pages never move; sequences map logical→physical blocks). Census fact: **no production session uses it** — in this tree it appears only in `mimir_well.mojo` and its tests (inspect-verified). It changes no per-token price where it would be used (same elements, plus page-table metadata).

Per-token price (uniform shape): **layers × 2 (K+V) × kv_heads × head_dim × 2 bytes**.

### 3.2 The dense CUDA cache — f16, K-block-then-V-block per layer

`core/llama3_cuda.mojo:244`: one device buffer, `enqueue_create_buffer[DType.float16](kv_elems)`, with `kv_elems = profile.kv_elements(context)` = layers × 2 × context × kv_width (`core/dense_gqa_profile.mojo:88`). Layout differs from the host's: **per layer, a K block of context × kv_width followed by a V block of the same size** (layer offset `layer × 2 × context × kv_width`, `llama3_cuda.mojo` layer step; `core/llama3_kernels.mojo:129` `llama_cache` stores K at `pos × width` and V at `+ capacity × width` inside the layer's span). The session serves **every** `DenseGQAProfile` (Llama 3 8B, Llama 3.2 3B, Qwen3 0.6B, Qwen2.5 Coder 7B), admitted at the profile's `context_cap`. Activations in this session are f32; the KV is not — it is f16, priced identically per token to the host cache. The memory planner agrees: `inference_memory.mojo:141` prices dense KV at `kv_elements × 2`.

### 3.3 The Gemma 4 CUDA cache — the f32 exception, ring-capped local layers

`core/gemma4_cuda.mojo:114`: one device buffer, `enqueue_create_buffer[DType.float32](cache_elements)`. Only **owning** layers get storage (the last `shared_kv_layers` read an owning layer's KV): the constructor packs per-owning-layer spans (`gemma4_cuda.mojo:100`–`:106`), each laid out **K slots then V slots** (`core/gemma4_kernels.mojo:141` `cache_kernel`: K at `offset + slot × width`, V at `offset + capacity × width + slot × width`). Capacity is per layer class: **local (sliding-window) layers get 512 slots; global layers get the full session context** (`gemma4_cuda.mojo:105`). The local ring is a **true ring**: `slot = position % capacity` overwrites the oldest slot — the only overwriting KV behaviour in the engine. The planner prices this cache at `kv_elements × 4` with exactly the same owning/512-cap sum (`inference_memory.mojo:157`–`:159`) — the tree is internally consistent that this KV is f32.

### 3.4 The hybrid and shared shapes (host) — where "per token" needs three numbers

- **Gemma 4 on the host** uses the §3.1 cache, but its shape breaks the uniform formula three ways: the cache is allocated for **all** layers (the engine sizes `block_count` unconditionally) at the **global** width (kv_dim = kv_heads × global head_dim); only owning layers ever write; and local layers' rows (true width = kv_heads × 256) are **zero-padded to the global width** before append (`core/inference.mojo`, Gemma4Block: "Local K/V rows are zero-padded to the cache width"). Attention on local layers is window-masked (512), but **storage is full-context** — the 512 cap exists only on the CUDA path. The census therefore states allocated / written / useful per token for Gemma 4 (§4), never a single figure.
- **Qwen3.5 on the host** appends KV **only on full-attention layers** (`core/inference.mojo` Qwen35Block: the append sits under `if self.is_full_attn:`; interval default 4), yet the engine still **allocates all layers'** slots. Its non-attention layers carry a **fixed-size f32 SSM state** instead (`Qwen35State`, `core/inference.mojo:2077`): `ssm_layers × group_count × state_size² + ssm_layers × (conv_kernel − 1) × conv_dim` f32 elements plus scratch — constant in context length, **not KV**, and excluded from the per-token table (named here so J-091's ladder does not mistake it for KV growth). No profile constants for Qwen3.5 exist in the tree (shapes are file-derived at load), so its KV row in §4 is a formula, per the roadmap's instruction for model-file-resident numbers.
- **Gemma 2-class** layers on the generic host path: sliding window is an attention mask only (`core/inference.mojo:113`–`:117`); storage stays full-context f16 at the uniform price.
- **The spill session** (§3.1) deserves one accounting note: its host cache is sized for **all** layers while only tail layers write to it (front layers' KV lives in the front CUDA session's f16 buffer, sized for the executed prefix only — `llama3_cuda.mojo` exec-layer recomputation). The front layers' host slots are allocated and never written. That is over-allocation by construction of the split, recorded here as a census fact, not a defect: the host cache is drawn from the shared well and the split's own doc states the division.

### 3.5 What does not exist

- **No 8-bit / quantized KV anywhere** (inspect-searched over all of `aesir_engine/`; the only near hits were adjudicated false positives — a GGUF header `kv_count` field and a GEMM tuning-cache file path — both recorded in the inspect script). J-088 starts from zero, beside an f16 (and one f32) baseline.
- No KV persistence to disk, no KV compression, no per-head or per-layer precision variation: every storage is one dtype throughout.
- The Part V speculative accounts track KV *positions* for rollback, not bytes; `core/moe_gpu_plan.mojo`'s KV allowance is a caller-stated figure, not a derivation — this slice's module (§5) is the first place the tree derives KV bytes from shapes mechanically.

## 4. The census table (exact arithmetic over the tree's constants)

Formula (uniform shapes): `bytes/token = layers × 2 × kv_heads × head_dim × elem_bytes`. Totals are per-token × context. All rows re-derived by `j087_inspect.py` from the profile files (the parser reads the constructor tuples in `core/dense_gqa_profile.mojo` / `core/gemma4_profile.mojo`; OLMoE's dims are the J-015 file anatomy as filed in J-053: 16 layers, kv_dim 2048).

### 4.1 Dense GQA profiles — f16 on host and CUDA alike

| Profile (source) | Layers × kv_heads × head_dim | **Bytes/token** | @512 | @4,096 | @8,192 | @32,768 | Cap (profile) |
|---|---|---|---|---|---|---|---|
| Llama 3 8B | 32 × 8 × 128 | **131,072** | 67,108,864 | 536,870,912 | 1,073,741,824 | — (cap) | 8,192 |
| Llama 3.2 3B | 28 × 8 × 128 | **114,688** | 58,720,256 | 469,762,048 | 939,524,096 | — (cap) | 8,192 |
| Qwen3 0.6B | 28 × 8 × 128 | **114,688** | 58,720,256 | 469,762,048 | 939,524,096 | 3,758,096,384 | 32,768 |
| Qwen2.5 Coder 7B | 28 × 4 × 128 | **57,344** | 29,360,128 | 234,881,024 | 469,762,048 | 1,879,048,192 | 32,768 |

Host-allocation note: on the host the same models allocate at `min(16000, file context)` tokens (§3.1), so e.g. the 8B's host cache at a 128k-context file is 131,072 × 16,000 = **2,097,152,000 B**; the CUDA session admits at most the profile cap. The cap column is the CUDA/profile cap; file contexts live in the GGUF headers, and where they exceed the caps the caps govern.

### 4.2 Streamed MoE (OLMoE) — host f16

16 layers × kv_dim 2,048 → **131,072 B/token** (the same headline as the 8B, by a different shape: 16 × 2 × 2,048 × 2). File context cap 4,096 → at most **536,870,912 B**; the J-022/J-030 legs ran ctx 512 → 67,108,864 B allocated. (The session's expert cache is a separate, larger economy — Part II's record; KV is never its binding constraint.)

### 4.3 Gemma 4 — the three-tier host table and the f32 CUDA table

Host (f16; cache width = global kv_dim; useful = non-padding bytes actually representing the model):

| Profile | Allocated /token | Written /token | Useful /token | Owning (local/global) |
|---|---|---|---|---|
| E4B (42 layers, 18 shared, period 6, kv_heads 2, head_dim 256 local / 512 global) | **172,032** | **98,304** | **57,344** | 24 (20 / 4) |
| E2B (35 layers, 20 shared, period 5, kv_heads 1, head_dim 256 local / 512 global) | **71,680** | **30,720** | **18,432** | 15 (12 / 3) |

The useful tier is the figure J-053's table quotes for E2B (18,432) — correct as *useful* bytes; the machine nevertheless *allocates* 71,680 B/token of context on the host. Both numbers are true; they answer different questions, and J-093's memory ceiling must use the allocated tier.

CUDA (f32; local rings fixed at 512 slots; only global owning layers grow):

| Profile | Local rings (fixed) | Global marginal /token | Total @512 | Total @4,096 | Total @ cap |
|---|---|---|---|---|---|
| E4B (cap 32,768) | 41,943,040 | **32,768** | 58,720,256 | 176,160,768 | 1,115,684,864 @32,768 |
| E2B (cap 16,384) | 12,582,912 | **12,288** | 18,874,368 | 62,914,560 | 213,909,504 @16,384 |

Worked check (E4B CUDA): fixed = 20 local owning × 2 × 512 slots × (2 heads × 256) × 4 B = 41,943,040; marginal = 4 global owning × 2 × (2 × 512) × 4 B = 32,768/token. At equal context the CUDA cache is *smaller* than the host's allocated cache (rings + owning-only) despite costing 4 B/element — the two effects must not be conflated in J-091's ladder.

### 4.4 Formula rows (numbers live in model files, per the roadmap's instruction)

- **Generic host dense (any GGUF the loader reads — llama / qwen2 / qwen3 / gemma2 / granite classes):** bytes/token = `block_count × 2 × kv_dim × 2`, kv_dim from the file header; allocated context = `min(16000, file context)`.
- **Qwen3.5 (hybrid):** written bytes/token = `(block_count ÷ full_attention_interval) × 2 × kv_dim × 2` (interval default 4); **allocated** stays the generic row (all layers sized). Plus the fixed f32 SSM state of §3.4, constant in context.
- **Spill split:** device front = `exec_layers × 2 × kv_width × 2`/token (f16) + host allocated = the generic row for the whole model (§3.4 note).

### 4.5 Representative totals at the runtime ceiling

At the host's 16,000-token allocation ceiling: Llama 3 8B / OLMoE shape 2,097,152,000 B; 3B / Qwen3-0.6B shape 1,835,008,000 B; Coder shape 917,504,000 B; Gemma 4 E4B allocated 2,752,512,000 B (useful 917,504,000 B); E2B allocated 1,146,880,000 B (useful 294,912,000 B). These are the figures J-093's memory-ceiling slice starts from.

## 5. What was built — the census made executable

**`aesir_engine/core/kv_account.mojo`** (new, pure accounting in the J-067 grain — sibling to `core/igpu_account.mojo` / `core/moe_gpu_plan.mojo`; it allocates nothing, opens no device, contains no speed, and wires into **no live session path**, because no session's storage changes in a census slice):

- The uniform price (`kv_bytes_per_token`, and the kv_dim form `kv_bytes_per_token_width` the host sessions themselves size by), totals (`kv_total_bytes`), and the host allocation rule (`host_cache_context` = min(16000, file context)).
- Gemma 4's shapes in full: owning/local/global layer counts from the profile fields, the three host tiers (allocated / written / useful), and the CUDA form (fixed local rings + global marginal + total at a context).
- The **claim verdict** (`evaluate_kv_claim`): a claimed per-token figure MATCHES only if it equals the derivation from the stated shape and precision, exactly — the mechanical form of this census, so a later slice's KV claim can be checked instead of believed.
- The **J-088 projection** (`kv_int8_projected_per_token`): int8 payload + one scale per (layer, K/V, kv-head) row, the scale's bytes stated by the caller and refused when unstated. It is labelled projection in the module, in the tests, and in §7 — nothing in the tree stores KV this way today.

**Host contract** (in the module docstring, binding): KV byte claims for named shapes are stated through the verdict before being quoted; J-088 grades its saving against this module's f16 figures — and, for the Gemma 4 CUDA path, against its f32 figures.

No existing module was modified. Registration in `tests/run_all.mojo` is **not** done here, for J-031 §10's stated reason (the branch line's counted-run pin cannot be re-accounted without the counted run, which belongs to an on-box leg).

## 6. Tests and inspect (PROVEN, VM, lightest target)

Filed as `j087_test_output.txt` (build recipe and machine state in its header):

- **`test_kv_account` (new): 10/10 groups PASS** — precision codes (f16/f32/projection-only int8); dense per-token pins (131,072 / 114,688 / 114,688 / 57,344); totals closing at the profile caps + the 16,000 host rule; OLMoE by the kv_dim form; Gemma E4B and E2B host tiers; Gemma CUDA fixed/marginal/total for both profiles (with the f32 marginal exactly twice its f16 counterfactual); the int8 projection (67,584, strictly between half and whole of the f16 price); the claim verdict on all branches **including the J-053 defect pin** (§8); invalid inputs refused (6 cases).
- **Neighbours rebuilt from this tree and re-run:** `test_igpu_account` (J-067) **11/11 PASS**; `test_moe_gpu_plan` (J-031) **7/7 PASS**; `test_dense_buffers` **PASS** (its single filed group line).
- **Inspect: `j087_inspect.py` — 43/43 checks PASS, exit 0** (filed with its output): storage dtypes and layout offsets grepped from the cache definitions and kernels; profile constants **parsed** from the profile files and every §4 figure re-derived; the runtime cap, the padding behaviour, the Qwen3.5 append guard, the MoE construction, the PagedKVCache's absence of production users, and the absence of any 8-bit KV all asserted mechanically.

## 7. The baseline J-088 is graded against

1. **The figures:** §4's tables, as pinned by `core/kv_account.mojo` and re-derivable by `j087_inspect.py`. An 8-bit KV's saving is claimed per path against *that path's* figure: f16 paths halve-ish; the Gemma 4 CUDA path quarters-ish (f32 → int8) if J-088 extends there.
2. **The projection (arithmetic, NOT a tree fact):** with int8 payload + one f32 scale per (layer, K/V, kv-head) row, the Llama 3 8B shape projects to 65,536 + 2,048 = **67,584 B/token = 0.5156 × today's 131,072** — the scales are real bytes and any J-088 claim of "half" without them is a mismatch under the module's verdict. Other scale shapes (per-token, per-channel, block scales) change the second term, not the payload term; J-088 states its shape and this module prices it.
3. **The layout J-088 must fit or consciously change:** host = two separate K/V tensors, [layer][position][width]; dense CUDA = per-layer K block then V block; Gemma CUDA = per-owning-layer K slots then V slots with the 512 ring. Dequant cost inside attention (J-088's own measure) is read against these layouts, not a generic one.
4. **Deferred to J-088 / J-098 by name:** the 8-bit storage itself and its option surface (J-088); faithfulness grading of 8-bit vs this baseline (J-089, teacher-forcing rank/gap under the raw-oracle discipline); the mixed-precision question (J-090 — §3.4's Gemma tiers and Qwen3.5's full-attention-only writes are the natural first suspects); the context ladder at both precisions (J-091) and the memory ceiling with expert cache active (J-093, starting from §4.5's allocated figures).

## 8. Defects found

- **D1 — J-053's Llama 3.2 3B KV figure is wrong (found this slice; correction filed here, per the gate precedent that corrections live in the later record, not in rewritten slice files).** `docs/janas/j053_inspect.py`'s ARCHS row for "Llama 3.2 3B (dense GQA)" hardcodes **131,072** B/token, and J-053's doc table repeats it (incl. "KV written @8,192 = 1,073,741,824 B"). The row's own stated shape — 28 layers, kv width 1,024 — derives 28 × 2 × 1,024 × 2 = **114,688** B/token (and 939,524,096 B @8,192), which is also what `llama3_2_3b_profile()` in `core/dense_gqa_profile.mojo` yields and what this slice's parser derives. 131,072 is the 32-layer 8B figure, carried into the 28-layer row. Every other J-053 KV row re-derives exactly (8B 131,072; Qwen3 0.6B 114,688; Coder 57,344; OLMoE 131,072; E2B useful 18,432). **Disposition:** the correct figures stand in §4.1 of this doc; the new suite pins the defect mechanically (`evaluate_kv_claim(131072, 28, 8, 128, f16)` = MISMATCH; the derived 114,688 = MATCHES); the inspect script asserts the defect's presence in the filed J-053 script so the correction stays auditable. J-053's other conclusions (pass plans, MACs, walls) do not rest on this cell. The keeper's harvest should amend the campaign record's J-053 citation where the 3B KV figure is quoted.
- **No defect found** in any KV storage, kernel, planner, or profile code: the host and CUDA layouts match their planners' pricing on every path (f16 ×2 dense; f32 ×4 Gemma CUDA; the Gemma sums skip shared layers and cap locals identically in the session and the planner), and the J-053 E2B figure reconciles once its tier (useful) is named. My own inspect script's first two 8-bit-search patterns produced false positives (a GGUF header field; a tuning-cache path) — both adjudicated by hand and recorded in the script, so the final absence claim rests on KV-specific patterns.

## 9. NOT PROVEN list

- **Any live memory measurement** — resident bytes of any cache in a running session, on any hardware. This census is allocation arithmetic over the tree's constants (PROVEN as arithmetic); that a running process's RSS/VRAM matches it byte-for-byte is **NOT PROVEN** and belongs to J-091/J-093's measured legs.
- Any wall, tok/s, bandwidth, or dequant-cost figure for any KV precision — none was measured; none exists in this slice.
- That the Gemma 4 CUDA f32 cache is *necessary* (vs an f16 conversion the kernels could make) — the census records what the tree does, not whether it should; the question is J-088's/J-090's to grade.
- Qwen3.5 per-file KV numbers for any specific model file (no pinned profile exists; §4.4 is the formula, and a file's header supplies its constants at load).
- Any architecture beyond the profiled/pinned set (e.g. a Gemma 4 MoE file — the dense CUDA path refuses it by name; its KV, if a MoE path ever serves it, is uncensused).
- Janas's published KV/long-context numbers as evidence about Aesir — none are cited as such anywhere in this slice.

## 10. Banking

Filed on branch `yrsa/janas-j087` (worktree `~/workspace/aesir-janas-j087`, base `e4c0f14c`): `docs/janas/J087_KV_PRECISION_CENSUS.md` (this doc), `docs/janas/j087_inspect.py`, `docs/janas/j087_inspect_output.txt`, `docs/janas/j087_test_output.txt`; in the tree: `aesir_engine/core/kv_account.mojo` (new) and `aesir_engine/tests/test_kv_account.mojo` (10 groups). **No existing module was changed.** Campaign copies of the doc + evidence in `~/workspace/model-tests/janas/`, sha-identical (verified by hash). Push by explicit refspec `git push origin HEAD:refs/heads/yrsa/janas-j087`, foreground, with `git ls-remote` verification that the branch moved and origin/main stayed at `605562f6b919a0f58fa6decd0b45a83cdc41a6d5`; the commit hashes and ls-remote lines are recorded in the campaign state entry for J-087 and the slice worker's report (a doc cannot contain its own commit hash). No README touched. Hailo untouched/parked. No Docker.
