# Own ordinary source shard collections through existing parsers

Date: 2026-10-23. Publish before production. Parent:
`TASK_hailo10h_source_compiler_plan.md`. Owner scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Previous native metadata ownership:6ff5ec6. Broad ordinary-model support100%
remains fixed; missing formats/architectures/operations remain implementation work.

## Boundary and permitted changes

The existing SourceModelRoot opens actual regular files beneath one owned root
with bounded path/file/work/source policies. Existing sealed byte copy accepts a
BORROWED original fd and returns an exclusive actual sealed copy. Existing sealed
metadata/Safetensors consuming parsers own those copies. Existing shard collection
joins verify all tensor names, source labels, total_size and aggregate bounds but
retain only copied descriptors after closing originals. The next slice connects
these established components while retaining every actual sealed backing file.

Add only new `smidr/sealed_source_collection.mojo` and scoped tools/tests. Zero old
production edits. Reuse SourceModelRoot.open_file, seal_source_copy, the consuming
sealed metadata/Safetensors parsers, existing Safetensors inventory projection and
source storage validation, and existing aggregate charge/policy helpers. No JSON,
header, dtype conversion, file-copy, hash, beneath-root or storage-sort algorithm
copy. All production OS effects use existing HAILBRU interfaces. No descriptor
duplication, proc/label reopen, raw OS additions or temporary borrowed fd owners.
No calls to old collection path readers as substitutes for owned sealed inputs.

New movable shard value holds label, SealedSafetensors and existing
SourceStorageInventory. New indexed collection holds SealedSourceConfig,
SealedSourceIndex and a List of these shard values; the unindexed collection holds
SealedSourceConfig and one shard value. Both retain root diagnostic path, existing
tensor/metadata/payload/work totals and an aggregate copied-source-byte total.
Field destruction supplies cleanup; explicit idempotent close closes all backing
owners and continues cleanup across reported errors. Report the first failure
from existing raising close interfaces; retain the existing nonraising Safetensors
close behavior without claiming that it surfaces every underlying syscall failure.
Retained copied descriptors/byte windows may outlive close; new reads must refuse.

## Exact loading and accounting

New indexed/unindexed factories take ordinary root/labels, existing root/config/
index/fd/collection policies and explicit aggregate source-byte/read-call/write-
call/digest-call bounds. Source-byte bound covers the SUM of actual config/index/
shard file extents, including padding. Copy/hash attempt bounds apply separately
per file and per copy/parser hash phase; do not relabel them as a global permit.
Parser, root-open and collection work/metadata/payload accounting retain their
established separate meanings. Charge before allocation/copy and before any
narrowing; use remaining aggregate source bytes and checked subtraction/addition.
Refuse invalid/overflowing policies and extents before effects where possible.

A consuming local SourceRegularFile bridge checks actual host against its owner,
borrows its exact live fd/declared extent to ONE existing seal_source_copy, closes
the original before returning bytes, and cleans original and partial sealed owner
on every error. Existing copy rechecks actual regular-file extents. Root opens
remain beneath the same live directory; labels are diagnostic, never paths for
subsequent parser or constant reads. No source-root symlink policy is weakened.
Root closes before a collection is returned; every successfully opened original
closes before its sealed parser runs. Previously admitted sealed owners clean up
if any later file, policy, join, close or parser fails.

Parse config/index from their sealed owners. Deduplicate shard labels, cap shard/
tensor/header/rank/work policies by remaining collection limits, and retain every
sealed payload owner. Project existing parsed Safetensors descriptors through the
existing inventory/storage routines, preserving original rank/axis/dtype namespace,
raw metadata and exact spans. Verify no duplicate global tensor, no extra/missing
index tensor, exact label membership and declared_total_size versus actual payload.
Unindexed loading retains current one-file collection semantics; further formats,
variants and indexed/unindexed paths remain implementation work, never product
eligibility restrictions. Labels/parsed caches/digests are writable, not identity.

Provide bounded borrowed byte/constant access through the existing sealed helpers
while these owners live. Select an actually retained shard, enforce exact live
sealed extent/mapping and existing bounds. Do not claim compiler/artifact identity
from cached collection metadata; later compiler binding must rehydrate/revalidate
against retained bytes. No model/layer/attention computation is allowed on host.

Only scoped owned observed-collection lifetime may follow actual gates. Atomic
multi-file original version, global source/binding/artifact identity, architecture
semantics, numerical format/fit/placement, execution and device-access flags remain
false. Originals can change between file copies, or during a copy; no atomic source
revision is claimed. No invented numerical opcode/register/configuration or target
request. All LLM execution remains on Hailo-10H. No DFC, outside compiler/external
compilation machine, vendor-precompiled prerequisite, host forward or proxy.

## Pre-code qualification and acceptance

669 current source identities match the previous actual frozen source snapshot;
72 Python inputs/copies and119 native controls are verified before production.
A consuming SourceRegularFile-to-sealed-copy closed-owner probe compiles with zero
diagnostics and is NEVER EXECUTED; it proves type/cleanup feasibility only.
Evidence: `docs/evidence/sealed-collection-contract-2026-10-23/`.
Freeze actual current source/test snapshots and controls again before implementation.

Prove every old source/test exact; recompute real new-leaf consumers. Rebuild the
new tool/API and selected existing source-root tool, indexed/unindexed collection
tools/APIs, sealed metadata tools/API, sealed Safetensors tools/API and sealed-copy
tool/API from stable sources before native acceptance. All119 pre-code controls
remain immutable; no claim of rebuilding unrelated entries. Compare complete old
stdout/stderr/exit/handled messages by source identity, with independent fault
logs and complete restored mutation preimages/postimages/deletion states.

Independently check complete metadata/maps/storage descriptors, every actual
backing digest/byte stream and representative exact F16/BF16/F32 component words,
including special values, scalar/empty shapes and boundaries. Match old complete
collection outputs where their scope overlaps. Test indexed/unindexed ordinary
folders, nested beneath-root labels, shared label deduplication, missing/extra/
duplicate/misassigned tensors, declared sizes, Unicode/NUL/escaped metadata,
invalid source types, forbidden symlinks/escapes and every root/parser/aggregate/
copy/hash/constant bound. Preserve current unsupported dtype behavior as missing
implementation, not changed eligibility. Cover forged caches/claims, moved/closed
owners, repeat close and retained independent windows. Actually modify, truncate,
rename/replace and same-size-write originals after copy before parse/after return;
restore full preimages before independent repeats and compare complete postimages.

Inject copy/hash/seal/parser/join/root/close faults and a failure in a later shard
with earlier owners already admitted, followed by fresh success. Audit PID/name/
fd-generation split/resumed/unreturned syscall records. Prove original-close-before-
parse, same copied descriptor through full hashes/parser/mapping/read, exact mapping
capacity/unmap, root/ordinary/sealed close balance and no label reopen. Keep literal
opaque records without inferred effects; inspect dependencies separately. No target,
network, ioctl, inference runtime or external compiler calls. Retain all failed
attempts and exact final inputs. Verify → commit/publish Hailo → exact remote head/
tree → fast-forward main preserving owner work → verify both clean checkouts →
continue compiler bindings and actual numerical configuration/delivery/results.
