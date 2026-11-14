# QC-3a — Whole-model Q8_0 conversion of stories260K + grade (2026-11-14)

Worker slice on worktree /home/volmarr/aesir-qc-3, branch yrsa/qc-3,
base 0023000b (= yrsa/hip-serve tip, re-read by ls-remote at start).
Deliverable definition: QC-0-PLAN.md section 6 (QC-3, first half —
the small whole-model proof), bound by QC-1-NOTES.md (writer +
file_type duty) and QC-2-NOTES.md (quantizer API + its risks list:
file_type duty, exact f16->f32 widening, per-role policy).

Method: ONE worker running the six Forge roles sequentially
(recon -> spec -> build -> proof -> regressions -> bank). No
sub-agents were spawned (depth limit), per the commission.

Machine state: purpleraider up 5h21 at start (NOT freshly booted),
load ~1.1, MemAvailable ~27.7 GB of 121 GB. The sibling Q35-6
worker was ACTIVE in /home/volmarr/aesir-q35-6 throughout recon,
the builds, and the first proof run (its grade_qwen35_hip process,
RSS ~24.5-28.4 GB, ~96% CPU on one core; its tree never touched);
it had finished by the final rerun (MemAvailable back to ~122 GB).
CONTENTION IS THEREFORE PRESENT for part of the slice and is
recorded honestly: every number below is a correctness number
(byte identity, error bounds, rank/gap), never a timing. All
builds/runs ran as systemd user units fenced MemoryHigh=24G /
MemoryMax=32G. No aesir-gate / Ollama / Voxta processes were
observed; services stayed down per Volmarr's orders, untouched.

## Placement decision (CLI vs slice tool)

