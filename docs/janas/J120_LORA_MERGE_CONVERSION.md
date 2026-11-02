# J-120 — LoRA Merge at Conversion

**Slice:** J-120 (Part VIII — Conversion and Model Breadth, J-119–J-136), Project Aesir Janas clean-room road.
**Roadmap text:** "LoRA merge at conversion. An HF LoRA adapter merged into its base during conversion to GGUF (the `hf2gguf` behaviour), merged weights verified against the unmerged pair computed the slow way."
**Governing handoff:** J-119 doc §3 (C03 + C04 + C05 + C10 → J-120): (1) a safetensors reader for an HF checkpoint, (2) the LoRA merge arithmetic with the roadmap's own verification (merged weights checked against the unmerged pair computed the slow way), (3) a GGUF writer mirroring `loader/gguf.mojo`'s directory format, (4) a stated scope decision on C05, (5) C10's `--from-gguf` leg as a flag/mode on this converter, not separate work. Witness slice: J-128 grades the merged conversion end-to-end on a sha-pinned Llama-3-family file (not this slice).
**Base:** branch `yrsa/janas-j119` tip `f8f69f4d4ca57157df629d0d70fda1fd76832658` (ls-remote verified by the keeper at dispatch). Origin/main untouched at `4ca75cc237de872a7e69777872ec1077f9e93e92` — this branch line does not rebase onto it.
**Machine state (VM, stated for every claim):** MemAvailable ~0.9 GB at dispatch — far below the 5,500 MB inference gate, so no inference runs and none is in scope; lightest compiles only, staged, one at a time. purplelongship is **not used at all** — owned by the 204 road's live S-104 under the coordination law. Synthetic fixtures are the honest scale for this VM; no real HF checkpoint download is required and none is attempted.
**Clean-room record:** no Janas material is consulted in this slice beyond the road's own already-filed clean-room records (J-119's census + handoff, Part I's records). The LoRA merge convention (scale = alpha / rank applied to the low-rank product B·A added to the base weight) is the public PEFT/LoRA convention, answered from public LoRA documentation and Aesir's own architecture, per the clean-room law — never from Janas source. No Janas source code is opened, in this slice or any other.

---

## 0. Protocol (committed first, before any converter code was built)

This section is committed and pushed (ls-remote verified) before the build (§§1+ are filed after, under these rules and no others).

### 0.1 The build chain, exactly as inherited

One new pure layer, `aesir_engine/core/lora_convert.mojo` (imports nothing; the layer decides and serialises, hosts execute), one host driver, `docs/janas/j120_convert.mojo` (reads checkpoint files, writes the GGUF, prints the census), and one unit suite, `aesir_engine/tests/test_lora_convert.mojo`. The chain:

1. **Safetensors reader** over a whole file's bytes: the 8-byte little-endian header length, the JSON header (a bounded scanner of this layer's own, in the J-109 shape — the tree has no general JSON parser for nested objects), and tensor data decoded to Float32. Dtypes accepted: `F32`, `F16`, `BF16` (decoded exactly: BF16 by bit extension, F16 by exact widening). Any other dtype is refused by name. `__metadata__` is skipped, not mistaken for a tensor. Offsets are bounds-checked against the file; a truncated or overlapping file is refused by name. A matching emitter (`lc_build_safetensors`) exists so tests and fixtures round-trip through the same format definition.
2. **LoRA pairing + merge** (§0.2–0.3).
3. **GGUF writer** (§0.4) mirroring the directory format `loader/gguf.mojo` reads: GGUF v3 header, metadata key/values, tensor directory, data aligned to `general.alignment` = 32, tensor offsets relative to the aligned data start, exactly as `_parse_tensors` computes `data_offset`.
4. **C10 mode** (§0.5).

### 0.2 Adapter naming and pairing (answered-locally, stated on the face)

