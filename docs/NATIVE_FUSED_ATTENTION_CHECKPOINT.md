# Sealed owning-context replay after fused attention prefill

Read `TASK_fused_attention_checkpoint.md`, test and script ownership MD before
changing this gate. Native Mojo owns the optional strict3B/context1536/F16 KV/
precision0 strategy4 test path on the observed sm_75 device. Python/NumPy/llama.cpp
are independent test oracles. The normal service keeps its original prefill4 binary.

## Capability and ownership contract

`FixtureReplayPlan` copies token IDs and exact tile counts. Its final
`fused_capable=False` flag preserves ordinary0..3 plans and their seal equations.
Strategy4 requires mode1 and explicit true. Ordinary constructor4, native0 with4,
legacy strategy with true, foreign strategy/capability and changed flag/seal refuse.
The new flag participates in the4 fingerprint. The checksum detects mutation of
this process-local plan; it is not cryptographic authentication or a saved format.

Restore forwards the actual fixture capability only for mode1. Before reset,
configuration or enqueue, admit the plan, actual weights/activation/cache owners,
sampler window, execution flags/profile/physical spans and idle healthy uncontrolled
state. Recheck ownership after replay. Original four-token/native and32/4/scalar
fixture boundaries are preserved. Pending chosen ID stays in the sealed plan and
is committed only when continuation advances. Sampling configuration/history and
actual RNG draw count are restored. Controls/tracing stay disabled for this gate.

## Build and collect

From the frozen environment:

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_checkpoint_replay.mojo \
  -o /path/to/new-fused-checkpoint-probe
```

Finish sm75/sm89/original collector/master/normal/check before serial GPU collection,
then CPU validation. Use fresh private evidence paths, exclusively created CSV/
stderr, bounded process lifetime, actual exit and SHA/UTC receipts. Invoke:

```sh
/path/to/new-fused-checkpoint-probe /path/to/original.gguf 4
```

Omission keeps0; explicit0..3 preserve their previous schema. Unsupported5 refuses
before model/CUDA with a nonexistent model. Strategy4 requires fused/batched rotary/
elementwise/down128 original precision0 flags with controls/tracing closed.

The public37-token prefix plus eight native-forced scalar IDs creates an exact
45-ID checkpoint for greedy and fixed seeded policies. Export actual IDs/tile
boundaries/checkpoint samples/positions/history/draws/pending plan ID. Baseline and
restored continuation each have four frames per policy, every128256 logit for all
four owners (baseline native/matrix, restored native/matrix), actual UInt32 bit
comparisons including signed zero, source/sample/state checks and4352 guards.
Two cap-sized pinned host snapshots hold baseline vectors; no device workspace.

Six damaged fields per native/matrix plan (tile count, weights, draws, strategy,
fused capability, activation owner) plus elementwise/fused fixture flag drift
produce14 refusals per policy,28 total. Native checks ensure allocation identities,
health, sampled/committed state, IDs and actual down/fused/original counters remain
unchanged. Pure master checks retain ordinary4 refusal and explicit copied4 seal/
capability/owner constraints; these are distinct from physical GPU execution.

Actual down28/fused56 remain through checkpoint and restore. Original query calls
are252 at45 committed IDs and364 after four more scalar IDs. Ordered initial,
restored and final records bind these actual counters; restore resets counters
rather than accumulating previous continuation work.

## Validate accepted source and current binary

First retain [accepted causal decode4](NATIVE_FUSED_ATTENTION_DECODE.md), its exact
96-frame report SHA and actual decode binary. Use the pinned optional reference
versions (NumPy2.4.4/llama-cpp-python0.3.23), original/derived F32 models and derivation:

```sh
/path/to/oracle-python scripts/check_turing_checkpoint_replay.py /path/to/capture.csv \
  --fused-attention \
  --model /path/to/original.gguf --model-sha256 ORIGINAL_SHA256 \
  --reference-model /path/to/expanded-f32.gguf --reference-sha256 DERIVED_SHA256 \
  --reference-provenance /path/to/derivation.json \
  --accepted-report /path/to/accepted-decode4.json \
  --accepted-report-sha256 ACCEPTED_REPORT_SHA256 \
  --accepted-binary /path/to/accepted-decode4-probe \
  --binary /path/to/new-fused-checkpoint-probe --binary-sha256 CURRENT_BINARY_SHA256 \
  --output /path/to/new-checkpoint-report.json
```

Explicit fused opt-in is exclusive with down128. Default accepted-report/metadata
readers reject4. Require complete all-four source case/frame/policy/count/public-ID/
numerical/causal/sample/state/own-replay/counter coverage, unchanged budgets and
pinned zero-GPU expanded-F32 CPU scope. Model-source proof has exact strategy4/
closed-control/model/CSV/report/binary identity. Current and accepted decode binary
hashes are checked before/after; a passed Boolean alone cannot hide bad metrics.

Checkpoint IDs/choices and baseline continuation choices must match accepted short
source frames. All current baseline/restored vectors are compared independently
to the pinned zero-GPU CPU oracle, context4096/F16 KV/batch128/four threads/no flash
attention, under .05 maximum/.005 RMS/full-vocabulary matching argmax budgets.
Greedy choices equal argmax; seeded/native/matrix samples agree. Declared bit counts
must match the actual exported F32 bytes, and every restored byte/state must equal
its baseline. Complete numerical failures retain all measured frames.

Streaming CSV admission uses one no-follow bounded regular descriptor, at most
256MiB/UTF8 newline lines<=1024 bytes/16 fields/256 bytes per cell, ordered records,
same-descriptor SHA/stat checks and current four vectors only. Accepted report is
bounded1MiB, strict duplicate-key/nonfinite rejection and explicit SHA. JSON output
is exclusive. Rehash current capture/binary, original/derived weights, derivation,
accepted report and accepted decode binary after oracle; supervisor source hashes
must also agree. Exit0 requires complete acceptance; exit1 retains partial/complete
failure and interrupted evaluation/cleanup. Retry into fresh destinations.

## Evidence boundary

No elapsed process/export/oracle value is a speed score. This proves same-process
owning-context reset/replay at these exact boundaries. It does not certify a
persisted format, crash restoration, context recreation, arbitrary candidate
trajectories, enabled controls, production32, broader devices/contexts/concurrency/
soak or provider speed. Default4 remains closed without explicit plan/live/source
capabilities. Next earn cooperative control cancellation/reset/recovery before
broader runtime integration. Hosted compilation is separate from physical proof.

[Retained measurement](evidence/fused-attention-checkpoint-2026-10-03/README.md).

Explicit cooperative fused_controls capability now has a separate
[control and reset recovery gate](NATIVE_FUSED_ATTENTION_CONTROLS.md). Ordinary
source/default4 profiles and control-capable4 sealed replay remain separately gated.
