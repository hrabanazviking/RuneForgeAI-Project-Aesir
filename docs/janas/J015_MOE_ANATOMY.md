# J-015 — MoE Anatomy in GGUF, Measured

**Slice:** J-015 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Measured:** 2026-10-31 ~01:20 EDT, on **purplelongship** (AMD Ryzen 9 4900HS, 16 threads, 39,517 MB RAM, RTX 2060 Max-Q 6 GB — GPU unused; this slice is header/tensor-directory parsing only, **no inference was run**). Machine state at measurement: idle apart from ollama serve (idle) and an idle tmux session; the 204 road had no live heavy run (checked before download and before parsing). Files stored in the wave store, `/home/volmarr/aesir-gpu/.aesir/models/`.
**Method:** a purpose-written GGUF v3 header parser (`~/workspace/model-tests/janas/j015_parse_gguf.py`, sha256 `b512d63b4f4138fbebc68f9778e3e75dc745a6bcee3991da13256042073abed5`) that reads the metadata block and the tensor directory only — no tensor data. Every byte count below is computed from the directory (element count × quant block size) and cross-checked: for both files, header + Σ tensor bytes + padding gaps accounts for the file size **exactly**.
**Honesty classes:** file facts are **MEASURED** from the files themselves. Derived figures (per-token bytes) are exact arithmetic on measured sizes, with their assumption stated. Anything not present in a file is recorded as absent / NOT PROVEN, never guessed. No Janas material was used in this slice at all (this is GGUF + Aesir only), so the clean-room law was not even engaged.

**Verification & completion addendum (keeper worker, 2026-10-31 ~01:41 EDT).** The first worker's run stalled before banking, so a second worker re-measured everything independently before this document was filed: both wave-store files were re-hashed on purplelongship (sha256 match the §1 pins and Hugging Face's published LFS oids), re-parsed with gguf-py's canonical `GGUFReader`, and analysed with the campaign parser. **22 of 22 spot-checked claims from §§1–5 reproduced exactly** (file/tensor/expert/resident bytes, both down-quant layer patterns, the 28-byte Granite gap, the 251,904-byte Granite span excess, OLMoE layer-0 expert offsets, `file_type`, `size_label`). Two parser defects were found and fixed during verification (see §8): a mis-keyed GGUF type table, and a per-token shortcut that assumes uniform layers. Neither affected this document's §§1–5 numbers: the type-table errors touched only quant types absent from these Q4_K_M files (Q4_K/Q6_K/F32 entries were already correct), and §4's per-token figures already use the exact top-k ÷ expert-count × expert-bytes arithmetic. The same verification pass added a third witness — the `qwen2moe` family the first worker had to reject on budget — as §7. Machine state for the verification pass: the 204 road's S-087 worker was live on purplelongship; this pass ran download + header parsing only, no inference, and did not touch `~/s087`.

---

## 1. File choice — and the alternatives rejected

The wave store held **no MoE GGUF at all** before this slice (381 files, all dense: llama / qwen2 / qwen3 / mistral3 / gemma4-dense — keeper-verified). Two files were acquired, total **6,230,401,056 bytes**, under the ~8 GB slice cap:

| # | Repo (Hugging Face) | File | Bytes | LFS sha256 pin | Downloaded sha256 |
|---|---|---|---|---|---|
| 1 (primary) | `allenai/OLMoE-1B-7B-0924-Instruct-GGUF` | `olmoe-1b-7b-0924-instruct-q4_k_m.gguf` | 4,213,512,672 | `8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f` | **matches pin** |
| 2 | `bartowski/granite-3.1-3b-a800m-instruct-GGUF` | `granite-3.1-3b-a800m-instruct-Q4_K_M.gguf` | 2,016,888,384 | `48e0edcd578fd4462f26127f04c651d0e650741110185297741089aea01a82b3` | **matches pin** |

**Why these two.**

