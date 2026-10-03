# Tests Domain: Verification & Invariant Rites

## Domain Overview
The `tests` domain holds the master test runner and domain-specific verification scripts.

The optional owned strategy2 prefill trace probe and its source/range gates are
documented in `docs/NATIVE_TURING_PREFILL_TRACE.md`. Execute the compiled binary
directly, retain full-session raw traces and strict actual process identity,
select only the synchronized semantic range after all rows validate. Exported
complete F32/cache bytes must equal independently admitted source; no speed score.

Explicit projection tracing stays disabled by default. The direct probe can bind
actual loaded tensors to query/key/value/output/gate/up/down/head and batch1/4/32;
read docs/NATIVE_TURING_PROJECTION_TRACE.md. Child CPU ranges only label enqueues;
successful correlations project GPU duration without changing synchronization.

- **`run_all.mojo`:** Master orchestrator registering 190 executable named cases
  and one explicit external-fixture skip.
- **Native Gemma CUDA evidence:** `test_gemma4_cuda.mojo`,
  `test_gemma4_quant_parity.mojo`, and `inspect_gemma4.mojo` are opt-in physical
  checks. `scripts/check_gemma4_conversation.py` validates the logged 20-turn
  transcript. See `docs/GEMMA4_CUDA.md` for their scope.
- **Native Stheno CUDA evidence:** independent tokenizer, packed matvec and
  RoPE/SiLU/GQA checks, profile admission, session limits and 20-turn transcript
  accounting are documented in `docs/STHENO_CUDA.md`. These opt-in proofs keep
  large weights external and do not establish general Llama compatibility.
- **`test_hardware_discovery.mojo`:** Deterministic injected-record tests for
  discovery statuses, validation, accumulation, deduplication, and selection.
- **`test_gpu_discovery.mojo`:** Opt-in physical MAX CUDA enumeration and
  topology-selection proof; intentionally excluded from the CPU master suite.
- **`test_cuda_resource_budget.mojo`:** CPU-only GPU-2 byte accounting,
  transactional rejection, rollback, overflow, and device-policy admission.
- **`test_gpu_resources.mojo`:** Opt-in physical GPU-2 selected-context,
  budgeted F16 buffer, synchronized transfer, and scope-cleanup proof.
- **`test_cuda_gemm_plan.mojo`:** CPU-only GPU-3 shape/product/ABI/launch and
  transactional three-buffer budget verification.
- **`test_gpu_gemm.mojo`:** Opt-in physical GPU-3 production-gateway F16 GEMM,
  independent F32 parity, reuse, failure, and negative-control proof.
- **`test_ledger.mojo`:** Tests-domain pass/fail/skip ledger, per-case error
  boundary, stable result lines, ordered failure details, and terminal status.
- **`test_compute.mojo`:** Unit tests for GEMM, Flash Attention-2, SiLU, GeGLU, and Q4_K_M dequantization.
- **`test_gguf.mojo`:** Unit tests for malformed GGUF rejection and `GGMLType` constants.
- **`scripts/test_special_file_admission.py`:** Built-CLI anti-stall proof for
  FIFO-shaped configuration, GGUF, resumable-download staging, Modelfile,
  source/installed blob, and catalog inputs; CI enforces a five-second deadline
  per rejected operation.
- **`test_tokenizer.mojo`:** Unit tests for `RuneWeaver` token encoding/decoding.
- **`test_real_gguf.mojo`:** Opt-in external-fixture proof for metadata,
  zero-copy F16 mapping, F32 normalization conversion, tokenizer parity, and
  exact 32-token deterministic inference parity. It also preserves the original
  first-token assertion. It is intentionally not part of `run_all.mojo` because
  model weights are not committed.
- **`test_inference.mojo`:** Synthetic forward-pass smoke coverage plus isolated
  stable generation-stop policy assertions for EOS, requested length, context
  exhaustion, and continuation.

