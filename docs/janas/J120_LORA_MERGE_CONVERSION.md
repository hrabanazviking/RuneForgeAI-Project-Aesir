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
