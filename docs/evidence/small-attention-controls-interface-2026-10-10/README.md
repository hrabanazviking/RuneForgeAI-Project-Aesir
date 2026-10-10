# AES500-003: strategy5 controls constructor interface

The declared 13-case constructor refusal matrix passes on 2026-10-10.
[complete.json](complete.json) retains exact expected/observed exceptions,
owning gates, process intervals, exit codes, byte counts and raw stream hashes.
The corrected task contract was pushed as
`6b6651eb2ee4de0435e2e1a3a8c9dde4b02fe2d2` before this final matrix ran.

## Execution and identity

Every case uses the unchanged accepted AES500-002 sm_75 executable:
`8a9e6a5a0ac3dc5009746b51a5621c6da4b87542cbad979054588a8ebfdca8a8`.
All 272 source/toolchain inventory hashes equal the
[accepted baseline inventory](../small-attention-controls-baseline-2026-10-10/provenance.json)
before and after. The executable hash is unchanged. The input is a verified
nonexistent GGUF path within a fresh private directory, still absent afterward.

Each actual process exits 1 with exactly the known Mojo 1.0.0 stdout diagnostic:
its fixed stack-trace preamble, then the row's exact exception. Stderr is empty.
No collector CSV, fallback admission success, model loading error or CUDA
message replaces the expected gate. The first attempt retained all outcomes but
failed the initial assumption that diagnostics went to stderr. Its raw streams
and failed manifest remain untouched and are identified in the final report.
After observing the runtime transport, the contract correction was committed
and pushed before this fresh attempt. The expected exceptions did not change.

## Which gate actually ran

| Case family | Cases | Observed first gate |
|---|---:|---|
| Missing fused, borrowed controls/tracing, controls with fused tracing, small tracing with fused tracing | 5 | Small-attention predecessor |
| Missing down128 | 1 | Fused-attention predecessor |
| Wrong precision | 1 | Batched rotary/cache predecessor |
| Missing batched rotary/cache | 1 | Batched elementwise predecessor |
| Controls without small strategy | 1 | Direct small-controls capability |
| Controls with replay | 1 | Direct small-controls replay exclusion |
| Small tracing without small, with controls, or with replay | 3 | Direct small-tracing capability/exclusion |

The full task table and report list each of the 13 modes and exact messages.
Earlier predecessor rejection does not prove a later shadowed predicate executed.

Constructor checks precede `Llama3CUDASession(path)` in the source. The exact
gate exception with a nonexistent input and this source ordering supports
refusal before model construction and fixture CUDA resource allocation. Output
silence by itself is not a resource-lifetime proof, and this matrix is not
physical GPU inference evidence.

## Positive scope, defaults and request methods

[AES500-002's fresh executed baseline](../small-attention-controls-baseline-2026-10-10/README.md)
supplies the positive capable-disabled scope: declared strict 3B fixture,
sm_75 RTX 2060 Max-Q, context1536/F16 KV, admitted capability, disabled requests
and healthy observed owners. This slice reuses that result and those exact
executable bytes; it does not claim another positive model run.

The optional constructor default is source-verified `small_controls=False`;
`small_tracing` follows it. Only True requires the admitted small strategy.
The constructor defaults, `configure_control`, `start_control`, admission
snapshot comparisons and reset policy are documented in
[the owning operator interface](../../NATIVE_SMALL_ATTENTION_CONTROLS.md).
Those method statements are source-reviewed interface facts, not fresh live
mutation, timeout, SIGINT, recovery, reset or poison observations. Admission
snapshot fields are mutable and their comparison does not imply immutable
storage.

## Service, review and boundary

The ordinary service remains active/running with the same main PID throughout.
Authenticated before/after health is identical: HTTP200/ready, CUDA,
context4096, prefill batch4 and CPU offload0. The service was not stopped.
Raw outputs and manifests remain private; public records use symbolic paths.

Pre-execution Cartographer, Forge Worker, Architect, Auditor and Skald reviews
mapped the cases, first-gate order and claim boundary. Final independent Architect and Auditor receipt reviews pass; the Auditor
compared all13 actual raw streams, the corrected historical task version, all272
source hashes and both retained attempts, and confirmed unchanged service PID.
Scribe continuity review passes after correcting the remaining-gate ranges.
Documentation drift contracts/checks and whitespace verification pass before
the accepted slice is committed and pushed. Hosted CI is observed for its exact
revision separately.

This gate establishes the finite constructor interface matrix plus the declared
source-reviewed interface and existing positive disabled scope. A fresh
default-false owner, live capability mutation, cooperative abort/recovery,
resource faults, normal runtime admission, broader devices/models and speed
remain separate gates. Continue with AES500-004's scoped implementation gate.

## Reproduction

Verify the accepted executable and all baseline inventory hashes first. Use a
new directory and do not create the sentinel model. For each mode in the task
matrix, capture both streams and process status:

```sh
"$SMALL_MODEL_BINARY" "$NONEXISTENT_MODEL" "$REFUSAL_MODE" \
  > "$TASK_ARTIFACTS/$REFUSAL_MODE.stdout" \
  2> "$TASK_ARTIFACTS/$REFUSAL_MODE.stderr"
```

Validate exit1, exact two-line diagnostic stdout and empty stderr; any different
message or output fails the declared row. Verify input absence, executable and
source hashes, and ordinary service health afterward. The task's exact matrix
is the acceptance corpus; the command example alone does not perform its checks.

All links in the nine changed Markdown owners resolve. The optional repository-
wide link check still finds nine missing anchors in the unchanged
`Complete_Mojo_Programming_Language_Guide.md`; its bytes match the pre-slice
commit. Those existing guide findings are recorded in [verification.json](verification.json),
not counted as a global link pass or part of this interface implementation.
