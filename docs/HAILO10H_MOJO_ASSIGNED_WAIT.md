# Assigned-channel native wait and cancellation

Date: 2026-10-19. Contract: `TASK_hailo10h_bounded_wait.md`, physical gate 3
and cancellation/terminal portion of gate 4. No DMA was launched.

## Implementation

`SocSession.wait_interrupts()` enables only its assigned input/output channel
mask on engine zero, then starts the owned in-process Mojo pthread ioctl.
A successful join precedes result/errno decoding and bounded IRQ validation.
Returned engines/channels must belong to this session. A monotonic join
deadline does not destroy the waiter. Instead, cancellation disables those
owned channels, waking the installed driver's interrupt wait, then joins it.

There are at most two cancellation attempts, each with a 1000ms join bound.
A first disable failure can be recovered by the second attempt. Diagnostics
and attempt count are retained. Persistent failure takes named
`SocWaitCancelFatal` and exit_group status 124, before normal resource
destructors. This is a terminal invariant path, not silent timeout success.
The host-level whole-process terminal behavior was proved in the prior slice.

A timeout or error marks the session cancelled; further normal use is refused.
`close()` joins/stops any live waiter before channel close, mapping/list
cleanup, driver-fd finalization and host munmap. Uncertain interrupt-enable
side effects arm cleanup before ioctl. Failed channel close uses file-context
finalization, retaining host pages through it. The consumer is
`smidr/tools/soc_wait.mojo`; it maps both buffers but posts no transfer.

## Physical verification

Six methods pass across **18 native child runs**, each with a ten-second
outer deadline, using the rebuilt native consumer:

- Eight fresh 25ms timeouts. Actual assigned mask is preserved in the wait
  response, the mask has the two assigned engine-zero channels, disable wakes
  the blocking ioctl with zero records, and the waiter joins before teardown.
- First disable returns injected EIO; the first rescue join times out, the
  second disable succeeds and join precedes cleanup. A fresh session follows.
- Enable failure and monotonic-clock failure unwind through armed cleanup.
- Channel-close failure after waiter join retains host pages until actual fd
  finalization. A fresh session follows each failure.
- Persistent injected disable failures reach status 124 after two rescue
  deadlines. No explicit mapping/descriptor/host-memory teardown runs with the
  waiter still active. Kernel process cleanup completes; the next fresh owned
  session succeeds without reset or driver rebinding.

strace -f supplies full thread/syscall evidence. The two host allocations are
matched to later munmap calls after driver close on every ordinary path. No
launch ioctl appears. Injection indices are per thread: the parent disables
on its ninth ioctl; the native wait thread issues its own first ioctl.

Evidence: `evidence/assigned-wait-2026-10-19/wait-tests.txt`, complete
`physical-wait-traces.jsonl`, binary fingerprint and build records. The first
verification invocation started before the replacement binary finished building
and saw its older JSON without `owned_mask`; that failure is retained in
`initial-verification-error.txt`. The qualified suite was rerun after the build
completed and passes all cases with the final binary.

Rebuilt regression verification also passes: storage eight methods/32 child
runs, descriptor/connection seven methods/17 runs, and host worker nine
methods/48 runs. Complete regression traces and build records are in the same
evidence directory. A subsequent supported identify succeeds on firmware
5.3.0/HAILO10H after the terminal cancellation experiment and all regressions.

## Limits and next gate

This proves bounded userspace waiting and assigned-channel cancellation with
no transfer. It does not prove DMA completion, cache visibility after device
writes, read-only Mojo RPC or any compute program. Driver ioctl execution and
OS scheduling are not universally bounded by a userspace join timeout.

Continue `TASK_hailo10h_native_rpc_roundtrip.md`: owned CPU byte access, enable
before posting D2H/H2D, exact descriptor accounting, both directional completion,
cache synchronization and typed create/identify/destroy correlation. The
Mojo-owned source-model compiler and broad architecture coverage remain open.
