# Owned safetensors headers from the admitted descriptor

Date: 2026-10-20. Design published first at4b40f0f, positional ABI refinement at
fe23493: `HAILO10H_SAFETENSORS_OWNED_FD_DESIGN.md`. Fixed broad-model scope is
unchanged; every LLM execution remains Hailo-10H-only.

## Connected original implementation

The existing original header object/metadata/tensor/coverage methods are factored
into a resource-free borrowed header decoder in `armvegr.safetensors`. The three
metadata/descriptor/coverage method implementations match pre-refactor source; one extent comment now
refers to the shared admission check. Public prefix-length and exact-prefix+header byte APIs validate extent/
policies and return owned descriptors/full axes/metadata. Byte owners remain
alive through all raw pointer uses. Returned copies have no fd or tensor map.
The legacy mapped loader delegates to that same decoder, preserving complete
mappings and static-constant behavior. Its inherited ignored munmap/close return
values and mmap concurrency limits are documented, not silently certified fixed.

`smidr/safetensors_fd.mojo` consumes exclusive fd ownership on entry, including
invalid policy/host/format/read failure. The caller transfers once from the
verified root/file owner. Actual statx TYPE/SIZE checks apply to that very fd.
ARM64 positional reads copy exactly8 prefix bytes and the declared bounded JSON
header, with checked short reads, read-byte cap before allocation and full size
recheck. Current file position is irrelevant. No tensor payload, mmap, path
reopen, model evaluation or device access occurs. The inventory is copied and
native close must succeed before return. Close errors disarm and refuse without
retry; error paths attempt cleanup and do not report a successful result.

Positive header/tensor/rank/work/depth/read-byte policies are explicit; depth
at most64 applies to existing recursively skipped values. Known schema parsing
retains prior behavior. Read_bytes includes prefix, while work is the existing
4*tensor_count squared guard; header/rank/depth bound other metadata separately.
These are not total instruction accounting, resource fit or deadlines. Native
fd integers are checked before libc close so an oversized integer cannot truncate
to an unrelated live fd. Positional syscall ABI is currently verified ARM64;
other-host coverage remains implementation work. Pure decoder file size is
caller-supplied descriptive metadata; fd reader obtains/rechecks it on disk.
Same-size concurrent rewrites remain unauthenticated. Caller retains label/path
separately for binding; descriptor inventories do not invent canonical paths.

Shared projection and inspector formatting are reused. Projection of a validated
header is a copy operation; mutating a header does not preserve its earlier
validation. Native root-to-fd-to-inventory inspector performs real file loading
and closes root before output. No external runtime/compiler was introduced.

## Independent verification

Five new methods pass365 native calls (226 accept,139 expected refusals).
Fifty seeded plus four explicit collections compare complete output across the
frozen pre-refactor inventory binary, rebuilt path reader, new fd reader and
borrowed decoder with input/header mutation. Independent expected names/dtypes/
full axes/scalar/empty/elements/bytes/offsets agree. Prefix/header/full-file
extents, every header-buffer truncation, extra bytes, malformed UTF-8/metadata/
descriptors, wrong policies, exact guards and invalid fd integer refusal pass.

Traces prove header-only reads across8192-byte chunks and a sparse20 MB payload,
no source map/device access, exact closes and unchanged sources. Setting the
original fd offset to EOF still reads the correct prefix. Replacing the source
pathname after admission still yields the original open file's tensor metadata.
Forty malformed-then-valid cycles match descriptor closes. Thirteen isolated
fault modes include real short reads, read/EINTR/EOF/header-body failures,
invalid count, statx/type/mask/changed-size/advertised-size and consumed-close
errors; only the genuine short-read case succeeds. Close-failure injection
closes the real fd first, then reports error. The shim is test-only.

Six rebuilt consumer suites add48 methods/1551 native calls: inventory11/219,
constants9/97 with264204 word checks, tagged storage7/452, index10/516,
config6/190 and root5/77. Full slice: **53 methods/1916 native calls**.
Final new/consumer builds are warning-free except the pre-existing legacy
header probe's unused conversion initializer warning; no conversion mode ran.
Initial partial-field-move compiler failures are preserved. Explicit owned
copies keep aggregate destruction valid on the installed Mojo toolchain.
Evidence/commands: `evidence/safetensors-fd-2026-10-20/`.

Prior root9c5103f hosted runs39462666118/39462615893 fail historical master
compilation; later gates skip. This published slice's CI is observed separately.
No complete repository or source-model execution pass is claimed.

## Next automatic connection

Implement `HAILO10H_INDEXED_SHARD_COLLECTION_DESIGN.md` under
`TASK_hailo10h_shard_collection.md`: same-root JSON fds, actual distinct shard
loads, exact original index/name/label matching, tagged source spans, aggregate
bounds/totals and separate per-shard metadata. Complete config/architecture/
semantic storage integration and actual numerical Hailo instruction/precision/
packing/placement/upload/result/cleanup remain required toward broad support.
