# QC-1 — GGUF writer core (2026-11-14)

Worker slice on worktree /home/volmarr/aesir-qc-1, branch yrsa/qc-1,
base ff823ef3 (= yrsa/hip-serve tip). Deliverable definition:
QC-0-PLAN.md section 6 (QC-1), bound by section 2 (writer state +
emission spec derived from our reader) and section 5 (emission
order, metadata rules).

Method: ONE worker running the Forge roles sequentially
(recon -> spec -> build -> proof -> regressions). No sub-agents
were spawned (depth limit), per the commission.

Machine state at start (measured 2026-11-14 ~14:47 EST):
purpleraider up 4h46, load ~0.1, MemAvailable ~118 GB of 121 GB.
No mojo/aesir build processes running; the Q35-6 sibling worktree
(/home/volmarr/aesir-q35-6) showed no active compile (only a git
remote-https fetch in flight) — no CPU contention observed.
Running services are the ordinary desktop set (sddm/plasma/
NetworkManager/...); aesir-gate, Ollama, Voxta are NOT running —
down per Volmarr's orders, untouched by this slice.

## Module placement decision

`aesir_engine/loader/gguf_writer.mojo` — beside the two readers it
must satisfy (loader/gguf.mojo GGUFSeer, loader/packed_gguf.mojo
PackedGGUF), in the same package so it imports GGMLType and reuses
GGUFSeer's own _tensor_byte_size as the single pricing source of
truth (a writer that prices differently from the reader is the
classic silent-corruption shape; Q8-1's lesson). A core/ sibling
was rejected: the writer speaks the loader's file format, not
engine maths; quantization itself (QC-2, core/quantize.mojo per
the plan) will call this module from core, not live in it.


## Design (spec-as-built; readers arbitrate)

One module, `aesir_engine/loader/gguf_writer.mojo` (774 lines):

- `GGUFModelDesc` — the in-memory model description: `kvs`
  (List[GGUFKV], order preserved), `tensors`
  (List[GGUFWriterTensor]: name, dims in GGML order, GGML type
  number, payload bytes riding inside the entry), `alignment`
  (default 32). Callers fill payloads directly or via
  `copy_gguf_model` — the plan's "payload callback" at fixture
  scale; a streaming provider interface is named future work
  (see Risks), not silently implied.
- `GGUFKVValue` carries a value as its GGUF type tag + RAW encoded
  bytes (the exact bytes after the tag). Typed constructors
  (`gguf_kv_u32`, `gguf_kv_string`, `gguf_kv_f32_array`, ... — all
  13 scalar types + string/u32/i32/f32/bool arrays) build the
  bytes; the copy path captures them verbatim. Raw carriage is
  what makes metadata copy exact for values the flat reader only
  summarizes (per-layer arrays, QC-0 U-QC4) and for keys no reader
  interprets (e.g. stories260K's upstream-typo
  `tokenizer.ggml.seperator_token_id`, preserved untouched).
- Emission (`build_gguf_bytes` / `write_gguf_file`): 24 B header
  (magic 0x46554747, version 3 only, u64 counts), KVs in caller
  order, directory in caller order (name, n_dims 1..3, u64 dims,
  type, u64 relative offset), zero padding to the alignment,
  payloads in order with zero padding between; the stream ends
  exactly at the final tensor's end.
- Pricing: `gguf_tensor_byte_size` delegates to a never-opened
  GGUFSeer probe's `_tensor_byte_size` — writer and reader share
  one pricing function and cannot drift. The accepted type set is
  exactly the reader's explicitly-priced set (25 types: dense
  F32/F16/BF16; 32-block Q4_0/Q4_1/Q5_0/Q5_1/Q8_0/Q8_1/IQ4_NL;
  256-block Q2_K/Q3_K/Q4_K/Q5_K/Q6_K/IQ1_S/IQ1_M/IQ2_XXS/IQ2_XS/
  IQ2_S/IQ3_XXS/IQ3_S/IQ4_XS/TQ1_0/TQ2_0).
