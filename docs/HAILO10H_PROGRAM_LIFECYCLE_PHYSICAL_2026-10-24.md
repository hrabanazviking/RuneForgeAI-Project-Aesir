# Program lifecycle — one bounded physical observation run (2026-10-24)

Contract: `TASK_hailo10h_program_lifecycle_physical.md` (published
at b34e11e1 before code; one refinement recorded in it before code).
Roadmap Campaign 3, slice 3.3 (AES-PROG-003). Exactly ONE physical
child ran on Mimir against the real Hailo-10H. **Result: the
experiment is ACCEPTED, and the observation is branch B2 — the
receiver does not answer create-infer-model metadata alone on this
channel.**

## Host gates on the Pi (all green before the child)

- Diagnostic `smidr/tools/program_lifecycle_probe.mojo` (at
  ab3ddbb3), qualified by `tests/test_hailo_program_lifecycle_probe.py`
  against the program oracle: **6 tests OK** — the full B1 branch
  (create → destroy-infer → device destroy, observer wires
  byte-identical to independent fixtures), B3 (typed refusal), B2
  (phase-targeted IRQ silence driving the exchange to failure),
  Phase-A failure admitting nothing further, close faults blocking
  acceptance, argument refusals. Qualification history retained in
  the run record: the B2 scenario first silenced Phase A as well
  (the run stopped correctly at the 32-snapshot cap — Campaign 2's
  S6 law corroborated on a new path), and the oracle's phase
  selector needed one off-by-one correction (phase counts the
  exchange by its wait stage); both fixes were in the test
  harness/oracle, not the code under test.
- Read-only profile gates re-checked immediately before the run:
  kernel `6.12.112-v8-16k-hailo+`, page 16384, PCIe `0x1e60`/`0x45c4`,
  `/dev/h1x-0`; the session's driver owner query validated the
  5.3.0 profile before allocation, as in -016/-018/-004.

## The one physical child

`program_lifecycle_probe physical-once`, fresh context, `setsid` +
`timeout -k 5 20`, aligned observer preloaded (capacity 512).
Returned **rc=0** (experiment accepted). Sanitized result (no
handle, wire or serial values printed; the ProgramIdentity line
preceded it in stdout):

```json
{"accepted":true,"physical_mode":true,"branch":"B2",
 "phase_a_ok":true,"infer_destroy_attempted":false,
 "infer_destroyed":false,"vdevice_destroy_attempted":false,
 "vdevice_destroyed":false,"poisoned":true,"retained_views":0,
 "finalization_unconfirmed":false,"close_failed":false,
 "exchanges":1,"snapshots":5}
```

Observer: 68 calls used, 0 dropped, `owner_at_exit` −1. Evidence
hashes (raw records stay local on the Pi under
`~/aesir-build/physical-program-2026-10-24/`): probe stdout sha256
`ce08053b6e9ae3c0cfc0490573d3da775b0052de6523a0b9967e944f6005aa2d`;
observer log sha256
`2ae02969a2398293e3fe3e0fee920d2aefd91766acff1401d2e31652677fdac9`.

## PROVEN

- PHYSICALLY VERIFIED: Phase A — a fresh device CREATE exchange
  completed and validated on the real profile (the run's one
  completed exchange), as in AES-TRANSFER-004.
- PHYSICALLY VERIFIED (the B2 observation): after valid action-2
  create-infer-model metadata was launched on the grouped channel,
  **no reply became CPU-visible and the exchange did not
  complete** — 5 interrupt snapshots total across the run, no
  directional completion credited for Phase B, the owner poisoned
  by law and made no further attempt. The whole child finished
  far inside its 5 s exchange budget, so the failure presented
  promptly rather than as a silent hang. This is consistent with
  the AES-PROG-001 interface finding — the receiver reads the
  separate program-bytes phase before answering — and it rules
  out the B1 possibility that metadata alone earns a reply on
  this channel. It also was not B3: no refusal status arrived.
- Local finalization confirmed, zero retained views, device fd
  closed (observer), as contracted.

## NOT PROVEN

- The payload phase's mechanism: B2 does not establish *how* the
  receiver takes the program bytes (a follow-on transfer on this
  channel, a differently framed phase, or another path), nor the
  exact interrupt-record class behind Phase B's failure (the
  diagnostic does not capture it and does not claim it). Whether
  the metadata was queued server-side awaiting bytes, or rejected
  silently for another reason, is likewise not established.
- Any program object: no infer handle was obtained, no payload was
  sent (per contract), no configure/activate/destroy of a program
  object was exercised. Campaign 3's exit condition is **not**
  met.
- Residue, as pre-stated in the contract: this run's Phase-A
  virtual-device handle was **not** logically destroyed (B2
  branch). It joins the recorded residue class of AES-CONTROL-018
  and AES-TRANSFER-004.

## Next gate

The payload question moves from observation to source study:
Research Track R lane A/B on the receiver's create-infer-model
read path in the pinned public sources, to pin the phase's
mechanics (channel, framing, chunking) as a specification. Only
then can a successor contract admit sending the staged payload.
Slice 3.4 (failure teardown) proceeds host-side in the meantime:
the partial-creation paths this run could not reach are already
exercised against mocks under AES-PROG-002's gates; 3.4
contracts and extends that coverage.
