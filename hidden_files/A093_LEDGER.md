# A-093 Ledger - NPU memory sharing (team-23)

- Date: 2026-11-13 (EST, purpleraider local)
- Machine: purpleraider - ASUS ROG Flow Z13, Strix Halo, XDNA 2 NPU + Radeon 8060S gfx1151, XRT 2.25.00
- Worktree: /home/volmarr/aesir-team-23, branch yrsa/aesir-team-23, base d67e0773 (banked main, 88 of 216)
- Verdict: PASS - dma-buf sharing byte-exact. An NPU BO (type 2) exported via xrtBOExport was consumed by the CPU through an mmap of the dma-buf fd, byte-exact in BOTH directions, and re-imported via xrtBOImport byte-exact. No zero-copy claim beyond what was proven: the fd mmap path is the standard dma-buf sharing mechanism and reads/writes landed in the same underlying buffer (write via fd visible in the BO map after sync, and vice versa).

## Acceptance mapping
- Buffer produced by one device consumed by another, byte-exact: XRT NPU BO (64 KiB, pattern pat(i,seed)) -> xrtBOExport -> dma-buf fd -> CPU mmap: forward read 0 mismatches (seed 7); CPU wrote inverted pattern (seed 99) through the fd mapping, msync, xrtBOSync FROM_DEVICE -> BO map read 0 mismatches. Reverse consumption proven, not just read.
- Second consumer: xrtBOImport of the same fd into a second device handle -> sync FROM -> map: 0 mismatches (IMPORT_BYTE_EXACT).
- Copy cost filed (S8, median of 5, type-2 BOs): 64 KiB xrtBORead 70,861 MB/s vs map memcpy 73,443 MB/s; 1 MiB 73,502 vs 73,719 MB/s; 16 MiB 30,808 vs 33,712 MB/s. On the unified pool the API read and a plain memcpy cost the same within noise - there is no measurable device-crossing copy penalty, and the BO map itself is direct CPU access (no copy at all).

## Evidence (logs in hidden_files/)
- a093_run1.log: first run, main BO type 1: xrtBOExport FAILED - [XRT] ERROR DRM_IOCTL_PRIME_HANDLE_TO_FD err=-95 EOPNOTSUPP, export_fd=-1. Filed honestly: type-1 BOs cannot be exported on amdxdna.
- a093_run2.log: patched probe (type-2 main BO + type-1 export attempt kept as S1): S1 type1_export_fd=-1 (same EOPNOTSUPP), S2 export_fd=4, fd_read mismatches=0, fd_write->syncFROM(0)->bomap mismatches=0, S2b IMPORT_BYTE_EXACT, S2 RESULT DMABUF_BYTE_EXACT fwd=1 rev=1, S2 FINAL PASS, exit 0.
- Probe: aesir_engine/npu_share_probe.c (final sha256 c38d9c86edfe5777e7143ccec920bc2c2d191d84ffe0e90c26c73277ec1cf08b), built gcc -O2 against libxrt_coreutil.so.2, run via sudo -n (A-007 memlock caveat; limit never changed).
- Authoring note: source was assembled on-device from five 1000 B parts (hidden_files/a093/parts/q_*), each file.write sha256-verified; whole-file sha256 verified before compiling - the third-lead fix for the first lead whole-file transfer failure.

## Not claimed / next work
- Vulkan (RADV gfx1151) import of the XRT dma-buf and HIP external-memory import were NOT run in this slice; the CPU-fd and XRT-import consumers are proven, GPU-kernel consumption of an NPU BO is the open road for a later slice (candidate: VK_EXT_external_memory_dma_buf import + vec_add dispatch).
- Type-1 BO export is a driver-level EOPNOTSUPP, not an Aesir defect; re-open if amdxdna gains PRIME_HANDLE_TO_FD for type-1.

## Suite (E-MASTER, solo, this worktree)
- hidden_files/a093_run_all.log via hidden_files/run_a093.sh: see CAMPAIGN_STATE outcome for counts read from the log.
