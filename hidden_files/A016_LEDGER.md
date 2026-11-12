# A-016 Ledger — XRT buffer objects (team-02)

- Date: 2026-11-12 (EST, purpleraider local)
- Machine: purpleraider — ASUS ROG Flow Z13, AMD RYZEN AI MAX+ 395, XDNA 2 NPU [0000:c5:00.1] aie2p, firmware 1.1.2.65
- Worktree: /home/volmarr/aesir-team-02, branch yrsa/aesir-team-02, base 11594f9a (A-014 banked; A-011 tip 83c9fdf9 verified banked by subject in main, ab0e51b7)
- VERDICT: ACCEPTANCE PASS — byte-exact BO round trip through the XRT device API on the real NPU device handle, via sudo. NO NPU kernel execution is claimed: no xclbin exists on this machine, so no AIE kernel ran. What ran: xrtDeviceOpen on the amdxdna device, BO alloc/map/sync/write/read — the device-API / host-side BO path, exactly the evidence class the slice brief names as real.

## Environment facts (hidden_files/a016/probe_env.log, probe2.log)
- XRT 2.25.0 distro packages only (libxrt2, libxrt-npu2, libxrt-utils, libxrt-utils-npu 1:2.25.0-4ubuntu1). NO headers (no libxrt-dev), NO .xclbin anywhere on the filesystem, NO Vitis/mlir-aie toolchain. /dev/accel/accel0 present (root:render, user ACL rw).
- sudo -n works. sudo xrt-smi examine: XRT 2.25.00, amdxdna 7.3.0-10-generic, [0000:c5:00.1] NPU Strix Halo aie2p 6x8.
- Unprivileged device open FAILS exactly as A-007 recorded: mmap len=67108864 EAGAIN, RLIMIT_MEMLOCK 8192 kB. No limits were raised; no driver/kernel changes made. All device runs below are via sudo -n.

## Road taken
- libxilinxopencl.so.2 does NOT export the legacy xcl* HAL2 BO symbols on this NPU stack (nm evidence: symbols.log). libxrt_coreutil.so.2 DOES export the native XRT C BO API: xrtDeviceOpen, xrtBOAlloc, xrtBOMap, xrtBOSync, xrtBOWrite, xrtBORead, xrtBOFree, xrtBOSize (symbols.log).
- Probe: aesir_engine/xrt_bo_probe.c — stable xrt.h C ABI declared locally (no headers installed), linked directly against the versioned /usr/lib/x86_64-linux-gnu/libxrt_coreutil.so.2. sha256 e1742e1c4b8f97cffe5e83c8f0f03ad7b8761e737f254fa730ec75e3347ee35e.
- Key discovery: xrtBOAlloc with flags=0 fails on the xdna shim: "unsupported buffer type: none flag (err=95)" (run1.log, sweep.log — low-bit flags 0..256 and groups 0..3 all fail identically). The BO type is encoded in bits 24+ of the flags argument: type 1 (1<<24) and type 2 (2<<24) allocate; types 3..6 do not.
- An early probe iteration reported map mismatches after a destructive memset between syncs (run2.log): sync on these host BOs does not resurrect deliberately zeroed host memory — filed as a probe-method artifact, not a device defect. The final probe cross-verifies without destroying data between syncs.

## Acceptance evidence (hidden_files/a016/run_final.log, via hidden_files/run_a016.sh)
4096-byte BO, pattern b[i]=(i*131+7)&0xff, three cross-verified paths, all rc=0, all 0 mismatches, for BOTH BO type 1 and type 2, and type 1 repeated:
- A) map-write -> xrtBOSync(TO_DEVICE) -> xrtBORead == pattern
- B) xrtBOWrite(inverted pattern) -> xrtBOSync(FROM_DEVICE) -> map-read == pattern
- C) xrtBOWrite -> xrtBORead == pattern
- RESULT BYTE_EXACT_ROUND_TRIP, probe exit 0. Standalone runner reproduces it end-to-end (compile + sudo run).
Log sha256: run_final.log ce1ceb0309626d2401c3d9630948244636262efd51ffb0c226a37e8f9e42c553; run1.log f6d322f0fa2058f709964ee0094ab48b9734a21c3902e59809e62dab6a200eca; sweep.log db31ab5c43f35a876ce42b6564a676ea612afea555e8a966b44cd581aa1be137; symbols.log 1ab1ad66b7d44312217ed2c969ea239e832cdd841d5f69c28232f5258c0ba978; probe_env.log bd3f81dc3ab1baec344a52bd42c01288603600e48bf737d21349235008a4e9f4; probe2.log a2ad92875d13c8ff0d05dc3957149523f40480e746a9913648ca8a0b32b28ba6; run2.log 2eb592de30b9d9a3b36e9386aacefa7e4fa80440a474453564f788fcf69b52f3.

## What this does NOT prove / NPU plan adjustment
- No AIE kernel execution: a kernel-context BO (xrt::bo with a kernel group id) requires an xclbin; none exists on this machine and none can be built with installed tools (no Vitis, no mlir-aie/IRON, no XRT headers). This is the named boundary of this slice, evidenced above — not a silent skip of the round trip, which passed on the host-side BO path.
- Relation to A-092 (NPU hello-compute): A-007 already filed that xrt-smi validate needs the VTD test archive amdxdna/bins/xrt_smi_strx.a (smi_install_archive.sh xrt_smi_strx.a 2.25.00, github.com/Xilinx/VTD). That archive is the first step of A-092 and is also the most likely source of the first usable xclbin / hardware context on this machine. NPU plan adjusted accordingly: A-092 should (1) fetch the VTD archive, (2) load its xclbin via xrtDeviceLoadXclbin-family calls, (3) only then attempt kernel-group BOs + a real kernel run. A-016's flags-type encoding (bits 24+) and sudo requirement carry forward to every later NPU slice.
- Builds on A-009's backend_registry (banked), which reports XRT present via sysfs — this slice adds live device-API proof beneath that registry entry; nothing duplicated.

## Suite integration (honest)
- The probe requires sudo, so it is NOT wired into run_all.mojo: a sudo case must not silently enter the E-MASTER gate. Standalone runner: hidden_files/run_a016.sh. Suite stays at the banked baseline; counts from hidden_files/a016_run_all_canonical.log are recorded in CAMPAIGN_STATE.md.
- Bugs found: none in repo code. The xcl* absence and the flags-type encoding are XRT-stack facts, documented above.
