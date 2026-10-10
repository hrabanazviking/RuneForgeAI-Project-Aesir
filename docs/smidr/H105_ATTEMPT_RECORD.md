# H105 — First Compute Attempt: Attempt Record

**Date:** 2026-10-10
**Slice:** H105 (Campaign 6, SMIÐR / The Wall)
**Verdict:** **BLOCKED** — no compute was attempted, and none is claimed.

## What H105 asked

"Document the first compute attempt honestly: attempt to submit the
vector-add command through the proven transport (H102), document what
happened, and analyze whether the descriptor format needs the actual
compute encoding. If H102 transport is blocked, then H105/H106 are blocked
too — mark them BLOCKED rather than faking a result."

## What happened

H102's transport proof **failed**: the firmware mailbox accepts command
writes (readback-verified) but the firmware never responds — no completion
bit, no MSI, no response bytes, across every hardening attempt (see
`docs/smidr/H102_ATTEMPT_RECORD.md`). The "proven transport" H105 requires
does not exist. Per the slice's own acceptance criteria, H105 is therefore
**BLOCKED**, and H106 with it. Nothing was submitted to the chip; no
partial or simulated result is presented as an attempt.

## Analysis: what the attempt would need

Even with a working transport, the H104 vector-add configuration is not
chip-executable. Per the H019 surface survey, a chip-executable
configuration needs all of elements 1–7; SMIÐR-CFG v1 provides only:

| H019 element | SMIÐR status |
|---|---|
| 1. Operation descriptors (compute encoding) | **UNKNOWN** — the 0xFFFFFFFF sentinel in the H103 vecadd descriptor marks exactly this gap |
| 2. Tensor descriptors | Provided (fp16, 64, contiguous-1d) |
| 3. Memory allocation directives | Unknown (on-chip SRAM arena layout) |
| 4. Data-movement programs | Field set studied; chip-side BAR2 programming uncorroborated |
| 5. Scheduling / ordering | Unknown |
| 6. Completion signaling contract | Partially studied (bit 26 of BAR0+0x018C); never observed live |
| 7. Firmware handshake preamble | **BLOCKED** — this is the H102 failure |

The descriptor format question the slice poses — "does the descriptor
format need the actual compute encoding?" — is answered **yes**: element 1
is the load-bearing unknown. SMIÐR's honest position (H103/H104) is that
the compute section carries an explicit UNKNOWN sentinel rather than
fabricated bytes. Filling it requires learning the chip's operation
encoding, which requires a working firmware dialogue (H102) or the
proprietary dataflow compiler — the former is blocked, the latter is
out of scope by law (L5 clean-room, no vendor toolchain).

## Alternative avenues considered and closed

1. **VDMA direct (BAR2):** the exact chip-side descriptor byte layout is
   uncorroborated and the channel-programming sequence unknown;
   programming the DMA engine blind risks wedging it, and success would
   still not yield the compute encoding (element 1).
2. **Vendor driver ioctl:** `/dev/h1x-0` rejects raw FW_CONTROL
   ("not supported on integrated device type") — tried in H102.
3. **Simulating the attempt:** would be fakery; the honesty law forbids it.

## Verdict

**H105: BLOCKED** (blocked on H102). No compute attempted. The H103/H104
artifacts stand as honest host-side work products; the wall between them
and chip execution is documented, not crossed by pretense.
