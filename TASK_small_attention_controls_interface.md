# Task: AES500-003 Strategy5 Controls Interface

## Authorization, owner and prerequisites

Volmarr authorized all 500 Mythic Engineering slices, six specialist agents,
verification, and a commit/push after every independently accepted slice.
The test-fixture domain owns this interface gate. AES500-002 is accepted and
pushed as `4fa7b260eca0dcd740273d68ee90775fe1660326`: its fresh COUNTS1/STATE1
capable-disabled baseline, exact source inventory and unchanged sm_75 executable
are this gate's positive input. Hosted CI remains a separate release signal.

Cartographer and Forge Worker independently mapped all 13 existing negative
modes and constructor ordering. The primary agent executes the declared matrix;
Architect/Auditor review the contract and resulting evidence; Skald/Scribe
reconcile framing and continuity. GPU/model execution is not required by the
negative matrix. No source implementation change is proposed by this slice.

## Current interface and outcome

`TuringPrefillFixture.__init__` accepts optional `small_controls=False` followed
by optional `small_tracing=False`. Only `small_controls=True` requires admitted
`small_attention=True`; False is valid with other strategies. The constructor
rejects incompatible capabilities before its first `Llama3CUDASession(path)`.
Capability defaults and source ordering are source evidence. A successfully
constructed default-false small owner is not freshly observed by this matrix.
AES500-002 supplies the already executed positive capable-disabled scope.

Document the constructor, capability admission snapshot, cooperative request/start and
reset policy precisely. Run the unchanged accepted executable against a verified
nonexistent model path in a fresh private directory for each negative mode.
Require exit code 1, the exact expected exception message, clean stderr, and
only the known Mojo exception diagnostic on stdout: the fixed stack-trace
preamble followed by one `Unhandled exception caught during execution: MESSAGE`
line. Reject any extra collector CSV, fallback `... admitted` error or
model/CUDA output.
The nonexistent input and exact exception, together with reviewed constructor
ordering, establish the named pre-load refusal. Output silence alone is not a
proof of the boundary.

## Declared refusal matrix

| Mode | Expected first exception | Actual owning gate |
|---|---|---|
| `reject-fused` | `Small attention requires original fused strategy with controls/tracing closed` | small-attention predecessor |
| `reject-controls` | `Small attention requires original fused strategy with controls/tracing closed` | small-attention predecessor |
| `reject-tracing` | `Small attention requires original fused strategy with controls/tracing closed` | small-attention predecessor |
| `reject-down` | `Fused attention requires original down128 strategy with controls/tracing closed` | fused-attention predecessor |
| `reject-precision` | `Batched rotary/cache requires original precision0` | rotary/cache predecessor |
| `reject-batched` | `Batched elementwise requires admitted rotary/cache strategy` | elementwise predecessor |
| `reject-controls-without-small` | `Small controls require exclusive admitted small attention strategy` | small-controls capability |
| `reject-controls-with-tracing` | `Small attention requires original fused strategy with controls/tracing closed` | small-attention predecessor |
| `reject-controls-with-replay` | `Small controls and replay require separate acceptance` | small-controls replay exclusion |
| `reject-small-tracing-without-small` | `Small tracing requires exclusive small strategy without controls or replay` | small-tracing capability |
| `reject-small-tracing-with-controls` | `Small tracing requires exclusive small strategy without controls or replay` | small-tracing exclusion |
| `reject-small-tracing-with-replay` | `Small tracing requires exclusive small strategy without controls or replay` | small-tracing exclusion |
| `reject-small-tracing-with-fused-tracing` | `Small attention requires original fused strategy with controls/tracing closed` | small-attention predecessor |

Do not claim execution of a later shadowed gate from an earlier rejection.
The direct small-control gate and replay exclusion each have their own case.
The matrix validates constructor interface admission only; it does not execute
live capability mutation, request interruption or recovery.

## Request and reset interface to document

