# QC-2 — Q8_0 quantizer + round-trip property tests (2026-11-14)

Worker slice on worktree /home/volmarr/aesir-qc-2, branch yrsa/qc-2,
base ccf79bd5 (= yrsa/hip-serve tip, re-read by ls-remote at start).
Deliverable definition: QC-0-PLAN.md section 6 (QC-2), bound by
section 5 (the quantizer's maths) and QC-1-NOTES.md (the writer this
slice builds on + its named risks).

Method: ONE worker running the six Forge roles sequentially
(recon -> spec -> build -> proof -> regressions -> bank). No
sub-agents were spawned (depth limit), per the commission.

Machine state: purpleraider up 5h05 at start, load ~0.1,
MemAvailable ~118 GB of 121 GB at recon. During the build/test runs
the sibling Q35-6 worker was ACTIVE in /home/volmarr/aesir-q35-6
(its tree never touched): its grade_qwen35_hip_q35_6b process
(RSS ~24.5 GB, ~98% CPU, from ~15:08 EST) held MemAvailable at
~22-26 GB. CONTENTION IS THEREFORE PRESENT and is recorded here
honestly: every number in this slice is a correctness number (byte
identity, error bounds), never a timing, so contention affected
wall-clock only. All builds/tests ran as systemd user units fenced
MemoryHigh=24G / MemoryMax=32G. Services aesir-gate, Ollama, Voxta
verified INACTIVE at start and left down per Volmarr's orders.

## Module placement decision

`aesir_engine/core/quantize.mojo` (new, ONE module) — in core/,
beside the dequantizers it inverts (core/compute.mojo
dequantize_q8_0 lives there; loader/quantization.mojo's block twin
is the same layout), exactly as QC-0 section 6 prescribes
("core/compute.mojo sibling module core/quantize.mojo"). The GGUF
writer stays in loader/gguf_writer.mojo (QC-1) and remains
format-agnostic; this module's output (List[UInt8] payload bytes)
drops straight into a GGUFWriterTensor, priced identically by
q8_0_payload_bytes and the writer's own GGUFSeer-priced check.

API: `quantize_q8_0(values: List[Float32]) raises -> List[UInt8]`,
plus `q8_0_payload_bytes(element_count)` (same refusals, for
callers pricing before quantizing) and the Q8_0_BLOCK_ELEMENTS /
Q8_0_BLOCK_BYTES / Q8_0_GGML_TYPE constants. No second dequantizer
was written: every round-trip below closes through the engine's
existing dequantizers only.

## The quantization rule + its source

Layout (verified against core/compute.mojo dequantize_q8_0, which
walks raw bytes): block_q8_0 = 34 B: f16 scale d @0, 32 x int8
qs @2..34; dequant value = q * d.

