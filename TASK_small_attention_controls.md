# Task: Optional Small-Score Strategy5 Cooperative Controls and Recovery

## Authorization and scope

Volmarr authorized the 500-slice AESIR program and immediate continuation through
well-defined slices. This task is the current strategy5 frontier identified in
`ROADMAP_AESIR_SPEED_LEAD.md` section 6 and `ROADMAP_AESIR_500_SLICES.md`.
It authorizes a default-false strategy5 control capability, its focused test and
source-bound evidence path, and synchronized documentation. It authorizes no
production selection, speed claim, deletion, or change to strategies 0–4.

## System statement

The small-score strategy5 fixture passes narrowly scoped complete-model,
causal-generation, and sealed owning-context replay gates. Strategy5 cannot yet
use cooperative timeout, cancellation, reset, and recovery. Existing controls
for strategy4 are separately admitted; strategy5 currently rejects them.

## Owning domain and files

- `aesir_engine/tests/turing_prefill_fixture.mojo` owns the test-fixture
  capability contract, request checkpoints, tile transaction boundary and reset.
- New focused Mojo collector(s) under `aesir_engine/tests/` own disabled-mode and
  abort/recovery observations; existing source-bound collection remains isolated.
- New Python checker/supervisor under `scripts/` owns hostile input, source and
  artifact admission, failure retention and evidence output. It does not execute
  inference or substitute a compute provider.
- `aesir_engine/tests/INTERFACE.md`, `scripts/INTERFACE.md`, `TODO.md`,
  `ROADMAP_AESIR_SPEED_LEAD.md`, `README_AI.md`, `CAPABILITY_LEDGER.md`,
  `DEVLOG.md` and a new `docs/NATIVE_SMALL_ATTENTION_CONTROLS.md` are updated only
  after the exact behavior/evidence exists.

## Desired outcome

1. An explicit `small_controls=False` capability is required before strategy5 may
   enable the existing cooperative control machinery.
2. Constructor/runtime/replay admission rejects unsupported combinations before
   model loading, owner mutation, sampler configuration or GPU enqueue.
3. A fresh capable-but-disabled strategy5 owner reproduces the accepted model5
   complete output/state/cache/counter/guard/CPU-quality gate.
4. Pre-expired deadline, cooperative mid-tile timeout, owned cancellation and
   invalid-descriptor abort preserve allocations, leave the aborted tile
   uncommitted, require explicit reset before reuse, and recover the exact
   accepted source vectors.
5. An observer exception poisons health and refuses reuse/reset. Known synchronized
   aborts and poisoned failures remain distinct.
6. Evidence binds the accepted strategy5 source CSV/report/binary, actual current
   source/binary, model/reference provenance, complete cache, IDs, sampler history
   and draws, actual counters, signal mask, guards, and pre/post artifact hashes.
7. Ordinary runtime remains on the previously admitted path; enabled-control time
   is unscored and strategy5 remains an explicit test fixture.

## Invariants

- Capability defaults false. Normal model/service selection and strategy0–4
  behavior do not change.
- Control and tracing capabilities remain mutually exclusive; control-capable
  replay remains separately gated unless its seal/admission contract is extended
  and independently accepted.
- No aborted tile commits tokens, cache position, sampler state or pending IDs.
- Explicit reset is required after a known abort; poison is not cleared by reset.
- Admission refusal is mutation-free. Allocations and unrelated owner state remain
  stable on refusals.
- No assertion relies solely on a success Boolean or caller-provided label.
- Synthetic controls prove local contracts only; physical evidence is reported
  only for the executed sm_75/model path.

## Implementation sequence

1. Read fixture, control, replay, collector, checker and supervisor interfaces.
2. Add the default-false capability to fixture construction, validation and all
   runtime mutation boundaries. Add mutation-free constructor/live refusal cases.
3. Add a fresh disabled-control strategy5 collection and bind it against the
   accepted source5 CSV/report/binary: all 513,024 F32 values per owner, complete
   cache, IDs, own bits, counters, guards and unchanged independent CPU quality.
4. Add and run pre-expired and mid-tile timeout, owned cancellation, invalid
   descriptor, explicit reset/reuse, and observer-exception poison cases.
5. Extend replay/checkpoint seal only if the final contract allows controls during
   replay; otherwise retain a strict refusal and document that boundary.
6. Add hostile portable contracts for flag types/combos, wrong source identities,
   altered states/counters, incomplete vectors, source/binary/model tampering,
   signal-mask drift, duplicate/nonfinite JSON, interruption and output races.
7. Finish all builds before serial physical GPU capture, then independent CPU
   oracle. Preserve each failed artifact and rerun only into fresh destinations.
8. Synchronize interface docs, TODO, roadmap, ledger status (without promotion),
   evidence operation, DEVLOG and README_AI. Run owning validation and review exact
   diff; commit/push this slice and verify hosted CI for the exact revision.

## Verification and release gate

Use the accepted model5 evidence and exact commands/identities documented in
`ROADMAP_AESIR_SPEED_LEAD.md`, `docs/NATIVE_SMALL_ATTENTION_MODEL.md`,
`docs/NATIVE_SMALL_ATTENTION_DECODE.md`, and
`docs/NATIVE_SMALL_ATTENTION_CHECKPOINT.md`. Keep all 7-or-more build targets
from the owning control contract completed before GPU activity. Run focused
portable contracts and checkers, the master suite, normal build/readiness and
negative-control/drift checks. Physical timeout/cancellation/reset must execute
on the target device; hosted CI alone cannot establish the physical behavior.
Record exact commit and hosted CI separately.

## Completion boundary

Passing this task establishes only the declared strategy5 cooperative control
and recovery behavior for the stated fixture, model, device, source and policy.
It does not establish tracing, runtime selection, persisted/context recreation,
broader devices/models, production readiness, provider parity, or speed lead.
