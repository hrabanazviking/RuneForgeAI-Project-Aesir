# QC-0 — Compression workstream: recon + slice plan (RECON AND PLAN ONLY)

Commission (Volmarr, 2026-11-14): "work on teaching it how to compress
the models too." Aesir already READS the whole compression ladder;
this workstream teaches it to WRITE compression: quantize a source
model and emit a valid GGUF that Aesir itself — and llama.cpp as an
independent cross-check — can load and run.

Method note: this slice was executed by ONE worker running the Forge
roles sequentially (recon → spec → plan). No sub-agents were spawned
(depth limit), no code was changed, no model was loaded, nothing was
compiled. Every fact below is from a read-only probe of the tree at
base 9853ba62 (branch yrsa/qc-0, worktree /home/volmarr/aesir-qc) or
from the campaign's own banked notes in this folder. File/line
evidence is given so the coordinator can re-verify from disk.

## Goal + grading discipline (fixed by the commission)

- Deliverable of the workstream: an `aesir quantize`-class path that
  takes a registered GGUF source, requantizes its weight tensors to a
  named tier, and writes a new GGUF v3 file.
- Grade, for every tier and every model: teacher-forcing rank + logit
  gap on RAW prompts, compressed output vs ITS OWN uncompressed (or
  least-compressed available) source, CPU-vs-CPU. The machinery
  already exists: aesir_engine/core/near_tie_gate.mojo (band:
  rank <= 2 AND gap_milli < 1000, i.e. sub-logit; rank 0 requires gap
  0; worst rank and worst gap are independent maxima, never averaged).
  Near-tie band = faithful compression.
- Size-vs-quality is reported per tier honestly, including where a
  tier hurts. A tier that grades divergent is reported divergent,
  not re-banded.
- Cross-check bar: a file is "written" only when BOTH our loader
  (GGUFSeer/PackedGGUF + profile validation) AND llama.cpp load it.
  Where the two readers' expectations differ, the cross-check slice
  settles it from evidence, never by assumption.

## 1. Dequant inventory — what the engine can READ today

GGML type numbers are loader/gguf.mojo GGMLType (lines 21-47).
CompressedFormatType discriminants (core/mimir_well.mojo:497-531)
DIFFER from GGML numbers; core/packed_quantization.mojo
ggml_kind_of_format() is the only sanctioned translation — a writer
must emit GGML numbers in the file, never format discriminants.

### 1a. Classic 32-value blocks (core/compute.mojo, byte-walked)

| fmt | GGML | bytes/blk | layout (offsets in block) | formula |
|---|---|---|---|---|
| Q4_0 | 2 | 18 | f16 d @0; 16 qs bytes @2 | (nib-8)*d; low nibbles = lanes 0-15, high = 16-31 (compute.mojo dequantize_q4_0; loader/quantization.mojo dequantize_q4_0_block agrees) |
| Q4_1 | 3 | 20 | f16 d @0, f16 min @2, qs @4 | nib*d + min (asymmetric) |
| Q5_0 | 6 | 22 | f16 d @0, qh 4B @2, qs 16B @6 | ((nib \| hb<<4)-16)*d |
| Q5_1 | 7 | 24 | f16 d @0, f16 min @2, qh @4, qs @8 | (nib \| hb<<4)*d + min (asymmetric) |
| Q8_0 | 8 | 34 | f16 d @0, 32 x i8 @2 | q*d, SIGNED quants |
| Q8_1 | 9 | 40 in compute (f32 d @0, f32 sum @4, qs @8) BUT loader _tensor_byte_size prices 36 B/blk — CONFLICT, see U-QC2 |
| FP8 E4M3/E5M2 | — (non-GGUF compute only) | 1 B/elem | dequantize_fp8_* in compute.mojo; no GGML type, not a GGUF write target |

Trap recorded in-tree: the Mojo BlockQ4_1/Q5_0/Q5_1 structs have
32-byte stride, NOT the packed size; all production readers walk raw
bytes (S-083 comments). A writer must emit the PACKED sizes above.

