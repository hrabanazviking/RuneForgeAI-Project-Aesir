# Compare complete retained ordinary tensor representations

Date:2026-10-23. Publish before implementation. Parent:
`TASK_hailo10h_source_compiler_plan.md`. Owner scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Boundary:`docs/HAILO10H_TIED_OUTPUT_IDENTITY_BOUNDARY_2026-10-23.md`.

## Allowed original implementation

Add ONLY new`smidr/ordinary_tensor_identity.mojo`and scoped inspector/test leaves.
Zero old production/test edits. Implement indexed/unindexed comparison entry
points taking a retained owned ordinary binding, two canonical source names,
explicit positive total element and temporary chunk bounds, and the supplied
existing binding policy. This is an internal compiler prerequisite; no user
model conversion or source-file rewrite is introduced.

Before selecting tensors, reuse existing supplied/owned policy comparison,
actual retained-source refresh and complete schema/source comparison. Claimed
hashes, mutable caches and a tie flag cannot establish equality. Locate both
actual retained shards from the freshly derived canonical source storage. Require
the same Safetensors representation kind, axis order, full shape, element and
byte counts. Different representation/shape must explicitly refuse as unresolved
comparison work; this is not a permanent model eligibility rule.

Reuse the existing sealed collection constant reader. Compare ONLY its raw words,
not converted floating values; no new dtype decoder, hashing, sorting, JSON,
alias or numerical recipe implementation. Walk every element in bounded chunks
even after a mismatch. Check positive bounds, total counts and actual selected
layout before temporary allocation. Preserve exact source names, original names,
paths, spans, kind, axes and shapes as independent returned copies. Report the
complete compared element/byte count, differing-element count and first differing
element, with an explicit all-elements-equal result. Same-name comparison still
validates actual owners and scans all bytes. No approximate/numerical equality.

No new raw OS API, fd duplication, path/proc/label reopen, remap or whole-shard
copy. Owners stay with their caller; copied result descriptions may outlive
close. Use the existing mapping/seal/lifetime guards and actual source extent
accounting. Existing nonraising source-close limitations remain visible.

This slice does not resolve the tied-output graph alias, remove/merge a source
binding, change tie semantics, relax the old compiler refusal or certify global
artifact identity. Subsequent typed alias lowering must be separately contracted
and revalidate actual source observations. Full broad model support100% and
all remaining formats/architectures/operations remain required work.

## Qualification and acceptance

Pre-code actual695 Mojo sources,83 Python tests and150 immutable native controls
are copied and verified with compiler SHA256
`be46936245ae995680155dcc2f61af5dac8678254c634110e99ceff25ce57c39`.
Reverify these and freeze a fresh baseline immediately before production.
Recompute all new consumers and link them, selected owned binding/compiler,
projection-schema and sealed collection controls, and every auxiliary test binary
before acceptance. Stable final source/test copies must precede execution.

Use independent tiny indexed/unindexed fixtures with actual stored bytes. Cover
all three current raw floating representations, exact equal and unequal spans,
first/middle/last mismatches and NaN payload/signed-zero distinctions, every-byte
mutation coverage, separate shards, same-name, all chunk tails, work/count bounds,
incompatible shapes/kinds, absent names and original changes after ownership.
Verify complete returned source layouts/accounting independently; no host model,
layer, attention or master forward. Retain existing duplicate tied-output compiler
refusals and complete old stdout/stderr/exit/handled messages against frozen
controls. Restore full original file/directory state for paired mutations.

Mutate supplied/owned policy, schema/source/alias/span/layout caches and actual
owner fields; refresh safely or refuse before selecting wrong data. Exercise
moves, close, forged extents/seals, injected copy/hash/read/close failures and
fresh recovery with complete independent fault logs. Audit actual PID/fd/map/
hash/read/cleanup joins and inspect ELF dependencies separately. No device,
network, inference library or external compiler effects are allowed. Preserve
every failed attempt and opaque trace record without fabricated effects.

Report only observed complete representation comparison on retained source
bytes. Physical numerical precision/packing/placement/CCWs, program transport,
activation/results/cleanup remain active under
`TASK_hailo10h_numerical_encoding_sources.md`. No invented opcodes, device writes,
DFC, external compile machine, vendor artifact prerequisite or CPU/CUDA/cloud LLM
execution/proxy. Verify -> publish Hailo -> exact remote head/tree -> preserve
owner work and fast-forward main -> verify clean checkouts -> next slice.
