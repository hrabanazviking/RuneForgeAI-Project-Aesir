# GEMM KIND REGISTRY — FROZEN (S-092)

The GEMM kind registry for Project Aesir, frozen at roadmap slice S-092
(2026-10-31) against `origin/main` `2444d6106459128c93efe0d250413732b3a613e7`.
This is the map Part IV's CUDA work mirrors: every device kernel is built
against a row of this table, by GGML tensor type number.

## The three numbering spaces (read this first)

Aesir uses three different numbers for the same weight formats. Confusing
them is the classic registry bug; this freeze pins which is which.

1. **GGML tensor type** — per-tensor, on disk in every GGUF tensor info
   record. Constants: `GGMLType` in `aesir_engine/loader/gguf.mojo:21`.
   This is the registry's key column.
2. **CompressedFormatType** — per-tensor internal discriminant carried on
   a loaded tensor (`quant_format`). Constants and `name()`:
   `aesir_engine/core/mimir_well.mojo:463`. The loader maps (1) → (2) in
   `GGMLType.to_compressed_format` (`loader/gguf.mojo:50`). Dense types
   (F32/F16/BF16) have **no** compressed format: they are mapped plain or
   converted at load, never routed through the compressed dispatch.
3. **GEMM kind** — the `Int` handed to a GEMM dispatch helper. For the
   K-quant, IQ, and ternary families the kind **is** the GGML type number
   (kinds 10–14, 16–23/29, 34/35). The legacy and precision families have
   no kind number; they dispatch by named function (`gemm_q4_0`,
   `gemm_f16_direct`, `gemm_bf16`, …) from `gemm_f16`
   (`core/compute.mojo:2660`).

Status vocabulary: **FAST** = decode-once GEMM (each packed block decoded
once into an f32 scratch row, SIMD dot, output columns partitioned across
threads, bit-identical to the serial body). **SCALAR** = per-element
decode on every use, serial loops (correct, slow). **DIRECT** = dense
storage read with no dequant step. **LATENT** = implemented and
fixture-gated, but no acquired file carries the type. **REJECTED** =
deliberately not mapped; the loader fails closed.

## The frozen table — GGUF tensor types

Byte sizes are per packed block from `GGUFSeer._tensor_byte_size`
(`loader/gguf.mojo:841`). Embedding = `_embed_token_into`
(`core/inference.mojo:861`) unless noted.