### 1b. K-quants: 256-value super-blocks (core/packed_quantization.mojo packed_value + packed_block_group; core/compute.mojo _dequantize_ggml_k_simd — declared bit-identical)

| fmt | GGML | bytes | layout | formula |
|---|---|---|---|---|
| Q2_K | 10 | 84 | 16 scale/min bytes @0 (low nibble scale, high nibble min, per 16-elem sub-block), 64 qs @16 (2-bit), f16 d @80, f16 dmin @82 | d*(sc&15)*q - dmin*(sc>>4) |
| Q3_K | 11 | 110 | 32 high-bit bytes @0, 64 low bytes @32, 12 scale bytes @96 (6-bit scales packed, bias -32), f16 d @108 | d*scale*q, q in -4..3 via high bit (signed trick: q = low if high set else low-4) |
| Q4_K | 12 | 144 | f16 d @0, f16 dmin @2, 12 scale/min bytes @4..15 (8 sub-blocks of 32: first 4 groups plain 6-bit scale+min bytes; last 4 packed across bytes 4-15 — see packed_value g>=4 reconstruction), 128 qs @16 (4-bit, low nibble = even group) | d*scale*q - dmin*min (asymmetric per sub-block) |
| Q5_K | 13 | 176 | same header as Q4_K; qh 32B @16, qs 128B @48 | Q4_K + high bit adds 16 |
| Q6_K | 14 | 210 | ql 128B @0, qh 64B @128, 16 x i8 scales @192 (per 16 elems), f16 d @208 | d*scale*((ql nib \| qh 2bit <<4) - 32); scales SIGNED, NO min (symmetric-with-offset-32) |
| Q8_K | 15 | — | named in GGMLType but NO dequant and _tensor_byte_size falls through to the Q4_0 default — effectively UNSUPPORTED; not a write target |

Q3_K_S/M/L, Q4_K_S/M, Q5_K_S/M are the SAME block layouts; the S/M/L
rung lives only in general.file_type + per-tensor type assignment
policy (which tensors get which precision), not in block bytes.
Q4_K/Q5_K arithmetic subtlety: the reader forms the INTEGER product
scale*q (<= 63*31 = 1953, exact in f32) BEFORE multiplying by d —
the writer's scale search must respect that this is the decode, and
round-trip tests must compare against this exact order.

### 1c. IQ + ternary: 256-value super-blocks (core/extreme_quantization.mojo + core/iq_codebooks.mojo)

All are codebook/grid formats: value = scale * grid_digit * sign,
with grid tables in core/iq_codebooks.mojo (IQ1_S_GRID 2048 entries,
IQ2_XXS_GRID 256, etc.). Byte sizes (iq_block_bytes / gguf
_tensor_byte_size, agreeing): IQ1_S 50, IQ1_M 56 (scale packed into
top nibbles of 4 u16 scale words @48 — no leading f16), IQ2_XXS 66,
IQ2_XS 74, IQ2_S 82, IQ3_XXS 98, IQ3_S 110 (= Q3_K size, different
layout), IQ4_NL 144 as 8x18B sub-blocks (f16 d + 16 qs each; values
via the NON-UNIFORM kvalues_iq4nl table: -127,-104,...,113 —
extreme_quantization.mojo _iq4nl_kv), IQ4_XS 136 (packed 6-bit
group scales, ls-32 bias, same iq4nl table), TQ1_0 54 (base-3
trits, scale @52), TQ2_0 66 (2-bit, values q-1, scale @64).
These are READ-ONLY citizens for this workstream: writing them
requires nearest-grid search over signed codebooks (a research
problem per format). Named as later rungs (QC-8 candidates), NOT
first targets. IQ2 sign encoding even uses a 7-bit even-parity
expansion (_iq2_sign_mask) — exactly the class of subtlety a writer
must not improvise.

### 1d. Non-GGUF external formats (core/external_quantization.mojo)

