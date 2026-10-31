# J-021 — Dense Spill, Generalised

**Slice:** J-021 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "Dense spill, generalised. The proven laptop spill path re-expressed through the same residency machinery (dense layers as the streaming unit), token-identity re-proven after the refactor."
**Built + measured:** 2026-10-31 ~05:28–05:50 EDT. Module + unit tests + replay on the VM (light targets only; VM MemAvailable ≈ 0.6 GB, no VM inference); spill builds + runs on **purplelongship** (Ryzen 9 / RTX 2060 6 GB, kernel 7.0.0-38-generic) in the guarded idle gap after the 204 road's S-090 driver finished. **No Janas material was used or needed** — this slice stands on J-017/J-018/J-019/J-020 and the 204 road's S-011 spill proof; the clean-room law was not engaged.
**Spec stood on:** J-017 §6.4 ("J-021: dense layers become the streaming unit — the residency/cache contracts are written to admit a second unit type without redesign, but the unit-type extension is J-021's to specify"), J-018 (the cache contracts and statistics vocabulary), the S-011 spill proof and its no-scratch re-verification (204 road state: token-identical to whole-GPU, `[SPILL] gpu_layers=31/32`, VRAM 4,746 MiB, from clean origin/main).

---

## 1. What the proven spill path actually is (inspected, not assumed)

`core/llama3_spill.mojo` at origin/main `a1593e4e`: a **static split execution**. `Llama3SpillSession` builds a `Llama3CUDASession` front with an exec-layer cap — its device weights are a *compaction* of exactly the front tensors (embedding + front layers, descriptor offsets remapped by `llama3_compact_front`, because real files scatter tensor data) with a front-only KV cache — and a CPU tail that reuses the ordinary CPU path (`TransformerBlock` layers over an mmap'd `GGUFSeer`). The hidden state crosses once per token; selection is greedy argmax over the CPU final norm + output projection. It is **not** a streaming path: nothing is demand-loaded, evicted, or re-read per token. Layers are partitioned once at open, by count (`exec_layers`), and the partition never moves.

So "re-expressing it through the residency machinery" cannot mean routing it through `ExpertCache.access()` — that module does not exist on main (each Part II slice branches from main independently; J-018's cache lives on `yrsa/janas-j018`), and, as §4 measures, demand eviction is the *wrong policy* for dense layers anyway. The honest generalisation, and what this slice builds, is:

1. **The same contracts and vocabulary, with the unit changed** — a new module, `core/dense_residency.mojo`, that carries the J-017/J-018 machinery over whole dense layers (§2).
2. **The spill split stated and validated through that machinery in the live session** — `Llama3SpillSession` now computes its split as a `DenseResidencyPlan` from directory-true per-layer bytes and prints it as a `[RESIDENCY]` line at open (§3). Accounting only: the execution path is byte-for-byte the proven one, which is what makes the token-identity re-proof in §5 a proof about the *refactor* and not about a new engine.
3. **The demand form measured as a counterfactual** — `DenseLayerCache` replayed over the dense demand stream, so the road has numbers, not taste, for why dense residency is a pinned partition rather than a demand cache (§4).

## 2. What was built

`aesir_engine/core/dense_residency.mojo` (+ `aesir_engine/tests/test_dense_residency.mojo`, registered in `run_all.mojo` as `memory.dense_residency` beside `memory.checked_span`):

- **Directory-true layer accounting.** `dense_layer_bytes(model, layer)` sums `byte_count` over the layer's tensor suffixes present in the `PackedGGUF` directory (the dense GQA profile's require-list: attn/ffn norms, q/k/v/output projections, gate/up/down, optional q/k norms and biases). `dense_front_resident_bytes` (token embedding + rope factors) and `dense_tail_resident_bytes` (final norm + untied output head) split the always-resident set by the side it rides with. Every size comes from the opened file's directory — the J-017 §3.3 contract, unchanged. A layer with no tensors in the directory is an error, never a silent zero.
- **The spill plan.** `DenseResidencyPlan` states a split in residency terms: front prefix pinned device-resident, tail host-resident, per-side resident bytes, total layer bytes, device-resident total. `describe_dense_spill` states a chosen split (what the session does); `plan_dense_spill` derives the largest front prefix a device budget admits — whole layers only, in order, never split, never skipping a misfit for a smaller later layer; the always-resident set is charged first, and a budget below it yields an honest `gpu_layers=0` plan with the numbers showing why.
- **Open-time sizing.** `plan_dense_layer_budget` is J-018's `plan_expert_cache_budget` term for term (reserve = resident + KV allowance + scratch + ⅕ total as OS headroom; hard cap by flag/env with J-018's resolution rule and byte grammar — flag `--dense-layer-cache-bytes`, env `AESIR_DENSE_LAYER_CACHE_BYTES`; plumbing is J-036's, as with the expert surface). One honest difference: the floor is the *largest single layer*, where the expert floor is one token's routed demand — a layer cache smaller than its largest unit cannot hold even one unit.
- **`DenseLayerCache`** — the demand form: J-018's policy machinery with the unit changed from (layer, expert) pairs to layers. Same access outcome codes (same values), same two segments (probation ⅛, main ⅞), same frequency gate, promotion on second touch against a frequency-compared victim, faithful `lru`/`lfu` baselines through the same interface, pinning, policy-ordered shrink, evict-then-admit so the cap is never exceeded transiently, and `DenseLayerStats.describe()` emitting **exactly J-018's field names** over layer units. One deliberate structural difference: it manages residency *metadata only* — dense layer bytes live in the file image / device buffers the session already owns, whereas streamed expert slabs land in cache-owned buffers (J-019's reasoning). It is the accounting ledger and the measured counterfactual of §4, **not** the spill path's execution policy.

**Wiring into the proven path.** `Llama3SpillSession.__init__` now, after the `[SPILL]` line, computes per-layer sizes from the front session's own directory (the front model's directory keeps true file sizes — the compaction rewrote only descriptor copies) and prints `[RESIDENCY] <plan.describe()>`, storing the plan on the session. Both spill vehicles (`test_llama3_spill`, `test_qwen2_spill`) ride this constructor, so both inherit the accounting. Nothing on the step path reads the plan.

## 3. The accounting cross-validates to the byte (MEASURED, purplelongship)

File: `L3-8B-Stheno-v3.2-Q4_K_M.gguf` — the S-011 proof's own file — 4,920,734,240 B, sha256 `8e98c1953f9c04e060fd9640bbe866685c844363a2360f09099b79c6c9195fc4` (re-verified on-box this run). An independent Python reader (`j021_layer_sizes.py`, J-015's gguf-py-verified type table) and the Mojo module in the live session agree on every sum:

