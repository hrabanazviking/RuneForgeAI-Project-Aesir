# Owned model-root and beneath-root regular shard descriptors

Date: 2026-10-20. Parent: `TASK_hailo10h_shard_collection.md`.
Fixed scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

Audit existing public syscall gateway and safetensors file ownership first.
Current safetensors open uses open64/lseek/mmap; it cannot consume an already
admitted descriptor. Current source_metadata_file owns exact JSON reads, not a
model directory or shard handle. Avoid a separate preflight check followed by
path reopen. Add a complete original Mojo owned model-root directory and an
explicitly transferred regular-file descriptor, consumed by the parser in the
following child slice after its ownership API is verified.

Use installed Linux public UAPI facts/license first. Investigate openat2 with
RESOLVE_BENEATH and RESOLVE_NO_MAGICLINKS, regular-fd TYPE/SIZE checks, readonly/
nonblocking/close-on-exec and owned directory lifetime. Preserve descriptive
original label separately from the admitted descriptor. Positive path/work/file
count policies are explicit caller values. Unknown architecture/kernel interface
or unsupported path currently refuses honestly, with no unsafe fallback. This
is current loader admission behavior, never a permanent model eligibility rule.
Nested relative labels and contained symlinks should remain possible; escape
and absolute labels refuse. Existing index metadata can still represent labels
which are not admissible paths, including NUL; admission must not mutate them.

Publish checked native ABI buffers and resource ownership design before code.
Verify exact C header constants/layout, tiny real directory/files/nested paths,
contained and escape symlinks, absolute/empty/NUL labels, special files, boundary
policies, descriptor transfer, success/error/repeated cleanup and unchanged
sources. Use injected pre-effect faults where needed. This gate must perform
real file admission; a host structure alone is insufficient. No tensor/model
math, external compiler/runtime, device write/reset/firmware/kernel change.
After publication, connect that same admitted fd to the existing safetensors
parser and automatic checked multi-shard collection under the parent contract.