GPTQ 4/8-bit (group scales + qzeros, zero stored minus 1), AWQ
4-bit, EXL2 variable-bit, HQQ 4-bit axis-1, SmoothQuant W8A8 — full
dequant + GEMM, but these are in-memory matrix structs, not GGUF
tensor types. Out of scope for the GGUF writer; noted so nobody
counts them as GGUF-readable rungs.

Readable GGUF ladder, total: F32/F16/BF16 (dense) + Q4_0, Q4_1,
Q5_0, Q5_1, Q8_0, Q8_1(disputed size), Q2_K, Q3_K, Q4_K, Q5_K, Q6_K,
IQ1_S, IQ1_M, IQ2_XXS, IQ2_XS, IQ2_S, IQ3_XXS, IQ3_S, IQ4_NL,
IQ4_XS, TQ1_0, TQ2_0. PackedGGUF's geometry table
(loader/packed_gguf.mojo packed_block_geometry) covers only
0,1,2,3,6,7,8,10,11,12,13,14,20,23 — the packed (qwen35/gemma4)
path accepts FEWER types than GGUFSeer; a written file destined for
the qwen35 profile must use types in the intersection.

## 2. GGUF writer state: ABSENT — and the emission spec from our reader

Search evidence (grep quantize/writ/emit/serializ across aesir_engine
loader/, core/, cli/): NO GGUF writer exists. Serializers found are
for conversations, manifests/catalogs, model preferences, config and
the autotuner cache — never model bytes. Decisively,
aesir_engine/cli/llama_cpp_compat.mojo:66 lists quantize among
llama.cpp subcommands explicitly Unsupported, and cli/commands.mojo
has inspect/serve dispatch but no quantize command. The writer is
greenfield; its spec is our reader (loader/gguf.mojo GGUFSeer +
loader/packed_gguf.mojo), field by field:

- Header (24 B, all little-endian — every reader helper is LE):
  magic u32 0x46554747 ("GGUF"), version u32 == 3 ONLY (v2 refused),
  tensor_count u64 @8, kv_count u64 @16. (_parse_header)
- Metadata KV sequence starting at offset 24: key = GGUF string
  (u64 length + UTF-8 bytes, no NUL terminator), value_type u32,
  then the value. Duplicate keys are REFUSED. Value types (skip_value):
  0/1/7 = 1 B (u8/i8/bool), 2/3 = 2 B, 4/5/6 = 4 B (u32/i32/f32),
  10/11/12 = 8 B (u64/i64/f64), 8 = string, 9 = array
  (u32 elem_type + u64 count + elements; array elem type must be < 13).
- Typed-key contract (_parse_metadata_value): the writer MUST emit
  the types our reader demands or the file is refused —
  general.architecture STRING(8); <arch>.context_length /
  embedding_length / feed_forward_length / block_count /
  attention.head_count / head_count_kv / key_length /
  rope.dimension_count / sliding_window / ssm.* / expert_count etc
  UINT32(4); rope.freq_base / layer_norm_rms_epsilon and the
  scale/softcapping keys FLOAT32(6); tokenizer.ggml.unknown/bos/eos
  UINT32(4); add_bos_token / add_space_prefix BOOL(7);
  tokenizer.ggml.model / pre STRING(8); tokens = ARRAY(9) of STRING,
  merges = ARRAY of STRING, scores = ARRAY of F32, token_type =
  ARRAY of I32; general.alignment UINT32(4) if present
  (must be a power of two <= 4096; default alignment is 32).
  feed_forward_length MAY be a per-layer u32 array (gemma4 style) —
  the flat reader takes max, profiles read the array.
  tokenizer.validate_vocabulary() runs at load: the tokenizer KV set
  must be complete and consistent, so the writer COPIES the source
  file's metadata wholesale and changes only what quantization
  changes (general.file_type, general.name/quantization labels).
- Tensor directory (immediately after metadata): per tensor —
  name string, n_dims u32 (reader accepts 1..3 ONLY), dims as u64
  each in GGML order (dim0 = columns/innermost, dim1 = rows;
  3-D folds [in, out, experts]), type u32 (GGML number), offset u64
  RELATIVE to data_offset. Duplicate tensor names refused.