- `configure_control(timeout_ms=0, cancel_fd=-1)` validates strategy and health
  before changing request policy. Timeout accepts `0..3600000`; descriptor
  accepts `-1..2147483647`. Both defaults leave request controls disabled.
- Enabled requests require `start_control()` before tile admission. A capability mismatch against its construction snapshot is rejected by `admit_execution_strategy` before work.
- Known cooperative interruption requires explicit reset. Failed fixture health
  refuses reset. Reset clears start/deadline/interruption state but retains the
  timeout/descriptor policy; disabling that policy needs `configure_control()`.
- Ordinary strategy5 without the control capability currently reaches the
  earlier fused-control refusal in `configure_control` and `start_control`.

These method statements are current source-reviewed interface documentation;
fresh enabled timeout/cancel/abort/recovery execution remains a separate gate.

## Acceptance commands and evidence

1. Before execution, commit/push this task and inspect its remote revision.
2. Verify SHA-256 of the accepted executable equals
   `8a9e6a5a0ac3dc5009746b51a5621c6da4b87542cbad979054588a8ebfdca8a8`
   and all 272 AES500-002 source inventory entries equal current files.
3. For each matrix row execute `"$SMALL_MODEL_BINARY" "$NONEXISTENT_MODEL" MODE`.
   Retain raw stdout/stderr, exact argv, UTC interval and return code. Do not
   create or substitute a model at the sentinel path. Capture every outcome;
   a wrong exception or process failure cannot be counted as the declared gate.
4. Verify executable/source identities unchanged afterward. Preserve ordinary
   service activity and inspect authenticated health before/after, without
   stopping the service for these constructor refusals.
5. Publish the compact matrix receipt and source/binary identity binding using
   symbolic paths. Synchronize owning fixture/operator interfaces, task, roadmap,
   TODO, ledger and devlog. Run documentation drift contracts/checks and
   `git diff --check`; no new inference test/build is required because the
   previously accepted executable and source inventory are unchanged.
6. Obtain independent source/evidence review, commit and push this slice, verify
   the exact remote revision and observe hosted CI, then continue to AES500-004.

## Claim boundary

One finite constructor refusal matrix plus source-reviewed defaults/methods and
AES500-002's positive disabled owner scope. No freshly observed default-false
owner, live capability-snapshot mutation, abort/recovery, reset/poison execution, resource fault,
normal runtime, broad model/device, or speed promotion is established here.

Pre-execution Architect, Auditor and Skald reviews pass. Admission snapshots
are mutable fields compared by the fixture; immutable storage is not implied.

## Observed diagnostic transport correction — before final execution

The first retained matrix attempt observed all thirteen expected errors and
exit codes, with source/binary/service identities unchanged. Its receipt failed
because the initial contract assumed exception text on stderr and empty stdout.
Mojo 1.0.0 actually emits this fixed stdout preamble and one exception line,
with empty stderr:

```text
stack trace was not collected. Enable stack trace collection with environment variable `MODULAR_DEBUG=stack-trace-on-error`
Unhandled exception caught during execution: MESSAGE
```

The corrected acceptance requires exactly those two stdout lines, replacing
MESSAGE with the row's predeclared exact exception, and empty stderr. No expected
exception or constructor gate changes. Preserve the failed receipt/raw streams;
commit/push this correction before executing a new fresh-directory matrix.

## Accepted final matrix — 2026-10-10

The new fresh-directory matrix passes all thirteen declared first exceptions,
exit1 and exact known two-line stdout diagnostic with empty stderr. The accepted
binary and all272 source hashes remain unchanged. The sentinel remains absent;
ordinary service state, main PID and authenticated health are unchanged without
service interruption. The [dated receipt](docs/evidence/small-attention-controls-interface-2026-10-10/README.md)
contains exact symbolic arguments, process intervals and raw artifact hashes,
alongside the preserved failed diagnostic-transport attempt. Default and request/
reset statements remain source-reviewed; positive disabled scope reuses002.
Final independent review, doc gates and exact remote/CI observation follow this
local acceptance. Continue next with separately scoped AES500-004.