- **True routed-expert MoE, both.** Per-layer fused expert tensors plus explicit routing metadata (`<arch>.expert_count`, `<arch>.expert_used_count`) — the anatomy Part II's streaming design (J-017) stands on.
- **Q4_K_M**, the road's primary quant class, in both — not a low-quant stand-in.
- **OLMoE primary:** the publisher's own GGUF repo (AllenAI), 64 experts × 16 layers, no shared expert — the cleanest reference anatomy. (Bartowski's duplicate of the same quant was rejected in favour of the official repo; the two differ by 352 header bytes.)
- **Granite second:** a different architecture family (IBM Granite MoE) with a contrasting anatomy — 40 experts × 32 layers, GQA attention, tied embeddings, an importance-matrix quant provenance recorded in the file, and (see §5) a *split* expert layout — for only 2.0 GB.
- **Fit to Aesir at the level Aesir reads today.** Aesir's GGUF loader (`aesir_engine/loader/gguf.mojo`, `PackedGGUF`) is architecture-generic: it parses `general.architecture`, the `<arch>.*` metadata keys, and the full tensor directory for any arch; the dense execution profiles (`core/dense_gqa_profile.mojo`) likewise read arch-prefixed keys generically. Per J-012, Aesir has **no MoE execution code at all** — so the honest level for this slice is exactly metadata + tensor map, and both files use the same tensor naming Aesir's proven dense families use (`token_embd.weight`, `blk.N.attn_*`, `blk.N.ffn_norm.weight`) with the expert tensors as the new, additional part.

**Rejected alternatives.**

- **Qwen1.5-MoE-A2.7B (arch `qwen2moe`)** — the closest relative of Aesir's proven Qwen2 line, and the keeper's first candidate, but: there is **no official Qwen GGUF repo** for it, and the community Q3_K_M is **7,437,745,472 bytes alone** (tensorblock) — it would consume the whole slice budget at a non-primary quant; the Q2_K is 5,890,164,032 bytes and worse. (The pre-slice estimate of "~3 GB for Q4_K_M" was wrong — the model has ~14 B total parameters; recorded here so the estimate is not repeated.)
- **Qwen3-30B-A3B (`qwen3moe`)** — the Part II flagship class, but its Q4_K_M is far above this slice's cap; it belongs to J-022 / J-123 / J-032, not to an anatomy slice.
- **Mixtral-8×7B (`llama` arch)** — attractive because Aesir's llama line is proven, but ~26 GB class at Q4_K_M; same deferral as above.
- **Phi-3.5-MoE, DeepSeek-V2-Lite, Qwen3-Next-80B** — all far above the cap; larger MoE anatomies are J-022/J-032/J-123 territory.

---

## 2. Routing metadata — what the files declare

### OLMoE (`general.architecture = olmoe`), GGUF v3, 38 metadata keys, 195 tensors

| Key | Value |
|---|---|
| `olmoe.block_count` | 16 |
| `olmoe.embedding_length` | 2048 |
| `olmoe.feed_forward_length` (per-expert FFN width) | 1024 |
| `olmoe.context_length` | 4096 |
| `olmoe.attention.head_count` / `head_count_kv` | 16 / 16 (MHA) |
| **`olmoe.expert_count`** | **64** |
| **`olmoe.expert_used_count` (top-k)** | **8** |
| `general.file_type` | 15 (= Q4_K_M), `general.quantization_version` 2 |
| `general.size_label` | `64x577M` |
| `olmoe.rope.freq_base` | 10000.0 |
| `olmoe.attention.layer_norm_rms_epsilon` | ~1e-5 |

**Absent (checked, not assumed):** no `expert_weights_scale`, no expert-norm key, no shared-expert anything, no router bias. Routing-relevant metadata is exactly the two expert keys.

### Granite (`general.architecture = granitemoe`), GGUF v3, 46 metadata keys, 322 tensors

| Key | Value |
|---|---|
| `granitemoe.block_count` | 32 |
| `granitemoe.embedding_length` | 1536 |
| `granitemoe.feed_forward_length` (per-expert FFN width) | 512 |
| `granitemoe.context_length` | 131072 |
| `granitemoe.attention.head_count` / `head_count_kv` | 24 / 8 (GQA) |
| **`granitemoe.expert_count`** | **40** |
| **`granitemoe.expert_used_count` (top-k)** | **8** |
| `general.file_type` | 15 (= Q4_K_M), `general.quantization_version` 2 |
| `granitemoe.vocab_size` | 49155 |
| Granite scalar multipliers | `embedding_scale` 12.0, `residual_scale` 0.22, `logit_scale` 6.0, `attention.scale` 0.015625 |
| `granitemoe.rope.dimension_count` / `rope.freq_base` | 64 / 10,000,000.0 |
| Quant provenance | `quantize.imatrix.*` keys present (imatrix file, 250 entries, 152 chunks — bartowski importance-matrix build) |

