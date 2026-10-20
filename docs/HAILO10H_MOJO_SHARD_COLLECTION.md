# Actual indexed ordinary source files and tensor binding

Date: 2026-10-20. Published-first design at1a74c1b:
`HAILO10H_INDEXED_SHARD_COLLECTION_DESIGN.md`; parent contract
`TASK_hailo10h_shard_collection.md`. Broad ordinary-model target unchanged.

## Original connected implementation

`smidr/shard_collection.mojo` loads the actual source index/config and distinct
indexed safetensors shards beneath one owned root fd. JSON uses consumed
positional regular-file descriptors and exact whole-file bytes; shard metadata
uses consumed positional prefix/header reads. Neither route reopens descriptive
paths. Index/config parsers and full source header grammar are reused. The
existing source metadata path reader retains current-offset reads/syscall close;
its read arithmetic/lookahead is now shared with the new positional fd owner.
Old path fault behavior and cleanup regressions remain intact.

The collection preserves raw index/config fields, original tensor names/shard
labels, full axes, container/dtype namespace, descriptive backing paths/spans
and separate per-shard metadata. Shared safetensors-to-tagged-storage projection
is factored from the existing reader, including its validation. Matching names
or file shapes do not create architecture defaults or executable model support.

Distinct labels are enumerated in first encounter order. Each referenced shard
is opened once and every actual tensor must have the exact index name mapped
to that original label. Extra/missing/misdirected/global duplicate names refuse.
Optional declared total_size must equal actual tensor payload-byte sum, excluding
all prefixes/headers. Empty consistent collections are representable. No tensor
payload is read, no source map is created and no semantic alias is guessed.
Snapshots and paths are not immutable source identity; same-size rewrites remain
unauthenticated. Actual binding verification is scoped to checked metadata at
load time. Nested index/config inspectors retain their own metadata-only flags.

`ShardCollectionPolicy(shards,tensors,metadata_bytes,payload_bytes,work)` supplies
positive aggregate limits. Metadata bytes = index bytes + config bytes + sum
of shard prefix/header bytes. Logical work = metadata bytes + indexed names +
distinct labels + actual tensors + sum of actual ranks. Checked sums/caps apply
before growth, JSON/header read caps use remaining aggregate bytes/work, index
entry cap and remaining per-shard tensor caps are narrowed without replacing
invalid supplied policies. Root path/attempt/work/source-size and individual
parser policies remain explicit. These are logical units, not CPU instruction
counts, deadlines, placed hardware memory or model-fit proof. All success/error
paths close consumed fds/root before a successful result; close failure refuses.

Public APIs are read_indexed_shard_collection and the owned collection/shard
records. The native inspector takes explicit diagnostic policy arguments; it is
not a model-specific conversion workflow. Current positional fd implementation
is verified ARM64 Linux; initial source dtypes remain F16/BF16/F32. Other hosts/
source dtypes/containers/architectures remain implementation work. Indexed input
is this slice's source format, never a permanent model prerequisite; ordinary
unindexed file loading follows without asking the user to invent a manifest.

## Independent verification

Five new methods pass205 native calls (132 accept,73 expected refusal).
Thirty seeded and explicit multi-file collections match independent source
headers and existing tagged-storage output. Original Unicode/NUL names, Unicode
file label, scalar/empty/full axes, all current floating source kinds, optional
or exact totals, reused labels and colliding per-shard metadata are preserved.
Raw config modifiers survive unchanged; separate owned collection mutation does
not affect a second result. Empty metadata collections also pass.

Exact aggregate bounds/root attempt/work edges and invalid per-parser policies
refuse, including invalid fd policies on an empty index. Missing/extra/misdirected/
global duplicate names, missing file, wrong/negative total, malformed config/late
header and escape/absolute/NUL/empty/special labels refuse without partial output.
Root config/index/shard traces show exact actual opens/closes and only shard
prefix/header reads, with no payload/source mmap/device access. Twenty late
missing-tensor failures interleaved with valid loads match all descriptor/root
close counts. Sources stay unchanged outside explicit synthetic fixture setup.

The owned whole-file fd byte reader copies sizes0/1/2/8191/8192/8193/20000 exactly,
including invalid UTF-8 bytes at this format-agnostic layer, and works with an
original offset at EOF. JSON layers validate UTF-8 separately. Invalid bounds/fd
integers refuse; fourteen isolated metadata I/O fault modes cover actual short
reads, EOF/body/read/EINTR, invalid count, injected byte after admitted EOF,
statx/mask/type/size and native close. Only the actual short-read case succeeds.
The test shim closes the actual fd before reporting close failure. Test-only C
is not linked into production. Preliminary202-call success evidence is retained
before Unicode-label/extra-byte coverage was added; no failed assertion occurred.

Seven regression suites add53 methods/1916 calls, including previous fd365,
inventory219, constants97/264204 word checks, tagged storage452, index516,
config190 and root77. Changed index/config/storage consumer pairs were rebuilt;
unchanged shared binaries were rerun. Full slice: **58 methods/2121 native calls**.
All new/rebuilt builds are warning-free; previously recorded legacy warning is
not relabeled. Commands/hashes/provenance: `evidence/shard-collection-2026-10-20/`.

Prior owned-header1a74c1b hosted CI fails separately and is observed at its exact
SHA. Repository consistency reports8564 diagnostics:534 baseline issues
plus8030 literal execution-evidence paths; no new production/test source path
violation or ledger count mismatch is named. Current slice CI is checked after publication; no full repository pass or
numerical device/model execution is claimed. No outside compiler, model weights
download, special model conversion, inference proxy or device write occurred.

## Next automatic connection

`TASK_hailo10h_unindexed_source_collection.md` covers ordinary single-file input
without an index prerequisite. Complete tagged semantic storage/config/rotary/
window/bias/tied handling, full format/architecture breadth and actual numerical
Hailo precision/packing/placement/instructions/upload/results/cleanup remain
required toward the owner's fixed broad target.
