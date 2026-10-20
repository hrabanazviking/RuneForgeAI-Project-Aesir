# Owned beneath-root regular-file admission

Date: 2026-10-20. Design published before implementation at36653d8:
`HAILO10H_MODEL_ROOT_ADMISSION_DESIGN.md`; controlling task
`TASK_hailo10h_model_root_admission.md`. Broad ordinary-model scope unchanged.

## Original connected ownership

`smidr/source_root.mojo` implements move-only root-directory and regular-file
owners. The native inspector performs actual read-only/nonblocking/CLOEXEC
openat directory admission, openat2 BENEATH|NO_MAGICLINKS relative-label
resolution and statx TYPE/SIZE on the same admitted file descriptor. There is
no path-reopen fallback. The root is the opened directory object, including
after rename; descriptive source paths retain original spelling, not canonical
identity. Relative contained symlinks/nested paths work. Escaping/absolute/
magic-link paths, NUL/empty labels and nonregular files refuse.

Positive `SourceRootPolicy(path_bytes,files,work,source_bytes)` is explicit,
path_bytes at most4095. Root path and each label are independently bounded.
Work charges root UTF-8 byte length plus bytes+1 for each valid relative-label
attempt; files counts those attempts including failed kernel opens/statx checks.
Malformed labels and exhausted policies refuse before kernel effects. Accounting
and policy fields are revalidated before subtraction/increment. Empty regular
files are representable within a positive source extent bound. These are local
admission policies, not permanent model eligibility rules or hardware fit.

Explicit close disarms first, is idempotent and reports errors without retrying
Linux close. Destructors supply cleanup on return/unwind and report close errors;
callers should use explicit close when success depends on cleanup. `take_fd`
transfers responsibility exactly once and leaves the file owner disarmed.
File handles can outlive their root; a consumer must close the transferred fd
on every success/error path. Owner fd/architecture fields must not be externally
closed or mutated. The next safetensors child must consume that same descriptor.

New syscall helpers use the C-verified ARM64 UAPI only; other hosts/kernel
interfaces remain implementation work. No directory-mode number was inferred
from the generic header. Exact24-byte open_how output agrees with the isolated
C oracle. No tensor content is read by admission. Observed statx sizes do not
protect concurrent same-size rewrites, authenticate sources or certify stable
future mmap data. Logical work is not an I/O deadline. Kernel-unavailable
openat2 and absolute symlinks (even if their target is within the root) currently
refuse; there is no unsafe fallback or change to the broad model target.

## Verification

Five methods pass77 native calls (16 accept,61 expected refusals), including
real nested/Unicode paths, contained symlinks, root symlink selection, internal
parent components, escape/absolute/magic/special/missing paths and NUL guards.
Exact path/work/source-size/attempt bounds, sparse oversize, empty files and
mutated accounting/policy refusals pass. Direct ABI bytes match C; unknown and
currently unimplemented host names refuse.

Explicit/idempotent close, implicit return/unwind, closed-root refusal, one-time
fd transfer with root closed first and40 missing-then-valid cycles pass with
matching traced descriptor closes. A real fixture directory rename after root
open still permits admitted-file access through its original descriptor. Nine
isolated syscall fault cases cover root/open/ENOSYS/statx/mask/type/file-close/
root-close and post-transfer statx failure. The transfer probe closes the raw fd
on error. Faults operate on real synthetic files; close-failure injection closes
the actual fd first. No source contents change and no device/ioctl/model read
occurs. The isolated C shim is never a production link/runtime dependency.

Four index/config consumers were rebuilt against the changed syscall source.
Their16 methods/706 calls pass. Full slice: **21 methods/783 native calls**.
Final new/consumer builds are warning-free. Initial explicit-copy/StringSpan
compile failures remain in evidence; the successful preliminary76-call run is
also retained before adding the post-transfer failure case. No numerical model,
CPU/CUDA/cloud forward, outside compiler or device operation was performed.
Evidence/commands: `evidence/model-root-2026-10-20/`.

Prior config2e57b8a hosted runs39461175232/39461131756 fail historical master
compilation; later gates skip. This slice's CI is observed after publication;
no complete repository or hardware-model pass is claimed.

## Required next connection

Actual safetensors parsing/index matching is not certified by descriptor
admission. Continue `TASK_hailo10h_safetensors_owned_fd.md`, then complete
`TASK_hailo10h_shard_collection.md`, exact architecture/storage migration and
numerical Hailo encoding/configuration/precision/packing/placement/upload/
results/cleanup. Broad model support remains the full target.
