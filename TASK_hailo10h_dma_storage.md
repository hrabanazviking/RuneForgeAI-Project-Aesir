# Owned DMA storage before RPC transfer

Date: 2026-10-19. Contract before implementation.
Parent: `TASK_hailo10h_dma_observation.md`, fixed source-model/Mojo objective.

## Consumer and acceptance

The native assigned-session owner will own page-aligned host storage for its
2068-byte RPC messages. This is transport infrastructure for Aesir-generated
programs, not a restriction to vendor-precompiled models.

1. Independently encode installed 5.3.0 USERPTR map/unmap and cache-sync ABI.
   Check every field offset, ioctl number and complete buffer against a C++
   oracle including the installed UAPI. Unmap uses the original tuple; sync
   uses the returned handle. Refuse invalid ranges without unsigned overflow.
2. Allocate anonymous page-aligned storage with the host's actual page size.
   Keep logical and allocation sizes distinct. A movable HAILBRÚ owner must
   retain memory through mapping failure/uncertain driver ownership and until
   file-context finalization or successful unmap. No storage destructor may
   free memory still mapped to a live driver context.
3. Integrate two owned storage objects with the assigned-session lifecycle.
   Verify real map, explicit full-range CPU/device sync, unmap and close with
   no transfer. Test both directions, repeated close, unwind and injected map,
   sync and unmap failures; prove memory release follows context quiescence.
4. Publish exact evidence and continue bounded wait/cancellation, then typed
   create/identify/destroy. Storage/map/sync success alone proves neither DMA
   completion nor data coherence after a transfer.

No user DMA launch is authorized by this slice. No model, inference, kernel,
firmware, reset or binding change. All device/syscall access stays in HAILBRÚ.
Installed dual-licensed UAPI and previously licensed driver sources supply
interface facts only; no implementation is copied or translated. Record the
normal cleanup order and fallback on uncertain map/unmap failures explicitly.