| GGML type | Name | Format (2) | Bytes/block | GEMM route (kind) | Embedding | Status |
|---|---|---|---|---|---|---|
| 0 | F32 | — (plain) | 4 B/elem | dense; converted to F16 at load (`_map_tensor`, gguf.mojo:950) | plain | SUPPORTED (dense) |
| 1 | F16 | — (plain) | 2 B/elem | `gemm_f16_direct` (compute.mojo:2436), width-16 SIMD, threaded | plain | **FAST — DIRECT** |
| 2 | Q4_0 | 4 (Q4_0) | 18 B/32 | `gemm_q4_0` (compute.mojo:737) | yes | SCALAR |
| 3 | Q4_1 | 5 (Q4_1) | 20 B/32 | `gemm_q4_1` (compute.mojo:775) | yes | SCALAR |
| 6 | Q5_0 | 8 (Q5_0) | 22 B/32 | `gemm_q5_0` (compute.mojo:819) | yes | SCALAR — LATENT (no store file) |
| 7 | Q5_1 | 9 (Q5_1) | 24 B/32 | `gemm_q5_1` (compute.mojo:871) | yes | SCALAR — LATENT (no store file) |
| 8 | Q8_0 | 13 (Q8_0) | 34 B/32 | `gemm_q8_0` (compute.mojo:1070) → `_gemm_q8_0_fast_range`, decode-once SIMD, threaded | yes | **FAST** |
| 9 | Q8_1 | 14 (Q8_1) | 36 B/32 | `gemm_q8_1` (compute.mojo:1101) | **no branch** | SCALAR — LATENT (no store file) |
| 10 | Q2_K | 0 (Q2_K) | 84 B/256 | `_gemm_k_fast` kind 10 (compute.mojo:1720) | K branch | **FAST** |
| 11 | Q3_K | 2 (Q3_K_M) | 110 B/256 | `_gemm_k_fast` kind 11 | K branch | **FAST** |
| 12 | Q4_K | 7 (Q4_K_M) | 144 B/256 | `_gemm_k_fast` kind 12 (+ VNNI int8 mode, kinds 12/14 only) | K branch | **FAST** |
| 13 | Q5_K | 11 (Q5_K_M) | 176 B/256 | `_gemm_k_fast` kind 13 | K branch | **FAST** |
| 14 | Q6_K | 12 (Q6_K) | 210 B/256 | `_gemm_k_fast` kind 14 (+ VNNI int8 mode) | K branch | **FAST** |
| 15 | Q8_K | — **unmapped** | — | none | no | **REJECTED — LATENT (see below)** |
| 16 | IQ2_XXS | 24 | 66 B/256 | `_gemm_iq_fast` kind 16 (compute.mojo:1884) | yes | **FAST** |
| 17 | IQ2_XS | 28 | 74 B/256 | `_gemm_iq_fast` kind 17 | yes | **FAST** |
| 18 | IQ3_XXS | 29 | 98 B/256 | `_gemm_iq_fast` kind 18 | yes | **FAST** |
| 19 | IQ1_S | 23 | 50 B/256 | `_gemm_iq_fast` kind 19 | yes | **FAST** (parity note below) |
| 20 | IQ4_NL | 30 | 18 B/32 (144 B/256 super-block) | `_gemm_iq_fast` kind 20 | dedicated 32-block branch | **FAST** |
| 21 | IQ3_S | 27 | 110 B/256 | `_gemm_iq_fast` kind 21 | yes | **FAST** |
| 22 | IQ2_S | 26 | 82 B/256 | `_gemm_iq_fast` kind 22 | yes | **FAST** |
| 23 | IQ4_XS | 31 | 136 B/256 | `_gemm_iq_fast` kind 23 | yes | **FAST** |
| 29 | IQ1_M | 32 | 56 B/256 | `_gemm_iq_fast` kind 29 | yes | **FAST** |
| 30 | BF16 | — (plain) | 2 B/elem | at-load conversion `convert_bf16_to_f16` (loader) + direct `gemm_bf16` (compute.mojo:2535) for raw BF16 storage | plain (converted) | **FAST — DIRECT** (GEMM fixture-gated: no BF16 weight file exists) |
| 34 | TQ1_0 | 25 (TQ1_0) | 54 B/256 | `_gemm_tq_fast` kind 34 (compute.mojo:2351), decode-once threaded; block decode is the shared scalar `dequantize_tq_block` by design | yes | **FAST** (decode-once) — LATENT, fixture-gated (S-088) |
| 35 | TQ2_0 | 33 (TQ2_0) | 66 B/256 | `_gemm_tq_fast` kind 35 | yes | **FAST** (decode-once) — LATENT, fixture-gated (S-088) |

IQ block decode for the fast path is `dequantize_iq_block`
(`core/extreme_quantization.mojo:1357`) with per-kind block sizes from
`iq_block_bytes` (extreme_quantization.mojo:1226); the SIMD lane decoders
are proven bit-identical to the scalar `*_value` decoders per kind
(S-030/S-084/S-087). Whole-tensor dequantization for every mapped format
goes through `dequantize_compressed_tensor` (compute.mojo:621).

### The Q8_K row (GGML type 15) — deliberately loader-rejected / latent

