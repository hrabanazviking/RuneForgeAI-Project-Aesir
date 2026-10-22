# Parse and read GGUF from an owned sealed descriptor

Date: 2026-10-22. Publish before production. Parent:
`TASK_hailo10h_source_compiler_plan.md`. Owner scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Owned observed source copies are verified at `a035435`; they are not yet consumed
by the source parser. The next slice connects the existing parser and constant/
byte readers to those exact immutable bytes. No model inference is authorized.

## Existing code audit and allowed shared changes

`GGUFSeer` currently opens a path, owns its fd/mmap and parses bounded bytes.
Its `_require_range` and cleanup use public mutable `file_size`; there is no
separate recorded mapping capacity. `PackedGGUF` opens/maps, parses the header
and then interprets metadata/tensor tables in its constructor. Reuse these
original parsers; do not add a parallel GGUF parser or copy an external loader.

Allowed existing production changes are limited to:

- `aesir_engine/loader/gguf.mojo`: independent recorded mapping extent; owned
  sealed-fd admission/mapping; bounds and cleanup using actual recorded capacity.
- `aesir_engine/loader/packed_gguf.mojo`: factor the existing metadata/tensor
  table body into one shared method and add an owned sealed-fd constructor.
- `hailbru/source_sealed_copy.mojo`: checked exclusive fd transfer.

Add new adapter/tool/test leaves. Keep every other production module and every
old consumer output unchanged. Preserve current geometry/width/rank/metadata
admissions and diagnostics; remaining formats/architectures/ranks are further
implementation work, never permanent model eligibility restrictions. No new
semantic, device format, resource-fit or execution claim follows from this work.

## Exclusive transfer and actual mapping capacity

Add `SealedSourceBytes.take_fd(mut self) raises -> Int64`. Check the live actual
fd, required same-fd seals and exact owner extent using the existing sealed-owner
guard. On success invalidate the old owner's fd before returning it. On failure
retain ownership for ordinary cleanup. Repeated transfer and later sealed reads
through the released owner refuse. Do not trust a writable digest string as an
identity gate. Existing close/destructor behavior and old CLI outputs stay intact.

Add a recorded mapping-extent field to `GGUFSeer`, initialized to zero and set
only when mapping succeeds. Capture it for both the old path and new fd route.
`_require_range` must never admit bytes beyond either declared file size or actual
recorded capacity. Preserve subtractive overflow-safe checks and existing errors.
Cleanup must unmap exactly the recorded extent even if public `file_size` was
mutated; clear capacity/pointer/mapped state afterward and close an owned fd once.
Do not use this record as proof against arbitrary caller memory/state corruption.

Add `_adopt_owned_sealed_fd(mut self,owned_fd:Int64,expected_size:Int64) raises`
for a fresh unmapped seer. It consumes exclusive descriptor ownership, including
validation and later parse failures. Validate the exact Linux fd range before
Int32 storage, actual required seals, regular-file type and exact extent. Refuse
invalid/closed/unsealed/wrong-size inputs before mmap. Refuse already-owned state;
never close that instance's existing live descriptor when an invalid caller
passes an alias of it. Valid distinct incoming ownership must be cleaned on
refusal. Use existing HAILBRU helpers for new OS interactions.

Map the actual admitted fd read-only/shared at offset zero, record its capacity
before parsing, and retain the fd for the full mapping lifetime. Never reopen
`file_path`, `/proc/self/fd`, `/dev/fd` or a source label. No descriptor duplicate,
new syscall family, driver or firmware operation is needed. No writable mapping.
Retain the sealed admission route across close: later _open_and_map, metadata
inspection or load entrypoints must reuse the live sealed mapping or refuse a
closed sealed source; they must never fall back to opening its label. Internal
route state may be added to enforce this without changing the old path route.
Ensure cleanup after mmap/header/table failures and fresh-source recovery.

Add a `PackedGGUF(label:String,owned_sealed_fd:Int64,source_bytes:Int64)` constructor.
The label is diagnostic/source provenance, not a path to open. Initialize owned
state, admit the transferred fd, then reuse `_parse_header` and the exact shared
table interpretation body. The existing path constructor uses that same table
body after its old path admission. No duplicate table decoder or changes to
source arithmetic, aliases, metadata defaults or source shape semantics.