- Data section: data_offset = directory end rounded UP to
  alignment; every tensor's relative offset must satisfy
  offset % alignment == 0 (_map_tensor refuses otherwise); tensor
  payloads are the packed block bytes of section 1, sized by
  _tensor_byte_size(element_count, type) — element counts must be
  exact multiples of the block geometry (32 or 256 along dim0;
  packed_row_bytes additionally refuses non-aligned rows outright).
- Endianness: little-endian throughout; f16 scales are raw IEEE
  half bits in LE order. No big-endian variant exists in our reader.
- Required-tensor validation is per-architecture
  (_validate_required_tensors + profile validators): the writer
  preserves the source's tensor names/shapes exactly and changes
  only storage types, so a source that validated still validates —
  EXCEPT type-sensitive gates: qwen35_profile.validate_qwen35
  refuses any rows==1 tensor whose kind != F32 (norms/scales stay
  F32), and the Q35-3r resident gate requires every large qwen35
  weight to be storable/acceptable in the target tier.

Where llama.cpp may differ from our reader (to be settled by QC-4,
not assumed): (a) llama.cpp accepts GGUF v2 and v3; our v3-only
emission is inside its envelope either way. (b) llama.cpp's
quantize uses its own tensor-type POLICY (per-role fallbacks,
attention/output upshifts, ftype rules) — our file must be loadable
by it, not policy-identical to its output. (c) llama.cpp may require
KV keys our reader ignores (general.file_type is one our registry
READS — model_registry.mojo:377 — with llama_ftype semantics;
writer must set it correctly: Q8_0 = 7, Q4_K_M = 15). (d) alignment:
llama.cpp defaults 32; emitting general.alignment = 32 matches both.
(e) Q8_1 block size conflict (section 1a) is OURS, not llama.cpp's,
until U-QC2 settles it.

## 3. Profile surface — what may be quantized, what must not

Registry (core/model_registry.mojo): profiles gemma4, llama3
(dense GQA), qwen3 (incl. the 0.6B verified quants Q4_K_M/Q5_K_M/
Q6_K), qwen35 (hybrid SSM; qwen35_quantization_supported admits
Q8_0 ONLY today — QC-6/QC-7 must extend that gate with evidence,
which is part of their deliverable, not an assumption).
Native K-quant list: Q4_K_S/M, Q5_K_S/M, Q6_K (+ F16/BF16/F32).

Per-role policy, from the real files' censuses and the validators:
- NEVER quantize: 1-row tensors (norms, scales, biases) — they stay
  F32. Evidence: 27B census 498 Q8_0 + 353 F32 (Q35-1/Q35-2 notes;
  the 353 are exactly token/output norms, per-layer norms,
  ssm_a, ssm_dt.bias, ssm_conv1d-adjacent small tensors and kin);
  qwen35 validate hard-refuses rows==1 non-F32. Q35-3r confirms the
  F32 set is tiny (~2.65M elements, ~10.6 MB on the 27B).
- token_embd.weight / output.weight: quantizable in the ladder's
  conventions (they ARE Q8_0 in the 27B file — 2 of the 498) but are
  the most quality-sensitive tensors; llama.cpp convention keeps or
  upshifts them (output often one rung higher). QC policy v1:
  quantize token_embd with the tier, keep output.weight at the tier
  for Q8_0; for Q4_K_M follow the grade — if the fixture grade hurts,
  the named fallback is output at Q6_K (llama.cpp's own -M policy
  does exactly this class of upshift). The choice is graded, not
  guessed: QC-3/QC-5 report both if the first choice fails the band.
- SSM small tensors (ssm_a, ssm_dt.bias, ssm_conv1d.weight): F32 in
  the real file; conv1d has tiny row widths that are NOT 256-aligned,
  so K-quant blocks cannot even tile them — they stay F32, full stop.