## Failure Semantics

The master suite is fail closed. Every existing asserted mismatch in an invoked
test raises or propagates `Error`, so `run_all.mojo` exits nonzero and cannot
reach its final success banner. The two former KV-cache print-and-return paths
also raise. A deliberate corruption of the stable `GGMLType.F16` expectation
was verified to exit 1; restoring it returned the focused test and master suite
to exit 0.

The runner catches errors only at each named case boundary, records the failure,
and continues with later cases. After all 191 reportable cases, it prints unique
`[SUMMARY]` keys and raises if any case failed or the expected total is wrong.
The RAG external-fixture boundary is counted as one skip, and real model
execution remains the opt-in test below.

A normal baseline run reports:

```text
[SUMMARY] Passed: 190
[SUMMARY] Failed: 0
[SUMMARY] Skipped: 1
[SUMMARY] Total: 191
[SUMMARY] Status: PASS
```

The historical Forge 0B negative gate deliberately corrupted the F16 type expectation.
The runner recorded `gguf.type_constants` as failed, continued through the final
swarm case, reported 48/1/1/50, and exited 1 after the summary. Exact restoration
returned that Forge's suite to 49/0/1/50 and exit 0. Later stages expanded the
current baseline to 182/0/1/183; the consistency checker mechanically keeps
the runner total and capability ledger synchronized.

## How to Run

Run the master suite from the repository root so tracked configuration fixtures
resolve through their production-relative paths:

```bash
pixi run mojo run aesir_engine/tests/run_all.mojo
```

Run the opt-in physical GPU-2 resource proof from the repository root:

```bash
MODULAR_NVPTX_COMPILER_PATH=/usr/bin/ptxas pixi run mojo run aesir_engine/tests/test_gpu_resources.mojo
```

Its `--negative-control` form must exit nonzero after injecting one transfer
mismatch. Neither command is part of hosted CPU CI.

Run the opt-in production GPU-3 CUDA GEMM proof from the repository root:

```bash
MODULAR_NVPTX_COMPILER_PATH=/usr/bin/ptxas pixi run mojo run aesir_engine/tests/test_gpu_gemm.mojo
```

Its `--negative-control` form must exit nonzero after corrupting an independently
computed expectation. The normal command executes two shapes for three rounds
each through the reusable production gateway; it is not part of hosted CPU CI.

Run the real-model proof with the pinned fixture and oracle described in the
root `fixture_manifest.json` and `TASK_verified_multi_token_generation.md`:

```bash
pixi run mojo run tests/test_real_gguf.mojo /path/to/stories260K.F16.gguf
```

The expected completion for `One day, Timmy went to` at 32 new tokens is:

```text
 the park with his mom. They saw a big box with a big box. The box was very small and
```

This proves only the documented F16 single-device CPU greedy path. The master
suite still includes historical synthetic/scaffold checks whose broader labels
are not proof of real accelerator, quantized-model, server, network,
concurrency, resilience, or distributed behavior. A zero exit means that all
counted local assertions passed; it does not expand their evidence boundary. See
`PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`.

Tracked fixture payloads, if added, belong only under `tests/fixtures/` and must
be registered before admission. Run `python3 scripts/check_fixture_manifest.py`
from the repository root to validate classifications, provenance, consumers,
storage boundaries, byte sizes, and SHA-256 values. The directory currently
contains only its policy README and no payload data.
## Matrix fixture ownership

The test-only TuringFixturePlan admits exercised context1536/strict3B geometry,
observed CUDA capability7.5, canonical normal layout, exact guarded counts and
observed headroom before extra allocation. Every tile rechecks all layout fields
and actual buffer lengths. Pure portable tests do not prove GPU execution; repeat
full independent logits and byte-identical prior mode0 vectors after changes.
Read ../../docs/NATIVE_TURING_FIXTURE_ADMISSION.md before expanding this plan.
## Matrix fixture controls