QC-0 section 6 assigns QC-3 the cli/quantize command ("Files:
cli/quantize command (new dispatch in cli/commands.mojo)"), so the
conversion is wired there, not improvised as a slice-local tool:

- `aesir_engine/cli/quantize.mojo` (new): the reusable conversion
  `quantize_gguf_q8_0(source, output) -> QuantizeReport`, the
  per-tensor policy `q8_0_keep_reason`, the report printer, and
  `dispatch_quantize` (`aesir quantize <source.gguf> <output.gguf>
  [--to q8_0]`; any other tier is refused by name — QC-5 owns
  Q4_K_M).
- `aesir_engine/cli/commands.mojo`: one import, one dispatch
  branch beside `inspect`, three help lines.
- The llama.cpp-compat surface (cli/llama_cpp_compat.mojo's
  Unsupported `llama-quantize`) is a different surface and is
  untouched.

Conversion path, as built: QC-1's metadata-copy parse
(read_gguf_header_copy) + GGUFSeer mmap tensor access; per tensor,
either exact widening to F32 (F16 -> F32 exact; F32 passthrough;
BF16 -> F32 exact by bit extension) into QC-2's quantize_q8_0, or
a verbatim payload copy for kept tensors; KVs copied wholesale as
raw bytes except general.file_type, set to 7 (the caller-owned
duty QC-1 and QC-2 both named); emission through QC-1's
write_gguf_file, directory order/names/shapes preserved exactly.

## Policy as applied (stories260K census: 37 F16 matrices + 11 F32 norms)

| class | tensors | rule | result |
|---|---|---|---|
| weight matrices, dim0 % 32 == 0 | 32 | quantize to Q8_0 | 237,056 elems: 474,112 B F16 -> 251,872 B Q8_0 |
| blk.*.ffn_down.weight (x5) | 5 | dim0 = 172, 172 % 32 = 12: stays at source type, listed by name, no padding | F16, 110,080 B, payloads byte-identical |
| norms (output_norm + blk.*.attn_norm/ffn_norm, x11) | 11 | one-dimensional (norm/scale/bias class): stays at source type | F32, 2,816 B, payloads byte-identical |

Every kept tensor, named (from qc-3-cli.log): output_norm.weight;
blk.0..4 .attn_norm.weight, .ffn_norm.weight (F32, one-dimensional);
blk.0..4 .ffn_down.weight (F16, dim0 172 not a multiple of 32).
Quantized, named: output.weight, token_embd.weight, and per layer
blk.*.attn_k / attn_output / attn_q / attn_v / ffn_gate / ffn_up.

## Size report

- Source: 601,248 B (sha256 57a81ed1...09da1a0e == fixture pin,
  re-verified this run, qc-3-source-sha.log). Header/KV/directory
  to data_offset 14,240; payloads 587,008 B with zero inter-tensor
  padding (every source payload is a multiple of 32).
- Emitted: **379,152 B** (63.06% of source; 222,096 B saved),
  sha256 **5d4df894e4ed0d16f84d94c0a2a7524a4915123fe96148dc0e41b7bc1a6d77b7**,
  at `hidden_files/qwen35-adapter/stories260K.Q8_0.gguf` in the
  worktree (NOT committed: the repo's fixture practice keeps model
  binaries external / git-ignored — *.gguf is ignored tree-wide;
  the source fixture itself is manifest-classified "external").
  Identity check: 14,240 (same header size) + 364,768 payload
  (251,872 Q8_0 + 110,080 F16 + 2,816 F32) + 144 padding (nine
  16-byte pads after the nine non-final 11,696-byte gate/up
  payloads; no pad follows the final tensor) = 379,152. An
  independent Python census of the emitted file agrees: file_type
  7, type census {Q8_0: 32, F32: 11, F16: 5}, data_offset 14,240,
  all offsets 32-aligned.
- Per-element: quantized class 2.0 -> 1.0625 B/elem; whole model
  payload 2.005 -> 1.246 B/elem.

## Proof (test_quantize_model_qc_3; log qc-3-test.log) — ALL PASS

- Policy counts and byte totals exactly as the table above;
  kept-reason strings name the dim0 alignment for ffn_down and the
  one-dimensional class for norms.
- Emitted metadata == source metadata except general.file_type
  = 7 (all 21 KVs compared; the rest verbatim via gguf_kv_equal).
- Directory preserves names/shapes/order; quantized tensors are
  type Q8_0, kept tensors keep source type and byte size; all
  offsets % 32 == 0.
- Every kept payload is byte-identical to the source payload.
- Emitted Q8_0 blocks dequantize inside QC-2's proven per-element
  bound (bound recomputed per block from the source values):
  token_embd.weight worst err/bound 0.799858, blk.0.attn_q.weight
  0.798652 — in line with QC-2's measured 0.80-0.90 band.
- Load proof: GGUFSeer mmap_and_load reaches VALIDATED (llama
  config + 512-token tokenizer agree; tensor types map as
  emitted); PackedGGUF constructs in full (offsets/kinds/byte
  counts for all 48 tensors; general.file_type reads back 7);
  the engine runs the file — greedy 8 from "One day, Timmy went
  to" = 265 282 295 433 335 345 357 426 (" the park with his
  mom."), identical to the source model's own first 8 greedy
  tokens and to the fixture's pinned llama.cpp oracle prefix.

## Registry/profile finding (named, not papered over)

`aesir inspect` on BOTH files (logs qc-3-inspect-source.log /
qc-3-inspect-q8.log): Status NOT READY, Compatibility
UNSUPPORTED, with the IDENTICAL reason — "Tokenizer/chat-template
metadata mismatch: Llama 3 requires gpt2/llama-bpe tokenizer
metadata". The registry classifies stories260K as variant
"Llama 3.x / 5L/64d" and the fixture's tokenizer metadata
(tokenizer.ggml.model = "llama") does not satisfy that profile.
So: (a) the emitted file's profile admission is IDENTICAL to its
source's — conversion changed nothing there; (b) the emitted
file's quantization is read correctly as Q8_0 (from file_type 7)
where the source reads F16; (c) stories260K's working path today
is the direct GGUFSeer/engine path (test_real_gguf), not registry
READY admission — it never had READY, before or after conversion.
Also observed: the variant's "Supported quantizations" list
names the K-quants only (Q4_K_S/M, Q5_K_S/M, Q6_K), not Q8_0;
the tokenizer refusal fires first, so whether Q8_0 would also be
refused for this variant is not settled by this evidence.
Finding F-3a-1, for the coordinator: registry llama3-variant
admission vs the stories fixture class — pre-existing, not a
conversion defect, no code changed for it in this slice.

## GRADE (grade_quantize_qc_3; logs qc-3-grade.log, CSV
## qc-3-grade.csv, independent re-grade qc-3-grade-summary.log)

Discipline: teacher-forcing rank + logit gap on RAW prompts,
compressed vs its own F16 source, Aesir CPU vs Aesir CPU,
identical token-ID streams into both runs (tokenized once with
the source model's own RuneWeaver, add_bos; the quantized model's
tokenizer asserted to reproduce the identical streams). Graded
stream per prompt = RAW prompt + the source model's own greedy
continuation (16 tokens), the A-045 convention; prompt-internal
positions reported as their own subtotal. Records are the rank +
gap of the COMPARATOR's (source's) argmax in the CANDIDATE's
(Q8_0) logit row (the Q35-3b rank_comp account), filed through
core/near_tie_gate: rank 0 = top; band = rank <= 2 AND
gap < 1.0. Six RAW prompts (TinyStories register; token counts
8/13/8/11/12/15).

- AGGREGATE: 157 records — exact 156, near-tie 1, divergent 0.
  Gate verdict **FAITHFUL_NEAR_TIE** (a PASS verdict). In-band
  157/157 = **100.00%**. Argmax agreement **156/157 = 99.36%**.
  Worst rank 1, worst gap 0.007 logits.