PEFT adapters name their tensors after the base tensor they adapt. This converter accepts, for a base tensor `<stem>.weight`, the adapter pair `<stem>.lora_A.default.weight` / `<stem>.lora_B.default.weight`, with an optional leading `base_model.model.` prefix on the adapter names (the PEFT wrapper prefix) stripped before pairing; the bare `.lora_A.weight` / `.lora_B.weight` spellings (no `default`) are also accepted. A is the down-projection `[rank, in]`, B the up-projection `[out, rank]` — the public LoRA convention. The adapter configuration (rank `r`, `lora_alpha`) is read from the adapter config JSON the host passes in (`lc_parse_adapter_config` extracts `r` and `lora_alpha` by name; either missing or non-positive is refused by name).

**Refusals, each by name (the suite must prove every one):**

- an adapter tensor whose name carries no `lora_A`/`lora_B` marker → refused as not a LoRA adapter tensor;
- a `lora_A` without its `lora_B` (or the reverse) for the same stem → refused, pair incomplete, the missing half named;
- an adapter pair whose stem names no base tensor → refused, no base tensor, the stem named;
- shape disagreement: A not `[r, in]`, B not `[out, r]`, or the A/B inner dimension not equal to the configured rank `r` → refused as a rank mismatch, with the shapes stated;
- a merge target that is not a 2-D base tensor → refused by name;
- an adapter file with zero pairable tensors presented for a merge → refused as a non-LoRA checkpoint (nothing to merge is not a silent plain conversion);
- a base tensor name with no GGUF mapping (§0.4) → refused by name at conversion.

Base tensors the adapter does not target pass through unchanged — bit-exact at the Float32 decode level, before the writer's storage rounding (§0.4).

### 0.3 Merge arithmetic and the verification rule (pre-registered)

For a targeted base weight `W` of shape `[out, in]`, adapter `A` `[r, in]`, `B` `[out, r]`, configured rank `r` and alpha `α`, the merged weight is, element by element, in Float32 with the rank sum accumulated in increasing `k` order:

```
merged[i, j] = W[i, j] + (α / r) * Σ_{k=0..r-1} B[i, k] * A[k, j]
```

**Verification rule.** The merged weights are verified against the unmerged pair computed the slow way: an independent computation that, for each output element, forms the full product sum from the unmerged `W`, `A`, `B` by explicit element loops (in the test suite: a test-local implementation sharing no code with the layer; at file level: a pure-stdlib Python implementation rounding every intermediate to Float32). The rule is **exact agreement**: zero differing elements at the Float32 level before storage rounding, and after the writer's BF16 rounding (§0.4), every stored element equals the BF16 rounding (round-to-nearest-even) of the slow-way Float32 value. Any disagreement fails the slice's evidence, is disposed in the doc, and is never averaged away.

### 0.4 Name mapping, storage rule, and the C05 scope decision

**HF → GGUF name mapping (llama family, the documented subset J-128 will witness):**
`model.embed_tokens.weight` → `token_embd.weight`; `lm_head.weight` → `output.weight`; `model.norm.weight` → `output_norm.weight`; per layer `N`: `model.layers.N.input_layernorm.weight` → `blk.N.attn_norm.weight`; `self_attn.q_proj` → `attn_q`, `k_proj` → `attn_k`, `v_proj` → `attn_v`, `o_proj` → `attn_output` (all `.weight`); `post_attention_layernorm.weight` → `blk.N.ffn_norm.weight`; `mlp.gate_proj` → `ffn_gate`, `mlp.up_proj` → `ffn_up`, `mlp.down_proj` → `ffn_down` (all `.weight`). Any other name is refused by name (no silent dropping, no invented mapping). Model geometry (context, embedding, feed-forward, blocks, heads, KV heads, rope dimension/base, RMS epsilon, vocabulary) is carried explicitly in the conversion request, not guessed from tensor shapes beyond the census the writer itself emits; the emitted metadata set is: `general.architecture`, `general.name`, `general.alignment` (32), `<arch>.context_length`, `<arch>.embedding_length`, `<arch>.feed_forward_length`, `<arch>.block_count`, `<arch>.attention.head_count`, `<arch>.attention.head_count_kv`, `<arch>.rope.dimension_count`, `<arch>.rope.freq_base`, `<arch>.attention.layer_norm_rms_epsilon`, `tokenizer.ggml.model` (`llama`), `tokenizer.ggml.tokens`, `tokenizer.ggml.scores` (zeros), `tokenizer.ggml.token_type` (zeros), `tokenizer.ggml.unknown_token_id`, `tokenizer.ggml.bos_token_id`, `tokenizer.ggml.eos_token_id` — the set `loader/gguf.mojo`'s metadata parser consumes for a llama file, no more claimed than that.

