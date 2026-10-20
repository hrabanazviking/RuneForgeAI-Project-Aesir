# Explicit source-bound KV address scenarios

Date: 2026-10-20. Contract: `TASK_hailo10h_cache_layout.md`.

## Interface and interpretation

Original Mojo `smidr/cache_layout.mojo` consumes a borrowed dense semantic
graph and explicit `CacheLayoutAssumptions`, returning owned `CacheLayout` /
`CacheRegion` snapshots. The graph's current cache shape is
`[slot, kv_head, component]`; the selected scenario assigns a padded contiguous
row per token, preserving distinct K/V dimensions and widths. Every layer's
key/value cache retains its source tensor/view identity. Regions occupy a
single relative pool in layer order, K then V, with no duplicate alias storage.
This is an explicit source-bound address scenario for a future SMIÐR output
builder, not a discovered or placed hardware layout.

Caller supplies positive K/V element widths, row strides, power-of-two
alignment, pool bound and nonempty provenance. Token bytes, padded region
sizes, per-layer totals and pool volume use checked Int64 arithmetic. Strides
must hold complete entries and satisfy assumed alignment; insufficient pool
rejects. No device budget, actual dtype, quantization or stride is inferred.
Neither payload nor a cache-sized buffer is allocated.

The planner validates cache/session dimensions; consumed K/V projection
binding shape/byte extent; unique graph tensor names; exact cache, writer and
view shapes; persistent ownership/retention; append input/output/alias identity;
writer/rotary key projection identity and view last uses. Unexpected persistent
tensors/aliases reject. This is a scoped cache-structure check, not a complete
graph/numerical typechecker or immutable-source certificate. Binding snapshots
remain observations, with no new protection against later file replacement or
concurrent source mutation.

`cache_element_offset` revalidates the returned layout (region identities,
source-ID bounds/uniqueness, dimensions, strides, exact sequential extents and
pool total) before returning a relative byte offset for region/slot/head/
component. A changed returned descriptor therefore cannot bypass range or
overlap checks. No pointer or physical device address is returned. Provenance
and all arrays survive destruction of the original graph/source owner.

## Acceptance

Warning-free Mojo 1.1.0 builds and targeted synthetic checks:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/cache_layout.mojo -o ../cache-layout
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine tests/hailo_cache_layout_api.mojo -o ../cache-layout-api
python3 tests/test_hailo_cache_layout.py --binary ../cache-layout --api-binary ../cache-layout-api --strace /usr/bin/strace --evidence docs/evidence/cache-layout-2026-10-20
```

Six methods pass, **89 native calls: 18 accepted and 71 refused**. Independent
address/interval oracles enumerate 3353 element offsets across sixteen small
accepted fixture scenarios, checking exact slot/head/component order, byte
span nonoverlap and all region origins/lengths. Fixtures span multiple layers,
GQA ratios, distinct K/V dimensions and widths, explicit padding/alignment,
exact entry strides, tied weights and past/query dimensions. Exact pool-bound
acceptance and one-byte-short refusal are tested.

Refusals cover invalid/overflowed policy/session dimensions, strides/widths/
alignment/provenance/budget, address indices and a diagnostic enumeration cap
that is explicitly a host-output bound. Forty-one malformed graph/returned
layout cases check ownership, source projection bindings, cache names/shapes/
lifetimes, append/writer identities, unknown persistent/alias tensors, duplicate
IDs, overlapping regions and changed extents. Returned ownership is tested
after graph destruction. Source SHA-256 values remain unchanged; the read-only
trace opens no Hailo node or CUDA/HailoRT/ggml library and performs no ioctl.
Evidence: `docs/evidence/cache-layout-2026-10-20/`. This is not full hosted CI.

## Remaining execution gates

Every inspector result labels the layout assumed_token_major and reports
hardware_layout_verified, source_fingerprint_verified, execution_tested and
device_access false. Source graph shape agreement does not establish physical
writer/reader agreement or device precision. Actual row format/conversions,
K/V quantization, cache-ID assignment, DMA channel/descriptor placement,
initialized-slot/ring state and absolute token/RoPE positions remain separate
work. No model/attention/cache data is evaluated or mutated on the host.

Continue original numerical CCW/register/configuration discovery under
`TASK_hailo10h_program_delivery.md`, using the pinned public compiler/cache
leads without copying external implementations or running their host model
forward/calibration pipeline. The original output builder still needs complete
metadata, payload integrity, placement, owned upload/configure, real numerical
hardware result and cleanup. The owner's broad source-model goal is unchanged.
