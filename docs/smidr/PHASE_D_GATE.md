# Phase-D Gate (H111) — The Wall Verdict

**Date:** 2026-10-10
**Campaign:** 6 (SMIÐR / The Wall), slices H101–H120
**Gate:** H111 — Phase-D go/no-go decision gate

## Evidence table (H101–H110)

| Slice | Verdict | Evidence |
|---|---|---|
| H101 — Command-queue mechanism research | **PASS** | `docs/plunder/HAILO_COMMAND_QUEUE.md`: mailbox model (corrects the ring-buffer premise), doorbell BAR4+0x1754, completion bit 26 of BAR0+0x018C, IDENTIFY opcode 0 / protocol v2, per-claim CORROBORATED/UNCORROBORATED marking, live BAR probing on Mimir. |
| H102 — Command-submission transport via HAILBRÚ | **FAIL** | `docs/smidr/H102_ATTEMPT_RECORD.md` + `data/smidr/first_command_trace.json`. `smidr/mailbox.mojo` + `smidr/tools/mbping.mojo` (100× IDENTIFY design, 1:1 accounting). On Mimir via UIO: command writes land (readback-verified), doorbell offset correct, firmware **completely silent** — no completion bit, no MSI, no response — across 5 hardening attempts + vendor-ioctl attempt + final core-doorbell probe. |
| H103 — Minimal command descriptor builder | **PASS** | `smidr/descriptor.mojo` (pure Mojo, built+run on Mimir): no-op (byte-exact IDENTIFY), memory-copy (studied VDMA field set), vector-add (tensor descriptors + explicit UNKNOWN compute sentinel). Independent TEST-ONLY checker `prof/smidr/check_descriptors.py`: all checks passed. 5/5 malformed inputs fail closed with named `BadDescriptor`. Emitted bytes in `data/smidr/descriptors.json`. |
| H104 — Vector-add configuration generator | **PASS** | `smidr/config_gen.mojo` (pure Mojo, built+run on Mimir): deterministic seeded xorshift64, 64×fp16 exact values, SMIÐR-CFG v1 format traceable to H019 manifest (new section in `docs/plunder/HAILO_CONFIG_SURFACE.md`, elements 2+12). Independent TEST-ONLY validator `prof/smidr/check_vecadd_config.py`: golden values byte-exact, a+b exact, schema conformant, no magic bytes — all passed. Determinism proven (2 runs, seed 12345, byte-identical). Golden vectors in `data/smidr/vecadd/`. Chip executability honestly marked UNPROVEN. |
| H105 — First compute attempt | **BLOCKED** | `docs/smidr/H105_ATTEMPT_RECORD.md`: blocked on H102 — no proven transport exists to submit through. Analysis of what the attempt would need (H019 elements 1,3,4,5,6,7) recorded. Nothing faked. |
| H106 — First chip computation (vector-add) | **BLOCKED** | Requires H105 (strict-serial). No transport → no submission → no computation. |
| H107 — Bit-exact verification vs ARMVEGR | **BLOCKED** | Requires H106 PASS (strict-serial law, roadmap line 261). |
| H108 — Tiny matmul | **BLOCKED** | Strict-serial chain broken at H105. |
| H109 — 1000× repeatability suite | **BLOCKED** | Strict-serial chain broken at H105. |
| H110 — Repeatability analysis | **BLOCKED** | Requires H109 PASS (strict-serial law). |

## PHASE D VERDICT

**NO-GO**

Decision rule (roadmap line 330): GO iff H106 PASS **and** H109 PASS **and**
H110 PASS (all three, documented). H106 is BLOCKED, H109 is BLOCKED, H110
is BLOCKED. The rule forces NO-GO. No third option, no hedging.

## Written technical account of the blocking finding

**What was tried.** SMIÐR built a faithful, study-derived firmware-mailbox
implementation in pure Mojo (`smidr/mailbox.mojo`): length-prefixed command
slot at BAR4+0x0000, doorbell at BAR4+0x1754, completion polled on bit 26
of BAR0+0x018C, response at BAR4+0x0640, IDENTIFY as version 2 / opcode 0
— every constant cited to the clean-room studies (H101 §4). On Mimir, via
the proven UIO path (hailo1x unbind → uio_pci_generic bind → D0 → bus
mastering), the submission sequence was executed with five hardening
variants: write-ordering barrier (Normal-NC), 32-bit stores with readback,
bus-mastering re-enable, driver interrupt-enable replication, 5 s timeout.
A final probe tried the documented core doorbell (0x2).

**What the chip did.** Command writes land in the BAR4 slot
(readback-verified: BAR4+0x0000=0x8, +0x4=0x2, +0x8=0x0). The doorbell
offset is correct (C5 proved BAR4+0x1754 live via soft-reset). Then:
nothing. No completion bit, no MSI on /dev/uio0, no response bytes — on
both doorbell targets, at every timeout up to 5 s. The vendor driver's own
diagnostic ioctl rejects raw commands ("not supported on integrated
device type"). The device itself is healthy (golden register map clean,
D3hot + hailo1x restored after every session).

**Why the path is judged intractable within campaign bounds.** The wall
has two faces, and both held:

1. **Transport face (H102):** the firmware's control service does not
   answer. Without a command round-trip, no configuration — however
   well-formed — can be submitted. Every legitimate avenue is exhausted
   (both doorbells, all hardening variants, vendor ioctl).
2. **Encoding face (H019 elements 1,3,4,5,6,7):** even with transport,
   SMIÐR knows the tensor descriptors (element 2) but not the operation
   encoding (element 1, marked by the honest 0xFFFFFFFF sentinel), nor the
   SRAM allocation, scheduling, or handshake elements. Learning them
   requires the firmware dialogue that face 1 denies, or the proprietary
   dataflow compiler, which is out of scope by law (L5).

**What the assault did yield.** H101's corrected mailbox model, H103's
fail-closed descriptor builder, and H104's deterministic SMIÐR-CFG v1
generator are genuine, tested, honest artifacts — host-side infrastructure
that any future attempt (with a responding firmware or a learned encoding)
can build on. They are banked under F3 (H118).

## Downstream routing

Per the routing table (roadmap §5): H112/H113/H114 SKIP; **H115–H119 RUN**;
H120 RUN (NO-GO-flavored). C7–C10 execute in CPU-only F1 mode; H121–H135,
H171, H172, H184 SKIP per the table.

---
*Verdict dated 2026-10-10, signed in DEVLOG (H111). All downstream slices
check this verdict value.*