**Storage rule.** 2-D tensors are stored **BF16** (round-to-nearest-even from Float32); 1-D tensors are stored **F32** (the GGUF llama convention the loader's shape validation expects of norms). A base tensor of more than 2 dimensions is refused by name at conversion (MoE expert stacks are J-123's territory, not silently folded here).

**C05 SCOPE DECISION (stated here, restated at filing, per J-119 §3 — silence is not an option): this converter is BF16-only.** The post-conversion file-quantization leg (C05) is **not built** in this slice: no quantized GGUF file can be produced, and a request to quantize is refused by name rather than silently emitting BF16 under a quantized label. Rationale on the record: the tree has no GGUF writer of any kind before this slice (J-119 C05), the merge must first be proven exact at full precision, and a file quantizer is a separable build with its own faithfulness burden (J-122's harness grades conversions; a quantizer built here ungraded would violate the no-silent-conversions rule). The refusal-ledger consequence is J-131's to restate if the leg is still unbuilt at the gate.

### 0.5 C10 — the `--from-gguf` leg as a mode on this converter

J-119 §3: once the converter exists, C10's local-convert leg is a flag on it, not a new tool. Its Aesir form (Aesir's native format is GGUF, so "convert locally to the same result" means re-emission through this writer): the converter accepts a BF16/F32 GGUF as its base input (read through the layer's own directory reader, which mirrors the loader's layout rules), optionally merges an adapter exactly as in §0.2–0.3, and emits through the same writer; the emitted file's tensor census (names, shapes, types, values after storage rounding) must agree with the input's for untargeted tensors and with the slow-way merge for targeted ones. A quantized tensor in a `--from-gguf` input is refused by name — the direct consequence of the BF16-only scope (§0.4), stated rather than hidden.

### 0.6 The re-read proof (what "the loader reads it back" must mean here)

Three levels, all required for the file-level claim, in increasing strength:

1. **Census re-read via `loader/packed_gguf.mojo`** (`PackedGGUF`): the written file's tensor names, shapes, types, byte counts, and non-overlap are accepted by the tree's own packed loader machinery, and the census agrees with the conversion's own emitted census exactly.
2. **Metadata re-read via `GGUFSeer.inspect_metadata`**: header + metadata parse and tokenizer vocabulary validation pass on the written file.
3. **Full validation via `GGUFSeer.mmap_and_load`** on a tiny *complete* synthetic llama checkpoint (1 layer, shapes satisfying the loader's generic required-tensor validation): the written file reaches state `VALIDATED`. (Recorded for honesty: the loader's `_require_tensor_shape` verifies presence and shape; stored-type agreement is proven by levels 1 + the file-level verifier, not by level 3 alone.)

A separate re-read driver (`docs/janas/j120_reread.mojo`, importing the loader family) performs levels 1–3 so the pure layer's own suite stays at the lightest compile target. If the VM's memory blocks that driver's compile, the leg files as DEFERRED-WITH-REASON with the exact recipe instead of being forced — the bound stated in the dispatch.

### 0.7 File-level evidence (independent, synthetic, honest scale)

`docs/janas/j120_fixtures.py` (pure stdlib) writes a synthetic HF checkpoint on disk — base `model.safetensors`, adapter `adapter_model.safetensors`, `adapter_config.json` — a 1-layer llama-shaped model (vocab 8, hidden 8, heads 2, KV heads 1, ffn 16, rank 2, alpha 4) with deterministic dyadic-rational values (chosen so Float32 arithmetic is exact and BF16 rounding is unambiguous), two adapter-targeted tensors (`q_proj`, `gate_proj`), the rest pass-through. `j120_convert.mojo` converts the files to a GGUF on disk; `docs/janas/j120_verify.py` (pure stdlib, independent implementations of both the safetensors and GGUF formats) re-reads the GGUF, recomputes the slow-way merge from the fixture files with Float32 rounding at every step, and checks every element under §0.3's rule plus the full census. No number in this slice is a wall, a rate, or a latency; no live model runs.