| Quantity | Python reader | Mojo `[RESIDENCY]` / `[CUDA]` |
|---|---:|---:|
| Layer body (32 layers, two size classes 138,936,320 ×16 / 122,716,160 ×16) | 4,186,439,680 | total_layer_bytes 4,186,439,680 |
| Front 31 layers | 4,063,723,520 | gpu_layer_bytes 4,063,723,520 |
| Tail layer (31) | 122,716,160 | host_layer_bytes 122,716,160 |
| Front-resident (token_embd, Q4_K) | 295,501,824 | always_resident_bytes 295,501,824 |
| Tail-resident (output Q6_K 430,940,160 + norm 16,384) | 430,956,544 | host_resident_bytes 430,956,544 |
| Device-resident total | 4,359,225,344 (sum) | device_resident_bytes 4,359,225,344 |
| — vs the front's own compaction total | — | `[CUDA] weights_bytes=4,359,225,344` |

The last row is the strong check: `llama3_compact_front` independently walks the same tensors to build the device image, and the residency plan's device total equals its compacted total **exactly** — two code paths, one directory, zero drift. The whole-file sum also closes: layer body + both resident sets = 4,912,898,048 B = the reader's tensor-byte total.

## 4. The demand form, measured: dense layers thrash under every demand policy (MEASURED replay)

