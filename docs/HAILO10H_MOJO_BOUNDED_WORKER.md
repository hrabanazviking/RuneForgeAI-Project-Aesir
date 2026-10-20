# Native owned blocking worker: host deadline proof

Date: 2026-10-19. Contract: `TASK_hailo10h_bounded_wait.md`, gates 1–2 and
host terminal-path portion of gate 4. Physical interrupt cancellation is next.

## Original implementation

`hailbru/blocking_call.mojo` owns one native pthread, immutable syscall inputs,
exclusive worker result/errno/payload storage and a single-use state machine.
The callback is an ordinary Mojo function with explicit C ABI. It performs
one syscall and captures that thread's errno without allocation, Strings,
exceptions or private async runtime APIs. Parent-side allocation occurs before
start; payload/result access is refused until a successful join. The parent
never resizes or frees active worker storage. Moving the owner preserves its
List allocation; copying is excluded by its Movable-only conformance.

HAILBRÚ's syscall gateway owns pthread_create, pthread_clockjoin_np, absolute
CLOCK_MONOTONIC deadline construction and the host-test pipe wrapper. The
native worker offers admitted read and interrupt-wait entry points; the read
consumer is a host proof. A timeout keeps active ownership armed. Clock/join
errors also leave ownership armed. A failed start cannot arm a thread.

Successful join establishes result visibility and releases native thread
resources. Returning into normal destruction with a still-active worker is a
terminal invariant violation: named `LiveWorkerFatal`, then Linux exit_group
status 123 before its List or other Mojo resource destructors run. This path
is host-tested. It is not ordinary timeout recovery. The driver owner must
still implement channel disable and successful join for normal cancellation.
No async pthread cancellation, fork or external serving process is used.

## Independent ABI and host proof

The installed-system-header oracle checks pthread_t 8 bytes, timespec 16 bytes,
seconds/nanoseconds offsets 0/8, time_t 8 bytes, CLOCK_MONOTONIC 1, ETIMEDOUT
110 and aarch64 exit_group syscall 94. The process uses the installed libc's
pthread ABI, already available on this Pi. No new runtime library is bundled.

Nine methods pass across **48 native child runs**, with ten-second outer
containment deadlines:

- 32 fresh normal callbacks, exact byte/result/errno, live-result refusal,
  repeated-join refusal and no additional thread remaining after join.
- Eight actual 25ms monotonic join timeouts, then pipe wake and successful
  join/cleanup. Each run completes within two seconds in this evidence.
- Duplicate start and invalid deadline preserve the original active owner.
- The worker's own EBADF is captured separately from parent errno.
- Actual pthread start fails via EAGAIN injected only into the callback's
  clone, after Mojo's startup worker pool; both pipe fds close.
- Monotonic-clock failure and exception unwind wake/join the blocked read
  before cleanup. Dropping a live owner terminates the whole process with
  123, as required, without hanging or returning into unsafe teardown.

Evidence: `evidence/bounded-worker-2026-10-19/worker-tests.txt`, complete
`host-worker-traces.jsonl`, `thread-layout.json` and build records. Initial
compiler errors (explicit pointer origin and void-return FFI choice) and
initial test-harness failures are retained. The final implementation uses the
raw exit_group gateway. The harness now reassembles interleaved strace lines;
it targets the callback clone after the private pipe rather than assuming
Mojo starts no runtime threads. These were corrected before qualification.

## Primary interface provenance and limits

API facts, not copied implementation:
[Mojo C ABI](https://mojolang.org/docs/reference/function-declarations/),
[Mojo runtime scope](https://mojolang.org/docs/std/runtime/),
[GNU explicit join clocks](https://sourceware.org/glibc/manual/2.43/html_node/Joining-Threads.html),
[Linux pthread creation](https://man7.org/linux/man-pages/man3/pthread_create.3.html).
Installed glibc headers supply ABI declarations (LGPL-2.1-or-later notice read).

This is host control-flow evidence, not physical Hailo interrupt cancellation,
DMA completion or source-model execution. A userspace join deadline does not
bound arbitrary kernel processing or scheduler delays. Next: use only the
session's assigned mask, enable interrupts, wait, disable on deadline, join,
then close channels/mappings/storage. Persistent failed cancellation must take
the proved whole-process terminal path rather than free live resources. The
Mojo-owned source-model/compiler target remains unchanged and unfinished.