- Metadata-copy reader path (`read_gguf_header_copy`): GGUFSeer
  mmap + the reader's own bounds-checked cursor walk; copies out
  only KV raw bytes + directory rows (name/dims/type/relative
  offset/reader-priced byte size) + version/alignment/data_offset.
  No MimirWell, no tensor payload reads — the Q35-1
  no-materialization style. `copy_gguf_model` additionally lifts
  each payload from the source mmap, one tensor at a time, into a
  re-emittable desc.

Write-side refusals (all checked before any byte is emitted;
`validate_gguf_desc`): duplicate KV keys (reader refuses them on
read — writer refuses on write, no asymmetry); duplicate tensor
names; invalid value type (>12), malformed raw value bytes, array
element type >= 13 or == 9 (PackedGGUF refuses nested arrays);
the typed-key contract mirrored from
GGUFSeer._parse_metadata_value (known keys must carry the demanded
scalar type; the reader's array-normalization for scalar keys —
u32/i32/f32 arrays, i32 read as u32 layout — is mirrored exactly,
including feed_forward_length per-layer arrays and
sliding_window_pattern bool arrays <= 64); the four tokenizer
array keys must be arrays of their exact element types;
general.alignment, if present, must equal the emission alignment,
and a non-32 alignment without that key is refused (the reader
would default to 32 and misread the data section); alignment must
be a power of two <= 4096; tensor rank outside 1..3; dim0 not an
exact multiple of the type's block geometry (the reader prices
with integer division — a non-multiple would be silently
mispriced — and PackedGGUF refuses non-aligned rows outright);
payload length != the reader-priced byte size; unsupported tensor
type (see Erratum E-2).

## Proof (byte-level; logs in this folder)

Test: `aesir_engine/tests/test_gguf_writer_qc_1.mojo`
(log qc-1-test.log) — ALL PASS.

- Synthetic 3-tensor model, 33 KVs exercising all 13 value types
  plus string/f32/i32/u32/bool arrays: F32 norm dims [32] (128 B),
  F16 matrix dims [64,4] (512 B), Q8_0 matrix dims [64,8] = 512
  elems = 16 hand-built 34 B blocks (f16 d @0 — 0.5/0.25 alternating
  — i8 qs @2..34, 544 B). Directory end 1525, data_offset 1536,
  file size 2720 == 1536 + 1184 exactly. Header magic/version/
  counts read raw from the bytes; copy-parse reproduces every KV
  (key, type, raw value) and every directory row (name, dims,
  type, offset) EXACTLY; offsets 0/128/640, all % 32 == 0; every
  payload byte-identical to the input, Q8_0 blocks included.
- GGUFSeer: inspect_metadata parses (config + tokenizer agree);
  mmap_and_load maps all 3 tensors at the written absolute offsets
  with the written types/shapes (norm values verified through the
  F32->f16 pool copy) and stops ONLY at required-tensor
  validation — the codebase's established synthetic baseline
  (Q8-1/metadata-types pattern), since a 3-tensor file is not a
  model. PackedGGUF constructs in full: offsets/kinds/byte counts
  + typed KV reads (text/integer/floating) all agree.
- Ten refusal cases fire pre-emission (listed in the log).
- Real file — stories260K.F16.gguf (601,248 B, sha256
  57a81ed1...09da1a0e == fixture-manifest pin, verified): header
  copy == GGUFSeer's own parse (21 KV, 48 tensors, data_offset
  14240, typed values == config fields); directory == GGUFSeer
  full-load parse AND == PackedGGUF parse for all 48 tensors
  (type/offset/shape, offset/byte_count/kind). Re-emission of the
  copied model is BYTE-IDENTICAL to the source: 601,248 bytes,
  0 mismatches (raw-KV preservation + minimal aligned offsets +
  zero gaps, the source's layout first verified by an independent
  Python parse); the re-emitted file reaches GGUFSeer VALIDATED.