## Owned sealed source adapter

Add `smidr/sealed_gguf_source.mojo` with movable `SealedPackedGGUF` containing
`source:PackedGGUF`, `source_bytes:Int64`, `digest_hex:String`.

```
parse_sealed_packed_gguf(var bytes:SealedSourceBytes,label:String,
  digest_call_bound:Int)
  raises -> SealedPackedGGUF
load_sealed_packed_gguf(path:String,source_byte_bound:Int,
  read_call_bound:Int,write_call_bound:Int,digest_call_bound:Int)
  raises -> SealedPackedGGUF
```

The consuming parser factory saves the verified sealed extent, recomputes the
actual full sealed digest with an explicit bounded read policy instead of trusting
a mutable digest string, transfers the descriptor and constructs the shared
parser. The consuming parser uses its explicit positive digest_call_bound; the path
wrapper applies that limit separately to the copy hash and parser hash phases. The path wrapper opens the ordinary
source read-only, makes the bounded sealed copy with existing helpers, closes
the original, then parses the sealed bytes. No label reopen or user conversion.
All exception paths must retain or clean each actual owner exactly once.

The factory's result binds its parsed metadata and mapped source bytes to one
owned sealed file. The original may have changed during copying; atomic original
snapshot verification remains false. A scoped new tool may report
`sealed_input_bytes_bound=true` only after actual seal/digest/mapping/parser gates.
Keep existing source_fingerprint_verified, immutable-source, artifact-binding,
execution and device-access flags false. No old tool output changes. Compiled
artifact identity, graph/cache lifetime binding and hardware delivery remain work.

## Verification and publication

Before code verify656 source identities/actual snapshots,106 current native
controls and68 Python identities/actual snapshots. Evidence:
`docs/evidence/sealed-gguf-contract-2026-10-22/`. A compile-only movable-wrapper
probe succeeded; it was never executed and establishes no parser behavior.
Static local import inventory finds100 affected existing controls and6 unaffected;
recompute after implementation and cover all actual affected entrypoints. Build
stable sources before executing tests. No model/engine/master execution.

Use actual synthetic ordinary GGUF files and independent complete expected
metadata/axes/bindings/raw bytes/constants. Compare path and sealed routes across
all current geometries, metadata scalar/array/UTF-8/NUL cases, aliases, alignment,
odd/page/tensor boundaries and old refusal cases. Use existing source inventory,
constant readers, semantic bindings and generic byte tiles by borrowing the new
result's `source`; no host tensor/layer/attention forward. Preserve original
scalar words and source representation fields; do not count a digest-only
component check as full numerical representation verification.

Prove original replacement/truncation/mutation/closure after copying cannot alter
new parsed metadata or payload reads. Trace the same transferred fd into its
read-only map; no later open of the label. Check actual kernel seals throughout
admission, transfer refusal/recovery, closed/default/forged-owner bounds, mutable
file_size versus recorded capacity, exact unmap extent and no double close.
Exercise create/copy/digest/transfer/mmap/header/table failure cleanup and fresh
recovery. Restore test-only state mutations before destroying live owners unless
that mutation is the cleanup-capacity case under test.

Run established affected source/compiler primitive suites and full frozen-control
comparisons, retaining every success/refusal pair and actual old input. Record
any justified behavior change explicitly; never skip a pair to get a pass.
Keep dependency inspection separate. Preserve raw attempts, PID-aware split
traces including literal unresolved termination names, actual descriptor/map
counts and all source/binary/input identities. No target-device/network/ioctl/
inference/external compiler access. Verify, commit/publish Hailo branch, verify
remote head/tree, fast-forward main and verify both clean checkouts, then continue.

Next is coherent compiler/artifact binding across the owned source lifetime,
alongside remaining ordinary source/architecture/operation implementation and
actual H10H numerical configuration, packing, placement, original program
execution/results/cleanup. The fixed broad target remains100%.
