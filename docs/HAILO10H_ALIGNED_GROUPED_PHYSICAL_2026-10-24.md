# Aligned grouped lifecycle — one bounded physical attempt (2026-10-24)

Contract: `TASK_hailo10h_aligned_grouped_physical.md` (published at 7bcfd81c
before code). Branch: `yrsa/finish-line-roadmap`. This document is also the
roadmap slice 1.5 report for this attempt. Probe sources at 4448a7e5;
aligned observer variant at a8a4f415. Exactly ONE physical child ran, on
Mimir (Raspberry Pi 5) against the real Hailo-10H. The batch is now
**CLOSED**: no repeat and no follow-on physical child under this contract.

## Host gates on the Pi (all green before the child)

The probe's profile gate (host page 16384) is the Pi's profile, so host
qualification ran on Mimir itself, exactly as the AES-CONTROL-016
qualification evidently did.

- Pinned UAPI header `hailo_ioctl_common.h` (public hailo-ai/hailort-drivers
  tree 45e5fc53, driver 5.3.0) transferred to the Pi and verified:
  sha256 `a2731314f4676cb140b970043d53cc06d57da90ea46344ccd44a3c491aede26b`
  (22,819 bytes), identical to the VM copy used for the host oracles.
- Probe built on the Pi with its Mojo 1.1.0 (8189361e) toolchain (the VM
  host suites used Mojo 1.0.0); observer, aligned faults library and
  passthrough fixture built with the Pi's gcc against the pinned header.
- `tests/test_hailo_group_device_probe_aligned.py` on the Pi: **7 tests
  OK** (14.9–16.8 s across runs). First run with the AES-CONTROL-016
  observer failed test_01: that observer keys its captures on the legacy
  2068 geometry (input view size 2068, sync count 2068), so over aligned
  backing it captured only the replies. A test-only aligned variant
  (`tests/group_device_syscall_observer_aligned.c`) registers an aligned
  input extent (2048 + a power-of-two descriptor page in [64, 32768]) and
  gathers the outgoing logical wire (header 20 at 0, body 2048 at
  extent−2048) at the FOR_DEVICE sync boundary; with it the suite passes
  in full, including all six wire captures, fault, logging-failure,
  overflow and errno-passthrough cases. The -016 observer is untouched.
- Read-only profile gates before DMA: kernel `6.12.112-v8-16k-hailo+`,
  host page 16384, PCIe vendor `0x1e60` / device `0x45c4` at
  0001:01:00.0, `/dev/h1x-0` present (char 508:0). The probe's own driver
  owner query validated driver 5.3.0, HAILO10H, one DMA engine and
  firmware-loaded before allocation, as in -016.

## The one physical child

`group_device_probe_aligned physical-once`, fresh context, under
`setsid` with an independent `timeout -k 5 20` process-group watchdog and
the aligned observer preloaded (capacity 512). Returned rc=1 in ~0.16 s.
Sanitized probe result (the diagnostic prints no handle, wire, serial or
identity-bearing value):

```json
{"accepted":false,"physical_mode":true,"identity_matched":false,
 "handle_known":true,"destroy_attempted":false,"destroy_confirmed":false,
 "cleanup_attempted":false,"attempts":2,"primary_error":true,
 "cleanup_error":false,"close_error":false,"poisoned":true,
 "retained_views":0,"finalization_unconfirmed":false}
```

Observer record: 68 calls used, 0 dropped, `owner_at_exit` −1 (device fd
closed). Evidence hashes (raw records stay local on the Pi under
`~/aesir-build/physical-aligned-2026-10-24/`): probe stdout sha256
`349fde50d8b18ec50be619714870772a51b7b9b606dcc526e0722670a0efafcc`;
observer log (36,933 bytes) sha256
`4b2a0c2aa8373bba2e3fad7b30c593fe68f94eda521a609d9e93f25b1397a287`.

### What the observer saw

- **CREATE (20) completed end-to-end.** The aligned observer gathered the
  outgoing request at the input FOR_DEVICE sync; both launches returned
  the positive count **5** (D2H scalar and H2D grouped — the -016 EINVAL
  is gone); three interrupt waits returned successfully; the reply was
  captured only after the output CPU-sync: an exact typed create reply
  (length 4, action 20, status 0) carrying a real device handle
  (`handle_known: true`; the value is not published).
- **IDENTIFY (22) was launched but did not complete.** The request wire
  was gathered at sync; the D2H scalar launch returned **5**; the H2D
  grouped launch returned **5** with the two spans at storage+0 (20
  bytes) and storage+512 (2048 bytes) in the actual launch parameters.
  Two interrupt waits then returned successfully, but the distinct
  directional completions the client requires were not established
  within its progress snapshots: no output CPU-sync followed and no
  reply became CPU-visible. The client declared a primary error and
  poisoned the transport. (Addendum, decoded during the slice 2.1
  extraction against the pinned UAPI: identify's second wait reported
  `data = 0xFF` — CHANNEL_NOT_ACTIVE — for **both** owned channels,
  0 (input) and 16 (output). 0xFF is a failure indication under the
  UAPI defines, never a completion count; whether the transfers had
  completed device-side before the channels went inactive is not
  established. See `docs/HAILO10H_GROUPED_TRANSFER_SEMANTICS_2026-10-24.md` §S6.)
- **Failure discipline behaved exactly as contracted.** On a poisoned
  transport the client attempted **no** destroy (cleanup destroy is
  admitted only for a healthy transport), retained no views
  (`retained_views: 0`), and finalized locally: interrupt disable,
  channel close, descriptor release and unmaps all returned 0, the
  device fd closed, and finalization is confirmed
  (`finalization_unconfirmed: false`, `close_error: false`).
  Successful local close is not hardware-idle or remote-close proof,
  and no such claim is made: the device-side handle created by exchange
  1 was **not** logically destroyed.

## PROVEN

- PHYSICALLY VERIFIED: the real 5.3.0 driver **accepts** the aligned
  H2D grouped launch (positive return 5, twice — create and identify).
  The AES-CONTROL-016 span-offset rejection is answered: USERPTR spans
  at map offsets 0 and 512 are admitted where offset 20 was refused.
- PHYSICALLY VERIFIED: one complete grouped control exchange (CREATE)
  over Aesir's Mojo owner on the physical Hailo-10H — aligned scatter,
  grouped launch, directional interrupt completion, CPU-sync gather,
  exact typed reply, real handle.
- PHYSICALLY VERIFIED: the client's conservative failure law on real
  hardware — poison on an incomplete exchange, no destroy on a poisoned
  transport, zero retained views, confirmed local finalization.

## NOT PROVEN

- The full grouped lifecycle: IDENTIFY's reply completion and typed
  identity match did not occur, DESTROY was not attempted, and the
  contract's acceptance (success, identity matched, attempts == 3, no
  poison) **failed**. Campaign 1's exit condition is **not** met.
- Why identify's completions did not both become visible is not
  established by this evidence; the wait records alone do not prove a
  cause, and none is claimed.
- Nothing here establishes numerical configuration, packing, placement,
  program execution, or source-model support. A completed create
  exchange is control transport evidence only.

## Next gate

This batch is closed. Any further physical lifecycle attempt requires a
NEW one-shot contract (and, under the owner's standing orders, is taken
as its own roadmap step — never as a rerun of this one). Host-side work
continues with Campaign 2 slice 2.1: extract the transfer semantics
this evidence actually establishes (span description, positive launch
return, per-direction completion evidence, cache-sync points, ownership
until completion, late-completion quarantine) — on these facts only.
