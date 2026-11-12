# A-015 Ledger - Vulkan compute dispatch smoke (team-01)

Slice: A-015 - Vulkan compute dispatch smoke. One trivial SPIR-V
kernel (vector add) dispatched via Vulkan compute and read back.
Acceptance: results byte-exact vs CPU oracle at several sizes
including non-multiples of the workgroup size.

Verdict: ACCEPTANCE PASS with real device execution on purpleraider
(ASUS ROG Flow Z13, Strix Halo). Device: AMD Radeon 8060S Graphics
(RADV STRIX_HALO), vendor 0x1002, device type INTEGRATED_GPU (1),
compute queue family 0 - evidence hidden_files/a015_probe.log and
the header of hidden_files/a015_run_all.log. llvmpipe is explicitly
refused: the Mojo cases require vendor 0x1002 + RADV name marker +
non-CPU type before any dispatch assertion runs (the shim's device
scoring also penalizes llvmpipe/CPU devices, A-014). This is a
device-execution claim backed by live vkCreateShaderModule /
vkCreateComputePipelines / vkCmdDispatch / vkQueueSubmit calls.

## Starting point verified

- Seat main HEAD 11594f9a (A-014) confirmed by git ls-remote;
  team-01's old tip 7bed5e27 (A-010) confirmed banked by subject in
  main (e9e85375 A-010). Team branch reset --hard onto 11594f9a
  before building, so A-015 builds on the merged Vulkan library
  (seat gate stages ONE libaesir_vulkan.so from
  vulkan_context_shim.c + vulkan_buffer_shim.c; A-014's buffer
  symbols carry the aesir_vk_buffer_* names per the A-014 banking
  reconciliation - no collision with the new dispatch symbols
  aesir_vk_dispatch_available / aesir_vk_buffer_vec_add).

## What was built

- aesir_engine/shaders/vec_add.comp - the kernel source of record:
  c[i] = a[i] + b[i], local_size_x 256, element count as push
  constant guarding every invocation (tail workgroup exact).
  Compiled on purpleraider: glslangValidator -V vec_add.comp
  -> SPIR-V 1608 bytes, sha256
  b228710b1f464b3aa810a4d4cb73e67f2325fdf1eabaa2ceb6b2cf73309ce15b
  (reproduced identically in the a015_run_all.log header). The
  SPIR-V words are embedded verbatim in the shim.
- aesir_engine/vulkan_buffer_shim.c - EXTENDED (no third context):
  aesir_vk_buffer_vec_add(id_a, id_b, id_c, n) reuses the A-014
  shim's own instance / physical device / logical device / compute
  queue and operates directly on A-014 buffer slots (created with
  STORAGE_BUFFER usage). Per dispatch it creates shader module,
  descriptor set layout (3 storage buffers), pipeline layout
  (4-byte push constant), compute pipeline, descriptor pool/set,
  command pool/buffer; records bind + push + dispatch
  (ceil(n/256) groups), submits, vkQueueWaitIdle, destroys all
  pipeline objects. Fail-closed: bad id / zero n / undersized
  buffer -> AESIR_VK_INVALID; missing entry point -> AESIR_VK_ABSENT.
- aesir_engine/core/vulkan_buffers.mojo - VulkanBuffers gains
  dispatch_available() and vec_add(a, b, c, n) with local checked
  admission (positive n, every buffer >= n*4 bytes).
- aesir_engine/tests/test_vulkan_dispatch.mojo - three E-MASTER
  cases (below), present/absent discipline identical to A-014.
- aesir_engine/tests/run_all.mojo - registers the three cases;
  finish pin re-set 310 -> 313 (noted in a comment at the pin).

## Bugs discovered and FIXED in-slice (never left unfixed)

1. VkShaderModuleCreateInfo sType written as 15
   (VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO); RADV answered the
   mis-typed struct with an unknown positive result and no shader.
   Fixed to 16 (VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO).
2. Compute pipeline bound at VK_PIPELINE_BIND_POINT_GRAPHICS (0):
   recording vkCmdDispatch then SEGFAULTED inside the RADV driver.
   Fixed to VK_PIPELINE_BIND_POINT_COMPUTE (1) for both
   vkCmdBindPipeline and vkCmdBindDescriptorSets. (A debug
   detour is recorded for honesty: an early fprintf-instrumented
   shim returned 12 at the shader step - that was the
   instrumentation overwriting the call's return value with
   fprintf's byte count, not a driver result.)

## Oracle results (byte-exactness proven from logs)

C probe (hidden_files/a015_probe.c, direct shim ABI, run before
the Mojo cases and again in the suite header):
hidden_files/a015_probe.log - RESULT PASS, fails=0. Sizes
1 / 7 / 255 / 256 / 257 / 1000 / 4097 / 65537 elements, patterns
fa(i) = ((i*37+11) % 997) * 0.5 - 100, fb(i) = ((i*91+7) % 613)
* 0.25 + 3 (all values and sums exactly representable in f32),
output pre-filled with a -9999 sentinel, memcmp byte-exact at
every element, every size: BYTE-EXACT.

E-MASTER cases (all [CASE PASS] in hidden_files/a015_run_all.log,
sha256 ac4e30065511d23b72b184490e161e296da3d734d019552fe6eca188338d5fcb):
- gpu.vulkan_dispatch_vec_add_oracle - the same eight sizes
  through the Mojo gateway, exact at every element.
- gpu.vulkan_dispatch_rejection - zero n, oversize n (300 elements
  into 256-element buffers), and a bogus buffer id all rejected.
- gpu.vulkan_dispatch_no_leak - 50 dispatches at n=257; shim live
  byte/count accounting returns to baseline exactly.
Probe log sha256: 58d66b5648ec3179550b40ee12cc7e48ac76375efbf9c59b662463d1b56225bb

## Suite (canonical command, hidden_files/run_a015.sh)

310 passed / 1 failed / 2 skipped / 313 total. The one failure is
the pre-existing J-022 drift (gguf.tensor_directory_interface),
identical to the banked baseline (307/1/2/310 at 11594f9a):
baseline + exactly the three new cases, all passing. MOJO_EXIT=1
is the suite's own signal for that single known failure.
