# Retain sealed ordinary config and index bytes through existing Mojo parsers

Date: 2026-10-22. Publish before production. Parent:
`TASK_hailo10h_source_compiler_plan.md`. Fixed owner scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Native Safetensors ownership is verified at3d3b3a4. Broad ordinary support stays
100%; missing formats/architectures/operations remain implementation work.

## Exact boundary and permitted changes

`smidr/source_config.mojo` and `smidr/source_index.mojo` already parse bounded
owned bytes with ONE existing JsonParser and retain copied raw fields/bindings.
Their path readers close the original file and retain no sealed observed-byte
owner. `smidr/source_metadata_file.mojo` already has a borrowed positional
`_regular_bytes(arch,fd,size,True)` helper with8192-byte requests and one EOF
lookahead byte; its consuming wrapper must not be used on a borrowed owner fd.

Add ONLY original `smidr/sealed_source_metadata.mojo` and scoped tool/test leaves.
No existing production source may change. Reuse the exact existing borrowed
reader, config/index parsers and policy functions; copy no JSON/read algorithm.
No temporary SealedSourceBytes may own a borrowed fd. No fd duplication, label
or proc-fd reopening, old-module implicit cleanup, mmap or new raw OS calls.
All OS effects use existing HAILBRU interfaces.

## Owned values and exact APIs

New movable values:

- `SealedSourceConfig`: `source:SealedSourceBytes`,
  `config:SourceConfiguration`, `digest_hex:String`, `label:String`.
- `SealedSourceIndex`: `source:SealedSourceBytes`,
  `index:SourceShardIndex`, `digest_hex:String`, `label:String`.

Existing byte-owner field destruction supplies RAII; explicit idempotent
`close(mut self) raises` delegates to that owner. No second fd owner is created.
Copied parsed fields/byte lists may outlive close; fresh source reads must refuse.

```
read_sealed_metadata_bytes(source:SealedSourceBytes,byte_bound:Int)
  raises -> List[UInt8]
parse_sealed_source_config(var source:SealedSourceBytes,label:String,
  policy:SourceConfigPolicy,digest_call_bound:Int) raises -> SealedSourceConfig
parse_sealed_source_index(var source:SealedSourceBytes,label:String,
  policy:SourceIndexPolicy,digest_call_bound:Int) raises -> SealedSourceIndex
load_sealed_source_config(path:String,source_byte_bound:Int,read_call_bound:Int,
  write_call_bound:Int,digest_call_bound:Int,policy:SourceConfigPolicy)
  raises -> SealedSourceConfig
load_sealed_source_index(path:String,source_byte_bound:Int,read_call_bound:Int,
  write_call_bound:Int,digest_call_bound:Int,policy:SourceIndexPolicy)
  raises -> SealedSourceIndex
```

The borrowed byte helper requires an explicit positive byte bound, actual ARM64
host matching the owner architecture, exact live fd, required actual kernel
seals and actual regular-file extent. Check extent/bound/lookahead arithmetic
before allocation or narrowing, call ONE existing `_regular_bytes`, then verify
actual seals/extent again. Return all exact copied bytes. Retain its established
8192-byte request limit and single EOF lookahead: a request may extend one byte
past the actual extent to observe EOF; successful returned data is exactly the
source extent. Progress or refusal bounds calls by `source_bytes+1`. Metadata
I/O accounting is separate from parser work and the4096-byte digest/copy stages.

Both consuming parsers validate actual host/owner, positive explicit digest
permit and their existing parser policies for the real size. Recompute the full
actual sealed digest using existing read_sealed_source_digest; ignore writable
claimed hashes. Borrow the same live byte owner for the byte helper; keep the
copied List alive through ONE existing parser. Set parsed source_path to the
diagnostic label and move the original byte owner into the new wrapper. Every
policy/read/hash/parser failure consumes and cleans the incoming owner.

Path factories use existing bounded seal_source_copy and original-close-before-
parse behavior, shared only as new local orchestration. Validate ordinary paths
and parser policies; retain exact explicit source-byte/read/write/digest caps.
Digest permits apply separately to copy and parser hash phases. No parser,
source-root, shard-collection, architecture or compiler algorithm changes here.
The consuming parser APIs permit later beneath-root collection integration
without requiring users to transform ordinary files or generate a special index.

Only scoped `sealed_metadata_bytes_bound=true` may follow real gates. Atomic
original version/global fingerprint/immutable-source/binding/artifact identity,
semantic adapter/device format/fit/placement and execution/device-access flags
stay false. Parsed caches and claimed hashes are writable, not identity proofs;
arbitrary unsafe state corruption is not covered. Copies may observe mixed
concurrent original writes. This is a compiler-input ownership boundary only.

## Pre-code qualification and native acceptance

666 actual Mojo sources and prior actual snapshots,117 current native controls
and71 current Python inputs/copies are verified before production. One old
legacy current binary has the previously qualified inherited unused-initializer
warning; no warning suppression or source change is permitted. A closed config/
index owner move/cleanup probe builds cleanly and is NEVER EXECUTED, proving
only type feasibility. Evidence:
`docs/evidence/sealed-metadata-contract-2026-10-22/`.

With zero old production edits, prove all666 old source identities unchanged and
recompute real new-leaf consumers. Rebuild every actual affected consumer, new
tool/API and the six selected old config/index tool/API and sealed-copy tool/API
controls from stable sources before any native acceptance. All117 pre-code
controls stay immutable. Pair COMPLETE outputs, stderr, exit and handled errors
by source identity; keep independent fault logs, restore full mutation preimages
and compare complete postimages/deletion state. No omitted comparisons.

Use independent complete ordinary JSON bytes, raw field spans, decoded keys,
index maps/metadata/unknown fields/counts/work and existing frozen outputs.
Cover empty/scalar/wrong-root/missing-weight-map, null/default/raw modifiers,
Unicode/NUL/escaped duplicate keys, UTF8/depth/member/work/extent/overflow and
8191/8192/8193 plus page boundaries. Assert whole actual hash despite forged
claim; wrong actual extent/architecture/fd, moved/closed owners, retained copied
values, repeat close and fresh recovery. Truncate/replace and actually write
same-size originals AFTER copy BEFORE parse; retain complete pre/postimages and
independent repeat results. Inject copy/hash/seal, metadata read/short/EOF/
lookahead and parser failures without changing production interfaces.

Trace actual PID/name joins including split/resumed/unreturned calls. Verify
original close before sealed parsing, same sealed fd through two full hashes and
bounded metadata/lookahead reads, no label reopen, no mappings and exact cleanup.
Preserve literal opaque records without inferred effects. Separate dependency
inspection from observed effects; no target/network/ioctl/inference or external
compiler calls. Retain all failed attempts and exact final input snapshots.

Verify, commit/publish Hailo branch, verify exact remote head/tree, fast-forward
main preserving concurrent owner work, verify both clean checkouts and continue.
Owned ordinary shard payloads/compiler bindings and actual numerical H10H
configuration/packing/placement/original-program delivery/results remain work.
All LLM execution stays on Hailo-10H; no CPU/CUDA/cloud forward or proxy, DFC,
outside compiler, external compilation machine or vendor-precompiled prerequisite.