Harness `j021_layer_replay.mojo` (filed beside this doc; output `j021_replay_results.txt`): the dense demand stream — 28 tokens × 32 layers in order (the S-011 run's shape: 22 prompt + 6 generated) at the file's real layer sizes — through `DenseLayerCache` at four budgets × two policies:

| Budget | Policy | Hits | Streamed |
|---|---|---:|---:|
| Full body 4,186,439,680 | lru | **864 / 896 (0.964 = 1 − cold/accesses)** | 4,186,439,680 (body once) |
| Full body | segmented | **0** | 117,220,311,040 (28 × body) |
| Front-31 sum 4,063,723,520 | lru / segmented | **0 / 0** | 117,220,311,040 |
| Half body | lru / segmented | **0 / 0** | 117,220,311,040 |
| ⅛ body | lru | **0** | 117,220,311,040 |
| ⅛ body | segmented | **0** (all 896 bypassed) | 117,220,311,040 |

Three findings, each a property of the machinery measured in the machinery:

1. **The cyclic scan is all-or-nothing.** A dense token touches every layer, so reuse distance is always the whole body. Any budget below the full body scores exactly zero hits under both policies — LRU's textbook scan failure, reproduced at real sizes. There is no dense analogue of the MoE cache's graceful middle (J-017 §4.3's 0.74 at half body): the middle does not exist.
2. **The segmented shipping policy fails even at full budget — promotion starvation.** Promotion needs a second touch while a unit sits in probation; probation is ⅛ of the budget (≈4 layers here) and the scan's cycle is 32 layers, so every layer is evicted from probation before its next turn: 0 promotions, 0 hits, the body re-streamed per token. The probationary shape that *wins* for experts (J-018: 0.760 @512 vs LRU 0.740) is structurally wrong for units whose reuse distance exceeds the probation segment — which for dense layers is always.
3. **At small budgets the probationary door itself closes.** At ⅛ body, probation (1/64 of the body) is smaller than one layer, so no layer can ever be admitted (896 bypasses) even though each layer fits the budget as a whole.

**Verdict (DECIDED, on this evidence):** the generalised dense form of the residency machinery is the **static pinned partition** — the spill plan of §2 — with the demand cache kept as ledger and counterfactual. This is J-017's D1/D7 logic arriving at its dense conclusion: what is touched every token, in fixed order, belongs to the resident class by construction, and the only live question is *where the pin boundary sits* (the plan's budget derivation), not an eviction policy. A future dynamic variant would need scan-resistant machinery (e.g. direct-to-main admission for layer units, bypassing probation); it is **not built here**, and §4's table is the evidence any such proposal must answer.

## 5. Token-identity re-proof after the refactor (PROVEN, purplelongship)

Method, per the slice's discipline: the spill proof's own comparator — greedy output of the split run vs the whole-resident run on the same sha-pinned file, token-for-token (the established spill grading; no `llama-cli --single-turn` anywhere, no template rendering — both vehicles feed the identical hand-built prompt). Binaries built on-box from the J-021 tree (`28f6fca9`): `mojo build --mcpu znver2 --target-accelerator sm_75`, BUILD_EXIT=0 for both vehicles. Full outputs: `j021_spill_runs.txt`.

- **Whole-GPU @4096 is refused by the engine itself** (required 5,459,657,764 B > usable 5,368,709,120 B on the 6 GB card) — the whole model at the proof's context does not fit, which is the spill path's reason to exist. The comparator therefore runs whole-GPU at context 2048, where it fits; context length does not change the math for a 28-token run, and the condition is stated rather than hidden.
- **Whole-GPU @2048** (J-021 tree): prompt IDs `[128000, 128006, 882, …]` (22 tokens), output **"Two plus two equals four." + EOS 128009**, 6 generated.
- **Spill 31/32 @2048** (J-021 tree, refactored constructor): prompt IDs identical, output identical, EOS identical.
- **Spill 31/32 @4096** (J-021 tree): prompt IDs, output, EOS **identical to the S-011 record** (binary from clean `9ef77ad9`), and its `[CUDA]` session line is byte-identical to S-011's (weights 4,359,225,344, KV 520,093,696) with the `[RESIDENCY]` line added.

**Token-identity after the refactor: PROVEN** — three-way agreement (whole-GPU, spilled at two contexts, and the pre-refactor S-011 record), on the proof's own file, with the accounting change touching no execution code. Walls (single runs, box cooling from S-090's grade phase, Tctl 52 °C at first run, loadavg ≤0.52): spill @4096 prefill 1.694 s / decode 0.583 s vs S-011's 1.665 / 0.520 — same numbers class, **MEASURED-INDICATIVE**, not baselines.

## 6. Tests (PROVEN, VM)

`mojo run -I aesir_engine aesir_engine/tests/test_dense_residency.mojo` (project pixi env; only this target built — VM MemAvailable ≈ 0.6 GB, no inference):

- `PASS: dense residency sizing, cap resolution and size parsing` — the J-018 test's own numbers reproduce (reserve 2600, budget 7400, cap, below-floor at the largest-layer floor, grammar).
- `PASS: dense residency spill plan derivation and statement` — chosen 31/32 split stated exactly; budget 3150 derives 31 layers and 3149 derives 30 on uniform sizes; ragged sizes stop the prefix at the first misfit; out-of-range splits refused.
- `PASS: dense layer cache scan behaviour, cap, pinning, shrink` — full-residency LRU (cold = layer count, hits thereafter), cyclic-scan LRU thrash (0 hits, evicted-before-reuse counted), segmented promotion starvation asserted (0 hits / 0 promotions at full budget), oversize refusal by code, resident ≤ budget after every one of 200 churn accesses, miss accounting closes (admissions + bypasses + too-large = misses), pinned layer survives shrink.

