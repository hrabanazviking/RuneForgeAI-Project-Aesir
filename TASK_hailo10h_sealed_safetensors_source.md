# Consume sealed Safetensors sources in the existing Mojo reader

Date: 2026-10-22. Publish before production. Parent:
`TASK_hailo10h_source_compiler_plan.md`. Fixed owner scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
GGUF compiler-owned input is verified at80c7f2a;6a1eb4f also preserves the owner's
concurrent lawbook upload. This slice extends ordinary source-format ownership.
Broad support remains100%; missing dtypes/ranks/architectures/operations are
implementation work, never permanent eligibility restrictions.

## Exact existing boundary and permitted changes

`armvegr/safetensors.mojo` already has ONE header decoder and a live mapped
`SafetensorsLoader`, but only opens paths and cleans up using mutable file_size.
`smidr/safetensors_fd.mojo` consumes and closes a descriptor after bounded header
inspection; it cannot retain immutable payload ownership for constant readers.
Reuse the actual mapped loader and ONE decoder, rather than duplicating either.

Only one old production module may change: `armvegr/safetensors.mojo`.
Add original `smidr/sealed_safetensors_source.mojo` and scoped tool/test leaves.
No source-policy, graph, numerical conversion or ordinary-reader algorithm may
be copied/replaced. No user conversion, external compiler, DFC or precompiled
artifact prerequisite is introduced. All LLM execution remains Hailo-10H only.

The old loader gets independently captured `_mapping_extent` and persistent
`_sealed_route` state. Initialize capacity0; capture actual extent only after a
successful map on BOTH old-path and new-sealed routes. `_req` clamps ranges
against declared size AND captured capacity; cleanup unmaps the captured extent
and clears ownership. Preserve all old-path parsing/output/precision/default/
refusal behavior and explicit old-path close/reopen semantics. Existing tensor
and header decoders and FP conversion bodies remain byte-identical. No new
implicit destructor is added to the shared old loader.

Add `_adopt_owned_sealed_fd(mut self,owned_fd:Int64,source_bytes:Int64,
header_bound:Int,tensor_bound:Int,rank_bound:Int,work_bound:Int,depth_bound:Int)`.
Consume the actual fd on entry, including policy/seal/size/map/header failures.
Exact range-check before narrowing to Int32; validate actual host, required
kernel seals and actual regular-file extent through existing HAILBRU helpers.
New OS calls stay inside HAILBRU. Map the same descriptor read-only/shared at0,
then use the existing `_parse_header`/ONE header decoder. No dupfd, path/proc-fd
reopen or borrowed owner alias. A busy alias refusal preserves the current live
fd; a distinct incoming fd is closed once. The sealed-route guard persists
across close and refuses explicit path reopening; old ordinary-path reopening
remains unchanged. Cleanup must be exact on partial construction and exceptions.

## New owned wrapper and APIs

`SealedSafetensors(Movable)` owns `source:SafetensorsLoader`,
`source_bytes:Int64`, `digest_hex:String` and a diagnostic `label:String`.
The new wrapper alone supplies RAII cleanup of its contained loader and an
explicit idempotent close. Moving must not create a second fd/map owner.

```
parse_sealed_safetensors(var bytes:SealedSourceBytes,label:String,
  header_bound:Int,tensor_bound:Int,rank_bound:Int,work_bound:Int,
  depth_bound:Int,digest_call_bound:Int) raises -> SealedSafetensors

load_sealed_safetensors(path:String,source_byte_bound:Int,read_call_bound:Int,
  write_call_bound:Int,digest_call_bound:Int,header_bound:Int,tensor_bound:Int,
  rank_bound:Int,work_bound:Int,depth_bound:Int) raises -> SealedSafetensors

read_sealed_safetensors_constants(owner:SealedSafetensors,name:String,
  first:Int,count:Int,element_bound:Int) raises -> SafetensorsConstantWindow
```

The parser recomputes the full actual sealed digest with a positive explicit
call permit, ignoring writable claimed hash strings, then uses the existing
exclusive `take_fd` and new loader admission. The path factory uses existing
bounded seal/copy behavior and closes the original descriptor BEFORE parsing.
The digest permit applies separately to copy and parser hash phases. No label
is reopened, and no temporary SealedSourceBytes owns a borrowed fd.

The constant helper validates actual live seals/size/mapping/capacity, then calls
ONE existing `read_safetensors_constants`. No dense tensor/layer/attention/model
forward, independent decoder or host inference. Complete copied raw words and
binary32 component words may outlive close; subsequent source reads must refuse.
Preserve the separate Safetensors/GGUF dtype namespaces and full source rank,
axis order, metadata, empty/scalar spans and exact source offsets. Current dtype
implementation gaps remain work; do not relabel them model eligibility policy.

Only a scoped `sealed_input_bytes_bound=true` diagnostic may follow real gates.
Atomic-original snapshot/global fingerprint/immutable-source/binding identity,
compiled-artifact/device-format/fit/placement and execution/device-access flags
stay false. No protection against arbitrary unsafe caller-state corruption is
claimed. A copy may observe mixed concurrent original writes.

## Pre-code qualification and native acceptance

Baseline:663 current actual Mojo sources/snapshots,111 qualified native controls,
70 qualified Python inputs/actual copies, all verified. Existing source snapshots
are in the preceding owned-compiler final archive; the study pins all identities.
A new closed-source wrapper/move/destructor probe compiles cleanly and is NEVER
EXECUTED; this qualifies type feasibility only. Conservative import closure finds
101 qualified entrypoints importing the permitted old module. Recompute the real
closure after code, build every affected entrypoint and all111 qualified control
entrypoints with stable sources before any native acceptance execution. No
engine/master/E-REAL/model/attention forward is authorized.

Compare COMPLETE ordinary synthetic Safetensors headers, metadata, rank/axes,
source bindings and all three current dtype raw/binary32 component windows with
independent existing oracles. Cover scalar/rank0, higher ranks, empty tensors,
zero-byte payloads, odd/page boundaries, UTF8/NUL/duplicate/depth/header/extent/
overlap/overflow/refusal semantics and explicit budgets. Mutate/truncate/replace
and close originals AFTER copying BEFORE parsing; outputs remain sealed-source
views. Exercise forged hash/extent, live/closed/moved/busy alias/distinct owners,
capacity mutations, repeated close, copied results after close, syscall/parser/
hash failure cleanup and fresh recovery. No digest-only component comparison.

Pair every actual affected old consumer by SOURCE identity, including --binaries
directory aliases. Keep primary/control fault logs separate and compare COMPLETE
bytes. Restore intentional fixture preimages before controls, compare COMPLETE
postimages and restore primary postimages. Retain all failed attempts and inputs;
never omit comparisons to pass. Trace original close before sealed admission,
same fd through map/parser/component reads and exact unmap-before-close. Join
actual PID/name split records, including literal unresolved names and resumed-
but-unreturned calls; retain opaque effects without invented returns. Separate
dependency inspection from actual effects. No target/network/ioctl/inference or
external model compiler access. Derive all counts from actual logs.

Verify, commit/publish Hailo branch, verify exact remote head/tree, fast-forward
main while preserving concurrent owner work, verify both clean checkouts, then
continue. Owned ordinary config/shards, compiler bindings and actual numerical
configuration/packing/placement/program delivery/results remain subsequent work.
