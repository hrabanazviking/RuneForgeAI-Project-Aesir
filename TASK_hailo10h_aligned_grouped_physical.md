# One bounded physical grouped lifecycle on aligned backing: contract before code

Date:2026-10-24. Host qualification for the aligned grouped backing is
published as AES-CONTROL-017 (`docs/HAILO10H_ALIGNED_GROUPED_CONTROL_2026-10-24.md`,
branch `yrsa/finish-line-roadmap` at 6d60d014). Parent roadmap:
`docs/HAILO10H_YRSA_FINISH_LINE_ROADMAP_2026-10-24.md`, Campaign 1 slice 1.4.
Owner authorization for physical proof on the real Hailo-10: Volmarr,
2026-10-24 21:00 EDT ("make sure to use the real physical hailo 10 to test
and prove stuff", with slices advancing automatically thereafter). Owner
fixed scope remains broad ordinary UNMODIFIED source-model support 100%,
with Aesir-owned Mojo loading, conversion, lowering, device generation and
execution. This is a narrow transport experiment, not model execution or
numerical configuration proof.

The prior physical batch (AES-CONTROL-016) is CLOSED and is never rerun: one
child, D2H scalar return 5, H2D two-span launch EINVAL at map offset 20
against descriptor page 512. This contract authorizes a NEW single child on
the ALIGNED backing built under AES-CONTROL-017. Nothing else.

## What the one child does

Exactly ONE new physical child may own a fresh context and run the typed
grouped lifecycle `run_group_device_aligned` (create 20, identify 22,
destroy 21) against the real device on Mimir, with:

- Input storage allocated through the aligned path: header at map offset 0,
  body at map offset equal to the session descriptor page (observed policy
  512), mapped extent page + 2048 (2560 under the observed policy). Output
  storage stays the scalar 2068 legacy layout; D2H stays scalar 2068;
  the H2D grouped launch carries the two aligned spans.
- CPU-owned scatter before input device-sync and gather after output
  CPU-sync, exactly as host-qualified; the 2068-byte logical wire is
  unchanged. Capture outgoing bytes before input device-sync and incoming
  bytes only after successful output CPU-sync; never read device-owned
  pages.
- One 5000 ms lifecycle admission budget after establishment and an
  independent 20-second private-process-group watchdog with bounded
  TERM/KILL/reap. Do not reset budget between phases. Synchronous kernel
  calls are not forcibly preempted by userspace deadlines.
- The existing test-only direct-syscall observer
  (`tests/group_device_syscall_observer.c`, as qualified under
  AES-CONTROL-016) may observe the child; it must not alter requests,
  results or errno, inject faults, derive descriptor counts, read
  device-owned pages, or add hardware calls.

## Profile gates (checked read-only before admitting DMA)

Record fresh installed kernel/module identity and driver/device properties
first. Expected profile, from AES-CONTROL-016's recorded observation:
driver 5.3.0, HAILO10H PCIe (vendor 0x1e60, device 0x45c4), one DMA engine,
firmware loaded, host page 16384, descriptor page 512, kernel
6.12.112-v8-16k-hailo+. Expected typed identity: protocol 2, architecture 6,
firmware 5.3.0 (checked after bounded typed cleanup). Any mismatch stops
before launch. Never reset/rebind/change firmware, module, kernel or
configuration. Mock values are not physical profile evidence.

## Acceptance

Normal success is exactly three exchanges. Require actual positive launch
returns below the allocated 65536 ring as the admitted policy, distinct
assigned directional completions before CPU access, exact frame ID/action/
status and the existing typed body parsers. Track handle presence
separately from zero; mark destroy attempted before send; never retry a
possibly completed destroy. At most one logical destroy cleanup is
admitted, only for a valid known handle, healthy transport, remaining
budget and no previous destroy attempt; no guessed handle or poisoned
reuse. Acceptance requires: success, identity matched, attempts == 3, no
poison, no retained views, finalization confirmed. The probe diagnostic
(`smidr/tools/group_device_probe_aligned.mojo`, mode `physical-once`)
prints no handle, identity-bearing wire, serial or logger value; complete
raw wire evidence stays local on the device and in the local evidence
store, with only identities/hashes and sanitized facts published.

## Failure discipline

A timeout, unexpected result, uncertain close, or any refusal ends the
physical batch with NO repeat and NO follow-on physical child. Preserve
backing/fd retention on uncertainty and report unconfirmed logical/file/
hardware cleanup honestly. Successful file close is not all-failure
hardware-idle or remote-close proof. The result — success or failure — is
written up as its own evidence document with PROVEN / NOT PROVEN, a ledger
row, TODO/progress/roadmap updates, and a report to the owner. A success
here qualifies only this exact control lifecycle on the observed profile;
it is not numerical execution and must never be described as such.

## Host gates before the child

The aligned probe diagnostic and the observer must be qualified on host
mocks first (aligned device oracle; full paired stdout/stderr/exit
comparisons; independent protobuf/UAPI oracles; argument refusals with no
owner). No physical run occurs until these gates pass. Do not run any old
physical test or reuse the completed map-only or -016 batches as a
baseline.

No action 2/action 17, prepare/cancel, program transfer/activation,
arithmetic opcode, register write, model loading, numerical operation or
LLM inference. No DFC, outside compiler/machine, vendor-precompiled
prerequisite or CPU/CUDA/cloud/proxy inference.
