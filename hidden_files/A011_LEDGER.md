# A-011 — HIP memory (team-02 ledger, filed 2026-11-11)

Slice: hipMalloc/hipFree + hipMallocManaged round trips with leak
accounting. Acceptance: alloc/write/read/free tests pass; zero leaked
bytes across 1,000 iterations. OUTCOME: PASS with REAL device execution
(not honest-absent) — see HIP state below.

## HIP state on purpleraider (verified on-device this slice)

- Roadmap stand-up recorded "ROCm userland NOT installed (/opt/rocm
  absent)". Still true for /opt/rocm, rocminfo, hipcc and HIP headers —
  BUT the distro runtime packages are installed (Ubuntu packages
  libamdhip64-7 10.0-0ubuntu3, libhsa-runtime64-1, libhsakmt1,
  libamd-comgr3-rocm): /usr/lib/x86_64-linux-gnu/libamdhip64.so.7
  (7.15.0) is present and FULLY FUNCTIONAL. /dev/kfd carries an ACL
  granting user volmarr rw. A-005 (ROCm userland) remains team-05's
  slice for the full toolchain; the runtime A-011 needs already exists.
- Pre-existing probe bug found + fixed in-slice: AMDGate.get_handle()
  dlopened only the unversioned "libamdhip64.so" (a -dev-package
  symlink, absent here), so AMDGate.is_available() reported the
  runtime ABSENT while it was present. Fix: versioned soname
  libamdhip64.so.7 added to the probe (core/amd_gate.mojo). The HIP
  shim probes unversioned, then .so.7/.so.6/.so.5.
- Device evidence (C probe, dlopen/dlsym, no headers): DEVICE_COUNT 1;
  hipMemGetInfo total 65,227,026,432 bytes (unified pool share);
  1,000x (hipMalloc + H2D/D2H byte-exact round trip + hipFree) and
  1,000x (hipMallocManaged + host write + hipDeviceSynchronize +
  verify + hipFree) all pass. Log: hidden_files/a011_c_probe.log.
- Leak accounting truth: the FIRST process-touch reserves a one-time
  HIP context/pool block of 148,971,520 bytes (free 65,222,795,264 ->
  65,073,823,744) that hipMemGetInfo keeps counting as used for the
  process lifetime. After a warm-up it never grows: deltas were
  exactly 0 after 1,000 malloc iterations, 1,000 managed iterations,
  and a second combined round (C probe, two separate runs agree to
  the byte). The Mojo battery therefore warms up, baselines, and
  requires exact return to baseline: leaked = 0 bytes.

## Discovered incompatibility (recorded, worked around in-slice)

Mojo 1.0.0 cannot mix this repo's external_call["dlopen"/"dlclose"]
idiom (core/amd_gate.mojo and others) with stdlib OwnedDLHandle in one
program: the stdlib declares dlclose with a struct-wrapped pointer
signature that conflicts with the repo's raw-pointer declaration and
the module fails to lower ("existing function with conflicting
signature", std/ffi/__init__.mojo:1249). Minimal repro was built and
filed during this slice. Consequence: any future slice wanting
DLHandle-style loading inside run_all will hit the same wall.
Workaround (repo-precedented): all dynamic loading lives in C —
aesir_engine/hip_memory_shim.c, staged to libaesir_hip.so exactly like
libaesir_hailo10h/libaesir_par; core/hip_memory.mojo (HipMemory) calls
its flat aesir_hip_* ABI via external_call. The canonical E-MASTER
command in tests/run_all.mojo's header gained the third shim; the
team runner is hidden_files/run_a011.sh.

## Files in this slice

- aesir_engine/core/hip_memory.mojo (new): HipMemory — runtime_available,
  device_count, mem_info, allocate (hipMalloc), allocate_managed
  (hipMallocManaged/hipMemAttachGlobal), free (hipFree),
  device_synchronize, memcpy_host_to_device / memcpy_device_to_host
  (byte counts admitted via core/checked_span). Fail-closed when the
  runtime is absent; size<=0 rejected locally; HIP error codes raised
  verbatim.
- aesir_engine/hip_memory_shim.c (new): dlopen/dlsym loader + flat ABI;
  handle kept for process lifetime; returns HIP rc, or -1 when absent.
- aesir_engine/core/amd_gate.mojo: versioned-soname probe fix (above).
- aesir_engine/tests/test_amd_realm.mojo: +5 cases (below), each with
  an honest-absent fail-closed branch for hosts without HIP.
- aesir_engine/tests/run_all.mojo: +5 registrations, pin 280 -> 285,
  canonical command header extended with libaesir_hip staging.
- hidden_files/run_a011.sh + this ledger (tracked, per A-002/A-003
  precedent); run logs stay on-device (gitignored).

## Test evidence (counts read from logs, never memory)

- Standalone AMD/HIP runner (8 cases incl. the 3 pre-existing AMD gate
  cases): ALL PASS. hidden_files/a011_runner.log
  sha256 6e320d814ad10702e617bb03eb7c94fd396c5ed4eb6775ac9a64f2dc9fbfaf81
- E-MASTER full suite (hidden_files/run_a011.sh; log
  hidden_files/a011_run_all_canonical.log sha256
  8f0a88fd22095b986fd864ce237c36feeecdc5b072002f0d36a73b7711626a03):
  Passed 282 / Failed 1 / Skipped 2 / Total 285. Baseline (A-003) was
  277/1/2/280: the delta is exactly the 5 new A-011 cases, all PASS
  (gpu.amd_hip_malloc_free_round_trip, gpu.amd_hip_alloc_rejection,
  gpu.amd_hip_malloc_managed_round_trip,
  gpu.amd_hip_mem_get_info_accounting, gpu.amd_hip_no_leak_1000).
  Sole failure = gguf.tensor_directory_interface, the pre-existing
  J-022 drift triaged in A-003 (named roads A-165/A-121) — unchanged.
  Skips = the same 2 pre-declared (vision.cuda_session_image_chat,
  rag.real_engine_integration). MOJO_EXIT=1 is by suite design (any
  failed case raises in ledger.finish).
- C probe log: hidden_files/a011_c_probe.log sha256
  807a5e4011c30eb96c98b404224140dddcf1d087ee75e95e9214f40b70269485

## Notes for neighbours

- A-010 (team-01, in flight concurrently): HipMemory.device_count is
  available to build on; A-010's device-properties work is untouched.
- A-012 (HIP transfer + streams) builds directly on the memcpy entry
  points here. scripts/launch.py does NOT stage libaesir_hip yet —
  the app binary does not reference HipMemory; wire launch.py staging
  in the first slice that calls HIP from the main engine path.
- Push state unchanged: no GitHub auth on purpleraider; this commit
  stays local for the keeper to bank in roadmap order.

## Banking note (seat, 2026-11-12)

Banked at the seat by cherry-pick of team-02 commit 83c9fdf9. The
slice's amd_gate.mojo soname hunk was NOT taken: A-010 (banked
immediately before) had already landed the same fix in stronger form
(versioned soname probed FIRST via AMDGate._dlopen). All other slice
files banked as authored; run_all pin unioned to 297.