### 0.8 Carried items (re-cited, not this slice's scope)

- **`cli/repl.mojo` `read_line()`'s defective `String(List[Byte])` idiom** (discovery J-109 §7, re-cited J-118 gate §6 and J-119 §6) remains the road's immediate next item for its own fix slice with tests. It is not a converter defect and is not fixed here.
- **G-119-1** (vision conversion C07 has no Part VIII owner) was routed by the keeper's J-119 closure to **J-131's** refusal ledger. Re-cited here so the routing is not lost; nothing in this slice touches it.

**No README is touched. Hailo stays parked (no finish-line branch contact, no chip run or probe). No Docker. Nothing is deleted to free disk.**

*(§§1+ are filed below from the build, under this protocol.)*

---

## 1. Headline — what was built

The build chain §0.1 pre-registered now exists and is proven at the scales §0 stated: one pure layer, `aesir_engine/core/lora_convert.mojo` (1,542 lines; safetensors reader/emitter for F32/F16/BF16 with named refusals, PEFT adapter pairing + merge, HF→GGUF llama name mapping, a GGUF v3 writer mirroring `loader/gguf.mojo`'s directory format at alignment 32, the C10 `--from-gguf` directory reader + re-emission mode, and the C05 quantize refusal on the layer's own face), one host driver, `docs/janas/j120_convert.mojo`, one unit suite, `aesir_engine/tests/test_lora_convert.mojo` (9 groups, ALL PASS), the synthetic file-level evidence chain (`j120_fixtures.py` → convert → `j120_verify.py`: 41 checks, 0 fails, 192 merged elements verified exact), and the three-level loader re-read (`j120_reread.mojo`: PackedGGUF census, `GGUFSeer.inspect_metadata`, `GGUFSeer.mmap_and_load` reaching VALIDATED — all three levels PASS, none deferred). The C05 scope decision stands as pre-registered: **this converter is BF16-only**; file quantization is not built and is refused by name (§7).

## 2. Machine state and build

