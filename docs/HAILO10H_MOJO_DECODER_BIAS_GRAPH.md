# Original source-bound decoder bias arithmetic

Date:2026-10-21. Contract1f04e80 published on both branches before code.
Owner scope remains broad ordinary source-model support through Aesir-owned
translation and Hailo-only LLM execution.

## Original mathematical integration

DecoderBiasPolicy owns explicit per-layer attention/MLP flags, provenance and
checked work. New opt-in typed/scalar-neutral graph builders consume real source
bias vectors after Q/K/V/O and gate/up/down projections. Rank3 bias indexing spans
every head/component, using the complete projection output width. Bias results
precede rotary/cache writes, activations, multiplication and residual addition.
Source32/64 scalar words and raw original source facts remain intact. Explicitly
requested32 conversion is a separate diagnostic choice; source64 avoids it.

Each bias lowers into one add_source_projection_vector recipe operation, with
complete original binding/tagged storage/backing extent snapshots. Expanded IR
retains source-vector references and exact activation producers/last uses. Plan,
recipe and expanded/storage validators check explicit policy state, source names,
roles/ranks/widths, all selected operations, scalar metadata and ownership. They
reject a raw linear result bypassing its required bias. Full consumed source
coverage is checked against actual operation weights as well as derived marks.

The cache consumer now follows linear→bias→optional rotary→append, preserving
explicit NoPE selection and all prior cache address/stride rules. Matrix and
semantic storage consumers validate bias state before using the graph. Old
builders/schemas remain unchanged; explicit bias descriptors use schema3. All
byte widths/pools/workspaces remain caller-supplied hypothetical scenarios.

## Acceptance

Forty-one entrypoints rebuild warning-free under one unchanged source snapshot.
Twenty suites pass131 methods/3621 native child calls. New bias suite9 methods/
299 calls comprises147 accepted and152 expected refusals. Eight complete frozen
GGUF outputs match after removing only the new zero-bias policy metadata; two
additional complete zero-policy structural comparisons preserve all other fields.
Current source scalar, rotary, cache, storage, matrix, tagged source and ordinary
projection regressions pass. All source/binary/run identities, logs, commands,
traces and negative artifacts are recorded in
docs/evidence/decoder-bias-graph-2026-10-21/.

The standalone ownership proof mutates caller flag arrays, strings, bounds,
geometry/scalars and decoder policy after construction, then proves unchanged
owned graphs. Recipe policy snapshots remain independent of source-plan changes.
Repeated bad flags followed by fresh successful graph construction exercise40
in-process refusal/recovery cycles across two scalar paths. Read-only traces
verify descriptor cleanup, unchanged source bytes and no device/model payload
execution. Tiny independent source-vector addition checks evaluate only the
isolated synthetic primitive; no model/layer/attention forward is run.

Initial exploratory binaries and the earlier probe's stale legacy-harness case
are preserved. A new downstream probe reproduced the cache writer assumption
failure before correction; that negative receipt is retained. The first rebuild
was superseded while those consumer guards were extended, and its source-hash
check correctly refused a mixed snapshot. Final acceptance requires a fresh
unchanged source snapshot; no partial/mixed build is counted as final success.

## Remaining work toward the fixed target

This is source-bound mathematical compiler support, not numerical execution on
Hailo, complete ordinary architecture adaptation, immutable model identity,
physical memory placement/fit, device arithmetic/precision or an executable
original Hailo program. Complete activation/scaling/window/cache/training
semantics, source-to-graph integration, numerical configuration/packing/placement/
upload/activation/results/cleanup remain open. Broad model support remains the
fixed target. Missing operations/formats are implementation work, never permanent
eligibility restrictions. No DFC, outside compiler/machine, specially compiled
model workflow, CPU/CUDA/cloud LLM execution or inference proxy was introduced.

Whole-repository consistency remains failing: baseline18689/current19301;
all612 new diagnostics concern retained receipt paths, no new nonreceipt
issue after Markdown line normalization. Ledger census109 verified/154 IDs,
no duplicates. No historical master or whole-suite execution pass is claimed.