- Prompt segment: 61/61 exact (verdict FAITHFUL).
- Continuation segment: 96 records — 95 exact, 1 near-tie.
- The single non-exact record, named: prompt 2 ("The dog ran to
  the"), pos 10, true_next 335, source argmax 335, Q8_0 argmax
  426, rank 1, gap 7 milli-logits (0.007). The source's winner
  sits 0.007 logits behind the Q8_0 row's winner — a textbook
  near-tie, and exactly the position where free-running greedy
  diverges (below).
- Per prompt: 0: 23/23 exact; 1: 28/28 exact; 2: 22 exact + 1
  near-tie (agree 22/23); 3: 26/26; 4: 27/27; 5: 30/30.
- The independent Python re-grade of the filed CSV reproduces
  every number above exactly (rank distribution {0: 156, 1: 1}).

Greedy generation (16 tokens per prompt, both models, same
greedy config): token-identical on prompts 0, 1, 3, 4, 5.
Prompt 2 diverges at generation step 3 (source 335 vs Q8_0 426 —
the near-tie record above); both continuations stay coherent
TinyStories text (source: " park with his mom. They liked to
play with their to…" / Q8_0: " park. He saw a big box. He wanted
to…"). Prompt 0's continuation matches the fixture's pinned
llama.cpp oracle stream for its first 16 tokens on BOTH models.

VERDICT: **FAITHFUL** — Q8_0 conversion of stories260K sits
inside the near-tie band against its own F16 source (100% of
records in band, worst gap 0.007 logits), with the one
free-running greedy divergence named and traced to its
near-tie record.

## Regressions (run-qc-3-tests.sh; all fenced as above)

- Full engine compile exit 0 (qc-3-build.log, ENGINE_BUILD_EXIT=0;
  all six build targets exit 0).
- QC-3a conversion + load proof: ALL PASS (qc-3-test.log).
- CLI end-to-end (`aesir quantize`): exit 0; emitted file
  sha256-identical across the test-path and CLI-path conversions
  (5d4df894..., deterministic).
- QC-2 quantizer test rerun from this tree: ALL PASS
  (qc-3-regress-qc-2.log; 1M-element round-trip numbers reproduce
  QC-2's banked values exactly: max err 0.19629216).
- QC-1 writer test: ALL PASS (qc-3-regress-qc-1.log), incl.
  stories260K byte-identical re-emission.
- Q35-1 loader test: ALL PASS (qc-3-regress-q35-1.log).
- Full 905 matrix not re-run (slice order; baseline stands).

## Errata / findings from this slice

- E-1 (test-expectation correction, writer arbitrated): the
  test's first draft expected 379,168 emitted bytes — my hand
  count padded after all ten 11,696-byte gate/up payloads; the
  writer (correctly) emits no pad after the FINAL tensor, so the
  true size is 379,152. The test now carries the derivation in
  its header. No code was wrong; the expectation was.
- F-3a-1 (registry, above): stories-class admission is
  tokenizer-gated for source and conversion alike.
- Inherited, still standing: QC-2 F-1 (engine dequantizers write
  F16; grade paths inherit the amax <= 65504 practical range —
  stories weights sit far inside it) and F-2 (GGUFSeer failed-load
  dangling pointers — the proofs here load valid files and use
  the offsets/file-image pattern where a load is expected to be
  inspected post-hoc).

## Risks / handoff to QC-3b and QC-4

- QC-3b (gemma-4-E2B, Q4_K_M -> Q8_0) is NOT a rerun of this
  slice: (1) the input path here widens DENSE floats only — a
  quantized-source tensor is currently KEPT at source type by
  policy, so QC-3b must first wire a dequantizing input path
  (existing readers, row by row) before any E2B tensor can be
  requantized; (2) at 3.1 GB the QC-1 writer's whole-file
  materialization (desc holds all payloads; build_gguf_bytes
  holds the whole output) stops being viable — the streaming
  writer QC-1/QC-2 named is a prerequisite, to be named as its
  own step in QC-3b, not smuggled in; (3) gemma4's per-layer
  array metadata is proven only at header-copy level (QC-1
  bonus probe), not through whole-file re-emission.
- QC-4 (llama.cpp cross-check): our file is MIXED (Q8_0 + kept
  F16 + kept F32) under file_type 7 — U-QC5's question (does
  llama.cpp care beyond the label) is now concrete and testable
  with this exact file. The roundf tie rule (QC-2 E-1) means
  byte-identity with llama.cpp's own Q8_0 is NOT the bar; the
  grade is. And F-3a-1 cuts both ways: an Aesir grade of
  llama.cpp's stories Q8_0 must use the engine path, since the
  registry inspect surface refuses this fixture class outright.