VM (KVM), no GPU device used. MemAvailable ~3.7 GB at keeper check, ~4.4–4.7 GB observed during builds — below the 5,500 MB inference gate at every moment; no inference ran anywhere and none is in scope. purplelongship was not used at all (owned by the 204 road's live S-104; yielded). Builds: Mojo 1.0.0 (ed45d567) from the canonical tree's installed pixi env, `mojo build -I aesir_engine` (the re-read driver additionally `-I .` for the hailbru package at the repo root), staged one at a time, staging `~/workspace/.verify-tmp/j120stage`, build dir `~/workspace/.verify-tmp/j120build`, TMPDIR redirected to staging. All builds exit 0; all runs exit 0. Filed verbatim in `docs/janas/j120_test_output.txt`. No wall, rate, or latency number is in scope for this slice and none is claimed.

## 3. Unit suite — exact results (9 groups, ALL PASS)

`aesir_engine/tests/test_lora_convert.mojo`, build exit 0, run exit 0, in order: (1) safetensors round-trip — F32 exact, BF16/F16 exact on BF16/F16-exact values; (2) safetensors refusals — duplicate tensor name, truncated tensor data, empty file; (3) adapter config — `r`/`lora_alpha` read by name with a nested decoy `r` ignored, key-order independence, fractional alpha, missing `r` / missing `lora_alpha` / zero rank all refused; (4) merge exact vs the slow way — the test-local `slow_merge` (full product matrix formed first, sharing no code with the layer) agrees with the layer's merge with **0 differing elements**, PEFT `base_model.model.`-prefixed names paired, pass-through bit-exact; (5) merge refusals — §4; (6) naming — llama subset exact including a two-digit layer index, unmapped name refused by name; (7) GGUF write + the layer's own re-read — census 12, every tensor offset 32-aligned, 9 BF16 (2-D) + 3 F32 (1-D), file ends exactly at the last tensor, re-read values exact; (8) from-gguf — plain re-emission **byte-identical** to the original emission, and the merged from-gguf conversion equals the slow way exact after storage rounding; (9) quantized refusal + C05 scope — a hand-built Q4_K (ggml type 12) GGUF tensor refused by the from-gguf reader, `lc_refuse_quantize("q4_k_m")` refused, scope text states BF16-only and names C05.

## 4. Refusals proven (every one by name, per §0.2/§0.4/§0.5)

Adapter side: empty adapter (non-LoRA checkpoint), a plain weight tensor presented as an adapter (no `lora_A`/`lora_B` marker), incomplete pair (missing `lora_B`), pair whose stem names no base tensor, rank mismatch from the adapter side (inner dim 3 vs configured rank 2), rank mismatch from the config side (configured 4 vs adapter 2), shape mismatch (B out-dim 5 vs base 4), non-2-D merge target. Config side: missing `r`, missing `lora_alpha`, zero rank. Safetensors side: unsupported dtype (by name, in the reader), duplicate tensor name, truncated data, empty file, plus the reader's bounds/overlap guards in code. Conversion side: HF tensor name with no GGUF mapping, tensor of more than 2 dimensions, tokenizer vocabulary under 3 tokens / special-token id outside the vocabulary (in code). From-gguf side: quantized input tensor. Quantize side: any quantization request, by name, under the BF16-only scope.

## 5. File-level evidence (independent, synthetic, honest scale)

`j120_fixtures.py` (pure stdlib) writes the §0.7 checkpoint at the protocol's geometry — vocab 8, hidden 8, heads 2, KV heads 1, ffn 16, rank 2, alpha 4, deterministic dyadic values, two adapter-targeted tensors (`q_proj`, `gate_proj`), ten pass-through. `j120_convert.mojo` merges and writes `merged.gguf` (3,200 bytes, data offset 1,696, census 12: 9 BF16 + 3 F32, sha256 `c26af51dd9ebbea7a31635d3354ebb2dcf570dd69bd5df576ca01f1c1c7e2c6a`), then runs the C10 plain re-emission over the written file — **byte-identical** (the re-emitted file's sha256 is the same) — and demonstrates the quantize refusal. `j120_verify.py` (pure stdlib, independent implementations of both formats, every merge intermediate rounded to Float32) re-reads everything and checks the full census plus every element under §0.3's rule: **41 checks, 0 fails; 192 merged elements verified** (q_proj 64 + gate_proj 128), stored BF16 decoding exactly to the slow-way Float32 values (the fixture values are BF16-exact by construction, so exact agreement is the honest demand); pass-through 2-D elements equal the verifier's own round-to-nearest-even BF16 rounding of the base, 1-D elements are F32 bit-exact.

## 6. Re-read proof (§0.6, all three levels PASS — nothing deferred)

`j120_reread.mojo` (separate driver importing the loader family, per §0.6), run against the converted file: **Level 1** — `PackedGGUF` accepts the file and its census (12 tensors: names, shapes, ggml types, byte counts; non-overlap enforced by the packed loader itself) agrees with the conversion's emitted census exactly. **Level 2** — `GGUFSeer.inspect_metadata` parses header + all 19 metadata entries and validates the tokenizer vocabulary (vocab 8), state HEADER_PARSED. **Level 3** — `GGUFSeer.mmap_and_load` on the tiny complete checkpoint reaches state **VALIDATED** with 12 tensors mapped (the loader's own line: "GGUF validated: 12 tensors, 19 metadata entries, architecture llama"). Per the protocol's honesty note: level 3's `_require_tensor_shape` verifies presence and shape; stored-type agreement is proven by level 1 + the §5 verifier, not by level 3 alone. The VM-memory deferral §0.6 allowed was **not** needed: the driver compiled (`-I aesir_engine -I .`) and ran on this VM.

## 7. C05 scope decision (restated, per §0.4)

**This converter is BF16-only.** The post-conversion file-quantization leg (C05) is **not built** in this slice: no quantized GGUF file can be produced, and a request to quantize is refused by name (`lc_refuse_quantize`, proven in suite group 9 and again in the convert driver) rather than silently emitting BF16 under a quantized label. The quantized-input refusal in the `--from-gguf` reader is the same decision's other face. The refusal-ledger consequence is J-131's to restate if the leg is still unbuilt at the gate.

