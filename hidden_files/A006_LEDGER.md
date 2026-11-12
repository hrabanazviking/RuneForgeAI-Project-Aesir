# A-006 Ledger — Vulkan compute readiness (team-06)

- Date: 2026-11-12 (EST, purpleraider local)
- Machine: purpleraider — AMD RYZEN AI MAX+ 395 w/ Radeon 8060S, 32 threads, 121 GiB
- OS: Ubuntu 26.10 (stonking), kernel 7.3.0-10-generic
- Worktree: /home/volmarr/aesir-team-06, branch yrsa/aesir-team-06, base ba0cf066
- Method: system-level probe + native Ubuntu packages only. NO Docker.
- Distinct from A-013 (team-04): A-013 built the engine's Vulkan context
  wrapper; A-006 is the system-level readiness proof — full device
  properties, all queue families, the SPIR-V toolchain versioned, and a
  compiled SPIR-V module created as a shader module ON the RADV device.

## Toolchain — already installed, nothing to install (verified on-device)

All of the A-006 toolchain was already present natively; no apt install
was needed this slice. Versions filed in hidden_files/a006_versions.log:

- glslang-tools 16.4.0-1 — glslangValidator: Glslang 16.4.0, SPIR-V 1.6 target
- spirv-tools 2026.3~rc1-1ubuntu1 — SPIRV-Tools v2026.3 (spirv-val/dis/as)
- vulkan-tools 1.4.341.0+dfsg1-1 — vulkaninfo
- libvulkan1 / libvulkan-dev 1.4.357.0-1 — loader 1.4.357, headers present
- mesa-vulkan-drivers 26.2.4-1ubuntu1 — RADV, Mesa 26.2.4-1ubuntu1
- glslc also present (shaderc 2026.3-1, informational; glslangValidator
  is the roadmap-named compiler and is what this slice used)
- RADV ICD: /usr/share/vulkan/icd.d/radeon_icd.json (api 1.4.354,
  libvulkan_radeon.so)

## Acceptance — all proven from filed logs

1. gfx1151 Vulkan device, full properties (hidden_files/a006_probe.log
   sha256 d97dd30b9655825d1a436649051a341fe8ad149724d606cec6cfd6ded227c952;
   full vulkaninfo transcript hidden_files/a006_vulkaninfo.log sha256
   2333831caf154ec749bc39ca8fc75f975de05a13016d4f98cb715c3daea48288):
   probe (hidden_files/a006_vk_probe.c, raw Vulkan against the system
   headers, independent of the engine) enumerates 2 devices; device 0 =
   "AMD Radeon 8060S Graphics (RADV STRIX_HALO)", vendor 0x1002,
   device_id 0x1586 (= gfx1151), INTEGRATED_GPU, Vulkan API 1.4.354,
   driver_id 3 (MESA_RADV), driver_name radv, driver_info
   "Mesa 26.2.4-1ubuntu1", conformance 1.4.5.3. Compute limits:
   maxComputeWorkGroupInvocations 1024, workgroup size [1024,1024,1024],
   shared memory 65536 B, minMemoryMapAlignment 4096,
   nonCoherentAtomSize 64 (agrees with A-014's live-device table).
2. Compute queue family: RADV queue family 0 flags 0xf (GRAPHICS +
   COMPUTE + TRANSFER + SPARSE), count 1, timestampValidBits 64; a
   second compute-capable family 1 flags 0xe count 4 also exists.
   The probe creates instance/device/queue/command pool on family 0
   and vkDeviceWaitIdle succeeds (all rc=0 in the log).
3. llvmpipe is NEVER accepted: device 1 (llvmpipe, vendor 0x10005,
   CPU type) is enumerated and explicitly rejected — the probe selects
   only vendor 0x1002 + device 0x1586 + "8060S" in the name, and exits
   10 (A006_PROBE_FAIL) if no such device exists. A silent CPU fallback
   cannot pass this probe.
4. Compiled trivial SPIR-V module: hidden_files/a006_trivial.comp
   (GLSL 450 compute, local_size 64, out = in + 1.0) compiled with
   glslangValidator -V, exit 0 → a006_trivial.spv, 1228 bytes, sha256
   5d4b557d331eefd414321d6efb966d93ae5a7c9ca673da1c19592dd73f45db8b.
   spirv-val exit 0 (valid); spirv-dis filed
   (hidden_files/a006_spirv_dis.log sha256
   1b9f17349e66e33f7f8422d96ae67508fcafc44a32cf1a0e7bc19dfdb36f0fad):
   OpEntryPoint GLCompute, LocalSize 64 1 1. The probe then loads the
   .spv (magic 0x07230203 verified) and vkCreateShaderModule succeeds
   ON the RADV device (rc=0) — the toolchain output is accepted by the
   real driver, not merely written to disk.
   Final line: A006_PROBE_PASS + VERDICT DEVICE_IS_RADV_GFX1151=YES
   COMPUTE_QUEUE_OK=YES SPIRV_MODULE_CREATED_ON_DEVICE=YES.

## Probe fix made in-slice (found + fixed, not left)

First probe build requested ApplicationInfo apiVersion 1.0, under which
RADV left the VkPhysicalDeviceDriverProperties fields empty (driver_id
0, blank name/info) even though the device was genuine. Bumping the
request to VK_API_VERSION_1_2 (the struct is core since 1.2) filled
them: driver_id 3 / radv / Mesa 26.2.4-1ubuntu1 / conformance 1.4.5.3.
Recorded so later probes do not re-hit it: ask for ≥1.2 when reading
driver properties.

## Full suite (E-MASTER, canonical sm_89 compile-target, CPU execution)

- hidden_files/a006_run_all_canonical.log sha256
  329a92c1e89dda21658b8e9118470102ffae9c9817604b83d4c1e24d84ffe167:
  Passed 277 / Failed 1 / Skipped 2 / Total 280, MOJO_EXIT=1.
- IDENTICAL to the ba0cf066 baseline (team-03 canonical, confirmed by
  A-005): zero regressions. This slice adds no engine cases — it is a
  system-level readiness slice (A-005 precedent), so the finish pin
  stays 280 and run_all.mojo is untouched.
- The 1 failure is PRE-EXISTING: gguf.tensor_directory_interface
  (J-022 drift; roads A-165/A-121) — identical at base in team-01/02/03/05
  logs. Not caused by, and not fixable inside, A-006's scope.
- The 2 skips are the suite's named opt-in cases:
  vision.cuda_session_image_chat and rag.real_engine_integration.

## Repo changes (this commit)

- hidden_files/A006_LEDGER.md (this file)
- hidden_files/run_a006.sh (E-MASTER gate run, canonical shape)
- hidden_files/a006_vk_probe.c (readiness probe source)
- hidden_files/a006_trivial.comp (trivial compute shader source)
- Evidence logs + the compiled .spv stay on-device (gitignored):
  a006_versions.log, a006_vulkaninfo.log, a006_probe.log,
  a006_glslang.log, a006_spirv_val.log, a006_spirv_dis.log,
  a006_run_all_canonical.log, a006_trivial.spv.
- No engine source changed; no README touched; nothing merged or
  pushed — the keeper banks from ~/aesir-forge in roadmap order.
