# In-process bounded interrupt waiter

Date: 2026-10-19. Contract before implementation.
Parent: `TASK_hailo10h_dma_observation.md`, acceptance 4.

Use an owned native Mojo C-ABI pthread callback, with explicit heap argument
storage, one blocking driver ioctl and raw result/errno capture. Keep the
runtime in process. Do not use unfinished private Mojo async APIs, fork the
Mojo runtime, introduce a C/Python production bridge or perform inference.

1. Prove the installed LP64 pthread/time ABI against system headers. Route
   pthread/time interactions through HAILBRÚ's syscall gateway. Verify a
   successful native Mojo callback, result visibility only after join, a
   CLOCK_MONOTONIC join deadline, failed start and repeat-use refusal.
2. Host proof uses a private blocking pipe read. A timed-out join must leave
   ownership armed; parent wakes the read, joins and only then releases worker
   storage and pipe resources. Prove no worker remains on normal/error/unwind
   paths. Do not use asynchronous pthread cancellation.
3. Then run the actual installed driver's interrupt wait on only the assigned
   engine-zero input/output channel mask, with no buffer launch. On deadline,
   disable only those owned channels and join the waiter before session/storage
   cleanup. Preserve timeout/cancel result and exact observed ordering.
4. A failed cancellation cannot silently destroy live worker arguments, driver
   session or mapped storage. Use bounded retry/join diagnostics. If ownership
   cannot be recovered, the native process must fail closed as a whole without
   running unsafe resource destructors; document and verify that terminal path
   with host-only faults before claiming a reusable physical timeout API.
5. Publish each verified gate and advance to correlated typed physical RPC,
   then actual source-model operation/configuration/compiler work. No timeout
   or empty-channel cancellation result is compute or DMA-completion proof.

Primary interface references, consulted 2026-10-19:
- Mojo 1.1 function declarations: https://mojolang.org/docs/reference/function-declarations/
- Public runtime scope: https://mojolang.org/docs/std/runtime/
- GNU pthread join clocks: https://sourceware.org/glibc/manual/2.43/html_node/Joining-Threads.html
- Linux pthread create: https://man7.org/linux/man-pages/man3/pthread_create.3.html

These are API/behavior facts. No implementation is copied or translated.
Existing installed-driver license/provenance gates remain in force. No kernel,
module, firmware, reset, rebinding, model/catalog request or inference proxy.
