# One bounded physical exchange through the grouped transfer primitive: contract before code

Date: 2026-10-24. The minimal grouped transfer primitive is implemented
(AES-TRANSFER-002) and host-qualified (AES-TRANSFER-003, 11 tests /
574 runs, `docs/HAILO10H_GROUPED_TRANSFER_QUALIFICATION_2026-10-24.md`).
Parent roadmap: `docs/HAILO10H_YRSA_FINISH_LINE_ROADMAP_2026-10-24.md`,
Campaign 2 slice 2.4. Owner authorization for physical proof on the
real Hailo-10: Volmarr, 2026-10-24 21:00 EDT ("make sure to use the
real physical hailo 10 to test and prove stuff", with slices advancing
automatically thereafter). This is a narrow transport confirmation,
not a lifecycle completion, not model execution, and not numerical
configuration proof.

The AES-CONTROL-018 batch is CLOSED and is never rerun: its create
exchange completed physically, its identify was launched but reported
CHANNEL_NOT_ACTIVE on both channels, and its device-side handle was
not logically destroyed. This contract authorizes a NEW single child
exercising the PRIMITIVE (not the RPC client). Nothing else.

## What the one child does

Exactly ONE new physical child may own a fresh context and run **one**
grouped exchange through `SocGroupedTransfer.exchange_raw` on the
ALIGNED backing against the real device on Mimir:

- The packet is one control-class CREATE frame (action 20, empty
  body), supplied as raw bytes by the diagnostic; the primitive moves
  it framing-free, and the diagnostic's consumer layer validates the
  reply (frame decode, message id, action, status == 0) exactly as
  qualified under AES-TRANSFER-003, poisoning the owner on any
  framing failure.
- Input storage through the aligned path (header at map offset 0,
  body at the session descriptor page — observed policy 512 — extent
  2560); output scalar 2068; D2H posted before H2D; observed-return
  admission; the S4 sync sequence and S6 total deadline (single
  5000 ms budget after establishment) and snapshot law apply as
  host-qualified. An independent 20-second private-process-group
  watchdog with bounded TERM/KILL/reap wraps the child.
- The test-only aligned syscall observer
  (`tests/group_device_syscall_observer_aligned.c`, as qualified for
  AES-CONTROL-018) may observe the child; it must not alter requests,
  results or errno, inject faults, read device-owned pages, or add
  hardware calls. Outgoing bytes are captured before input
  device-sync; incoming bytes only after successful output CPU-sync.

## Known residue, stated before the run

A successful CREATE creates a device-side handle. This contract
admits **one exchange only**: no identify and no destroy are sent,
so the handle is **not** logically destroyed under this contract —
the same residue class already recorded for AES-CONTROL-018. The
full lifecycle remains Campaign 1's unfinished business under a
future contract of its own. File this residue in the write-up;
do not expand this contract to chase it.

## Profile gates (checked read-only before admitting DMA)

Record fresh installed kernel/module identity and driver/device
properties first. Expected profile, from AES-CONTROL-016/-018:
driver 5.3.0, HAILO10H PCIe (vendor 0x1e60, device 0x45c4), one DMA
engine, firmware loaded, host page 16384, descriptor page 512,
kernel 6.12.112-v8-16k-hailo+. Any mismatch stops before launch.
Never reset/rebind/change firmware, module, kernel or configuration.
Mock values are not physical profile evidence.

## Acceptance

Acceptance requires ALL of: the exchange completes; both launch
returns are the observed descriptor count 5; distinct assigned
directional completions are observed before CPU access; the reply
passes consumer-layer validation (exact frame id/action, status 0,
typed create body present); the owner is not poisoned; retained
views == 0; local finalization confirmed. The diagnostic prints no
handle, identity-bearing wire, serial or logger value; complete raw
wire evidence stays local on the device, with only hashes and
sanitized facts published.

## Failure discipline

A timeout, unexpected result, NOT_ACTIVE/ERROR record presentation,
uncertain close, or any refusal ends the physical batch with NO
repeat and NO follow-on physical child. The result — success or
failure — is written up as its own evidence document with
PROVEN / NOT PROVEN, a ledger row, TODO/progress/roadmap updates,
and a report to the owner. Success qualifies only this exact single
exchange through the primitive on the observed profile; it is not a
lifecycle, not numerical execution, and must never be described as
such.

## Host gates before the child

The physical diagnostic for the primitive must be qualified on host
mocks first, on the Pi (its 16384 page gate is the Pi profile):
paired current/frozen comparisons against the qualified aligned
device oracle for the single-exchange scenario, the aligned observer
capturing the outgoing gathered wire and the reply, argument
refusals with no owner, and the consumer-layer poison path for a
corrupted reply. No physical run occurs until these gates pass.

No action 2/action 17, prepare/cancel, program transfer/activation,
arithmetic opcode, register write, model loading, numerical
operation or LLM inference. No DFC, outside compiler/machine,
vendor-precompiled prerequisite or CPU/CUDA/cloud/proxy inference.
