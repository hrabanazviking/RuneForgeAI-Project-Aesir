# Checked source-graph storage scenario

Date: 2026-10-19. Contract: `TASK_hailo10h_source_compiler_plan.md`.

## Implemented

`smidr/storage_estimate.mojo` consumes the typed source graph and an explicit
`StorageAssumptions` value. Every activation width, KV width, token/position
index width, allocation alignment, aggregate device-weight byte count,
aggregate workspace count, budget and provenance string is caller supplied.
Widths, weights and budget must be positive, workspace nonnegative, alignment
a positive power of two, and provenance nonempty. There is no machine memory,
precision or layout default. Supplied aggregate weights/workspace must include
whatever padding/duplication that scenario assumes; tensor alignment applies
to the individual graph tensors, not again to those aggregate counts.

Each owning tensor's shape product, width product, alignment rounding and
aggregate byte sum is overflow checked. Persistent K/V bases are counted for
the whole session. Cache append views alias them and own zero additional bytes.
External token/position input storage is retained for the whole scenario.
Activation births and inclusive last uses produce a checked event timeline.
Inputs and outputs coexist at an operation, so no unproven in-place reuse is
assumed. Logits remain live through the graph-end sentinel. Every timeline
value, tensor byte count, peak and first peak step is inspectable.

The API rechecks graph shape/products, lifetime ranges, persistent spans,
alias extents/shapes, operation indices, input availability and retained result.
This prevents caller mutations of public typed structures from quietly causing
unsafe accounting. It does not independently prove the model's semantics.

The total is persistent KV + retained inputs + peak live activation bytes +
assumed aggregate device weights + assumed aggregate workspace. Source packed
weight bytes are separately reported. They are never silently substituted for
converted/duplicated device weights. Tied source bindings are counted once in
the source snapshot; actual device storage still requires lowering evidence.

## Verification

Native tools build with Mojo 1.1.0:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/storage_estimate.mojo -o ../storage-estimate
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine tests/hailo_storage_api.mojo -o ../storage-api
python3 tests/test_hailo_storage_estimate.py --binary ../storage-estimate --graph-binary ../semantic-plan --api-binary ../storage-api --strace /usr/bin/strace --evidence docs/evidence/storage-estimate-2026-10-19
```

Seven independent Python methods passed, **61 native child runs**:

- 38 estimator calls: 23 accepted and 15 refused;
- nine source semantic-graph calls for the independent interval oracle;
- 14 direct native graph-mutation/arithmetic API refusals.

The oracle brute-force scans inclusive tensor intervals rather than repeating
the production event algorithm. Every allocation, live-byte timeline entry,
peak, total and budget comparison matches. It covers prefill, decode and cached
chunks; two layers; unequal K/V dimensions; four explicit width/alignment
policies; exact budget minus-one/equal/plus-one boundaries; tied weights; packed
quantization kinds; malformed policy; alignment/product/sum overflow; stale
lifetimes; forward/negative inputs; bad producers/outputs; cache alias cycles
and oversize views; invalid shapes; and a discarded result.

All synthetic source hashes remain unchanged. A syscall trace shows read-only
mapping/unmapping with no Hailo node or CUDA/HailoRT library access. Evidence:
`docs/evidence/storage-estimate-2026-10-19/`. No CPU LLM forward was run.

## Meaning and remaining work

`within_supplied_budget` compares a hypothetical arithmetic scenario only.
`hardware_fit_verified`, `device_allocation_performed` and
`complete_lowering_resource_plan` remain false even when that comparison passes.
Peak live byte volume is not a placed arena: fragmentation, fixed pools,
physical addresses, bank constraints, compiler/program overhead, actual device
precision/layout/weight conversion/workspace and measured available hardware
capacity remain unresolved. There is no inference admission consumer of the
comparison and no buffer/device allocation or compute submission.

The fixed goal remains source-model execution on Hailo-10H. Next: pinned public
activation/configuration interface facts, independent lowering/program payloads
only for corroborated encodings, and the first real numerical Hailo operation.