The pure FixtureControl policy and enabled layer checkpoints reuse native
GenerationControl. Abort requires explicit reset after healthy stream drain;
unexpected failures poison reuse. The owned physical probe covers deadlines,
real SIGINT, invalid descriptors, full recovered vectors/guards and signal mask
restoration. Default disabled behavior retains complete independent model and
byte-regression gates. Read ../../docs/NATIVE_TURING_FIXTURE_CONTROLS.md; no
production control/admission or hard real-time claim follows from this fixture.

## Complete decode and seeded replay

test_turing_decode_quality.mojo exports complete128256 paired logits per
prediction after existing public37/1070-token prefixes, greedy32/seeded16 caps.
Native chosen IDs feed both owners; matrix choices remain evidence. Exact own
F32-bit replay, all committed IDs/state/draws and4352 fixture guards are required.
One-case pinned snapshots cap31.313MiB with no added device workspace. Read
../../docs/NATIVE_TURING_DECODE_QUALITY.md. Hosted compilation never proves GPU
execution; bounded streaming CPU/native/sample/replay gates own acceptance.

## Exact-boundary checkpoint replay

The pure FixtureReplayPlan copies IDs/tiles and seals every policy/owner/value
with a mutation checksum. A counted portable case checks mutation, foreign owner
and hostile token/tile/policy/draw admission. turing_checkpoint_replay.restore
preflights before explicit reset/GPU work, replays the recorded boundaries without
sampling and restores validated draw state only after exact commit/synchronization.
The owned physical collector compares every continuation F32 bit before/after
reset for greedy/seeded public37-ID history, with12 mutation-free plan refusals.
Read ../../docs/NATIVE_TURING_CHECKPOINT_REPLAY.md. Same-context memory only;
persisted formats/context recreation/runtime32 and provider gates remain open.

## Batched rotary/cache evidence ownership

The opt-in grid-y collector records actual host enqueue calls and full guarded
cache SHA using an unscored synchronized host copy/anonymous memfd. Original
precision0 and checked disjoint rows remain mandatory. Decode/checkpoint optional
flags preserve legacy omission and all complete quality/state/bit gates; replay
strategy drift refuses before reset. Read
../../docs/NATIVE_TURING_BATCHED_ROPE_CACHE.md. Portable master remains190
passing cases/one explicit skip; opt-in physical collectors run separately.

The explicit elementwise strategy2 additionally batches independent RMS/residual/
SiLU rows and binds actual successful host enqueue counts. Seven grid contracts
preserve legacy0/1 and refuse unknown tags, wrong counts/reference chains and
strategy drift. Master stays190 passes/one skip. Read
../../docs/NATIVE_TURING_BATCHED_ELEMENTWISE.md; physical evidence stays opt-in.

The enabled-control probe now accepts explicit strategy2 and preserves legacy
omission. Complete abort/reset/poison/guard/mask proofs bind the matching accepted
source. Read ../../docs/NATIVE_TURING_BATCHED_CONTROLS.md. Hosted compilation
remains separate from physical controls; master count stays190/0/1.

## Explicit down128 projection trace capability

Final down128_tracing=False requires down before model load when enabled. Default
down3 stays closed to tracing; explicit3 owned probe requires STAGES1 and refuses
enabled controls. Balanced project try/pop now includes down128 dispatch, preserving
math/counter order and poison behavior. TRACE3/DOWN_ROWS12828 or924/DOWN_TILE128,32
bind actual full F32/cache/IDs/state/counts/guards to accepted3 source. Default2
probe/checker remains. Complete full-session owner/correlation/resource validation
precedes ordered source child attribution; selected wrapper prefixes/grid/block
and per-kernel recorded resource distributions are explicit, never an occupancy/
spill/cause/speed claim. Read ../../docs/NATIVE_TURING_DOWN_PROJECTION_TRACE.md; ten adversarial contracts plus physical
plain/profiled cases and master190/one skip pass.