**Absent:** the same routing absences as OLMoE — no expert scale/norm keys, no shared experts, no router bias. The Granite scalar multipliers are architecture-wide constants, not routing metadata.

---

## 3. Tensor map — how the experts are stored

**Both files use fused expert tensors exclusively. Neither contains a single per-expert tensor.**

Per MoE layer, exactly three expert tensors, named (layer `N`):

- `blk.N.ffn_gate_exps.weight`
- `blk.N.ffn_up_exps.weight`
- `blk.N.ffn_down_exps.weight`

GGUF dims are stored ne-order (fastest-varying first); the expert count is always the **last (slowest-varying) dim**, so expert *e* occupies one contiguous slab inside each fused tensor — slab size = tensor bytes ÷ expert count.

| | OLMoE gate_exps / up_exps | OLMoE down_exps | Granite gate_exps / up_exps | Granite down_exps |
|---|---|---|---|---|
| dims (ne) | [2048, 1024, 64] | [1024, 2048, 64] | [1536, 512, 40] | [512, 1536, 40] |
| quant | Q4_K, all 16 layers | Q6_K in 8 layers, Q4_K in 8 | Q4_K, all 32 layers | Q6_K in 16 layers, Q4_K in 16 |
| tensor bytes | 75,497,472 | 110,100,480 (Q6_K) / 75,497,472 (Q4_K) | 17,694,720 | 25,804,800 (Q6_K) / 17,694,720 (Q4_K) |
| **per-expert slab** | **1,179,648** | **1,720,320 (Q6_K) / 1,179,648 (Q4_K)** | **442,368** | **645,120 (Q6_K) / 442,368 (Q4_K)** |

The Q4_K_M recipe makes itself visible here: in both files `gate`/`up` are uniformly Q4_K, while `down_exps` is **up-quantized to Q6_K in exactly half the layers** (OLMoE layer pattern, 0→15: `6644644644644666`; Granite: `66664464464464464464464464466666` — digit = down_exps quant of that layer). Any per-expert or per-token byte figure is therefore **layer-dependent**; §4 gives ranges, not a single dressed-up number.

**Per-expert total (gate + up + down slabs):**

- OLMoE: 3,538,944 bytes (Q4_K-down layer) / 4,079,616 bytes (Q6_K-down layer)
- Granite: 1,327,104 bytes (Q4_K-down layer) / 1,529,856 bytes (Q6_K-down layer)

**The router** is one dense tensor per layer in both files: `blk.N.ffn_gate_inp.weight`, F32 — OLMoE [2048, 64] = 524,288 bytes/layer (8,388,608 total); Granite [1536, 40] = 245,760 bytes/layer (7,864,320 total). **No bias tensor accompanies it in either file.**

**Shared experts: none.** Neither file contains any `*shexp*` tensor or any other expert-named tensor beyond the fused triples and the routers (verified by name scan of the full directories: OLMoE 195 tensors, Granite 322 tensors; expert-named = 48 + 16 routers and 96 + 32 routers respectively).

**Resident (non-routed) set, by category:**

| Category | OLMoE bytes | Granite bytes |
|---|---|---|
| `token_embd.weight` | 57,950,208 (Q4_K) | 61,935,300 (Q6_K) |
| output | 84,518,912 (`output.weight` Q6_K 84,510,720 + `output_norm` 8,192) | 6,144 (`output_norm` only — **tied embeddings**, no `output.weight`) |
| attention (all layers: q/k/v/output + attention-side norms) | 160,038,912 | 116,686,848 |
| norms (non-attention) | 131,072 | 196,608 |
| routers (`ffn_gate_inp`, counted resident — they are read every token) | 8,388,608 | 7,864,320 |
| **Resident total** | **311,027,712** | **186,689,220** |

Whole-file tensor-type split: OLMoE — Q4_K 3,209,969,664 / Q6_K 992,839,680 / F32 8,921,088. Granite — Q4_K 1,521,745,920 / Q6_K 485,134,020 / F32 8,263,680. (F32 is the norms + routers in both.)

