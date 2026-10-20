# Same-descriptor safetensors metadata without partial mappings

Date: 2026-10-20. Task: `TASK_hailo10h_safetensors_owned_fd.md`.
Prior owner9c5103f: `HAILO10H_MOJO_MODEL_ROOT.md`.
Owner scope remains broad ordinary models with Aesir-owned Mojo translation and
Hailo-only LLM execution. This design changes no target or eligibility scope.

## Actual existing consumers and cleanup finding

The current `SafetensorsLoader` opens a path using open64, obtains full size
using lseek, mmaps the complete source, parses its header, then exposes live
mapped constants through `smidr/safetensors_constants.mojo`. Its `close()`
unmaps/closes and clears all fields but ignores syscall errors. It has no
implicit owner destructor. Inventory wrappers explicitly close success/error.
Those APIs' previous narrow tests remain evidence, not newly upgraded cleanup
or immutable-source guarantees. Static constants depend on the complete mapping;
a header-only byte buffer must never masquerade as that live mapped owner.

The existing strict source grammar is already original Aesir code. Its header
object parsing, tensor descriptor parsing and shape/coverage checks are methods
on the mapped owner, despite depending only on header bytes and full observed
file extent. Duplicating that grammar would create divergent behavior. Importing
SMIÐR owners into ARMVEGR would create the wrong domain dependency.

## Original connection to implement

Factor the existing header/descriptor/metadata/coverage logic behind a published
borrowed-byte decoder in `armvegr.safetensors`, with an owned metadata result.
The input is exactly8-byte little-endian length prefix plus declared JSON
header, and separately the observed complete regular-file size and explicit
header/tensor/rank/work/depth policies. Require exact prefix/header extent,
header>=2, full file>=8+header, positive policies and all current strict format
checks. Byte pointers have proven backing extents and owners retained across
all parser use. Return owned descriptors/full axes/metadata; no fd, mapping or
payload value escapes. A header buffer is never described as a full-file map.

The existing path/mapped loader delegates its header decoding to this shared
logic, retaining its complete mapped source and legacy static-constant contract.
Document inherited mmap concurrency/cleanup limitations without silently
claiming repair. Refactoring must preserve current format admission and all
metadata/static-constant/tagged storage behavior. Existing conversion/inference
guards remain unchanged; no CPU/CUDA/cloud model forward is run.

Add original SMIÐR fd-to-inventory loading. A fresh regular-file owner transfers
one fd exactly once. The reader consumes it on entry, validates actual regular
TYPE/SIZE via the existing gateway, then reads exactly8 prefix bytes and the
bounded header through checked short-read loops. It must not read weight
payloads, reopen any path or use mmap. Before allocating header storage, check
actual observed full extent and explicit byte/work/header policies. Recheck
actual fd size before success; same-size rewrites remain unauthenticated. Close
on every path; a close failure disarms and reports failure without retry or a
false success. Invalid/negative fd and malformed policies refuse honestly.

Keep original label/descriptive backing path as descriptive metadata. Connect
root.open_file -> transfer -> fd reader -> owned inventory -> root close in a
native inspector. All tensor names/axes/source dtype IDs/byte spans come from
actual checked headers, not filename aliases. No resource fit or architecture/
numerical execution is inferred. This is the next automatic source-loading
connection before aggregating all indexed shards.

## Required independent verification

Compare complete owned decoder output against the frozen pre-refactor inventory
binary on tiny synthetic files; verify exact prefix/header/full-size/policy
boundaries and input-lifetime ownership. Cross-check admitted fd output against
independent JSON/format oracles and tagged storage projection. Use real source
rename/path replacement after fd admission to prove no reopen. Trace successful
and malformed reads, descriptor transfer, unchanged payloads and exact close
counts. Inject short reads, EINTR/error/EOF/changed-size/type/mask/close failures
on the new actual fd path. Check no tensor payload read, mmap or device access
in that consumer; runtime library mappings are separate from source mappings.

Regress safetensors inventory/static constants/tagged storage plus index/config/
root consumers after shared changes. Preserve all failed evidence and build/API
limits. Current unimplemented dtypes remain explicit implementation work toward
full broad support. No outside compiler, special source conversion, vendor
artifact prerequisite, guessed CCW or model inference proxy. After publication,
automatically implement exact indexed multi-shard aggregation under
`TASK_hailo10h_shard_collection.md` and continue semantic/numerical Hailo work.

## Descriptor offset and cleanup refinement, before code

Use positional pread64 for the new header owner, not current-offset read. This
ensures exact prefix/header offsets even if a transferred descriptor position
was changed before entry. Installed licensed Linux UAPI plus an isolated C
oracle confirm ARM64 pread64 syscall67, off_t8 and int4; facts at
`evidence/safetensors-fd-facts-2026-10-20/`. No external parser is involved.
New positional wrapper initially admits the verified ARM64 ABI only; other-host
coverage remains work. Native libc close through the syscall gateway handles a
consumed descriptor independently of any caller-supplied architecture string;
reject invalid fd integers rather than truncating them to another live fd.
This permits cleanup even when host detection/policy admission fails. No unsafe
wrong-architecture close syscall or retry after Linux close failure is allowed.

The new metadata owner obtains actual host architecture, statx type/size and
prefix/header through that same fd; no descriptive path is reopened. Copy the
pre-refactor inventory binary before shared decoder edits and retain its hash
for complete output comparisons. Positional I/O does not change immutable-
identity limits or turn header-only metadata into a full-file tensor map.