Rule, implemented exactly as ggml's reference
`quantize_row_q8_0_ref` (re-read from disk for this slice:
~/llama.cpp-build/ggml/src/ggml-quants.c lines 273-296 — the
implementation ggml itself labels "reference implementation for
deterministic creation of model files"):

- amax = max |w| over each 32-value block
- d = amax / 127 (f32); stored as f16 (round-to-nearest-even cast)
- id = d ? 1/d : 0; qs = roundf(w * id), clamped to [-127, 127]
  (the clamp is a guard; |w| <= amax already bounds |w * id| to
  ~127 up to f32 dust)
- zero block: d = 0, qs = 0 (id = 0 branch)
- qs are computed against the UNROUNDED f32 d, as ggml does; the
  stored scale is its f16 rounding.

PLAN ERRATUM E-1 (for the coordinator): QC-0 section 5 phrases the
rounding as "round-to-nearest-even". ggml's reference uses C
roundf — round half AWAY from zero. Per the slice brief (follow
ggml's rule where no era test pins otherwise; none does — no
quantizer existed to pin one), this slice implements roundf
semantics and PINS it with byte-exact tie tests (2.5 -> 3,
-2.5 -> -3, 0.5 -> 1, 63.5 -> 64 at d = 1; 31.75 -> 64 and
0.25 -> 1 at d = 0.5). The two rules differ only on exact .5 ties
and both satisfy the d/2 error bound; the plan text should be
corrected to roundf for QC-5's K-quant work, where ties are
likelier to matter.

## Error bound proven

Per block, with d = amax/127 (f32), d_hat = stored f16 scale:

  err <= d_hat/2 + 127*|d_hat - d| + amax*2^-10 + d_hat*0.002 + 1e-7

Terms: rounding of q (d_hat/2); f16 rounding of d amplified by
|q| <= 127; f16 product rounding inside the engine dequantizers
plus f32 dust in w*id (amax*2^-10 + d_hat*0.002 + 1e-7). The tests
assert this bound for EVERY element and report the worst
err/bound ratio per case — a bound the data nearly reaches
(0.80-0.90 on random data) is a proven bound, not a loose one.
Scope of the proof: blocks with amax <= 65504 (see Finding F-1);
real model weights sit orders of magnitude inside that range.

Measured (log qc-2-test.log, deterministic across runs):

| case | n | max err | mean err | worst err/bound |
|---|---|---|---|---|
| tie block A (d = 1.0) | 32 | 0.5 | 0.359375 | 0.7987 |
| tie block B (d = 0.5) | 32 | 0.25 | 0.03125 | 0.7987 |
| all-zero | 320 | 0.0 | 0.0 | 0.0 |
| all-equal 3.25 / -7.5 | 64 | 0.0 | 0.0 | 0.0 |
| single outlier 100 in 0.001 | 32 | 0.001 | 0.000969 | 0.0019 |
| dynamic range 1e4 beside 1e-6 | 64 | 1.0 | 0.03125 | 0.0198 |
| negative-only random, scale 50 | 128 | 0.20914 | 0.082825 | 0.8144 |
| positive-only random, scale 1/32 | 128 | 0.000123 | 5.70e-05 | 0.7970 |
| tiny, amax 1e-7 (d_hat = 0) | 32 | 1e-07 | 6.25e-08 | 0.4998 |
| small, amax 1e-4 (subnormal d) | 96 | 1.74e-06 | 6.01e-07 | 0.8000 |
| exact lattice (d = 0.25, 2.0) | 64 | 0.0 | 0.0 | exact |
| random multi-scale 1e-4..1e4 | 9216 | 42.08008 | 2.3806543 | 0.8951 |
| file quant.weight 256x64 | 16384 | 0.016937 | 0.0046754 | 0.8570 |
| file big.weight 32768x32 (1M) | 1048576 | 0.19629 | 0.0037532 | 0.8529 |

Exactness: values already on a power-of-two Q8_0 lattice
(k * 0.25 and k * 2.0, k in [-127, 127] incl. both endpoints)
round-trip with error EXACTLY 0, as do zero blocks — proven, not
sampled (every element asserted). Both engine dequantizers
(loader block path + core compute path) agree element-for-element
on every round-trip (asserted); they are two readers of the same
layout, so their agreement is the layout cross-check.

## Refusal rule (chosen: refuse, never pad)

quantize_q8_0 raises a named Error and produces no payload when:

- element count == 0, or not a multiple of 32 — GGUF has no
  padding semantics, the readers price dim0 by integer division /
  refuse non-aligned rows, and the QC-1 writer refuses the same
  shapes; per QC-0 section 3 such tensors stay at source type.
  (Tests: 0 / 31 / 33 / 100 values.)
- any value is NaN or +/-Inf (index named in the error).
- a block's scale overflows f16 (amax >~ 127 * 65504 = 8.3e6;
  tested at 1e10): the stored scale would be Inf and the block
  garbage; refused rather than emitted.

Scale UNDERFLOW is deliberately NOT refused: for amax ~1e-7 the
f16 scale rounds to 0, qs are still formed against the true d,
the block dequantizes to zero, and the error (= amax) stays inside
the proven bound via the 127*|d_hat - d| term (measured ratio
0.4998). Subnormal-scale blocks (amax 1e-4) likewise stay in
bound (ratio 0.8000).

## File-level proof + file_type duty