Q8_K is named in `GGMLType` (gguf.mojo:35) and **deliberately absent**
from `to_compressed_format`: a file carrying a Q8_K tensor fails closed
at load with `unsupported GGML tensor type 15`. `_tensor_byte_size` has
no Q8_K branch either (its fallthrough is unreachable — `_map_tensor`
raises in `to_compressed_format` immediately after sizing). Reason,
measured not assumed: Q8_K occurs in **zero** tensors of the 282-file
acquired-store census (S-079) and in **zero** tensors of the 8 sampled
UD candidate files (S-091) — in ggml it is an activation/K-cache-side
type, not a published weight rung (the file named `…-Q8_K_XL.gguf`
contains zero Q8_K tensors; see the UD section). If a future acquisition
brings real Q8_K weight tensors, that file will fail closed until a
slice builds its dequant/GEMM path — the correct behaviour, recorded
here so Part IV does not mirror a Q8_K kernel against a type the host
engine rejects.

### Parity note (IQ1_S, and the extreme rungs generally)

FAST is a statement about the GEMM path, not about token-exact parity.
For IQ1_S, ggml's own CPU and CUDA kernels disagree with each other
(S-029), so Aesir is graded on coherence against the oracle (road
S-095), never on token-exactness. The same honesty applies to IQ1_M and
TQ1_0 rows when real files arrive.

## File-level rung labels with no tensor type of their own

These names appear in filenames, catalog tags, and `general.file_type`
(§ below) but are **recipes over the tensor types above**, never types:

- **Q3_K_S / Q3_K_M / Q3_K_L** — all type 11 (+ Q6_K minorities). The
  S/M/L distinction is a file-level mix; one GEMM treatment (kind 11).
  `to_compressed_format` maps type 11 to format Q3_K_M (2); formats
  Q3_K_S (1) / Q3_K_L (3) exist as discriminants and share the same
  dequant/GEMM code.
- **Q4_K_S / Q4_K_M** — type 12 (format Q4_K_M 7; Q4_K_S is 6).
- **Q5_K_S / Q5_K_M** — type 13 (format Q5_K_M 11; Q5_K_S is 10).
- **Q2_K_S** — type 10 files with a different mix; kind 10 unchanged.
- **IQ2_M** — a mix of IQ2_S (22) blocks with IQ3_S/IQ2_XS minorities
  and K-type minorities; no IQ2_M tensor type exists.
- **IQ3_M** — a mix over IQ3_S (21) + IQ3_XXS (18) + K types.
- **IQ3_XS** — a mix label (bartowski) over IQ3_S/XXS constituents.
- **IQ4_M** — no tensor type and no acquired rung file; the IQ4 family
  is types 20 (NL) and 23 (XS) only.
- **UD-\* and \*\_XL** — dynamic per-layer recipes (next section).

## Mixed-type files and UD variants — dispatch is per-tensor, always

Every loader, GEMM, embedding, and head path dispatches on the
**individual tensor's** type/format, never on a file-level assumption
(audited S-090, re-confirmed S-091/S-092): `_map_tensor` /
`_tensor_byte_size` / `to_compressed_format` per tensor (gguf.mojo),
`gemm_f16` dispatch on `B.quant_format` per call (compute.mojo:2660),
`_embed_token_into` per embedding tensor (inference.mojo:861). Real
files are always mixes (270/271 LM files in the S-090 census, 244/271
mixed even excluding F32 norms).

**UD (unsloth/JMingo-style dynamic) files are the extreme case of the
same mechanism** — a per-layer, per-role sensitivity recipe over the
standard types above — and need no UD-specific code path. Two facts
are frozen here because they are easy to get wrong:

