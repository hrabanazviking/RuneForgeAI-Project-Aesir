# Program-object lifecycle — host implementation and qualification (2026-10-24)

Roadmap Campaign 3, slice 3.2 (AES-PROG-002). Implements the
AES-PROG-001 interface as an original Mojo owner over the Campaign 2
primitive. **Host qualification only — no physical run.** The created
handle residue of AES-CONTROL-018 / AES-TRANSFER-004 is untouched by
this slice.

## What was built

- `hailbru/soc_program.mojo` — `SocProgram`: the program-object
  lifecycle owner, composing the already-qualified codecs
  (`hrpc_program`, `hrpc_configure`) over `SocGroupedTransfer`
  (composition, not modification; the primitive and the Campaign 1/2
  evidence sources are untouched). Stages: create (action 2) →
  payload attestation gate → configure (action 4) → activate (10) /
  deactivate (11) → shutdown (12) → destroy-configured (5) →
  destroy-infer (3), with strictly increasing message ids and
  consumer-layer reply validation on every stage (any framing
  failure poisons owner and transport before state advances —
  AES-TRANSFER-003 law).
- `ProgramIdentity` — the roadmap's seven-field record (source
  digest, compiler version, target-profile digest, numerical-plan
  digest, placement digest, encoded-program digest,
  transport-metadata digest) with a deterministic printed form,
  emitted by the diagnostic before any exchange.
- The two AES-PROG-001 unknowns are **fail-closed laws**, not
  defaults: configure **refuses** until the caller attests delivery
  of exactly the identity's encoded-program digest (the payload
  phase's transport mechanics are NOT ESTABLISHED; this owner never
  moves program bytes and never fabricates delivery); teardown
  order is enforced conservatively client-side — destroy-configured
  refuses before shutdown, destroy-infer refuses while a configured
  object lives — because the receiver's own ordering is NOT
  ESTABLISHED.
- `smidr/tools/program_mock.mojo` — scenario diagnostic: the full
  seven-stage lifecycle plus six refusal scenarios (no-attest,
  bad-attest, early-configure, early-destroy, double-create,
  teardown-order), printing the identity line and a sanitized JSON
  result; any unaccepted scenario exits nonzero.
- `tests/group_program_rpc_aligned_faults.c` — a NEW test-only
  oracle. The AES-CONTROL-018 device oracle is hardcoded to the
  device lifecycle sequence (actions 20/22/21, sequence < 4) and
  aborts on program actions — a property of that qualified oracle,
  recorded here so no future slice rediscovers it. The new oracle
  keeps the -017 aligned group oracle's transport skeleton
  (identical ioctl emulation, sync/launch/IRQ/close fault knobs)
  and takes its replies from per-message-id fixtures
  (`AESIR_PROGRAM_REPLY<mid>`) that the suite computes independently
  in Python from the pinned public field contract — an independent
  reimplementation of the two codecs' wire forms.

## Qualification (on Mimir, Mojo 1.1.0)

`tests/test_hailo_program_mock.py`: **8 tests OK, 116 runs, zero
physical calls.** Coverage: the full lifecycle with observer wires
byte-identical to the independently computed fixtures at all seven
stages (requests and replies); all six fail-closed gates refusing
at the exact stage/exchange counts the design specifies; crafted
reply corruption (id at create; status and action at configure)
poisoning the owner; sync/launch faults poisoning; close faults
blocking acceptance with all seven stages complete; observer
logging failure/overflow inert; errno passthrough; argument
refusals with no owner.

Qualification history (failures retained): the first Pi run failed
5 of 8 tests, all aborts inside the AES-CONTROL-018 device oracle —
root-caused to its hardcoded lifecycle sequence asserts (above)
and resolved by the dedicated program oracle, not by changing the
code under test. The second run passed 7 of 8; the remaining
failure was the diagnostic exiting 0 on expected-refusal scenarios,
fixed by the uniform unaccepted-exit law.

## NOT PROVEN

- Everything physical for program actions: no program byte has been
  sent to the device; the action-2 exchange's payload phase, the
  receiver's teardown ordering, and structural acceptance of any
  program object remain unproven (slice 3.3's contract, which must
  first settle how the payload phase is observed).
- All numerical content, as ever.

## Next gate

Slice 3.3: a one-shot physical contract for the program lifecycle.
Its design must begin from the payload-phase question (AES-PROG-001
Q2) — most likely as a bounded observation of what the receiver
does after action-2 metadata — before any program byte is staged.
