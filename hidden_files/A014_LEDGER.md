# A-014 Ledger - Vulkan buffers (team-05)

Slice: A-014 - Vulkan buffers. Buffer allocation with host-visible
coherent mapping; write/read oracle test. Acceptance: byte-exact round
trip through a mapped buffer; alignment rules documented from the
device limits (read from the device, not assumed).

Verdict: ACCEPTANCE PASS with real device execution on purpleraider
(ASUS ROG Flow Z13, Strix Halo). Device selected by the shim:
AMD Radeon 8060S Graphics (RADV STRIX_HALO), vendor 0x1002, device
0x1586, Vulkan API 1.4.354, device type INTEGRATED_GPU, compute queue
family 0 - evidence hidden_files/a014_probe.log, cross-checked
against hidden_files/a014_vulkaninfo.log (vulkaninfo, Mesa RADV
26.2.4, radeon_icd.json). This is a Vulkan device-execution claim
backed by live vkCreateBuffer / vkAllocateMemory / vkBindBufferMemory
/ vkMapMemory calls, not by library presence.

## What was built

- aesir_engine/vulkan_buffer_shim.c - flat C ABI over libvulkan
  (dlopen libvulkan.so.1 / libvulkan.so), following the A-011 HIP shim
  precedent (Mojo 1.0 cannot mix the repo's external_call dlopen idiom
  with OwnedDLHandle; Vulkan's struct-heavy calls marshal in C).
  One process-lifetime minimal context (instance, selected physical
  device, logical device, compute queue), a 128-slot buffer table,
  and live-byte/live-count accounting. Mirrored Vulkan structs were
  verified field-by-field against the installed vulkan_core.h 1.4 ABI
  on this machine: hidden_files/a014_layout_check.c +
  a014_layout_check.log - LAYOUT RESULT PASS (every sizeof/offsetof
  equal; during development the check caught one mirror overshoot -
  sparseProperties padding 32 B vs the real 20 B - fixed in-slice to
  5 x uint32 before any device run relied on it).
- aesir_engine/core/vulkan_buffers.mojo - VulkanBuffers gateway:
  runtime_available / device_info / limits / requirements / allocate
  / map / unmap / free / live accounting, plus checked align_up /
  is_power_of_two arithmetic. All sizes admitted through checked_span;
  every failure raises with the taxonomy-shaped message
  (VulkanBuffers.<op>: ... VkResult N / honest-absent / invalid id).
- aesir_engine/tests/test_vulkan_buffers.mojo - four E-MASTER cases
  (below), also runnable standalone (own main).
- aesir_engine/tests/run_all.mojo - registers the four cases and
  re-pins the finish count 280 -> 284 on this branch's ba0cf066 base;
  the header's canonical command now stages libaesir_vulkan.so.

## A-013 dependency (honest note)

A-013 (Vulkan context wrapper, team-04) had NOT landed in any
worktree when A-014 was built (team-04 still at its A-004 commit).
Per the slice instruction, A-014 built the minimal context it needs
inside its own shim (instance/device/queue creation only) and the
keeper reconciles the two contexts at banking; A-014 claims nothing
about A-013's wrapper.

## Alignment rules - READ FROM THE DEVICE (gfx1151 / RADV)

Measured through the shim from VkPhysicalDeviceLimits +
VkPhysicalDeviceMemoryProperties of the selected device
(a014_probe.log) and identical in vulkaninfo (a014_vulkaninfo.log):

| Quantity | Value |
|---|---|
| minMemoryMapAlignment | 4096 |
| minStorageBufferOffsetAlignment | 4 |
| minUniformBufferOffsetAlignment | 4 |
| minTexelBufferOffsetAlignment | 4 |
| nonCoherentAtomSize | 64 |
| bufferImageGranularity | 1 |
| optimalBufferCopyOffsetAlignment | 1 |
| maxMemoryAllocationCount | 4294967295 |
| maxStorageBufferRange | 4294967295 |
| maxPushConstantsSize | 256 |
| requirements(size=1000) | size 1008, alignment 16, typeBits 0x7ad |
| preferred host-coherent type | index 3, flags 0x7 = DEVICE_LOCAL + HOST_VISIBLE + HOST_COHERENT |
| preferred heap | index 1, 46347997184 bytes (DEVICE_LOCAL) |
| heaps | heap 0: 23173996544 B; heap 1: 46347997184 B |
| memory types / heaps | 11 types, 2 heaps |

Rules the gateway and tests enforce from those values:
1. A pointer returned by mapping offset 0 is aligned to
   minMemoryMapAlignment (4096) - asserted live on every round-trip
   allocation.
2. Allocation size is the driver's VkMemoryRequirements.size: always
   >= the request and a multiple of VkMemoryRequirements.alignment
   (16 for every size probed) - asserted live.
3. Offsets into storage / uniform / texel buffers must be multiples
   of the matching min alignment (4 on this device).
4. Coherence: allocations use only HOST_VISIBLE + HOST_COHERENT
   memory (preferred type 3 is also DEVICE_LOCAL - the Strix Halo
   unified type), so mapped writes/reads need no flush/invalidate.
   nonCoherentAtomSize (64) would bound flush/invalidate ranges for
   non-coherent memory only; this gateway never allocates it and
   fails closed (-8) if no coherent type satisfies a buffer.
5. Size bounds: a request of 4x the preferred heap
   (185391988736 bytes) is refused by RADV itself and surfaces as a
   fail-closed error - driver message in a014_mojo_standalone.log.
6. bufferImageGranularity is 1: no extra padding granularity between
   linear resources on this device.

## Oracle results (byte-exactness proven from logs)

C oracle (hidden_files/a014_probe.c, run before any Mojo):
hidden_files/a014_probe.log - RESULT PASS, fails=0. Round trips at
1 / 7 / 64 / 4096 / 65536 / 1048576 bytes, two deterministic patterns,
write -> unmap -> remap -> verify (persistence across remap proves a
real device mapping, not a host staging copy), live accounting back
to 0 bytes / 0 buffers after frees.

Mojo standalone: hidden_files/a014_mojo_standalone.log - ALL PASS
(4 groups), MOJO_EXIT=0.

E-MASTER cases (all [CASE PASS] in the canonical log):
- gpu.vulkan_buffer_alignment_rules - checked align_up arithmetic;
  live limits are positive powers of two; preferred type carries
  HOST_VISIBLE + HOST_COHERENT; requirements(1000) obeys rule 2.
- gpu.vulkan_buffer_round_trip - the six sizes above through the
  Mojo gateway, byte-exact, mapped-pointer alignment asserted.
- gpu.vulkan_buffer_alloc_rejection - non-positive sizes rejected
  locally; double free rejected; oversize refused fail-closed.
- gpu.vulkan_buffer_no_leak - 200 alloc/map/touch/free iterations;
  shim live accounting returns to the post-warm-up baseline exactly.

## E-MASTER gate (counts READ FROM THE LOG)

hidden_files/a014_run_all_canonical.log (sha256
25b692803df3fe2222234ab123d2094e9c182a85c455b8a903ab36b7d70e0cd6):
281 passed / 1 failed / 2 skipped / 284 total. Baseline at ba0cf066
(A-003 canonical): 277 / 1 / 2 / 280. Delta is exactly the four new
Vulkan cases passing; zero regressions. Sole failure is the
pre-existing gguf.tensor_directory_interface J-022 drift with the
identical message as at base (roads A-165 primary / A-121) - not
introduced by A-014 and not this slice's to fix. MOJO_EXIT=1 comes
from ledger.finish raising on that one pre-existing failure, the
same behaviour as every baseline run. Runner:
hidden_files/run_a014.sh.

## Known next-work items (recorded, not silent)

- scripts/launch.py does not stage libaesir_vulkan.so yet; the first
  slice calling VulkanBuffers from the main engine path must wire it
  (same note A-011 left for libaesir_hip.so).
- Banking reconciliation: this branch is based on ba0cf066
  (finish pin 284). A-011 (285) and A-012 land ahead of A-014 in
  roadmap order, and A-013 (team-04) carries its own context wrapper;
  the keeper merges in order, unions the finish pin, and decides how
  the A-013 wrapper and this shim's minimal context converge.
- gguf.tensor_directory_interface (J-022) still fails at base;
  owned by roads A-165 / A-121 per team-03 triage.

## Banking note - Vulkan symbol convergence (seat, 2026-11-12)

Finding: A-013 and A-014 do NOT coexist cleanly as authored. Both
shims stage a library named libaesir_vulkan.so (in their team run
scripts), and both export two identical symbol names with, in one
case, incompatible ABIs:

- aesir_vk_available(void) - exported by both; identical signature,
  equivalent semantics (1 iff the Vulkan loader is present).
- aesir_vk_device_info - exported by both with DIFFERENT signatures:
  A-013 (uint64 dev, char *name, uint32 *vendor, uint32 *device_id,
  uint32 *api, int32 *type) vs A-014 (char *name, int cap,
  uint32 *vendor, uint32 *device_id, uint32 *api, uint32 *type,
  uint32 *queue_family). Both Mojo wrappers bind by name via
  external_call at link time, so in one run_all binary both call
  sites would resolve to a single implementation and one caller
  would run with the wrong ABI.

All other exported symbols are disjoint (verified with nm on both
objects: A-013 aesir_vk_create_*/select/get_queue/destroy_*/
inject_failure/clear_injection/device_wait_idle; A-014 aesir_vk_init/
limits/buffer_*/live_*). scripts/launch.py stages neither library
(grep-verified); the libaesir_vulkan.so name collision exists only
in the team run scripts.

Convergence applied at banking (collision fix only, no logic
rewritten): the A-014 side's two colliding symbols were renamed -
aesir_vk_available -> aesir_vk_buffer_available and
aesir_vk_device_info -> aesir_vk_buffer_device_info - in
vulkan_buffer_shim.c (definitions) and core/vulkan_buffers.mojo
(three external_call sites). The seat gate stages ONE merged
libaesir_vulkan.so built from vulkan_context_shim.c +
vulkan_buffer_shim.c; its dynamic symbol table is the disjoint
union of both shims (nm-verified at banking). The run_all canonical
header was unioned to match (HIP shim + merged Vulkan shim).

Seat gate (post-banking, hidden_files/seat_gate_a014.log sha256
a034319167b29dd17e20494bc1e3d77848fb011b9bf60ebefdd46a852ebc2318,
script hidden_files/run_seat_gate_a014.sh): 307 passed / 1 failed /
2 skipped / 310 total. Sole failure = pre-existing
gguf.tensor_directory_interface J-022 drift; skips = the 2
pre-declared. All A-008..A-014 cases pass at the seat, including
gpu.vulkan_context_* (A-013) and gpu.vulkan_buffer_* (A-014)
against the merged libaesir_vulkan.so.
