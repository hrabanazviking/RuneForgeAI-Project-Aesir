# A-013 — Vulkan context wrapper (team-04 ledger, filed 2026-11-11)

Slice: instance/device/queue/command-pool FFI wrapper (libvulkan) with
the repo's error taxonomy on every failure. Acceptance: context creates
on gfx1151; forced-failure tests map to taxonomy entries, never to
crashes. OUTCOME: PASS with REAL device execution — see evidence below.

## Vulkan state on purpleraider (verified on-device this slice)

- Mesa RADV is the Vulkan driver: /usr/share/vulkan/icd.d/radeon_icd.json
  (api 1.4.354, libvulkan_radeon.so); the loader is
  /usr/lib/x86_64-linux-gnu/libvulkan.so.1 (1.4.357); vulkaninfo and
  the Vulkan headers (/usr/include/vulkan) are installed.
- Two physical devices enumerate: device 0 = AMD Radeon 8060S Graphics
  (RADV STRIX_HALO), vendor 0x1002, device_id 0x1586 (= gfx1151),
  INTEGRATED_GPU, queue family 0 flags 0xf count 1 (graphics+compute);
  device 1 = llvmpipe (CPU) — never selected: the wrapper selects the
  first device with a compute queue family in enumeration order, and
  the test asserts the RADV/8060S identity + AMD vendor, so a silent
  llvmpipe fallback would FAIL the case, not pass it.
- A-006 (Vulkan readiness probe) is not yet built; per the slice
  order, A-013 did its own minimal device verification:
  hidden_files/vk_probe.c (raw Vulkan against the system headers,
  independent of the Mojo wrapper) created instance/device/queue/
  command pool on device 0 and tore them down — PROBE_PASS.
  Log: hidden_files/a013_vk_probe.log sha256
  0f5604fe71ae1f22f471cab0307a5cbdfea6d93c4a4edb52351a5ccb89459773.

## Design

- aesir_engine/vulkan_context_shim.c (new): dlopens libvulkan
  (unversioned, then .so.1) and resolves the 11 context entry points;
  flat aesir_vk_* ABI; handle kept for process lifetime. Follows the
  A-011 HIP shim pattern (all dynamic loading in C — the Mojo 1.0
  dlopen/OwnedDLHandle signature conflict filed in the A-011 ledger).
  Every fallible call returns the VkResult verbatim, or a sentinel:
  -1000 runtime absent, -1001 zero devices, -1002 no compute queue
  family. A one-shot forced-failure hook (aesir_vk_inject_failure,
  stages 1=instance 2=enumerate 3=device 4=command pool) lets tests
  fail each bring-up stage deterministically on any host.
- aesir_engine/core/vulkan_context.mojo (new): VulkanContext —
  runtime_available, create (instance -> select first compute device
  -> properties -> logical device -> queue -> command pool ->
  vkDeviceWaitIdle proof; every failure tears down what exists and
  raises a taxonomy error), close (reverse-order destroy, idempotent),
  require_valid_queue_family (local admission), inject_failure /
  clear_injection passthroughs, and the pure mapping
  taxonomy_code_for_vk_result / taxonomy_name_for_code.
- Taxonomy mapping (ERROR_TAXONOMY.md codes; every raised error
  carries code + name + raw VkResult):
  -1 OUT_OF_HOST_MEMORY -> MEM-001; -2 OUT_OF_DEVICE_MEMORY and
  -12 FRAGMENTED_POOL -> MEM-002; -10 TOO_MANY_OBJECTS -> MEM-003;
  -3 INITIALIZATION_FAILED and -4 DEVICE_LOST (at bring-up) ->
  GPU-001; sentinels -1000/-1001/-1002 -> GPU-002;
  -6/-7/-8 not-present and -9 INCOMPATIBLE_DRIVER -> GPU-006;
  any other VkResult -> GPU-001 catch-all with the raw code kept.
  Note: the taxonomy's GPU-category names are CUDA-worded
  (GPU-001 CUDA_INIT_FAILED etc.); the CATEGORY CODES are the
  repo-wide GPU failure codes and are what this Vulkan path reports
  under — the Mojo module names GPU-001 GPU_INIT_FAILED for the same
  reason. Recorded here so no reader mistakes this for a CUDA claim:
  this slice is Vulkan/RADV only, no CUDA, no Hailo claim.

## Test evidence (counts read from logs, never memory)

- Standalone battery (hidden_files/a013_standalone.log sha256
  a1f7f3907ae34e4f04a11f4a1f1dce4087c78fbd796e3180d4cb51a253f199b3):
  ALL PASS (4 groups) — context created on "AMD Radeon 8060S Graphics
  (RADV STRIX_HALO)", vendor_id=4098 (0x1002), device_id=5510 (0x1586),
  api_version=4211042 (1.4.354), queue_family=0, queue_count=1;
  taxonomy mapping (13 codes); forced failures at all 4 stages mapped
  (instance -9 -> GPU-006, enumerate -3 -> GPU-001, device -2 ->
  MEM-002, pool -1 -> MEM-001) with a clean create succeeding right
  after (injections one-shot, cleanup complete); local rejection of a
  negative queue family with GPU-002.
- E-MASTER full suite (hidden_files/run_a013.sh; log
  hidden_files/a013_run_all_canonical.log sha256
  6db117a22d092a2ab26eb158d78d7bdee9deb1fdc928bad1c7df0c111f88e1ec):
  Passed 281 / Failed 1 / Skipped 2 / Total 284. Baseline was
  277/1/2/280: the delta is exactly the 4 new A-013 cases, all PASS
  (gpu.vulkan_context_create, gpu.vulkan_taxonomy_mapping,
  gpu.vulkan_forced_failure_taxonomy, gpu.vulkan_context_rejection).
  Sole failure = gguf.tensor_directory_interface, the pre-existing
  J-022 drift (roads A-165/A-121) — unchanged. Skips = the same 2
  pre-declared. MOJO_EXIT=1 is by suite design (any failed case
  raises in ledger.finish).

## Files in this slice

- aesir_engine/vulkan_context_shim.c (new)
- aesir_engine/core/vulkan_context.mojo (new)
- aesir_engine/tests/test_vulkan_context.mojo (new, incl. standalone main)
- aesir_engine/tests/run_all.mojo: +4 registrations, pin 280 -> 284,
  canonical command header extended with libaesir_vulkan staging.
- hidden_files/run_a013.sh + this ledger (tracked, per A-011
  precedent); run logs stay on-device (gitignored). The C probe
  source hidden_files/vk_probe.c stays on-device with its log.

## Notes for neighbours

- A-014 (Vulkan buffers) and A-015 (compute dispatch) build directly
  on VulkanContext: handles are exposed via queue_handle() /
  command_pool_handle() and info carries the device limits source
  data (queue family, api version); buffer work will extend the shim
  with the memory entry points in the same style.
- scripts/launch.py does NOT stage libaesir_vulkan yet — the app
  binary does not reference VulkanContext; wire launch.py staging in
  the first slice that calls it from the main engine path (same note
  A-011 filed for libaesir_hip).
- No new bug discovered in this slice. The known J-022 item stands
  (roads A-165/A-121).
- Banking: this commit stays local on yrsa/aesir-team-04 for the
  keeper to bank in roadmap order (A-006..A-012 bank first).