## 8. Defects found and fixed in-slice

All in this slice's own artefacts, none in pre-existing engine code: (1) The stopped first worker's core/test drafts carried **14 implicit-copy build errors** under this toolchain (LcTensor / LcGeometry / List[Int] values used without `.copy()` at 3 sites in the test suite and 11 in the layer) — fixed in place, no logic change; the suite then built and passed as filed. (2) The file-level artefacts' first drafts carried the unit fixture's geometry (hidden 4, ffn 6) instead of §0.7's pre-registered geometry (hidden 8, ffn 16) — corrected in fixtures, convert driver, verifier, and re-read census before any evidence run; every filed number is from the corrected geometry. (3) Three dead first-assignments flagged by the compiler (the layer's unused `ends`, the suite's `want`/`rounded`) removed; final builds show no warnings for this slice's files. No filed number rested on any earlier draft.

## 9. Honesty ledger

**PROVEN** (runs actually executed on this VM, this slice): the safetensors reader/emitter round-trips and refusals; adapter-config parsing; the merge arithmetic **exact** against two independent slow-way implementations (test-local Mojo, stdlib Python with Float32 rounding at every step) at unit scale and at file scale (192 elements); the GGUF writer's format acceptance by the tree's own loader machinery at all three §0.6 levels, including VALIDATED; the C10 from-gguf plain re-emission byte-identical, and merged from-gguf exact after storage rounding; every §4 refusal; the C05 quantize refusal. **NOT PROVEN**: any real (non-synthetic) HF checkpoint conversion — J-128 is the witness slice for a sha-pinned Llama-3-family file; any tensor/geometry beyond the llama subset §0.4 maps; F16/BF16 *input checkpoints* at file level (the codecs are unit-proven on exact values; the filed fixtures are F32); inference on a converted file (out of scope; the loader validated and mapped, nothing was generated). **DEFERRED-WITH-REASON**: none in this slice — the §0.6 memory deferral was available and not needed. Carried legs that remain other slices' work, unchanged: C05 file quantization (unbuilt, refused by name, §7), MTP extraction (J-121's territory per J-119 §3), conversion grading harness (J-122), MoE expert stacks (J-123).

## 10. Carried items (re-cited, not this slice's scope)

- **`cli/repl.mojo` `read_line()`'s defective `String(List[Byte])` idiom** (discovery J-109 §7, re-cited J-118 gate §6, J-119 §6, and §0.8 here) remains the road's immediate next item for its own fix slice with tests. It is not a converter defect and is not fixed here.
- **G-119-1** (vision conversion C07 has no Part VIII owner) stands routed to **J-131's** refusal ledger, as §0.8 recorded. Nothing in this slice touches it.

## 11. Banking

Branch `yrsa/janas-j120` from J-119 tip `f8f69f4d4ca57157df629d0d70fda1fd76832658`; protocol commit `4b66af6ead03d9678164a18f096decd31a8c1cd7` (pushed, ls-remote verified before the build). Build commits: `ff739df38eb5ba0d4264c880de8f2c2e465aa364` (layer + unit suite) and `65ff5d3a91bb5a057134bc199621f784e2556bfd` (file-level evidence chain + filed test output); this doc's §§1+ and the inspect script/output are banked in the slice's closing commit on the same branch. Campaign copies, sha-identical to the repo files, are filed in `~/workspace/model-tests/janas/` (this doc, `j120_test_output.txt`, `j120_inspect.py` + `j120_inspect_output.txt`, `j120_convert.mojo`, `j120_reread.mojo`, `j120_fixtures.py`, `j120_verify.py`, `lora_convert.mojo`, `test_lora_convert.mojo`) and are re-derived mechanically by `j120_inspect.py`. Push is by explicit refspec with `git ls-remote` verification that the remote moved and origin/main is untouched (`4ca75cc237de872a7e69777872ec1077f9e93e92` at dispatch). **No README is touched. Hailo stayed parked. No Docker. Nothing was deleted to free disk.**
