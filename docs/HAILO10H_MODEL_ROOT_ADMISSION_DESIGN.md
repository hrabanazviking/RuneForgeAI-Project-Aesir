# Model-root descriptor ownership design and public ABI facts

Date: 2026-10-20. Published-first task:
`TASK_hailo10h_model_root_admission.md`, parent checked shard collection.

The installed Linux openat2/statx/fcntl/syscall UAPI license identifiers are
GPL-2.0 WITH Linux-syscall-note, read before interface facts. Only public types,
constants and kernel-call semantics inform original code; no external algorithm
or parser is copied/translated. The isolated original C sizeof/offsetof/constant
oracle is never a production link/runtime. Header hashes and executable output:
`evidence/model-root-facts-2026-10-20/`. The earlier statx receipt supplies the
regular-fd size layout. No outside model compiler or tensor model is involved.

On this ARM64 Pi, native C confirms open_how24 bytes/alignment8, flags/mode/
resolve offsets0/8/16, openat2 syscall437, CLOEXEC524288, NONBLOCK2048 and
BENEATH|NO_MAGICLINKS10. Exact regular-file how bytes are
`000808000000000000000000000000000a00000000000000`.
Architecture-specific O_DIRECTORY is16384 on ARM64; the installed generic
header's65536 must not be used blindly on this Pi. Current new ownership API
will admit the physically verified ARM64 host; other-host support remains
implementation work. There is no cross-host or kernel-call success claim from
this layout-only oracle.

## Complete next implementation boundary

Add original `smidr/source_root.mojo`, consuming documented syscall wrappers.
`SourceRootPolicy(path_bytes,files,work,source_bytes)` supplies positive caller
bounds, path_bytes at most4095. Work units charge root-path bytes and each valid
relative-label admission attempt's bytes+1; files counts those attempts,
including failed kernel admission. Invalid labels and exhausted policies refuse
before effects. Logical work is not a deadline. Empty regular files may be
admitted; the later safetensors parser must still enforce its minimum header.

`SourceModelRoot` is move-only and owns one directory descriptor; opening the
root uses readonly/nonblocking/CLOEXEC/O_DIRECTORY. Root is the actual opened
directory object, even after rename or path changes. Caller-selected root
symlinks may resolve to that directory. Labels preserve original spelling;
relative nested paths and contained symlinks resolve through openat2 BENEATH|
NO_MAGICLINKS on the same dirfd. Absolute/empty/NUL labels refuse. Kernel errors
(including unavailable openat2) refuse with no pathname fallback. Regular type
and bounded signed-host size are checked on that very file descriptor.

`SourceRegularFile` is move-only and retains original label/descriptive path/
observed size and fd. Explicit close is idempotent, disarms before close and
reports failure; destructor is a last cleanup path and does not retry Linux
close. `take_fd` transfers responsibility once and disarms the owner; the
next parser child must consume/close that same transferred fd, not reopen a
path. Shard files can outlive the root descriptor. No immutable identity or
same-size rewrite protection follows from descriptive paths/statx sizes.

Publish an inspector and direct native owner probe that perform real admission,
ownership transfer and cleanup over tiny synthetic regular files. Verify C bytes,
real nested/contained/escape/magic/absolute/special paths, exact policies, rename
stability, file-outlives-root, repeated/exception/error/implicit cleanup and
injected pre-effect failures. No model/layer/attention math or device access.
Same-fd safetensors integration and exact collection/index matching are the next
required child, never claimed by the descriptor-only acceptance. Preserve the
full broad-model target and numerical backend work in the parent roadmap.