## Optional16-column staging experiment

Separate narrow_turing_kernel/project_turing_narrow siblings retain all previous
packed Turing definitions verbatim. Rows64/128, columns16, original precision0 and
format12/13/14 share initialized guarded cells and original sequential F32 MMA;
half-group lane selection and extra barriers are explicit. Defined shared5440/
9792 bytes atbatch32 do not prove registers/occupancy/speed. Final narrow_rows=0
primitive harness extension stays exclusive with cached/large paths; default and
production dispatch remain. Native probe validates geometry before load. Explicit
MODE narrow metadata requires complete native/candidate/original64 F32 bits,
unchanged oracle/guard/840 rotated timing gates. Read ../../docs/NATIVE_TURING_NARROW_STAGING.md;19 portable contracts
retain complete failures/hash drift/interrupt/exclusive reports.

## Optional bounded runtime-group32-column staging

Separate core/packed_turing_loop.mojo imports original accumulation/target/span
helpers and preserves original packed core/quantization modules verbatim. Internal
runtime-group0..7/lane0..31 decode matches original equations; kind12/13/14 and
rows64/128/batch4/8/16/32/precision0 remain static. Shared32 width/both barriers/
chronological F32 public MMA/guarded cells stay; no global workspace or production
selection. Final loop_rows=0 harness dispatch is exclusive with cached/large/narrow
flags. Explicit loop metadata requires full original64 F32 bits, unchanged native/
independent/guard/840 rotated finite timing gates. Both numeric configs pass; all56
original64 comparisons lose.22 portable contracts/master190/one skip. Read ../../docs/NATIVE_TURING_LOOP_STAGING.md;
no register/occupancy/cause/provider claim follows.

## Optional paired FFN primitive

Separate packed_turing_pair owns pure two-matrix admission and an opt-in paired
64-row-per-tensor / 32-column kernel. Same-kind12/13/14 and batch4/8/16/32 only;
weight/output aliases refuse before enqueue. Original quant/MMA equations and
all initialized shared tails/barriers remain; no global workspace or selection.
Real Q4/Q4 gate/up passes 983040 complete values per owner, original F32 bits,
600 independent dots, 6720 guards, 144 synthetic pairs and 12 span refusals.
All120 rotated timings remain. Batch4 beats staged but loses native; batch32
loses staged, so no candidate selection. Ten adversarial contracts/master190
passes/one skip. Failed guard-formula checker report is retained; corrected
validation uses unchanged GPU data and a new exclusive report. Read ../../docs/NATIVE_TURING_PAIRED_FFN.md.
Actual model activation/full-model/runtime/provider gates remain separate.

## Optional bounded fused causal GQA

core/fused_causal_attention owns strict24/8/128 shape and pure causal F32/F16
span/alias admission, followed by a compatible CUDA-context fence. Allocation
bounds admit fixture stride33824 safely. One128-thread CTA per head/query uses
4096 shared F32 scores and original dot/softmax/value arithmetic; no global
workspace or production selection. All39 cases/1370112 complete original F32
bits and independent Float64 outputs/364518 guards/full query and KV input
immutability pass. All780 rotated times remain; full4/32 improve but long single
queries lose. Nine contracts/master190/one skip. Retained parse failure and
preliminary accepted capture precede rebuilt final stride refinement. Read
../../docs/NATIVE_FUSED_CAUSAL_ATTENTION.md. Actual model/full-model/state/runtime/provider gates remain separate.

## Explicit fused-attention complete-model gate

Final fused_attention=False capability selects strategy4 only with original
precision0/batched rotary/elementwise/down128 and controls/tracing closed before
model loading or step mutation. Count4/32 use checked owned fused attention after
ordered cache writes; count1 keeps original kernels. Actual counters reset and
record fused196/56/196/1008, original queries56/28/84/56. All513024 current F32
values per owner/IDs/full F16 cache match accepted3, unchanged CPU budgets/own
bits/4352 guards/eight invalid tiles/32 timings pass. Seven contracts/master190
and one skip. Explicit CLI/source3/binary/after-hash gates preserve default
reader/strategy4 replay refusal. Read ../../docs/NATIVE_FUSED_ATTENTION_MODEL.md; broader state/runtime/provider
gates remain separate.

