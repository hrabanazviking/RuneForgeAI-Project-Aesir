# Compiler-owned observed GGUF source lifetime

Date: 2026-10-22. Pre-code contract a416da3:
`TASK_hailo10h_owned_gguf_compiler.md`. Controlling scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Implemented boundary

The original Mojo `OwnedGGUFCompiler` owns the existing sealed PackedGGUF and
expanded mathematical graph together. Its consuming factory checks the actual
live descriptor, required seals, actual regular-file size, declared source
extent and captured mapping capacity. It recomputes the entire sealed digest
with an explicit positive call permit. Writable claimed hashes are ignored.

Before compilation it clears the consumed parser's writable table caches and
rebuilds them through the ONE existing header/table interpreter on the SAME
mapping. Existing dense parameters, inventory, semantic plan, recipes and global
expansion then run through their existing implementations. No old production
module changed, and no parser, numerical decoder or lowering algorithm was copied.

The path factory accepts an ordinary unchanged source file, copies and closes
its original descriptor before parsing/compiling, and keeps its sealed mapping
until close. The digest permit applies separately to copy, parser and compiler
hashing. No label/proc-fd reopen, duplicate owner or external compiler is used.
A moved compiler retains its source. Explicit close is idempotent; new tile reads
refuse afterward, and an already copied tile remains usable.

The new tile helper validates the actual owner and the graph's complete source
inventory/bindings/storage descriptors, then reuses the original matrix schedule
and source-byte reader. Constant readers borrow the same parser and retain their
existing representation semantics. No tensor contraction, layer, attention or
model forward runs on the host.

`compiler_input_bytes_bound=true` is scoped to the factory's actual observed
source gates. The original copy can still observe concurrent mixed writes. This
is not arbitrary caller-state corruption protection or a compiled chip-program
identity. Existing global fingerprint, immutable-source, binding/artifact,
device format/fit/placement and execution/device-access flags remain false.
The factory preserves the contracted legacy dense importer/default/rotary/layout
semantics; it does not silently select additional source-policy adapters.

## Native qualification

Evidence: `evidence/owned-compiler-native-2026-10-22/`.

- All660 previous Mojo sources and actual snapshots,69 qualified Python inputs
  and109 prior native binaries remain unchanged. Current source count is663.
- Nine stable clean Mojo builds cover two new entrypoints and all seven selected
  old controls. Three C fault shims also compile without diagnostics. Linking
  completed before acceptance execution. Actual consumers are mapped by source;
  these selected suites have no directory-selected binary arguments.
- Three canonical suites pass23 methods/596 primary child calls. Every selected
  rebuilt old control is covered by480 complete frozen pairs:367 zero exits and
  113 handled nonzero exits. No comparisons were omitted.
- The new eight methods make319 calls:275 successes and44 refusals. They compare
  38 COMPLETE semantic/recipe/global triples,9952 constant components,173 byte
  tiles/25740 exact payload bytes,38 complete old tile outputs, one full parser
  snapshot, six handled refusal pairs and a full path-factory diagnostic.
- All15 current source geometries, tied/untied weights, one/two layers, query/
  past/capacity choices, current dimension defaults and source scalar parameters
  are covered. Forgeable parser caches/hash strings are rehydrated/recomputed.
  Stale owner/inventory/storage/graph/schedule state, bounds, moves, repeated
  close, compiler hash/seal faults and fresh failure recovery are exercised.
- Three new original-file mutation pairs restore the complete preimage before
  an independent repeat and compare complete outputs/postimages. Changes occur
  AFTER sealed copying and BEFORE compilation. Existing controls also retain
  three complete mutation pairs and five separate complete diagnostic-log pairs.
- All209 recorded traces are audited:225 source opens/closes,204 memfd creates/
  closes and182 read-only sealed maps/exact-extent unmaps. Each mapped fd is
  sealed and has its actual extent checked; original source descriptors are
  closed before sealed mapping.5034 post-map hash reads reconstruct100 complete
  hash phases and three intentionally bounded partial phases. Unmap precedes
  owned fd close. No opaque records occur in this run; the auditor retains the
  reviewed PID/name joining and opaque unreturned/unknown-name handling.
- Actual traces contain no target device, network, ioctl or inference-library
  effects. Separate dependency inspection finds no such runtime or external
  cryptographic library dependency. No hardware access or model execution occurred.

## Retained attempts and limits

Development test API import placement and String method spelling errors are
retained. Initial native acceptance also retained two oracle-class discovery
errors and one incorrect success fixture assumption: the legacy importer
requires the omitted floating scalar metadata. The new harness now references
oracle modules without collecting their classes, tests actual dimension defaults,
and compares both omitted-scalar refusals. Production and old tests did not change.
The initial and reviewed inputs, traces, fixtures, outputs and all build attempts
are pinned in the archive identity manifest. Published evidence path labels use
a relative task prefix, and dependency runtime locations use a host-home marker;
raw local evidence and native output hashes are preserved. An initial dependency
path projection exposed nine hygiene diagnostics; raw output is retained and
the published projection is corrected without changing runtime evidence.

Whole-repository/hosted CI success is not claimed. The documentation checker has
23405 inherited failures, including109 control-path diagnostics from the preceding
contract publication. Native before/after output is RAW BYTE IDENTICAL
(sha2560c91ff46), with no added/removed issue and nine old schema diagnostics.
Root README and historical evidence remain intact.

The owner's broad ordinary-model target remains100%. Actual Hailo numerical
encoding/configuration, precision/packing/placement, original program delivery,
results/cleanup, executable-artifact binding and remaining ordinary formats,
architectures and operations remain required implementation work. This slice
establishes compiler-input ownership and byte reads, not source-model execution.
