# Hailo-10 Command-Queue Mechanism (H101)

**Date:** 2026-10-10. **Worker:** MIMISBRUNNR Campaign 6.
**Study basis:** clean-room studies H005 (`HAILO_PCIE_TRANSPORT_GUIDE.md`)
plus the H101/H102 follow-up study (see `CLEAN_ROOM_LOG.md` entry
"H101/H102 — Firmware mailbox doorbell + control-protocol study").
Original prose throughout; no studied code copied, translated, or vendored.
**Live basis:** read-only BAR/config probing on Mimir (purpleviking1),
device 0001:01:00.0 (Hailo-10H, 0x1e60:0x45C4), kernel
6.12.112-v8-16k-hailo+, vendor driver `hailo1x` bound except where noted.

## 1. The queue model (CORRECTED)

The H005 study and the follow-up study agree: **there is no classic
queue-pair** — no ring buffer in host or device memory, no tail-pointer
doorbell, no queue-depth register. The control path to the on-chip
firmware is a **single-slot mailbox with a flag**:

1. The host writes the command as a length-prefixed buffer into the
   firmware-access window (BAR4) starting at offset 0x0000: a 32-bit
   length word followed by the payload, padded to a 4-byte boundary.
   Maximum payload 1500 bytes.
2. The host writes a 32-bit "raise ready" value at a per-board offset in
   the same window. **This flag write is the doorbell.** The value's set
   bit selects which on-chip CPU handles the command (bit 0 = application
   CPU, bit 1 = core CPU).
3. The host waits for completion (see §3), then reads the response from
   the same window at offset 0x0640: a 32-bit length word followed by the
   response payload.

*Study evidence:* the driver's mailbox write path (studied file
`hailort-drivers/common/pcie_common.c`) performs exactly these three
steps; the firmware-control structure and flag bit masks are declared in
`hailort-drivers/common/hailo_ioctl_common.h`; the response-slot offset
constant is defined in `hailort-drivers/common/pcie_common.h`.
*Live corroboration:* the BAR4 window exists and is 16 KiB
(`probe bars` on Mimir: BAR4 @ 0x1800004000, size 16384) — CORROBORATED.
The command/doorbell/response offsets themselves have not yet been
exercised live — the doorbell write and response read are H102's work,
marked below per register.

## 2. The doorbell, exactly (for H102)

| Item | Value | Width | Evidence |
|------|-------|-------|----------|
| Firmware-access window | BAR4 (PCI BAR index 4) | 16 KiB | `probe bars` live |
| Command slot | BAR4 + 0x0000 | u32 length + ≤1500 payload, 4-byte aligned | study; live UNCORROBORATED (write) |
| Ready-flag ("doorbell") offset, Hailo-10H board | BAR4 + 0x1754 | u32 write | study (board table, HAILO10H entry); live UNCORROBORATED |
| Ready-flag value, application CPU | 0x1 (bit 0) | u32 | study (flag mask enum) |
| Ready-flag value, core CPU | 0x2 (bit 1) | u32 | study (flag mask enum) |
| Response slot | BAR4 + 0x0640 | u32 length + payload (read) | study; live UNCORROBORATED |
| Completion timeout used by the studied driver | 1000 ms | — | study (default-timeout constant) |

Consistency note: an earlier C5 session wrote the value 8 to BAR4+0x1754
as a soft-reset trigger and the device survived; the flag register is
therefore writable without bricking the device — CORROBORATED live
(C5 F3 notes). The value 8 is bit 3, a different flag than the
command-doorbell bits above; H102 uses only bit 0.

## 3. How completion is signaled (for H102)

The firmware answers a mailbox command by raising a **software interrupt**
to the host. The single MSI vector's handler reads the host
interrupt-status register and the read itself clears the bits
(read-and-clear; there is no separate acknowledge write):

| Register | Offset | Width | Semantics | Completion bit |
|----------|--------|-------|-----------|----------------|
| Host interrupt status | BAR0 + 0x018C | u32, read-and-clear | bits 31–24 = firmware software-IRQ flags; lower fields = VDMA channel completion | bit 26 (0x04000000): firmware-control completion |
| Interrupt mask | BAR0 + 0x0188 | u32 | — | — |
| Per-channel bitmap, source side | BAR0 + 0x0400 | u32, read-and-clear | VDMA completions | not used by mailbox commands |
| Per-channel bitmap, dest side | BAR0 + 0x0500 | u32, read-and-clear | VDMA completions | not used by mailbox commands |

*Study evidence:* the driver's interrupt-source parsing
(`hailort-drivers/common/pcie_common.c`: software flags are the status
word shifted right by 24; the firmware-control flag is bit 2 of that
byte) and the MSI handler (`hailort-drivers/linux/pcie/src/fops.c`).
*Live corroboration:* BAR0+0x018C reads 0x00800000 in D0 on Mimir
(bit 23 set at rest — the observed reset/idle value, NOT a completion);
0x0188 reads 0x00000000 (unmasked); 0x0400/0x0500 read 0x00000000 —
all CORROBORATED live (2026-10-10, D0 via standard PCI PM transition).
The completion bit itself (bit 26) has never been observed set live —
UNCORROBORATED; observing it is H102's acceptance.