test_file_roundtrip emits a 3-tensor GGUF through QC-1's writer
(F32 norm + quant.weight 256x64 + big.weight 32768x32 =
1,048,576 elements, 32,768 blocks, 1,114,112 payload bytes — the
>= 1M-element scale proof, no index overflow) with
general.file_type = 7 (the Q8_0 value, per QC-0 section 2 /
QC-1's caller-duty risk note) and asserts the copied-back KV
reads exactly 7. The emitted file's payload bytes are
byte-identical to the quantizer's payloads (QC-1 harness style);
GGUFSeer maps both Q8_0 tensors (load stops only at
required-tensor validation, the synthetic baseline) with types /
shapes / offsets agreeing across GGUFSeer, the header-copy path,
and PackedGGUF, which constructs in full. Dequantizing from the
file image at GGUFSeer's own parsed offsets through the engine
path satisfies the bound (table above).

## Findings (named; readers NOT edited in this slice)

- F-1 (reader range property): the engine Q8_0 dequantizers write
  F16, so a block whose amax exceeds the f16 ceiling (65504)
  dequantizes to Inf through the engine path (first version of
  the dynamic-range test, amax 1e6, measured err = Inf), even
  though the payload is ggml-valid — llama.cpp dequantizes Q8_0
  to f32 and round-trips such blocks fine. This is a pre-existing
  property of the f16-output readers, not a quantizer defect:
  the quantizer refuses only where the SCALE itself leaves f16
  (amax >~ 8.3e6). Between 65504 and 8.3e6 the payload is valid
  GGUF that Aesir's current dequant path cannot represent.
  Consequences: (a) this slice's engine-path proof is stated for
  amax <= 65504; (b) QC-3/QC-6 grades, which also flow through
  f16 paths, inherit the same practical range — real weights are
  far inside it; (c) if a future slice ever needs such blocks
  end-to-end, the fix belongs to a named reader slice (an f32-out
  dequant variant), not to the quantizer.
- F-2 (loader cleanup contract, test-design fact): GGUFSeer
  .mmap_and_load's except path calls _cleanup(), which munmaps
  the file before re-raising — after ANY failed load (including
  the expected required-tensor refusal on synthetic files),
  seer.tensors[*].data pointers DANGLE. The first version of
  this slice's file test dereferenced one and segfaulted; the
  proof now dequantizes the file image at seer.tensor_file_offsets
  (the design QC-1's test already embodies: pool-copied values +
  integer offsets post-raise). Validated production loads are
  unaffected (no exception, no cleanup). Recorded so future test
  authors don't rediscover it with a core dump.

## Not built here (deliberate)

- CLI plumbing stub (QC-0 section 6 mentions one for QC-2): NOT
  built. The slice brief scopes QC-2 to the quantizer + tests,
  and QC-0 section 6 assigns the cli/quantize dispatch to QC-3
  (cli/commands.mojo). The quantizer is a library API ready for
  that dispatch; no CLI surface was improvised in its place.
- Streaming/pointer entry point: quantize_q8_0 is List-based
  (whole tensor in memory). The block loop is block-local, so a
  row-streaming variant is mechanical future work — QC-6's road
  (with the streaming writer QC-1 already named), not needed at
  QC-2/QC-3a fixture scale.

## Regressions (build-qc-2.sh / run-qc-2-tests.sh, same fences)

- Full engine compile exit 0 (qc-2-build.log, ENGINE_BUILD_EXIT=0;
  all four build targets exit 0).
- QC-1 writer test rerun from this merged tree: ALL PASS
  (qc-2-regress-qc-1.log), incl. stories260K byte-identical
  re-emission.
- Q35-1 loader test: ALL PASS (qc-2-regress-q35-1.log).
- QC-2 test itself: ALL PASS (qc-2-test.log), deterministic —
  the final banked run reproduces the earlier run's error numbers
  exactly (e.g. big.weight max 0.19629216 / mean 0.0037531897).

## Risks / handoff to QC-3

- general.file_type remains caller-owned (QC-1's named risk):
  this slice demonstrates 7 for Q8_0 in its whole-file emission;
  QC-3's quantize command MUST set it per tier (Q8_0 = 7,
  Q4_K_M = 15) on every model it writes — a wrong label loads
  fine in both readers and misleads only the registry.
- QC-3a's input path: stories260K is F16; quantize_q8_0 consumes
  F32 values. Widening f16 -> f32 is exact, but the conversion
  loop + per-role policy (norms/biases stay F32 per QC-0
  section 3; tensors with dim0 not a multiple of 32 stay at
  source type and are listed in the run report) are QC-3's to
  wire through the metadata-copy path (copy_gguf_model as the
  starting point, replacing quantized tensors' payloads).
- The writer materializes whole files in memory (QC-1's named
  risk, unchanged): fine for stories260K (588 KB) and the E2B
  class is QC-3b's call — at 3.1 GB the streaming writer stops
  being optional; do not let QC-3b silently become the streaming
  slice without naming it.
- Grades inherit Finding F-1's range note and the tie-rule
  erratum E-1: when QC-4 cross-checks against llama.cpp, exact
  .5-tie lanes may differ by one quant step between any two
  ggml-faithful writers using different tie rules — ours matches
  ggml's reference roundf, so a mismatch there would indict the
  OTHER writer's rule, and the grade (rank/gap), not byte
  identity, is the arbiter.