---

## 4. The streaming ratio — expert bytes vs resident bytes

| | OLMoE | Granite |
|---|---|---|
| File bytes | 4,213,512,672 | 2,016,888,384 |
| Header (metadata + directory) bytes | 1,782,240 (data starts here) | 1,744,736 |
| Σ tensor bytes | 4,211,730,432 | 2,015,143,620 |
| **Routed-expert bytes** | **3,900,702,720** | **1,828,454,400** |
| Expert share of tensor bytes | **92.62 %** | **90.74 %** |
| Expert share of file bytes | 92.58 % | 90.66 % |
| Resident bytes | 311,027,712 (7.38 %) | 186,689,220 (9.26 %) |
| Expert : resident ratio | 12.5 : 1 | 9.8 : 1 |
| Per-layer expert bytes | 226,492,416 / 261,095,424 (by down-quant) | 53,084,160 / 61,194,240 (by down-quant) |
| **Per-token expert bytes, one layer** (top-k × per-expert total) | **28,311,552 – 32,636,928** | **10,616,832 – 12,238,848** |
| **Per-token expert bytes, all layers** (exact: top-k ÷ expert_count × expert bytes) | **487,587,840** | **365,690,880** |

The per-token figures are the **cold-cache, all-distinct-experts ceiling**: one token, top-8 routing in every layer, every chosen expert read from disk once, no cache hit and no expert repeated across the token's layers counted twice. Real demand is lower wherever J-016's router traces show reuse — that measurement is J-016's, not this slice's. What this slice proves is the shape of the problem Part II designs against: **≈ 0.37–0.49 GB of expert traffic per generated token against a resident set of only 0.19–0.31 GB** — the resident set fits comfortably in memory once; the expert stream is the workload.

---

## 5. On-disk layout — what a streaming reader actually faces

**Global (both files).** Tensor-directory order **is** offset order (monotonic in both files). Tensors are packed back-to-back at 32-byte alignment. OLMoE has **zero** padding gaps anywhere. Granite has exactly **one**: 28 bytes after `token_embd.weight` (its Q6_K size, 61,935,300, is ≡ 4 mod 32). Header + tensors + that one gap = file size, exactly, in both files.

**OLMoE — one contiguous expert run per layer.** File order within a layer (verified layers 0 and 1, pattern uniform):

`attn_norm` → **`ffn_down_exps` → `ffn_gate_exps` → `ffn_up_exps`** → `ffn_gate_inp` (router) → `ffn_norm` → `attn_k_norm`, `attn_k`, `attn_output`, `attn_q_norm`, `attn_q`, `attn_v`.

The three expert tensors are **adjacent with zero gap** (span = own bytes, all 16 layers): a whole layer's experts are a single 226–261 MB contiguous extent. Note the order inside the run is **down, gate, up** — not the gate, up, down computation order. But a *single routed expert* is never contiguous: it is three slabs in three tensors. Worked example, layer 0, expert 0 (absolute file offsets): down slab at **59,740,640**, length 1,720,320; gate slab at **169,841,120**, length 1,179,648; up slab at **245,338,592**, length 1,179,648. A streaming reader (J-019) therefore issues **3 seeks per expert per layer**, each landing on a ≥ 442 KB contiguous slab — sequential-friendly reads, random only at slab granularity.

**Granite — the expert run is split.** File order within a layer:

`attn_k`, `attn_norm`, `attn_output`, `attn_q`, `attn_v` → `ffn_down_exps` → `ffn_gate_exps` → `ffn_gate_inp` (router), `ffn_norm` → `ffn_up_exps`.

Down+gate are adjacent, but **up_exps sits after the router and the FFN norm**: in every one of the 32 layers the expert span exceeds the expert bytes by exactly **251,904 bytes** (245,760 router + 6,144 norm). Same 3-slab read pattern as OLMoE, but a reader that assumes "one layer = one run" would over-read or mis-seek on this family. Two families, two layouts — the residency design (J-017) must key its extents off the tensor directory per file, never off a family assumption.

