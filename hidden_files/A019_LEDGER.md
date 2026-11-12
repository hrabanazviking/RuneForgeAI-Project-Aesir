# A-019 Ledger — Zero-copy allocator (team-05)

Slice: A-019 (Wave 3 opener) — one allocation type serving CPU and
GPU behind the existing checked-span discipline, built on A-008's
findings. Machine: purpleraider (ASUS ROG Flow Z13, AMD Ryzen AI
Max / Strix Halo, Radeon 8060S gfx1151). Base: seat main da2cf9d8
(A-017, 17 of 216 banked, ls-remote verified); A-014 confirmed
banked in seat main by subject (11594f9a) before the branch reset.

## Acceptance verdict: PASS with real device execution

A buffer written by the CPU is read by GPU kernels with NO copy
call anywhere in the path, proven by instrumentation counters read
back from the shims (below) — on BOTH backends, and in the
GPU-write -> CPU-read direction on the HIP backend.

## Design (per the A-008 zero-copy rule, banked ledger)

- Unified type: core/zero_copy.mojo `ZeroCopy` gateway +
  `ZeroCopyBuffer` (backend tag + byte size + backend handle).
  Every range is admitted through core/checked_span
  (`checked_f32_span`) before any pointer arithmetic or launch.
- DEFAULT backend = HIP managed memory (A-008 rule 1): new
  aesir_engine/zero_copy_shim.c (libaesir_zc.so) wraps
  hipMallocManaged via the A-011 dlopen pattern, plus two HIPRTC
  kernels compiled for gfx1151 at runtime (transform:
  out = in*2+1; fill: out = ((i*37+11)%997)*0.5-100), launched
  with hipModuleLaunchKernel on the managed pointers directly.
  Reuses A-011's HipMemory for leak accounting (hipMemGetInfo).
- Vulkan backend = HOST_CACHED host-coherent ONLY (A-008 rule 4):
  vulkan_buffer_shim.c gains buffer_alloc_impl +
  aesir_vk_buffer_alloc_cached on the SAME A-013/A-014 context
  (no duplicated context); the finder requires HOST_VISIBLE |
  HOST_COHERENT | HOST_CACHED and refuses DEVICE_UNCACHED_AMD
  (0x40 — the 0.11 GB/s CPU-read trap). Dispatch reuses the
  A-015 vec_add kernel (VulkanBuffers.vec_add) unchanged.
  VulkanBuffers gains allocate_cached / buffer_type_flags /
  copy_call_count. NPU BOs are NOT part of this slice (A-016).
- Instrumentation: the HIP zc shim counts allocs / frees / live
  bytes / kernel launches / memcpy calls. It never resolves
  hipMemcpy — the memcpy counter has no code path that can move
  it, so a zero reading after 16+ launches is structural proof.
  The Vulkan shim resolves no copy entry point at all (no
  vkCmdCopyBuffer dlsym exists in the file); its copy counter is
  likewise structural. Both counters are read back by the probe
  and asserted by the E-MASTER cases.

## Counter + oracle evidence (read from logs, never memory)

C probe (hidden_files/a019_probe.c, direct shim ABI;
hidden_files/a019_probe.log sha256 c6ef0e7af3267dd879cf6fe928ed2
bb4f1c522711682ca5c2e74fc9ce6198486, RESULT PASS, PROBE_EXIT=0):
- VK_DEVICE: AMD Radeon 8060S Graphics (RADV STRIX_HALO),
  vendor 0x1002, type 1 (integrated GPU) — llvmpipe refused by
  the identity assertions in the Mojo cases as well.
- HIP_TRANSFORM + HIP_FILL byte-exact (bad=0) at n = 1 / 7 / 255 /
  256 / 257 / 1000 / 4097 / 65537 (incl. non-multiples of the
  256-wide block), both directions.