Practical consequence for H102: the wait loop polls BAR0+0x018C for bit
26 with the 1000 ms bound. Each poll read clears whatever bits are set,
so the loop must capture the word and test the bit from the captured
value. At idle (no VDMA in flight) no other bits are expected.

## 4. The no-op command: IDENTIFY (for H102)

The firmware's command set is defined by the control protocol studied in
`hailort/common/include/control_protocol.h`. The first opcode in the
protocol's opcode list is **IDENTIFY**: a read-only self-description
query handled by the application CPU. It changes no device state, making
it the legitimate no-op/ping:

- **Request bytes** (8 total, packed, little-endian): u32 protocol
  version = 2, followed by u32 opcode = 0 (IDENTIFY is the first entry
  of the opcode enum). The version value 2 is what the studied runtime
  places on the wire (`control_protocol.cpp` request-packing path).
- **Target CPU:** application CPU → doorbell value 0x1.
- **Response bytes** at BAR4+0x0640: u32 length, then a packed response:
  u32 version echo, u32 opcode echo, u32 status (0 = success, per the
  studied status enum), then the identity payload — protocol version,
  firmware version triple (major/minor/revision, u32 × 3), logger
  version, board-name length + name, device-architecture enum, serial /
  part / product name lengths + strings.
- **Validation (H102's independent check):** response length sane
  (12 ≤ len ≤ 1500 and matches the identity payload size); version echo
  == 2; opcode echo == 0; status == 0. The board name and firmware
  version are recorded as the device's self-report, not trusted blindly.

*Study evidence:* opcode list order and CPU routing
(`control_protocol.h` opcode table: IDENTIFY first, application CPU);
packed header layout (version, opcode / version, opcode, status);
identity response structure; protocol version constant value 2;
success status value 0 (`status.h`, `firmware_version.h`).
*Live corroboration:* NONE yet — the IDENTIFY round-trip is H102.
Side-effect-freedom is a protocol property (read-only query), but the
H096 golden-map check after H102's 100 submissions is the live proof.

## 5. What H102 will NOT use

- **VDMA descriptor rings** (BAR2 engine, up to 16 channels): the studied
  transport describes descriptor lists (page-size/control field, DMA
  address low/high halves, remaining-bytes/status field) for bulk data
  movement, but H102's mailbox ping needs no DMA. Descriptor-ring
  programming is UNCORROBORATED live (BAR2 never mapped in C6) and
  belongs to H103's memory-copy op, not to the ping.
- **Firmware-control offsets at BAR0+0x0640 and up:** these "talk to the
  on-chip CPUs" per the H005 study but their command encoding was not
  documented by any study; H102 does not touch them — UNCORROBORATED,
  out of scope.
- **Queue-pair registers:** none exist; any design assuming a ring
  buffer + tail pointer is building on a false premise (this corrects
  the roadmap's H101 goal text, which predates the H005 findings).

## 6. Power-state precondition (live-corroborated)

In D3hot, all BAR0 reads return 0xFFFFFFFF (device asleep) —
CORROBORATED live (snapshot in D3hot vs D0, 2026-10-10). The standard
PCI PM-control transition (config offset 0xFC, PM capability at 0xF8;
write 0x2008 for D0, 0x200B for D3hot) is the C4/C5-established safe
practice. H102 must perform the mailbox session in D0 and return the
device to D3hot before rebinding the vendor driver.

## 7. Claim inventory (per acceptance criterion)

| Claim | Evidence | Status |
|-------|----------|--------|
| Control path is a single-slot mailbox, not a queue-pair | study (mailbox write/read path) + BAR4 window exists live | CORROBORATED (mechanism), offsets UNCORROBORATED live |
| Doorbell = u32 write at BAR4+0x1754 (10H), bit 0 = app CPU | study (board table, flag masks) + C5 soft-reset write survived | CORROBORATED (writability), command-doorbell UNCORROBORATED |
| Response at BAR4+0x0640, u32 length + payload | study (response-slot constant, read path) | UNCORROBORATED live |
| Completion = bit 26 of BAR0+0x018C (read-and-clear) | study (IRQ shift 24, flag bit 2) | UNCORROBORATED live (bit 23 idle value observed instead) |
| IDENTIFY (opcode 0, version 2, app CPU) is a side-effect-free ping | study (opcode table, packed layout, read-only semantics) | UNCORROBORATED live |
| VDMA descriptor-ring format for bulk transfer | study (H005 transport guide) | UNCORROBORATED live (not needed for H102) |
| 1000 ms completion timeout | study (default-timeout constant) | adopted as H102's bound |

**H101 verdict: PASS.** The document names every register and DMA
structure H102 needs, with offsets, widths, and per-claim evidence;
uncorroborated claims are marked as such. The roadmap's "ring buffer +
doorbell" premise is corrected to the mailbox model per evidence.
