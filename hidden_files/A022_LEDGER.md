# A-022 Ledger - Buffer ownership law (team-08)

- Slice: A-022 Buffer ownership law (Wave 3, roadmap order)
- Worktree: /home/volmarr/aesir-team-08, branch yrsa/aesir-team-08
- Base: 36d2c240 (A-019 banked; 19 of 216 at resume time)
- Status: COMPLETE - committed on yrsa/aesir-team-08, awaiting banking
  by the keeper in roadmap order (A-020/A-021 bank first; no rebase).
- Resumed by a fresh lead after the previous lead was cancelled
  mid-build; all pre-existing WIP was preserved, nothing reset.

## The law (as built by the previous lead, preserved)
Exactly one owner per buffer; ownership is a registry entry inside
the allocating shim, never the raw pointer/handle itself. States:
LIVE -> HANDED_OFF (sender tombstone; receiver must claim) -> LIVE;
LIVE -> FREED (tombstone, so a second free is detectable). Borrows
never own. A handle is valid only for its own kind, shim, device and
generation. Every violation fails closed with a named taxonomy code
(MEM-004 use-after-free, MEM-005 double-free, MEM-011 use-after-
hand-off, MEM-012 cross-kind/device misuse, MEM-013 non-owner free,
MEM-014 stale handle, MEM-015 free-with-active-borrows), returned as
-22004..-22016 at the shim boundary (aesir_engine/buffer_ownership.h)
and translated by core/buffer_ownership.mojo ownership_taxonomy_name.
Enforcement: HIP shim registry (device/managed/pinned + stream/event
handle tables), Vulkan buffer shim registry (slot+generation ids),
zero-copy shim registry, and the XRT BO contract registry in
core/buffer_ownership.mojo (A-016 is probe-only; no sudo, no ioctls).
Deliverables: aesir_engine/buffer_ownership.h,
aesir_engine/core/buffer_ownership.mojo, ownership checks threaded
through core/hip_memory.mojo, core/hip_transfer.mojo,
core/vulkan_buffers.mojo, core/zero_copy.mojo and the three C shims,
plus aesir_engine/tests/test_buffer_ownership.mojo (4 cases) wired
into tests/run_all.mojo.

## Starting state at resume (log hidden_files/a022_run_all.log, run 1)
327 passed / 3 failed / 2 skipped / 332 total. Failures: (1) the
pre-existing gguf.tensor_directory_interface J-022 drift (tolerated,
roads A-165/A-121, NOT fixed here); (2) HIP adversarial: host-free of
device memory was not refused; (3) zero-copy adversarial: cross-shim
free was not refused with MEM-013.

## Fixes made by this lead (all in-slice)
1. HIP host-free (MEM-012): core/hip_transfer.mojo _raise_for_rc had
   the ownership-code branch nested INSIDE the HIP-absent branch,
   after a raise - dead code. Every ownership refusal from the
   transfer path fell through to a generic HIP-call-failed message
   with no MEM code, so HipTransfer.host_free(device_ptr) was in
   fact refused by the shim (-22012) but the test could not see
   MEM-012. Dedented the branch to sit beside the absent check,
   mirroring HipMemory._raise_for_rc exactly. Probe (previous lead
   debug file, re-run): host_free(dev) raw rc -22012, wrapped error
   now MEM-012 CROSS_DEVICE_MISUSE; legit frees unaffected.
2. Cross-shim free (MEM-013), both directions: proven by debug probe
   on purpleraider - the unified pool reuses a freed 4096-byte
   managed address for the very next managed allocation, so a HIP-
   shim managed pointer presented to the zero-copy shim matched a
   FREED zero-copy tombstone and was refused as MEM-005 instead of
   MEM-013 (raw rc -22005, identical address in all three
   allocations of the probe sequence); the reverse direction
   (zero-copy pointer to HipMemory.free) failed symmetrically.
   Fix: each shim now exports a pure live-ownership query
   (aesir_hip_own_live_kind in hip_memory_shim.c, aesir_zc_own_live
   in zero_copy_shim.c) and each free path (aesir_hip_free,
   aesir_hip_host_free, aesir_zc_hip_free) first asks, through the
   process-global symbol table (dlopen(NULL)/dlsym, no link-time
   dependency, absent peer = no-op), whether the pointer is LIVE or
   HANDED_OFF in the peer shim; if so it refuses MEM-013 before its
   own tombstone check. Genuine double-frees still return MEM-005
   (probe-verified), legit frees and accounting are unchanged.
3. Stream/event use-after-destroy (MEM-004) - latent failure masked
   by failure 2 aborting the HIP case early; exposed on the first
   re-run (328/2/2). HipStream.destroy and HipEvent.destroy zeroed
   the Mojo handle BEFORE the shim call, so a copied handle value
   whose destroy was refused by the shim (MEM-005) still lost its
   handle locally, and its later synchronize was rejected locally
   with a plain zero-handle message carrying no MEM-004. Fix: the
   handle is zeroed only after the shim accepts the destroy; a
   refused destroy changes no state (mirroring the shim law), so
   later use reaches the shim registry and is refused MEM-004.
   Docstrings updated to match.

## Final suite (counts read from the log file, never memory)
- Runner: hidden_files/run_a022.sh (canonical E-MASTER shape)
- Log: hidden_files/a022_run_all.log
  sha256 133d6673658a41b8ada9dc45d583dbbde97d4b9a74f2d17b0276a86d67b1c0a2
- Result: 329 passed / 1 failed / 2 skipped / 332 total.
- Sole failure: gguf.tensor_directory_interface J-022 drift
  (pre-existing tolerated baseline; not this slice).
- All four A-022 cases PASS: gpu.buffer_ownership_hip_adversarial,
  gpu.buffer_ownership_vulkan_adversarial,
  gpu.buffer_ownership_zero_copy_adversarial,
  gpu.buffer_ownership_xrt_contract.
- Debug artifacts aesir_engine/dbg_a022.mojo (previous lead) and
  aesir_engine/dbg_zc.mojo (this lead) were removed before commit.
- No README.md touched. No Docker. No merge/push by the team.