## Explicit strategy4 causal decode quality

The opt-in collector accepts4 with closed controls/tracing and original scalar
attention. Full greedy/seeded native-forced causal frames, exact UInt32 fresh
replay/state/guards and actual initial/replay fused/original/down counters bind
the plan. Explicit accepted model4 CSV/report/binary triplet is exclusive with3;
source and current binary before/after hashes join full source scope/counter/cache/
ID/numeric/CPU/predecessor proof. Default readers and sealed replay4 stay closed.
Eleven portable contracts plus physical complete GPU/independent CPU gates;
no speed scoring or production selection. Read ../../docs/NATIVE_FUSED_ATTENTION_DECODE.md. Next earn owning-context
sealed replay and enabled controls before broader runtime/provider acceptance.

## Explicit strategy4 sealed owning-context replay

FixtureReplayPlan final default-false fused capability preserves ordinary0..3
seal/default4 refusal. Explicit mode1/strategy4 plan and actual live capability
bind pre-reset/enqueue admission. Physical45-ID checkpoints/eight continuation
frames retain all four full vectors/UInt32 bytes/CPU/source choices/samples/state/
4352 guards;28 damaged-plan/flag refusals preserve actual owners/health/counters.
Actual down28/fused56 stay and original queries252/364 bind reset/tile plan.
Explicit source4 report/accepted decode binary/current binary SHA fences and strict
all-four source numeric/causal/counter scope remain default-closed/exclusive with3.
Nine adversarial contracts/master190/one skip; unscored same-process replay only.
Read ../../docs/NATIVE_FUSED_ATTENTION_CHECKPOINT.md. Next earn enabled control recovery before runtime/provider breadth.

## Explicit strategy4 cooperative control recovery

Final fused_controls=False preserves ordinary4 configure/start refusal. True is
exclusive with legacy3 control/trace flags, requires admitted4 and keeps tracing/
control-capable4 sealed replay closed. Fresh disabled-but-capable4 model retains
all513024 source4 F32 bits/IDs/full cache/CPU/own bits/4352 guards/eight invalid/
32 timing records, actual counters and current/source binary SHA. Explicit marker/
CLI/source keywords stay default-closed. Enabled pre-expired/10ms/owned SIGINT/
invalid-fd aborts drain healthy/uncommitted/reset-required work; allocation-preserving
reset recovers full source vectors. Observer exception poisons/refuses all reuse.
Actual layer down/fused/original counters, caller mask and9792 guards bind recovery.
Fifteen model/control adversarial contracts/master190/one skip. Read ../../docs/NATIVE_FUSED_ATTENTION_CONTROLS.md.
No enabled-control speed score or general fault repair/runtime/provider admission.

## Explicit fused attention owned tracing

Final fused_tracing=False requires exclusive original fused4/down128/rotary/elementwise
before model/step; default4 tracing and trace-capable4 control/replay remain closed.
Actual fused4/32 enqueue has balanced owned attention ranges beside existing actual
tensor projection ranges. Full source default4 CSV/report/actual binary and complete
F32/cache/ID/state/guard/count equality precede full-session process/runtime/kernel/
resource admission. Explicit source tile/stage/interleaved attention chronology,
one successful child correlation/kernel, exact wrapper/grid/block and full resources
are mandatory. Old trace schemas remain; all timings are diagnostic. Read ../../docs/NATIVE_FUSED_ATTENTION_TRACE.md.
Nine hostile contracts, serial plain/profiled37/1070, both target/original builds
and master190 passes/one skip are separately recorded.
