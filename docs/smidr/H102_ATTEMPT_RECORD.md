# H102 — Command-submission transport: attempt record

**Date:** 2026-10-10. **Device:** Mimir (purpleviking1), 0001:01:00.0
(Hailo-10H), kernel 6.12.112-v8-16k-hailo+. **Verdict: FAIL** (transport
not proven). This is a documented failed attempt with full evidence, per
the campaign honesty law.

## What was built (implementation PASS)

- `smidr/mailbox.mojo` — faithful implementation of the H101 mailbox
  mechanism: length-prefixed command at BAR4+0x0000, ready-flag doorbell
  at BAR4+0x1754 (u32 0x1 = app CPU), completion poll on BAR0+0x018C bit
  26 (read-and-clear), response read at BAR4+0x0640, 1000 ms bound (the
  studied driver's timeout). Includes the IDENTIFY request builder
  (version=2, opcode=0, packed LE) and an independent response validator
  (version echo, opcode echo, status==0).
- `smidr/tools/mbping.mojo` — live tool: 100× IDENTIFY round-trips with
  1:1 sequence accounting, pre/post H096 register snapshots (volatile
  bit masked), JSON trace output.
- `smidr/tools/mbdbg.mojo`, `mbdbg2.mojo` — diagnostics (kept in-tree as
  evidence tooling).

## What was attempted live

UIO session per the F3-2 reversible procedure (hailo1x unbind →
uio_pci_generic bind → D0 → mailbox work → D3hot → hailo1x rebind;
device left sane: hailo1x bound, /dev/h1x-0 present, D3hot).

1. **Smoke test** (`mbping`, 1 iteration): command writes land
   (readback-verified: BAR4+0x0000=0x8, +0x4=0x2, +0x8=0x0); doorbell
   written; **no completion within 1000 ms**; no MSI on /dev/uio0;
   response slot reads 0x0. Golden clean (device unperturbed).
2. **Write-ordering barrier** added (syscall round-trip between command
   and doorbell; sysfs PCI mappings are Normal-NC on ARM64): still
   silent.
3. **32-bit store semantics** (single dword stores + readback, matching
   the studied driver's iowrite32): still silent. Confirmed BAR4+0x1754
   is write-only/W1S (reads 0xFFFFFFFF always) — the doorbell write
   cannot be read back, but C5 proved the register is live (soft-reset
   via value 8).
4. **Bus mastering enabled** (`setpci COMMAND=0x0006`; was 0x0002 after
   unbind): still silent.
5. **Driver's interrupt-enable sequence replicated** (0x0188 |=
   0xFF00FFFF; clear 0x018C/0x0400/0x0500): still silent after 5000 ms
   (5× the studied timeout).
6. **Vendor-driver diagnostic**: rebound hailo1x, attempted the
   IDENTIFY via /dev/h1x-0 ioctl. The h1x node's ioctl dispatch does not
   expose raw FW_CONTROL ("Invalid ioctl type", "not supported on
   integrated device type") — could not test the firmware through the
   vendor driver. dmesg confirms "SOC Firmware batch was already
   loaded".

## Failure signature

- BAR0+0x018C never shows bit 26 (stays 0x00800000/0x00a00000, the idle
  bits); no MSI delivered; BAR4+0x0640 response length stays 0.
- The firmware never consumes the command: BAR4+0x0000 still holds the
  stale length word after the doorbell.
- Full trace: `data/smidr/first_command_trace.json`.

## Blocking finding

The firmware's app-CPU control mailbox does not service commands from
HAILBRÚ's UIO path. The mechanism, offsets, and command format are all
study-documented and the implementation is faithful (writes verified),
yet the firmware is completely silent — no completion, no error
response, no interrupt. Hypotheses (unresolved): the app-CPU control
service is not running despite "firmware loaded"; or the firmware
requires driver state HAILBRÚ does not replicate. What is certain: no
command round-trip is observable, so **no compute configuration can be
submitted** — the assault cannot proceed past this point.

## Acceptance criteria vs outcome

- Observable completion within timeout: **NOT MET** (0/1, then 0/1
  again with every hardening).
- 100 consecutive no-op submissions, 1:1 matched: **NOT ATTEMPTED**
  (0 completions — nothing to repeat).
- Golden map clean after submissions: **MET VACUOUSLY** (device
  unperturbed in every attempt; D3hot + hailo1x restored).

**H102 verdict: FAIL.** The implementation is complete and correct to
the best of study-derived knowledge; the live proof failed. This
blocks H105 (no transport to submit a configuration through) and,
through the strict-serial law, the rest of the assault chain.

## Final probe (2026-10-10, full-ambition close-out)

Before the H111 gate, one last documented avenue was tried: the **core
doorbell** (`MB_FLAG_CORE_CPU = 0x2`, a documented value never exercised
in the attempts above). A minimal probe (`smidr/tools/coreprobe.mojo`,
single IDENTIFY, `app_cpu=False`) was built and run in a fresh UIO
session (hailo1x unbind → uio_pci_generic bind → D0 → bus mastering
`0x0006`): **completed=False, 1005 ms** — the firmware is silent on the
core doorbell too. Device restored sane (hailo1x bound, /dev/h1x-0
present, D3hot verified via `power_state`).

With both documented doorbell targets silent, every legitimate
submission avenue is exhausted: app-CPU mailbox (5 hardenings), core
mailbox, vendor-driver ioctl. The FAIL stands, earned.