- MoE expert tensors (3-D, gemma4 26B A4B class): folded view keeps
  blocks along dim0; quantize per the same role rules. Not a first
  target (no MoE proof in this workstream's critical path).
- Any tensor whose dim0 is not a multiple of the tier's block size
  (32 for Q8_0, 256 for K) CANNOT be quantized in that tier without
  padding semantics GGUF does not have — it stays at source type and
  is listed in the run report. (Known instance: qwen35 tiny-fixture
  ssm_out at 24 columns already breaks packed Q8_0 row alignment.)

## 4. First-proof substrate — what actually exists on this box

Verified by listing (2026-11-14, this recon):
- /mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-
  Brilli-50x-AGI-NEO-Q8_0.gguf — 28,596,003,296 B, sha256
  1fca6eef...186f08e (campaign MAP). THE 27B source for QC-6.
  (A sibling ...-MTP-Q4_K_M.gguf, 16 G, also sits on the vault — a
  DIFFERENT (MTP) variant produced elsewhere; it is a size sanity
  reference only, never the QC deliverable or its source.)
- /mnt/vault/models/gguf/gemma-4-26B-A4B-it-heretic.Q8_0.gguf (26 G)
  and the 40B qwen35 Q8_0 (39 G): available, out of critical path.
- ~/aesir-forge/.aesir/models/gemma-4-E2B-it-Q4_K_M.gguf —
  3,106,738,272 B, the forge registry's one catalogued model
  (catalog.v1 COUNT:1, sha256 740185b2...4ec34b8). Registered,
  known-runnable, Q4_K_M source.
- ~/aesir-hipserve/.aesir/models/Llama-3.2-3B-Instruct-Q4_K_M.gguf —
  1.9 G, the gate's model file (llama3-3b). Registered, runnable.
- stories260K.F16.gguf — 601,248 B pinned external fixture
  (fixture_manifest.json id gguf.stories260k-f16-v3, sha256
  57a81ed1...09da1a0e; copies already on-box in sibling worktrees).
  A complete tiny llama-arch F16 model with tokenizer.
- NO uncompressed (F16/F32) mid-size registered model exists on the
  box; every candidate source is itself quantized. This shapes the
  design (section 5): the quantizer's input is per-tensor FLOAT
  VALUES obtained through the engine's own dequantizers (or raw
  F16/F32/BF16 passthrough), never "the source file's blocks".

FIRST PROOF CHOICE: stories260K.F16.gguf for the whole-model Q8_0
proof (QC-3a). Why: true F16 source (no dequant-of-source confound),
588 KB (a full CPU forward + grade runs in seconds under any fence),
complete tokenizer/metadata set (exercises the writer's KV copying
end-to-end), and its architecture is the plain llama profile whose
grading harness already exists (test_real_gguf.mojo consumes it).
SECOND SCALE: gemma-4-E2B Q4_K_M (QC-3b dequant->Q8_0 requant) —
proves the quantized-source path on a real registered model at 2.9 G
before the same path is trusted at 27B. llama3-3b is the named
alternate if the gemma4 profile's per-layer arrays complicate
metadata copying (U-QC4).

## 5. The quantizer's maths — decisions the plan fixes now

