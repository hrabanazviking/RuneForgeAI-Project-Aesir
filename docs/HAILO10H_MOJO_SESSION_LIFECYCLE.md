# Native Mojo assigned PCIe connection ownership

Completed 2026-10-19 under `TASK_hailo10h_soc_session.md`. This establishes
descriptor/connection acquisition and cleanup on the actual Pi device. It
does not yet transfer typed RPC messages or execute source-model programs.

`hailbru/soc_session.mojo` independently owns the checked driver file, two
circular descriptor lists, and the input/output channels assigned by the
service connection. It selects descriptor page size from actual properties
using the pinned SDK's default ceiling of 512, and requests 65536 descriptors
per direction. It connects to the integrated RPC service port 12133 and
checks assigned channel directions against the installed PCIe profile.
No channel address or handle is guessed.

The native consumer `smidr/tools/soc_session.mojo` successfully acquires the
real connection. The recorded run returned handles 16384/32768 and channels
0/16. These are observed outputs, never constants in the implementation.
The driver starts the assigned channels during connect; no user buffer,
transfer submission, RPC message, model or inference is supplied in this slice.

## Cleanup policy

- Before connect, release only successfully acquired lists, then close the fd.
- After a validated connection, close its assigned channels first, release
  output then input descriptors, and close the file.
- On uncertain connect or failed close, finalize the fd without explicitly
  freeing descriptors that might still belong to active channels.
- Continue remaining cleanup after a list-release failure and retain named
  errors. The driver finalizes its per-file channels before remaining lists.
- Repeat close is harmless; closed use rejects; move-only owner unwinding
  performs the same ordered cleanup.

This policy follows verified driver resource interfaces, not a copied vendor
implementation. The installed Linux driver's ordinary control wait is bounded
at 1000 ms; test child processes also have a 10-second deadline. No kernel,
module, firmware, reset, binding or service configuration is changed.

## Physical verification

Both native builds and all seven physical test methods pass. Raw strace
records show the actual eight successful ioctls in order: driver info,
properties, descriptor create twice, connect, close, descriptor release twice;
then exactly one device-file close. The consumer verifies repeat close and
closed-use refusal. Exception unwinding follows the same order.

Six separate EIO injections occur before the selected ioctl enters the
kernel: first/second descriptor allocation, connect, close, and each descriptor
release. Assertions check the exact cleanup requests after every failure,
including no explicit list release after failed connect/close. Each scenario
is followed by a fresh successful connection. Together the suite observes
ten ordinary successful sessions, one successful exception-unwind session,
and six injected failures. No successful reply is fabricated. Supported
`hailortcli fw-control identify` still succeeds afterward.

The tests establish this bounded control lifecycle. They do not measure all
kernel memory accounting, arbitrary firmware failure recovery, concurrent
client exhaustion, live user-DMA buffer ownership or RPC numerical behavior.
Driver file-context finalization is the observed/researched cleanup path;
failure to complete it is reported, not called success.

```sh
mojo build -I . smidr/tools/soc_session.mojo -o work/soc-session
mojo build -I . tests/hailo_soc_session_unwind.mojo -o work/soc-session-unwind
python3 tests/test_hailo_soc_session.py --binary work/soc-session \
  --unwind-binary work/soc-session-unwind --strace /usr/bin/strace \
  --evidence-root work/session-evidence --hardware -v
```

## Next acceptance

Resolve the actual session transfer sizing, alignment, cache handling,
interrupt completion and timeout/cancellation contract. Add owned transfer
buffers and the typed create/identify/destroy round-trip with correlated
replies and proven buffer lifetime. The nominal 2068-byte RPC message buffer
must not be rounded or fragmented by guesswork. Source-model lowering and
real executable-context generation remain required under the fixed target.

[Receipt](evidence/mojo-session-lifecycle-2026-10-19/receipt.json),
[raw passing tests](evidence/mojo-session-lifecycle-2026-10-19/tests.txt),
[physical connection data](evidence/mojo-session-lifecycle-2026-10-19/physical.json),
[raw connection trace](evidence/mojo-session-lifecycle-2026-10-19/physical.strace).