**Distance pattern.** Because directory order = file order and layers are laid out sequentially, consecutive layers' expert extents are separated only by the layers' resident tensors (per-layer resident totals: ≈ 10.5 MB OLMoE, ≈ 3.9 MB Granite — attention + norms + router, from §3's totals ÷ layer counts). A token's full expert working set is up to 128 (OLMoE) / 256 (Granite) expert selections per token, i.e. up to **384 / 768 slab reads** scattered across the whole file span — the access pattern J-019's disk discipline and J-018's cache are designed for.

---

## 6. What this slice does not prove

- **No inference was run.** That Aesir (or anything) executes these files is NOT PROVEN here and is not claimed; Aesir has no MoE execution code (J-012). Execution witnesses belong to J-022 and the Part VIII arch slices.
- **Router behaviour** (hit distribution, reuse, working set over real prompts) is not in the files — it is J-016's measurement, deliberately not pre-judged here.
- **Expert slab arithmetic assumes the standard GGUF quant block sizes** (Q4_K 144 B / 256 elems, Q6_K 210 B / 256 elems, F32/F16/Q4_K layouts per the format); the exact file-size accounting in §5 (header + Σ tensors + gaps = file size, to the byte, in both files) is the cross-check that those block sizes are right for these files.
- The two files above are the anatomy of **two** MoE families; §7 adds a third, **qwen2moe**, measured in the verification pass. The remaining families (qwen3moe, qwen3next, gemma4-MoE) are NOT PROVEN anatomies until their own files are parsed the same way — J-076 and Part VIII own those.

---

## 7. Witness C — Qwen1.5-MoE-A2.7B-Chat (`qwen2moe`), measured in the verification pass

The family closest to Aesir's proven Qwen2 line, rejected by the first worker because its Q4_K_M-class files exceed the slice budget (the model is ~14.3 B total parameters, not the ~3 GB pre-slice estimate). The verification pass acquired the smallest file in the family instead — a low quant is sufficient for an anatomy, whose facts (tensor map, metadata, layout) are quant-independent in structure, with per-tensor quant choices recorded as found:

| | |
|---|---|
| Repo / file | `tensorblock/Qwen1.5-MoE-A2.7B-Chat-GGUF` / `Qwen1.5-MoE-A2.7B-Chat-Q2_K.gguf` (Qwen's own GGUF repo answered HTTP 401 on 2026-10-31; this is its community mirror) |
| Bytes / sha256 | 5,890,164,032 / `cce008140714bb8b76185c0e2db802c60ce62182fa2eddb86ac53303b7525986` — matches the repo's HF LFS oid exactly; held on purplelongship at `~/j015/` |
| Header | GGUF v3, alignment 32, 34 KV keys, 411 tensors, tensor data starts at byte 5,954,880; Σ tensor bytes 5,884,209,152; header + Σ tensors = file size exactly, zero gaps |
| Routing metadata | `qwen2moe.block_count` 24, `embedding_length` 2048, `context_length` 32768, heads 16/16, `feed_forward_length` 5632, **`expert_count` 60, `expert_used_count` 4**, `expert_feed_forward_length` 1408, `expert_shared_feed_forward_length` 5632; `general.file_type` 10 (Q2_K recipe label) |
| Parameters (directory sum) | 14,315,784,192 |

**Tensor map.** Uniform 17 tensors per layer × 24, plus `token_embd` / `output` / `output_norm`. The expert layout is the **same fused triple** as §§3–5 — `ffn_gate_exps` Q2_K [2048, 1408, 60], `ffn_up_exps` Q2_K [2048, 1408, 60], `ffn_down_exps` IQ4_NL [1408, 2048, 60] — no per-expert tensors, no combined gate+up tensor. Per-expert slabs: gate 946,176 / up 946,176 / down 1,622,016 = **3,514,368 bytes per expert per layer**; per-token routed bytes (top-4, exact) **337,379,328** across 24 layers.

**Where it differs from both §1 witnesses — shared experts exist here.** Each layer carries a full shared-expert FFN (`ffn_gate_shexp` / `ffn_up_shexp` Q2_K [2048, 5632], `ffn_down_shexp` Q3_K [5632, 2048] — 12,525,568 bytes/layer) plus its own learned gate vector `ffn_gate_inp_shexp.weight` F32 [2048], beside the ordinary router `ffn_gate_inp.weight` F32 [2048, 60] (491,520 bytes/layer). The shared width 5632 is exactly 4× a routed expert's 1408. A residency design (J-017) must treat the shared expert as resident, not streamed: it fires on every token.

**Byte split.** Routed experts 5,060,689,920 bytes = **86.03 %** of tensor bytes. Resident 823,519,232: token embedding 102,100,992 (Q2_K), output 255,260,672 (Q6_K `output.weight` + norm), attention 153,354,240, shared-expert FFN 300,613,632, routers (both gates) 11,993,088, norms 196,608. Quant mix: Q2_K 3,074,813,952 / IQ4_NL 2,335,703,040 / Q6_K 255,252,480 / Q3_K 205,455,360 / F32 12,984,320 — the recipe upgrades the routed `down` matrices to IQ4_NL inside a "Q2_K" file, the same per-tensor hand visible in §3's Q4_K_M files.

**Layout.** Directory order = offset order, zero gaps, last tensor ends at EOF. Within a layer the expert tensors are interleaved with the shared-expert tensors (file order: `down_exps, down_shexp, gate_exps, gate_inp, gate_inp_shexp, gate_shexp, …, up_exps, up_shexp`), so a layer's expert span is 220,110,848 bytes for 210,862,080 bytes of experts — a third layout variant beside OLMoE's single run (§5) and Granite's split run (§5): the span's extra bytes are resident shared-expert data a streaming reader skips in place.

**Fourth file (parser-validation fodder, not a §1 witness).** The verification pass also parsed `bartowski/OLMoE-1B-7B-0924-Instruct-GGUF`'s `OLMoE-1B-7B-0924-Instruct-Q2_K.gguf` (2,562,763,584 bytes, sha256 `0b6554d40b4ae1ed84c20f0411b7869c10da264e826b8f185758cfd02e782b33`, matches its HF LFS oid; `~/j015/` on purplelongship): same `olmoe` anatomy as §2/§3 at Q2_K recipe (expert share 91.06 %, per-token exact 291,504,128 bytes), included in the evidence JSON. Its directory is what exposed the §8 type-table bug — its sibling Q4_K_M file could not have.

---

## 8. Parser defects found and fixed; evidence files

The campaign parser (`j015_parse_gguf.py`) is this slice's measuring instrument, so its defects are slice defects; both were fixed in scope and re-validated before banking:

1. **Mis-keyed GGUF type table.** From type id 19 onward the entries were shifted (id 20 labelled `I16` — it is `IQ4_NL`, 18 B/block), `Q8_1` read 36 B/block (correct: 40), `IQ3_XXS` 50 (correct: 98). On the Qwen file this mis-sized all 24 `ffn_down_exps` tensors. The table was corrected entry-by-entry against gguf-py's `GGMLQuantizationType` + `GGML_QUANT_SIZES`; the fixed parser reproduces gguf-py's `n_bytes` for **all 1,123 tensors across the four parsed files with zero mismatches** (the §§1–5 files were unaffected only because their quant types sat in the table's correct region).
2. **Uniform-layer per-token shortcut.** The parser's `per_token_expert_bytes_all_layers` multiplied one layer's per-expert bytes by the layer count — an overstatement on mixed-quant files (it reported 522,190,848 for OLMoE Q4_K_M against the exact 487,587,840). An exact field (`per_token_expert_bytes_all_layers_exact` = expert bytes × top-k ÷ expert count) was added; §4/§7 quote the exact figures.

**Evidence files.** Campaign records `~/workspace/model-tests/janas/`: this document; `j015_anatomy.json` (fixed-parser analysis + full tensor directories for all four files); `j015_anatomy_raw_all.json` (the gguf-py reader dumps the analysis was computed from; the two device-side dumps sha256 `ebd1a880bca83614eb316c7abcc9cae58690bf05770c328d07276565921f5e51` and `8f5a94d48b210f57dc988ed623aac41ce0aeffe0ceaf04ad863a7a4cfcec9022`, retrieved byte-identical); `j015_parse_gguf.py` (fixed). Filed in the repo under `docs/janas/` (document, analysis JSON, parser). The models themselves are never committed; their pins are §§1 and 7.