1. **`*_XL` is a recipe label, not a tensor type.** There is no
   Q8_K_XL / Q5_K_XL / Q3_K_XL / Q2_K_XL tensor type in GGUF, in the
   sampled candidate files, or in this registry (S-091 header census:
   the Q8_K_XL file's tensors are Q8_0 157 / F16 50 / BF16 1).
2. **`general.file_type` CANNOT express UD-ness.** A UD file declares
   the same file_type as its canonical neighbour (UD-Q4_K_XL = 15 =
   Q4_K_M; UD-Q8_K_XL = 7 = Q8_0) and GGUF carries no UD marker of any
   kind. A UD rung's identity therefore lives in its catalog name:tag
   and filename rung string — never in the ftype name returned by
   `gguf_quantization_name`. (Also documented at that function,
   `core/model_registry.mojo:16`.)

## `general.file_type` — the ftype → name table (frozen)

`gguf_quantization_name` (`core/model_registry.mojo:16`) names a file's
`general.file_type` — the llama.cpp `llama_ftype` MOSTLY_* enum. It is a
**file-level headline label**, not a tensor type and not a support
statement: a file labelled IQ2_M contains IQ2_S/IQ3_S/K tensors (§
above), and naming a value here does not mean Aesir can run such a file
(that is the tensor table's question). The table was completed at
S-092 — before the freeze it named only 11 values and returned
`unknown(n)` for 17 of the 27 values that actually occur in the
acquired stores (S-092 census: 284 files, values 0,1,2,3,7,10–31, plus
7 imatrix data files carrying no file_type at all). Every live enum
value is now named; values removed upstream (4/5/6, 33/34/35) and
GUESSED (1024) stay `unknown(n)` by design. The full mapping is pinned
by `test_model_registry` (`native.model_registry` in the counted run).

| file_type | Name | | file_type | Name |
|---|---|---|---|---|
| 0 | F32 | | 19 | IQ2_XXS |
| 1 | F16 | | 20 | IQ2_XS |
| 2 | Q4_0 | | 21 | Q2_K_S |
| 3 | Q4_1 | | 22 | IQ3_XS |
| 7 | Q8_0 | | 23 | IQ3_XXS |
| 8 | Q5_0 | | 24 | IQ1_S |
| 9 | Q5_1 | | 25 | IQ4_NL |
| 10 | Q2_K | | 26 | IQ3_S |
| 11 | Q3_K_S | | 27 | IQ3_M |
| 12 | Q3_K_M | | 28 | IQ2_S |
| 13 | Q3_K_L | | 29 | IQ2_M |
| 14 | Q4_K_S | | 30 | IQ4_XS |
| 15 | Q4_K_M | | 31 | IQ1_M |
| 16 | Q5_K_S | | 32 | BF16 |
| 17 | Q5_K_M | | 36 | TQ1_0 |
| 18 | Q6_K | | 37 | TQ2_0 |
|  |  | | 38 | MXFP4_MOE (named; **no tensor support**) |
|  |  | | 39 | NVFP4 (named; **no tensor support**) |
|  |  | | 40 | Q1_0 (named; **no tensor support**) |

## Out of the freeze's scope (recorded so the spaces are not confused)

`CompressedFormatType` values 15–22 (GPTQ_4BIT, GPTQ_8BIT, AWQ_4BIT,
EXL2_VARBIT, HQQ, SMOOTHQUANT_INT8, FP8_E4M3, FP8_E5M2) belong to the
external-format surface (GPTQ/AWQ/EXL2/FP8 loaders), not to GGUF tensor
types. They share the format discriminant space and the `gemm_f16`
dispatch, but they are not GEMM *kinds* in the sense of this registry
and Part IV does not mirror them. GGML types 24–28 (I8/I16/I32/I64/F64)
and 39–41 (MXFP4/NVFP4/Q1_0 tensor types) are not named in `GGMLType`
and are loader-rejected like Q8_K, with no acquired file carrying them.

## Freeze statement

This table was audited line-by-line against the source at
`2444d610` (S-092): loader mapping, byte sizes, GEMM dispatch
(`_gemm_k_fast`, `_gemm_iq_fast`, `_gemm_tq_fast`, the legacy scalar
GEMMs, `gemm_q8_0`'s fast path, `gemm_f16_direct`/`gemm_bf16`),
`dequantize_iq_block`, and the embedding branches. Changes to any row
require a slice that updates this document in the same commit.
