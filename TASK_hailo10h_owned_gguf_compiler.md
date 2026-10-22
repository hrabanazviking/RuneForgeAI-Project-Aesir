# Keep source ownership through internal GGUF compilation

Date: 2026-10-22. Publish before production. Parent:
`TASK_hailo10h_source_compiler_plan.md`. Controlling scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Sealed parser/source-reader integration is verified at73f89e9 under
`docs/HAILO10H_MOJO_SEALED_GGUF_SOURCE.md`.

## Existing boundary and intended change

The ordinary path semantic reader currently closes its PackedGGUF before
returning a structural plan. The new sealed parser owns immutable observed
bytes, and its tests already borrow that source into graphs and readers.
Connect these existing production components into one compiler-owned lifetime.
No old production module/API/output may change in this slice. Add original
`smidr/owned_gguf_compiler.mojo` and scoped tool/test leaves; reuse existing
parsers, source representations, semantic/recipe/global lowering and tile readers.
No copied/parallel parser, numerical decoder, graph expander or tile algorithm.

This is a compiler input/session boundary. It is not a numerical backend or a
chip-program artifact identity. Missing ordinary formats, architectures, ranks,
operations and numerical encodings remain implementation work toward the owner's
fixed broad100% target, never permanent model eligibility restrictions.

## Ownership and source admission

Add movable `OwnedGGUFCompiler` owning `owner:SealedPackedGGUF` and
`graph:ExpandedGraph`; the latter already owns its SemanticPlan and recipes.
No descriptor duplicates or path/label/proc-fd reopens. Do not retain two owners
of one fd or construct a temporary sealed owner around a borrowed fd.

Add a consuming factory:

```
compile_owned_gguf(var owner:SealedPackedGGUF,query_tokens:Int,
  past_tokens:Int,context_capacity:Int,digest_call_bound:Int)
  raises -> OwnedGGUFCompiler
```

Validate actual live mapping/descriptor, required seals, actual regular-file
extent, declared source size and captured mapping capacity using existing
HAILBRU/loader helpers. Recompute the full actual sealed digest with its explicit
positive call budget; ignore writable claimed digest strings as identity gates.
Reject inconsistent ownership/extent before compiler work. Exception cleanup
must release the consumed actual owner once and permit fresh independent recovery.

Cached PackedGGUF dictionaries are writable. Before compiling, clear only that
consumed parser's fields/field_types/tensors/tensor_shapes/data_offset and reparse
the actual header and single existing `_interpret_tables` method on its same
mapping. Do not trust forged cached offsets, types, names, shapes or alignment.
This reparsing is new-leaf orchestration, not a shared parser/API change. Do not
claim protection against arbitrary unsafe pointer or caller-memory corruption.

Build existing dense parameters and inventory from that exact parser, then the
existing semantic plan and expanded graph. Preserve existing scalar, default,
rotary/layout, architecture and unresolved-gate semantics. Do not select or invent
a device layout/precision or silently add ordinary architecture admission. The
source, graph and eventual byte reads must remain in one returned owned lifetime.
No host tensor, layer, attention or model evaluation.

Add a path convenience factory:

```
load_owned_gguf_compiler(path:String,source_byte_bound:Int,
  read_call_bound:Int,write_call_bound:Int,digest_call_bound:Int,
  query_tokens:Int,past_tokens:Int,context_capacity:Int)
  raises -> OwnedGGUFCompiler
```

Use the existing sealed parser path factory and consuming compiler factory. The
same positive digest budget applies separately to copy, parser and compiler
hash phases. Original path closure occurs before parser/compiler consumption.
The user supplies an ordinary unchanged source file, with no external model
compiler, converted intermediate, vendor-precompiled artifact or external machine.

## Bound byte streaming and close

Add `read_owned_gguf_weight_tile(context:OwnedGGUFCompiler,operation:Int,
policy:MatrixTilePolicy,index:Int,host_byte_bound:Int)` returning SourceWeightTile.
Validate the actual owned source's current seals/extent/mapping and graph source
inventory/bindings before using existing `plan_matrix_contraction` and
`read_source_weight_tile` on `context.graph.source` and `context.owner.source`.
No label reopen, dense weight conversion, product or host inference. Preserve
exact source bytes/components and original source/storage identities. Constant
readers may borrow `context.owner.source`; do not duplicate their decoders.

Explicit idempotent close closes the owned mapping/fd; later source reads refuse
without reopening a label. Moved returns and exceptions must not duplicate owners.
Copied tile/component results may outlive close; new reads may not. Existing
metadata alone must not certify a live source or artifact identity.

A new diagnostic may report `compiler_input_bytes_bound=true` only through the
actual factory/owner/lifetime gates. Keep atomic-original snapshot, existing
source_fingerprint_verified/immutable-source/binding identity, compiled-artifact
identity, device-format/fit/placement, execution and device-access flags false.
Public mutable labels or hashes are not attestations. Mathematical compiler IR
and byte streaming are not source-model execution or proof of H10H arithmetic.

## Pre-code qualification and acceptance

Current660 source identities and actual snapshots,109 current native controls
and69 qualified Python test inputs/actual snapshots are verified before this
contract. Evidence: `docs/evidence/owned-compiler-contract-2026-10-22/`.
A compile-only movable owner-plus-expanded-graph probe builds cleanly; it is
never executed and qualifies type feasibility only, not compiler behavior.
No existing source imports the planned new leaf; preserve all660 old sources,
69 old Python inputs and109 controls. Recompute actual consumer closure after
implementation. Build all affected new entrypoints and selected old controls
with stable sources before any native tests. No engine/model/master forward.

Independently compare COMPLETE ordinary synthetic source graphs/recipes/global
artifacts, source scalar words, source bindings, constant components and byte
tiles through the new owned context. Cover current geometries, tied weights,
query/past/capacity choices, aliases and source/default/refusal behavior. Modify,
replace, truncate and close the original AFTER copying and BEFORE compilation;
metadata/lowering/reads must still refer to the same sealed bytes. Test false
cached parser fields and digest strings, live/closed/moved/refused owners, stale
source/graph/schedule bindings, explicit bounds, compiler/hash/lowering failures,
exact cleanup and fresh recovery. No digest-only substitute for component checks.

Keep full success/refusal frozen pairs and unchanged old test inputs. Resolve
ALL actual consumers, including --binaries directories, by source identity;
isolate primary/control diagnostic logs and require complete equality. Restore
intentional file preimages before controls and compare complete postimages.
Never omit a comparison to get a pass. Trace exact descriptor→map→compiler/read→
unmap/close lifetimes and no later opens of labels. Join PID/name split records,
including resumed-but-unreturned termination and literal unresolved names;
retain opaque records without inferred effects. Derive counts from actual logs,
keep dependency inspection separate, preserve all raw failures and snapshots.
No target-device/network/ioctl/inference/external model compiler access.

Verify, commit/publish Hailo branch, verify remote exact head/tree, fast-forward
main and verify both clean checkouts, then continue. Actual physical numerical
configuration/packing/placement and original program execution/results/cleanup,
compiler executable-artifact binding and broad ordinary coverage remain required.
