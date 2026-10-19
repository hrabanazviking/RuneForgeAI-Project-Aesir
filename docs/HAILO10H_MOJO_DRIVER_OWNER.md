# Native Mojo driver owner and physical read-only query

Completed 2026-10-19 under `TASK_hailo10h_soc_session.md`. The source-model
compiler target remains fixed. This slice proves driver-file ownership and
two read-only kernel queries, before RPC connection and DMA submission.

`hailbru/soc_driver.mojo` discovers the PCI vendor/device, selects its one
associated `hailo1x` node, opens nonblocking with close-on-exec and no-follow,
and compares the opened character device's major/minor numbers with that
PCI node's sysfs `dev` attribute. It obtains the actual host architecture
through libc `uname` before selecting syscall numbers. All OS operations stay
inside the HAILBRÚ syscall gateway. `statx` inspects the opened file, avoiding
an unchecked path-only identity assertion.

The owner queries driver info/properties with the verified packed ABI and
requires the qualified 5.3.0 Hailo-10H PCIe profile with loaded firmware. This
is a driver ABI qualification, not a model compatibility limitation. It uses
neither libhailort nor a C++ runtime bridge. Explicit close is idempotent;
requests after close fail before ioctl. Move-only ownership also closes on
exception unwinding. Cleanup failures retain a named error; Linux close is
never retried on an fd that may already have been released.

## Physical result

Native `smidr/tools/soc_driver.mojo` returns actual kernel data on this Pi:

- BDF `0001:01:00.0`, node `h1x-0`, architecture `aarch64`;
- driver 5.3.0; maximum descriptor page size 4096;
- Hailo-10H board enum 2, PCIe DMA enum 0, one DMA engine, firmware loaded;
- file closed, repeat close accepted and post-close request refused.

`strace` observes exactly two read-only query ioctls and one close on the
actual device fd. No descriptors, connection, transfer or model are submitted.
Supported `hailortcli fw-control identify` still succeeds afterward, reporting
HAILO10H and firmware 5.3.0.

## Verification and corrected finding

Both native builds pass. Eleven test methods pass, including compiled system
header checks for uname/statx layouts and syscall/flag values; missing or
ambiguous PCI/node identity; malformed names; missing nodes; regular files,
FIFO and symlink refusal; physical rdev mismatch before ioctl; observed normal
and exception closes; and separate injected EIO failures at each read-only
query. `strace` injects failure before the selected ioctl enters the driver;
no fake success or device result is substituted. The prior ABI suite still
passes all nine methods with the extended test oracle.

The initial boundary run caught an architecture-specific flag error:
`O_NOFOLLOW` is octal `0100000` on aarch64, not the x86-64 `0400000` value.
The opened-fd identity guard rejected the symlink target, but the open itself
had followed it. The gateway now selects the installed architecture's value;
the final trace explicitly shows `O_NOFOLLOW` and the test requires refusal
at open. The other initial failure was a test parser expecting numeric ioctl
output when strace printed a decoded `_IOC` expression; its independent
numeric comparison now parses that expression. Initial evidence is preserved.

```sh
mojo build -I . smidr/tools/soc_driver.mojo -o work/soc-driver
mojo build -I . tests/hailo_soc_driver_unwind.mojo -o work/soc-driver-unwind
python3 tests/test_hailo_soc_driver.py --binary work/soc-driver \
  --unwind-binary work/soc-driver-unwind --oracle work/soc-abi-oracle \
  --strace /usr/bin/strace --hardware -v
```

The oracle is built with the operator's installed header as documented in
`HAILO10H_MOJO_SOC_ABI.md`. Omitting `--hardware` explicitly skips physical
cases; it cannot establish this receipt's physical claim.

## Next acceptance

Implement owned descriptor allocation and an assigned PCIe connection, close
it before freeing descriptors, and verify partial-failure cleanup. Installed
driver interface study confirms per-file channel ownership and file-context
finalization before descriptor cleanup. This must be proved for Aesir's owner
before live DMA. Independent typed RPC and source-model program generation
remain open. The fixed target has not been narrowed or completed.

[Receipt](evidence/mojo-driver-owner-2026-10-19/receipt.json),
[final tests](evidence/mojo-driver-owner-2026-10-19/tests.txt),
[physical data](evidence/mojo-driver-owner-2026-10-19/physical.json),
[full syscall trace](evidence/mojo-driver-owner-2026-10-19/physical.strace).
