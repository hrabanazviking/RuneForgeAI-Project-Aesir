# Owned ordinary shard-index metadata and exact file admission

Date: 2026-10-20. Published-first contract:
`TASK_hailo10h_source_index_metadata.md`; concrete reader/ABI design at `c491733`:
`HAILO10H_SOURCE_INDEX_READER_DESIGN.md`. Fixed owner scope remains broad ordinary
model support, with Aesir-owned Mojo translation and Hailo-only LLM execution.

## Connected original implementation

`smidr/source_index.mojo` exposes owned `SourceIndexPolicy` and move-only
`SourceShardIndex`, plus a borrowed-byte parser and path wrapper. Original tensor
names and shard labels remain exact decoded strings, including Unicode/NUL and
unusual labels; none is opened or resolved. Metadata and unknown root fields
retain owned raw validated JSON text, including internal whitespace and numeric/
escape spelling. Optional metadata presence is retained separately. When present,
`total_size` must have nonnegative signed-host-range JSON integer semantics; its
original raw spelling is also retained. Missing declared size is represented by
-1, without claiming an actual tensor/file sum or resource fit.

A full JSON pass checks UTF-8/escapes, duplicate decoded keys, bounded nesting
and trailing-whitespace/EOF. The schema pass requires an object weight_map of
string-to-string entries, optional object metadata and preserves other fields.
It rejects malformed required types or metadata byte-count interpretations.
Empty maps are representable. No model architecture/default, numerical layout,
shape or canonical alias is fabricated from familiar names.

The existing `armvegr.safetensors.JsonParser` supplies the grammar. New documented
`peek`, `copy_raw_span` and `parse_raw_value` methods provide checked lookahead,
independent UTF-8 text copies and raw validated values. Existing safetensors
parsing/number/string/skip behavior is unchanged. Borrowed byte owners must stay
alive through every untracked cursor use; the new parser explicitly extends its
List lifetime across both passes. Raw-span copying alone does not certify JSON.

`smidr/source_metadata_file.mojo` uses the existing syscall gateway and new
`os_fd_regular_size`: read-only/nonblocking/close-on-exec open, checked statx
TYPE/SIZE on the actual fd, bounded short-read loop with one-byte lookahead,
exact extent/final-size check and close on success/error. It never reopens the
path or mmaps metadata. Oversized files cannot become accepted truncated JSON
prefixes. Empty byte files are representable by the byte reader, while the
index parser correctly rejects empty JSON. Final symlinks to regular files are
supported; special files refuse without a blocking FIFO read. Interrupted/failed
reads raise with cleanup rather than returning a partial successful result.

## Policies and actual boundary

Policy fields are positive byte, tensor-entry, schema-member, work-unit and
nesting bounds. Current recursive nesting is at most64. Work units are
4*input bytes plus root fields, direct metadata fields and weight-map entries,
charged with checked arithmetic. Unknown nested members are controlled by the
byte/work/depth policy; the schema-member limit does not count them. Whole-JSON
validation precedes schema counts, with byte/work admission before either pass.
These are logical metadata units, not CPU instruction counts or deadlines.
Diagnostic hex input is currently32768 bytes; production byte/file APIs use
caller-provided bounds. The real pinned26899-byte index fits that diagnostic.

The file wrapper is tested on Linux ARM64. The gateway has explicit ARM64/x86-64
statx numbers and refuses unknown architectures; no other-host execution is
claimed. Descriptor checks and equal pre/post lengths do not authenticate same-
size concurrent rewrites, immutable file identity or a directory's shard set.
Source paths/labels remain descriptive. No CPU/CUDA/cloud LLM/layer/attention
forward, external compiler, model tensor download, device write, reset, firmware
or kernel change occurred.

## Independent verification

Ten new methods pass516 native child calls (175 accept,341 expected refusal).
Three rebuilt consumer suites pass768 more calls: safetensors inventory11/219,
static constants9/97 (264204 exact word checks), tagged storage7/452. Five
additional rebuilt legacy header-only calls pass. Full recorded acceptance is
**37 unittest methods /1289 native calls**, including the extra five commands.

New independent synthetic JSON/byte checks cover original labels, empty/optional
maps, Unicode/NUL/escapes, unknown nested values and exact raw spelling. Sixty
seeded indexes preserve fields/member order. Required types, duplicate decoded
keys at every nesting, integer limits, malformed UTF-8/numbers/literals/escapes,
trailing bytes, every truncation of a valid multibyte fixture and exact byte/
entry/member/work/global-depth limits refuse or pass as specified. Native copies
survive input mutation/destruction; cursor span/position/depth/UTF-8 checks pass.

Real file sizes0/1/2/8191/8192/8193/16384/20000 bytes are copied exactly; valid
prefix plus excess bytes, sparse oversize, FIFO/directory/socket/missing paths
refuse. A test-only C syscall interposer operates over real files to exercise
short reads and injected open/statx/mask/type/reported-size/read/EINTR/EOF/extra-
byte/close failures. Source bytes stay unchanged and close traces are checked.
Forty invalid-then-valid cycles in one native process have matching source open/
close counts. The fault shim is isolated test tooling, never a production link.

The pinned ordinary public JSON index (326 names/two shard labels) is checked by
hash against the previously published metadata facts and independently decoded
with Python JSON. No shard payload is read and no numerical equivalence is
claimed. Syscall traces show only the actual metadata path opened, cleanup
before output and no Hailo/CUDA/HailoRT/GGML/ioctl access. Native linked-library
inspection is retained. Format oracles/Python/C remain isolated verification.

Initial integer-type compile failures and unused initializer warning are kept.
Two initial test failures were harness defects: matching literal Unicode paths
against strace's octal escapes, and failing to retain a List behind an untracked
cursor. The direct cursor probe and production parser now extend owners through
all pointer uses; expected bytes and coverage were retained, not weakened. All
new final builds are warning-free. The historical header-only probe retains its
pre-existing unused conversion initializer warning; no conversion mode is run.
Evidence: `evidence/source-index-2026-10-20/`.

The repository-wide historical master/CI compile failure remains separate; the
last observed implementation run `39425860513` failed there and skipped later
gates. No whole-repository pass is claimed. Observe this slice's published SHA
independently after publication. The consistency checker reports534 issues;
its output before documentation updates is byte-identical to a clean c491733
baseline, preserved as `repository-consistency-baseline.txt`. After staging,
the checker additionally flags2444 literal machine paths in preserved native
evidence JSON; these are execution receipts, not new production settings.
The new canonical ledger entry and summary counts are synchronized. No new
production source-path violation is present; the whole checker still fails.

## Next original connection

This verifies index metadata and file admission. It does not resolve shard files,
verify tensor names/extents across shards, interpret full configuration/modifier/
rotary semantics, migrate all semantic storage consumers, emit numerical Hailo
instructions or execute source models. All output execution/fingerprint/fit
flags stay false. Continue ordinary configuration and shard/storage/semantic
integration together with actual numerical encoding/configuration/precision/
packing/placement/upload/results/cleanup under the unchanged broad target.
