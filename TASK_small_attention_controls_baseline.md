# Task: AES500-002 Strategy5 Capable-Disabled Baseline

## Authorization and owner

Volmarr authorized the complete 500-slice Mythic Engineering roadmap, verification,
and a commit and push after each accepted slice. The test-fixture domain owns
this baseline. The existing `TASK_small_attention_controls.md` controls the
capability contract. This work publishes independently reproducible evidence for
AES500-002 and adds collector/checker observations without changing inference
source or admission policy.

## Current truth

The accepted pre-control strategy5 model capture was produced on 2026-10-03.
Its actual CSV, checker report, and sm_75 executable remain available and their
SHA-256 identities match the published source receipt. The 2026-10-09 controls
receipt also retains a capable-but-disabled capture, after the control code
change, which matches that pre-change reference. These are distinct captures.

The current branch is `docs/cross-cutting-500-slice-roadmap`, at `ceb54c0` when
this work order was written. Hosted CI for that commit is in progress in run
38037210072; it is not physical fixture evidence. The local full Mojo suite has
an unresolved PTX ISA compilation failure. This task will independently build
and execute the affected sm_75 entry point, recording its actual outcome.

## Outcome and scope

1. Admit the retained pre-change source CSV/report/binary and preserve its
original dated provenance. Do not rebuild and relabel a historical binary.
   The Auditor found that the legacy capable-disabled marker does not serialize
   actual enabled/reset/health state. Add an explicit state-observation version
   and actual snapshots after all eight runs per case. Assert the disabled,
   healthy, admitted capability before and after each run. The checker must
   validate state, positions, sampler positions and committed lengths against
   the observed input counts; label-only historical captures cannot satisfy
   this strengthened fresh gate.
   The independent Auditor also found a fixed legacy admission count even when
   capable mode skips feature-refusal checks. Count validated tile and feature
   refusals during execution and emit versioned `COUNTS1` metadata. The current
   STATE1 gate requires eight actual tile refusals and zero skipped feature
   refusals; the ordinary current collector executes thirteen feature refusals.
   Historical fixed-count source metadata stays parseable as historical evidence.
2. Build the current `test_small_attention_model.mojo` for sm_75 into a fresh
   private task directory using the frozen installed toolchain.
3. Run its explicit `controls-disabled` mode against the exact fixture model.
   Capture raw stdout, stderr, process outcome and all input identities. Physical
   GPU work is serial; restore an initially active service after capture.
4. Run `check_turing_model_prefill.py --small-controls` with the pinned F32
   reference and actual historical source triplet. Retain every failure and use
   exclusive new destinations. The independent oracle uses zero GPU layers.
5. Publish a compact dated receipt, reproduction commands and source/binary/model/
   toolchain hashes. Update only AES500-002 status after its exact proof passes.

## Acceptance

- The pre-change triplet is CSV `0dcc24b233b8ff094ac0486fcad7734fcd53ba0eba0c9f2e684a2c2316cd4d2d`,
  report `22395c06b4cc62444ff063ba439cfcef89f3922c5ff0daabb284f56e23932a27`,
  and binary `3afd548ad0ef71952ae590aa13c06a6ebc08fff4355eacfee293af7998b82660`.
- The exact original model is `dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff`.
  The independently expanded F32 model is `b0dd20c95a6605d9773d9d3153c52f89f21628f21048ff81bb184684b6f7a42b`.
  The derivation snapshot is `9325ff2a1d58cd5334f1423d8db2eaffc631dd853785ed287a37f48b51dec5a9`.
- Current capture proves the explicit strategy5 capable-disabled marker, four
  complete input streams and 513,024 F32 values per owner, exact native/matrix
  bytes against the source, guarded-cache identities, dispatch counters,
  committed positions, repeated-logit checks and all 4,352 guards.
- Fresh independent CPU comparisons pass the predeclared maximum absolute
  error .05, RMS error .005 and matching full-vocabulary argmax for both owners.
  Oracle versions are llama-cpp-python 0.3.23 and NumPy 2.4.4, context 4096,
  F16 KV, batch 128, four threads and zero GPU layers.
- Input and source hashes remain equal before and after capture and checking;
  raw artifacts are retained privately. The compact receipt never embeds local
  paths or credentials. No performance score is accepted by this slice.
  Suppress generic timing scores for observed STATE1 baselines while preserving
  complete quality acceptance and raw timings. Preserve provisional attempts;
  a new capture is required after collector metadata changes.

## Verification and completion boundary

Owning files are `aesir_engine/tests/test_turing_model_prefill.mojo` (optional
observations, default off), `aesir_engine/tests/test_small_attention_model.mojo`
(explicit capable-disabled opt-in), `scripts/check_turing_model_prefill.py`
(state parsing/admission), the focused small-model checker contracts, and their
interface/operator documents. Preserve legacy non-control source readers and
historical captures. Test missing, duplicate, reordered, enabled, poisoned,
reset-required, capability-drift and position-drift snapshots before capture.

The exact build is `pixi run --frozen --no-install --offline mojo build -I
aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_small_attention_model.mojo
-o "$ARTIFACTS/small-model"`. Capture and checker commands are defined in
`docs/NATIVE_SMALL_ATTENTION_CONTROLS.md`; the dated receipt will provide their
exact arguments and hashes. Run the focused small-model/control checker
contracts and documentation drift checks, review the receipt, commit and push
AES500-002, then observe its exact remote revision and hosted CI status.

This gate establishes reproducibility of the declared disabled-control baseline
for one fixture/model/device. Enabled abort/recovery, tracing, current full-suite
success, runtime promotion and provider speed require their separate gates.
