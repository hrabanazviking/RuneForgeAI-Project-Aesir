# Owned sealed source-byte copy qualification

Date: 2026-10-22. Next native contract:
`TASK_hailo10h_sealed_source_copy.md`. Existing byte digests are verified in
`HAILO10H_MOJO_SOURCE_BYTE_DIGEST.md`; they identify an observed stream and do
not supply immutable compiler input.

## License-first public-interface qualification

Installed Linux UAPI headers declare `GPL-2.0 WITH Linux-syscall-note` at their
first lines. The [kernel licensing documentation](https://www.kernel.org/doc/html/latest/process/license-rules.html)
explains that userspace syscall interfaces have an explicit exception. Only
public interface constants are used; no kernel or external implementation body
is copied. The [memfd manual](https://man7.org/linux/man-pages/man2/memfd_create.2.html)
documents anonymous regular-file storage, optional sealing and descriptor
lifetime. Its example programs are not adopted.

An original isolated C oracle compiled against this Pi's installed headers
qualifies ARM64 `memfd_create=279`, `fcntl=25`, create flags1/2, seal controls
1033/1034 and required mask15. Package: linux-libc-dev1:6.12.109-1+rpt1;
running kernel:6.12.112-v8-16k-hailo+. Header hashes and raw attempts are preserved
in `evidence/sealed-source-copy-contract-2026-10-22/`.

Three anonymous host files of0,17 and8193 bytes preserve all8210 independently
checked bytes. Same-fd statx identifies regular files with exact extents.
Close-on-exec and all required seals are checked on actual fds. Writes, growth,
shrinkage and writable shared mappings refuse after sealing. Existing writable
shared mappings prevent sealing until unmapped. Read-only access continues;
all three descriptors close. The initial C indentation warning and an audit
correction for strace's `(deleted)` memfd decoration remain preserved. No new
Mojo implementation, device access or source-model execution is claimed.

## Next original implementation

The contract specifies a bounded owned host copy using existing positional I/O,
then kernel sealing and hashing of the actual sealed destination. It preserves
the borrowed original descriptor, all existing production modules/APIs and all
fingerprint flags. Baseline653 sources/actual snapshots,104 current controls and
67 Python inputs/actual snapshots are frozen before production.

A sealed copy stays immutable after its gates pass. Concurrent original writes
can still yield a mixed observed copy; this does not establish an atomic original
file version. Parsing and compilation must eventually consume the same sealed
bytes to establish coherent source/artifact binding. That integration remains a
separate required slice. No host storage policy becomes a permanent format,
architecture or model eligibility restriction.

Physical numerical lowering/configuration/precision/packing/placement and valid
original program delivery/activation/results/cleanup remain open. The owner's
broad ordinary unmodified model target and Hailo-only execution remain unchanged.
