# Task: Hailo-10H program lifecycle — one bounded physical observation run

Date: 2026-10-24. Roadmap Campaign 3, slice 3.3. This contract is
published and pushed BEFORE its diagnostic code exists. It admits
exactly ONE physical child on Mimir (Raspberry Pi 5) against the
real Hailo-10H. Its purpose is to buy the one observation
AES-PROG-001 left open — **what the receiver does after action-2
create metadata** (Q2, the payload phase) — under a pre-written
branch table. No branch improvises a payload send: how the bytes
travel is the question, not an assumption.

## The run

One fresh physical context, one diagnostic
(`smidr/tools/program_lifecycle_probe.mojo`, mode `physical-once`),
the aligned observer permitted, a single 20 s process-group
watchdog (`setsid`, `timeout -k 5 20`). Message ids are sequential
across the whole run on one grouped transfer session.

- **Phase A — device handle.** One CREATE exchange (device action
  20, empty body) through the Campaign 2 primitive with
  consumer-layer validation (the AES-TRANSFER-004 pattern). Gives
  this run's virtual-device handle. Failure here ends the run:
  nothing else is attempted.
- **Phase B — the observation.** One action-2 create-infer-model
  exchange through `SocProgram` (AES-PROG-002), declaring this
  run's staged payload: a deterministic 64-byte test pattern —
  **not a program, not numerical content** — whose digest is in the
  printed `ProgramIdentity`. Single 5000 ms exchange budget. Exactly
  one of three pre-written branches is taken, decided solely by
  what the receiver does:
  - **B1 — typed success reply** (status 0, infer handle present):
    the receiver answered metadata on this channel without first
    taking payload bytes over it. **No payload is sent** (its
    mechanics remain unestablished; attestation is never given).
    Admitted teardown on the same owners: destroy-infer (action
    3), then device DESTROY (action 21). Configure is NOT
    attempted. Infer-destroy failure is recorded and still admits
    the device destroy attempt.
  - **B2 — no reply** (deadline, transport failure, or a
    NOT_ACTIVE-class presentation): the receiver does not answer
    metadata alone on this channel — consistent with awaiting the
    separate phase before replying; stated as observation, not
    proof of mechanism. The owner is poisoned by law: **nothing
    further is attempted on it.** Local close only.
  - **B3 — typed refusal reply** (status != 0 or unparseable): the
    refusal class is recorded. Consumer law poisons the owner:
    nothing further is attempted on it. Local close only.
- **Residue, stated before the run:** B2 and B3 leave this run's
  virtual-device handle (and, in B3's case, possibly a partial
  server-side object) logically undestroyed — the same residue
  class as AES-CONTROL-018 and AES-TRANSFER-004, recorded, never
  hidden. The -018/-004 residue handles are NOT touched by this
  run. B1 destroys both handles it creates, if the receiver honors
  the destroys.

## Acceptance (of the experiment)

The run succeeds **as an observation** if: Phase A completes with a
validated reply; Phase B resolves to exactly one recorded branch
with sanitized evidence (branch, stage/error classes, descriptor
counts, snapshot counts — never handle values, wire bytes, or
serial-bearing data); in B1, both destroy attempts are made and
their outcomes recorded; local finalization is confirmed with
`retained_views == 0`. Campaign 3's exit condition (full lifecycle
including payload transfer and configure) is **not** claimed by
this contract under any branch.

## Host gates before the child (all on Mimir)

1. The diagnostic is qualified against the program oracle
   (`tests/group_program_rpc_aligned_faults.c`) in a derived suite:
   B1 (fixtures reply through create + destroy-infer + device
   destroy), B3 (action-2 reply carries status 7), B2 (IRQ `empty`
   fault drives the exchange to its deadline and poisons), plus
   Phase-A failure (device-create reply corrupted) admitting
   nothing further, and argument refusals with no owner.
2. Read-only profile gates immediately before the run (kernel,
   host page, PCIe vendor/device, `/dev/h1x-0`); the session's
   driver owner query must validate the 5.3.0 profile before
   allocation, as in -016/-018/-004.

## Hard exclusions

No action 4 (configure), no activation actions, no payload bytes
sent over any channel, no second child, no rerun, no other action
numbers, no model operation, no DFC, no vendor artifact. Any
failure — including an unexpected presentation — closes the batch
and is written up as AES-PROG-003 with PROVEN / NOT PROVEN.