- HIP_COUNTERS launches=16 memcpy_calls=0 live_bytes=0.
- VK_CACHED_TYPE index=5 flags=0xe — exactly the A-008
  HOST_CACHED coherent flavour; VK_VEC_ADD byte-exact at
  n = 1 / 7 / 257 / 1000 / 65537; VK_COUNTERS copy_calls=0.

E-MASTER cases (all [CASE PASS] in hidden_files/a019_run_all.log):
gpu.zero_copy_hip_cpu_write_gpu_read,
gpu.zero_copy_hip_gpu_write_cpu_read,
gpu.zero_copy_vulkan_cpu_write_gpu_read (asserts the cached
type flags live on every allocation), gpu.zero_copy_rejection
(zero size both backends, unknown backend, OOB checked span,
OOB launch, cross-backend transform), gpu.zero_copy_no_leak
(200 HIP transform rounds + 50 Vulkan rounds; HIP free bytes,
Vulkan live accounting, and shim alloc/free counters all return
to baseline exactly; copy counters stay 0 throughout).

## Bug found and FIXED in-slice

hiprtcDestroyProgram corrupts the heap on this ROCm 10.0
userland: the first probe build segfaulted inside
amd_comgr_destroy_data_set -> malloc_printerr when the shim
destroyed its HIPRTC program after hiprtcGetCode (gdb backtrace
captured during the session). Fix: the shim never destroys the
program — it is retained for the process lifetime, like the
shim's library handles; the A-008 probe did the same. Noted in
the shim source at the call site.

## Suite (canonical command, hidden_files/run_a019.sh)

hidden_files/a019_run_all.log sha256 c6080dea48a7b900571909d1b
275b2f7892b6d5f7c9ec77925dfd996c4461371:
321 passed / 1 failed / 2 skipped / 324 total. Baseline at
da2cf9d8 (seat gate A-017): 316 / 1 / 2 / 319 — the delta is
exactly the 5 new A-019 cases, all PASS, zero regressions.
Sole failure = gguf.tensor_directory_interface, the pre-existing
J-022 drift (roads A-165 / A-121), unchanged. Skips = the same
2 pre-declared. MOJO_EXIT=1 is by suite design (any failed case
raises in ledger.finish). run_all pin re-set 319 -> 324 with a
house-style comment; canonical header command extended with the
libaesir_zc staging (the keeper's seat gate needs the same line
at banking).

## Files in this slice

- aesir_engine/zero_copy_shim.c (new): HIP managed alloc/free +
  HIPRTC transform/fill kernels + instrumentation counters.
- aesir_engine/core/zero_copy.mojo (new): ZeroCopy gateway.
- aesir_engine/vulkan_buffer_shim.c: buffer_alloc_impl refactor
  (A-014 alloc behaviour unchanged), cached-coherent finder +
  aesir_vk_buffer_alloc_cached, aesir_vk_buffer_type_flags,
  aesir_vk_copy_call_count.
- aesir_engine/core/vulkan_buffers.mojo: allocate_cached,
  buffer_type_flags, copy_call_count.
- aesir_engine/tests/test_zero_copy.mojo (new): 5 cases above.
- aesir_engine/tests/run_all.mojo: +5 registrations, pin
  319 -> 324, canonical command header gains libaesir_zc.
- hidden_files/run_a019.sh, hidden_files/a019_probe.c (tracked,
  per house precedent); run logs stay on-device (gitignored).

## Notes for neighbours / keeper

- Banking: stage libaesir_zc.so alongside the other shims and
  add -laesir_zc to the seat gate link line (run_a019.sh is the
  exact shape). scripts/launch.py does not stage libaesir_zc yet
  — same standing note as libaesir_hip/libaesir_vulkan; wire it
  in the first slice that calls ZeroCopy from the main engine
  path.
- The HIPRTC program-retention workaround should be revisited
  if the ROCm userland is upgraded; the destroy crash is a
  runtime defect, not an Aesir defect.