- Bonus probe — gemma-4-E2B-it-Q4_K_M.gguf (3,106,738,272 B;
  test_gguf_writer_qc_1_gemma_probe.mojo, log
  qc-1-gemma-probe.log) — ALL PASS: header copy (56 KV, 601
  tensors, data_offset 15,819,776) == GGUFSeer metadata parse
  (incl. feed_forward_length array max 12288 == flat config) and
  == PackedGGUF directory for all 601 tensors;
  feed_forward_length (i32 array x35) identical element-for-
  element with PackedGGUF.integer_array. This settles the PARSE
  half of QC-0 U-QC4; whole-file gemma re-emission remains
  QC-3b's road (payloads at 3.1 GB want the streaming writer).

Regressions (build-qc-1.sh / run-qc-1-tests.sh, systemd user
units fenced MemoryMax 32G / MemoryHigh 28G; logs qc-1-build.log,
qc-1-regress-q35-1.log, qc-1-regress-meta.log):
- Full engine compile exit 0; fixtures + all test builds exit 0.
- Q35-1 loader test: ALL PASS.
- gguf metadata regression: exit 1 ONLY at the known pre-existing
  gguf.tensor_directory_interface (rank-3 probe expects "one or
  two dimensions", gets the missing-required-tensor error;
  documented since the HS line, identical signature to the Q8-1
  banked run; 13 PASS lines precede it). Attributed, not chased,
  per the slice order. It does not appear in the QC-1 unit tests.

## Plan errata (for the coordinator)

- E-1 (phrasing, not a conflict): QC-0 section 2's "file size ==
  data_offset + payload sum" holds exactly only when payload
  sizes are alignment multiples. The readers accept (and real
  files contain) inter-tensor zero padding: offsets must be
  alignment-divisible, so the general identity is file size ==
  data_offset + final tensor end. The QC-1 synthetic was sized so
  the plan's exact identity holds (128/512/544 B payloads); the
  writer implements the general form.
- E-2 (reader observation, no fix in scope): GGUFSeer
  ._tensor_byte_size falls through to a Q4_0 price (18 B/32) for
  types it does not explicitly price (e.g. 15 Q8_K); the refusal
  for such types arrives later, in to_compressed_format at map
  time. The writer refuses unpriced types up front instead.
  Named next work (not blocking any proof): make the loader's
  pricing refuse unknown types explicitly, or document the
  fallthrough as load-bearing if some path depends on it.
- E-3 (test-assumption correction, not a spec issue): stories260K
  carries NO llama.rope.freq_base key; the reader defaults it to
  10000.0. The proof asserts the absence + the default rather
  than a copied value. (An early draft of the test assumed the
  key existed and failed on exactly this; the file's Python
  census arbitrated.)
- Build gotcha (recorded for future test authors): with this
  toolchain an entry file that imports loader.gguf must first
  name a core.* module itself, or compilation fails with "unable
  to locate module 'core'" — the gemma probe carries a commented
  anchor import for this.

## Bugs found in readers

None that blocked the proof; no reader code was changed. E-2 is
the only reader-side observation, recorded as named next work.

## Risks / handoff to QC-2

- build_gguf_bytes materializes the whole output as one
  List[UInt8], and copy_gguf_model holds all payloads in the
  desc. Correct and sufficient at fixture scale (QC-1/QC-2 and
  QC-3a stories class); QC-6's ~15 GB output REQUIRES a streaming
  emission path (row-by-row payload provider) — named work for
  the QC-3/QC-6 road, deliberately not built here.
- general.file_type is caller-owned: the writer stores it raw
  and does not compute it. QC-3 must set it per tier (Q8_0 = 7,
  Q4_K_M = 15 per QC-0 section 2) — a wrong label is a file the
  registry misreads while both loaders accept it.
- The writer is payload-agnostic: block correctness (Q8_0's
  34 B layout, f16 d @0) is QC-2's quantizer's duty; QC-1's
  byte-identity harness pattern is the net that catches layout
  drift, and QC-2's round-trip should reuse it.
- Rank-3 tensors are emittable (GGUFSeer accepts 1..3) but
  PackedGGUF refuses rank > 2: a MoE (3-D) emission targeting
  the packed path needs a policy decision in its own slice.
- KV raw carriage preserves values it does not interpret; a
  caller can therefore emit a tokenizer set that
  validate_vocabulary would reject at load. That is by design
  for a copy path (fidelity over interpretation); synthesis
  callers (QC-3) own vocabulary completeness.