The full `run_all` runner was not executed (same VM memory constraint as J-018/J-019; registration is wired). The spill build on purplelongship compiles `llama3_spill.mojo` + `dense_residency.mojo` into a working binary — a compile proof of the wiring on the laptop line (znver2, sm_75).

## 7. Shared vs separate — the integration ledger, honestly

**Shared with the MoE machinery (real, in the tree):** the residency *contracts* — resident vs streamed classification with the fail-safe direction (J-017 D1/D2), whole-unit atomic admission (D3 generalised), directory-true byte accounting (D4/§3.3), open-time sizing arithmetic and cap grammar/resolution (J-018), statistics field vocabulary and access outcome codes (J-016/J-018), pin/shrink semantics. A reader of J-018's doc can read J-021's outputs unchanged, and vice versa.

**Separate (named gaps, not faked):**
- **Separate modules.** `dense_residency.mojo` and `expert_cache.mojo` are parallel implementations of the shared contracts, not one generic module — they live on independent slice branches from main, and neither imports the other. Unifying them into one unit-generic cache is future integration work (the natural moment is when a MoE forward lands and both unit types share one process); the contract parity built here is what makes that unification mechanical rather than inventive.
- **Separate execution.** The spill path does not stream: the tail is host-resident through the existing mmap loader, the front is pinned on the device, and `DenseLayerCache` executes nothing in the session. What the session gained is the plan + accounting (§2), not a new data path.
- **The qwen2 vehicle** rides the same session class and prints the same `[RESIDENCY]` accounting, but no qwen2 spill run was re-executed this slice — its token-identity stands on the pre-refactor proof, not on a J-021 re-run.

## 8. Defects found and fixed in scope

1. **First design of the plan lumped the whole always-resident set onto the device side.** The real session splits it: embedding rides with the front, the output head + final norm stay with the tail (the CPU tail applies them). Caught against the file's own numbers before the on-box build (device total would have overstated by 430,956,544 B and contradicted the compaction total). Fixed by the front/tail resident split (§2) before any run depended on it.
2. **Segmented-policy probation cannot admit a unit larger than the probation segment** (⅛-budget replay row: 896 bypasses, 0 admissions, for layers that individually fit the budget). For experts this never bit (units ≈ 1/273 of the body at J-018's scale); for layers it is structural. Recorded here as a measured property of the shared policy shape — the dense verdict (§4) routes around it via pinning rather than patching the expert policy's semantics from a dense slice. If a future slice wants demand-managed dense layers, direct-to-main admission for oversize-to-probation units is the named fix.
3. The on-box spill binary's first launch failed on `libaesir_par.so` (the build's `$ORIGIN` rpath was expanded away by the invoking shell — a harness fault in this slice's build command, not the tree's; the S-011 script's quoted form is the correct one). Runs were completed with `LD_LIBRARY_PATH` set; no tree change resulted.

## 9. NOT PROVEN / carried forward

- **Qwen2 spill token-identity after the refactor: NOT PROVEN** (not re-run; same session class, pre-refactor proof stands).
- **Any tok/s claim for the generalised machinery**: the only walls are §5's single indicative runs; no performance claim is made for the plan/accounting (it runs once at open) or for the demand cache (a counterfactual).
- **Dynamic dense residency** (mid-run re-partitioning, scan-resistant admission): not built; §4 is its evidence bar.
- **Gemma-4 dense spill**: the residency accounting's suffix list is the dense GQA profile's; Gemma sessions do not ride `Llama3SpillSession` and gained no `[RESIDENCY]` line this slice.
- **Module unification** (one unit-generic cache for experts + layers): roaded to the Part II integration slices, per §7.
- **KV bytes in the dense sizing reserve** remain a named configuration allowance until J-087, exactly as in J-018.

**Evidence files.** Repo `docs/janas/`: this document, `j021_layer_sizes.py`, `j021_layer_replay.mojo`, `j021_replay_results.txt`, `j021_spill_runs.txt`. Engine: `aesir_engine/core/dense_residency.mojo`, `aesir_engine/core/llama3_spill.mojo` (constructor accounting), `aesir_engine/tests/test_dense_residency.mojo`, `run_all.mojo` registration. Campaign copies in `~/workspace/model-tests/janas/`. No README touched anywhere. Hailo untouched/parked.