Input abstraction (applies to every slice): for each tensor, obtain
F32 values row by row via existing readers (dense copy or the
format's dequant), then emit target blocks row by row. Blocks run
along dim0 (columns); a row of width W is W/block independent blocks.

- Q8_0 (first slice's choice): per 32-value block, d = max|w| / 127,
  stored as F16; q = round-to-nearest-even(w / d) clamped to
  [-127, 127] (reader accepts i8 to -128 but symmetric 127 matches
  llama.cpp's quantize_row_q8_0 and keeps |q| representable both
  ways); zero block (max|w| == 0) emits d = 0, q = 0. This is
  EXACTLY invertible against our dequant by construction except for
  f16 rounding of d and the rounding of q — both bounded and tested
  elementwise in QC-2. No scale search: Q8_0 has one degree of
  freedom and min/max IS the optimum for the max-error metric.
- Q4_K_M (workhorse): per 256-value super-block, 8 sub-blocks of 32.
  First-slice choice = llama.cpp-compatible min/max affine fit per
  sub-block: scale = (max-min)/15, min as stored; then a bounded
  refinement pass (the make_qkx2_quants style search over scale/min
  multipliers minimizing block MSE) ONLY if QC-5's fixture grade
  fails the near-tie band with plain min/max — the grade arbitrates,
  per the commission. Sub-block scale/min are then packed into the
  6-bit fields and the d/dmin f16 super-scales exactly as
  packed_value reconstructs them (g<4 plain, g>=4 split-nibble
  packing — writer must implement the INVERSE packing and a
  round-trip test per group, because this is the single easiest
  place in the whole workstream to be silently wrong).
  Rounding: round-to-nearest on (w - min) / (d*scale) with clamp
  [0,15]; Q5_K adds the high bit identically at [0,31].
- Emission order: tensors in SOURCE directory order; blocks in row
  order, lanes in reader order (for Q4_0-family nibble interleave
  the low half is lanes 0-15 — not a QC-1/QC-5 format, recorded so a
  later classic-tier slice does not reinvent it). Metadata: source
  order preserved, quantization-owned keys updated in place.
- What would change these choices: ONLY grades. If Q8_0 round-trip
  is not elementwise-faithful, the bug is ours (format is exact) —
  fix, never re-band. If Q4_K_M min/max grades divergent on the
  fixture while llama.cpp's own Q4_K_M of the same source grades
  faithful, adopt the refinement search (that comparison is built
  into QC-5 as the arbitration experiment).

## 6. Slice list

QC-1 — GGUF writer core. Deliverable: new loader/gguf_writer.mojo
(or core/ sibling — implementer's choice, one module) that emits a
spec-exact GGUF v3 byte stream from an in-memory model description
(metadata KV list + tensor directory + payload callback), plus a
metadata-copy reader path (parse source header/KV/directory without
materializing tensors, Q35-1 no-materialization style). Files:
aesir_engine/loader/gguf_writer.mojo (new), a test under
aesir_engine/tests/. Proof: byte-level — write a synthetic 3-tensor
model (F32 norm + F16 matrix + Q8_0 matrix with hand-built blocks);
our GGUFSeer loads it, PackedGGUF loads it, header/KV/directory
parse matches the inputs exactly, tensor offsets all 32-aligned,
file size == data_offset + payload sum. No model semantics yet.
Depends on: nothing.

QC-2 — Q8_0 quantizer + fixture-tensor round-trip. Deliverable:
quantize_q8_0 (values -> blocks) beside the dequantizers
(core/compute.mojo sibling module core/quantize.mojo, new) + CLI
plumbing stub. Proof: property tests — for adversarial value sets
(all-zero, single spike, full-range, denormal-tiny, negative-only),
dequant(quantize(w)) error <= d/2 + f16(d) rounding per element, and
exact equality on values already on the Q8_0 lattice; block bytes
match the loader/quantization.mojo layout (34 B, f16 d @0).
Depends on: QC-1 (for the file-level test at its tail: one real
tensor written and re-read through GGUFSeer byte-identical blocks).

QC-3 — Whole-model Q8_0 + grade. (a) stories260K: F16 -> Q8_0 file
via QC-1+QC-2; our loader + qwen/llama profile validation accept;
CPU teacher-forcing grade vs the F16 source on RAW prompts through
near_tie_gate — pass = faithful band or honest divergent report with
per-layer attribution if divergent. (b) gemma-4-E2B: Q4_K_M source
dequant -> Q8_0; inspect READY; serve smoke on a side port; grade
vs source. Files: cli/quantize command (new dispatch in
cli/commands.mojo), scripts + logs in this folder. Depends on:
QC-1, QC-2.

QC-4 — llama.cpp cross-check. Deliverable: evidence, not code —
llama.cpp (build or binary located at run time; NONE is on the box
today — see U-QC1) loads the QC-3 files (llama-cli/llama-quantize
--help class checks + a real load + short generation), and Aesir
loads a llama.cpp-quantized Q8_0 of stories260K. Pass = both
cross-loads succeed and the Aesir grade of llama.cpp's file is in
the same band class as ours; every format disagreement found is
filed as a named fix in the owning slice, not worked around.
Depends on: QC-3.

QC-5 — Q4_K_M tier (the workhorse). Deliverable: quantize_q4_k with
the section-5 packing + policy table (section 3), file_type 15.
Proof: (i) block round-trip property tests incl. the g>=4 packed
scale reconstruction, per-group; (ii) whole-model Q4_K_M of the
QC-3b source (gemma E2B dequant path) + grade vs source; (iii) the
arbitration experiment: llama.cpp Q4_K_M of the same source graded
the same way (needs QC-4's binary). Pass = our grade in the
near-tie band, or the refinement search adopted and re-graded.
Depends on: QC-3; arbitration leg depends on QC-4.

QC-6 — The 27B: Q8_0 heretic -> Q4_K_M. Deliverable: the file
(~15.2 GB predicted: 26,893,352,960 large elements x 144/256 B =
~15.13 GB + ~10.6 MB F32 set + metadata/tokenizer; the on-vault
MTP Q4_K_M at 16 G brackets the prediction), produced under fence
discipline (section 7), streaming row-by-row (never materializing
the 53.8 GB F16 form). Plus: qwen35_quantization_supported extended
to admit Q4_K_M FOR THIS FILE CLASS with the grade as its evidence
(model_registry.mojo change rides this slice), resident-gate
analogue checked (Q35-3r's Q8_0-only enforcement must gain a
quantized-tier admission or the file serves non-resident — decided
from the code at run time, reported honestly). Proof: inspect
READY/COMPATIBLE; resident-or-named-mode load; CPU teacher-forcing
grade vs the Q8_0 source on RAW prompts; serve smoke on a side
port, two-turn chat. Depends on: QC-5 (+ QC-4 arbitration if QC-5
needed it).

QC-7 — Close + residency handoff to Q35-7. Deliverable:
QC_RESULTS.md in this folder (per-tier size-vs-quality table:
stories260K, E2B, 27B x Q8_0/Q4_K_M with worst rank/gap, file
sizes, tok/s where measured), the 27B Q4_K_M residency note Q35-7
consumes (stored bytes vs pool/KV at ctx, which serve mode admits
it), and the compression section of the campaign ledger updated via
the coordinator. Depends on: QC-6.

Later rungs (named, NOT scheduled): QC-8 candidates in evidence
order — Q6_K (simplest K writer after Q4_K: symmetric, i8 scales,
no min packing), Q5_K (Q4_K + high bit — nearly free after QC-5),
Q3_K_M/Q2_K (signed-trick and 2-bit packings), classic Q4_0/Q5_0
(32-block formats), IQ tiers last (codebook search per format).
Each gets its own recon note before scheduling; none is promised.

First targets, with reasons (confirming the expected shape):
Q8_0 first because it is the ONLY tier whose writer is provably the
exact inverse of a 20-line reader (34 B blocks, one f16 scale,
signed i8, no packing, no min) — it validates the writer core and
the dequant-sourced input path with zero format risk, and it is
the 27B's own storage format (so QC-3b/QC-6 source handling is
exercised from the start). Q4_K_M second because it is the
workhorse: the file_type of both registered small models, the
vault's own 27B-class rung (~2x smaller than Q8_0), HIP GEMV
already exists for it (core/hip_q4k_gemv.mojo), and its packing is
the hardest of the scheduled tiers — if the writer survives Q4_K,
Q5_K/Q6_K are variations, not new risks.

## 7. Hard unknowns — each with what settles it

- U-QC1: No llama.cpp binary or source tree exists on this box
  (searched: no llama-cli/llama-quantize on PATH, no ~/llama.cpp).
  QC-4 needs one. Settles it: QC-4's first step locates or builds
  llama.cpp CPU-only (native build, NO Docker per standing law) and
  pins its version in the results; until then every "llama.cpp
  accepts" statement in this plan is a requirement, not a fact.
- U-QC2: Q8_1 block size conflict — loader _tensor_byte_size prices
  36 B/blk; compute.mojo dequantize_q8_1 walks 40 B blocks (f32 d +
  f32 sum + 32 qs). One of them is wrong vs upstream (upstream
  block_q8_1 is 36 B with f16 d + f16 sum... our two readers agree
  with NEITHER fully). Q8_1 is not a scheduled write tier; settles
  it: a header census of any real Q8_1 file (none on box) or an
  upstream-source read at the time someone schedules Q8_1. Flagged
  here under the never-leave-a-bug rule as a NAMED pre-existing
  reader inconsistency for the coordinator's ledger, out of QC
  scope to fix.
- U-QC3: Does the qwen35 execution path accept Q4_K_M tensors
  end-to-end (packed GEMM dispatch is per-format; the profile has
  only ever run Q8_0)? Settles it: QC-6's load proof — if dispatch
  refuses, QC-6 gains a named sub-slice for the packed path rather
  than silently falling back to F16 materialization (which would
  void the residency point of the exercise).
- U-QC4: Metadata-copy fidelity for gemma4's per-layer ARRAY keys
  (feed_forward_length arrays, sliding_window_pattern) through our
  writer — GGUFSeer's flat parse proves readability, not that our
  emitted arrays re-parse identically. Settles it: QC-3b's
  inspect-READY + profile-validation pass on the emitted file;
  llama3-3b is the fallback substrate if gemma4 arrays block.
- U-QC5: general.file_type semantics for a MIXED file: our Q4_K_M
  output keeps some tensors at source type (section 3 policy);
  file_type 15 claims "mostly Q4_K" per llama_ftype. Whether
  llama.cpp's loader cares beyond the label settles in QC-4/QC-5's
  cross-loads.
- U-QC6: The 27B grade's comparator cost: teacher-forcing the Q8_0
  source on CPU is the Q35-3b-class heavy run. Settles it: QC-6
  sizes its prompt set to the fence (short RAW prompts, few steps,
  worst-rank/gap reporting) instead of discovering the cost live.
- U-QC7: output.weight policy for Q4_K_M (tier vs Q6_K upshift).
  Settles it: QC-5's grade on the small model, both variants if the
  first fails the band (section 3). Never settled by taste.

## 8. Memory / service notes for later slices

- Machine state at plan time (measured this recon, 2026-11-14
  ~13:26 EST): services aesir-gate, Ollama, Voxta all INACTIVE
  (stopped by Volmarr's orders, per MAP status override);
  MemAvailable ~118 GB of 121 GB total (MAP recorded ~124 GB
  earlier — the number moves; RE-MEASURE before every heavy run,
  as always), load ~0, box up 3h25. Vault free: 3.4 TB — the 27B
  Q4_K_M output (~15.2 GB) and intermediates fit trivially; the
  ROOT filesystem has 1.5 T free, worktree writes are not a risk.
- QC-6 runs under the campaign fence discipline: systemd-run
  MemoryHigh/MemoryMax sized and RECORDED in the ledger, ONE heavy
  run at a time, MemAvailable checked immediately before, and the
  writer streams (source mmap + row buffers + output file) — its
  honest footprint is page cache + a few hundred MB, NOT the 53.8 GB
  materialized form; if implementation drifts toward materializing,
  that is a defect to fix in-slice, not a fence to raise quietly.
- The QC-6 GRADE (source forward on CPU) is the heavy leg, not the
  write; it inherits Q35-3b's fence terms.
- A freshly booted or actively-used machine gets NO heavy run
  (standing law); purpleraider is Volmarr's desktop — check before
  QC-6 even though it was idle at plan time.
- No service is to be stopped or evicted for QC work; if a proof
  needs a port, use a side port and say so in the slice log.

## 9. What this slice did NOT do

No code changes, no builds, no model loads, no llama.cpp fetch.
The only file written is this plan. MAP.md and LEDGER.md were read
but not edited (the coordinator integrates at merge). The Q8_1
reader inconsistency (U-QC2) is reported, not fixed — it is a
pre-existing reader bug outside this slice's recon-only scope, and
fixing it belongs to a named slice with a real-file or upstream
oracle, per U-QC2's settler.
