# Native RPC storage owner: physical mapping and cleanup

Date: 2026-10-19. Contract: `TASK_hailo10h_dma_storage.md`, acceptance 2–3.
Fixed target: broad source-model compilation/execution in Mojo on Hailo-10H.

## Implementation and consumer

`hailbru/soc_storage.mojo` owns anonymous page-aligned storage for each
2068-byte RPC message. It asks libc for the actual host page size, rounds the
allocation separately, materializes/zeros it before mapping, and retains the
original USERPTR tuple and returned handle. On this Pi each allocation is
16384 bytes. HAILBRÚ's syscall gateway owns mmap/munmap/page-size access.

`SocSession.allocate_rpc_storage()` owns one H2D and one D2H object on the
same driver file. Each storage object is movable, records its owning fd and
architecture, and refuses duplicate mapping, CPU reads without CPU ownership,
closed sync and release while a map might exist. A full-range successful sync
for CPU grants CPU access; sync for device revokes it. Sync failure grants no
new access. The native consumer is `smidr/tools/soc_storage.mojo`.

A map attempt arms retention **before** the ioctl. A successful ioctl with a
bad reply therefore cannot free mapped pages. Normal close stops assigned
channels, unmaps known mappings using original tuples, releases descriptor
lists, closes the driver file, then munmaps both host allocations. Failed or
uncertain mapping/unmapping retains host storage through file-context
finalization. Failed channel close skips explicit unmap/list release and uses
file finalization before host release. Cleanup continues after individual
errors and reports them. A standalone storage destructor encountering an
unresolved mapping retains memory and reports misuse rather than freeing it.
These ordering claims cover this slice, which creates no waiter or transfer.

## Physical evidence

Eight methods pass across **32 child runs**, each with a ten-second outer
deadline. strace matches every owner allocation to one later munmap and
requires it to follow the actual driver-fd close. Evidence includes:

- Three normal sessions, repeat close, both real mappings, four successful
  full-range CPU/device sync calls, zero initialization and access refusals.
- Eleven pre-effect faults: two mmap failures, two maps, four syncs, channel
  close and both unmaps. Fresh normal sessions follow every fault.
- Two post-effect faults: strace `poke_exit` changes the first returned tuple
  byte **after the real map returns zero**. Both replies are refused; real
  kernel mappings survive until file-context cleanup, then host pages release.
- Exception unwind with both mappings, followed by another normal session.

All new native builds succeed. The rebuilt descriptor/connection regression
passes seven methods/17 child runs. The twelve-method byte suite passes with
explicit installed-C offset checks for every new field. Subsequent supported
`hailortcli fw-control identify` succeeds on HAILO10H firmware 5.3.0.

Evidence directory: `evidence/dma-storage-2026-10-19`. `storage-tests.txt`,
`physical-storage-traces.jsonl` (complete traces/stdout/stderr for all 32 runs),
`session-regression.txt`, its trace JSONL, build records, fingerprints and
sanitized identification are retained. Initial harness failures are preserved:
exact whitespace and pre-allocation address reuse defeated the first trace
matcher; restricting matching to the owned lifetime corrected it. An unused
ioctl preload fault helper could not intercept the raw syscall gateway; the
qualified post-effect fault uses strace instead. No production correction was
needed for these harness failures.

## Remaining work

No DMA launch, read-only Mojo RPC, cache visibility after device writes, model
operation or executable program is proved here. Successful sync ioctls are
not a coherence test. Bounded interrupt completion/cancellation must finish
before any transfer is introduced. Then correlate create/identify/destroy
replies, and continue actual operation/configuration generation and model
coverage. No vendor-catalog-only scope, fallback inference, kernel, firmware,
reset or binding change was introduced. Generic hosted CI retains its already
recorded unrelated legacy test limitation; this is targeted native evidence.
