# Explicit source-bound KV cache address scenarios

Date: 2026-10-20. Contract before implementation.
Parent: `TASK_hailo10h_source_compiler_plan.md`.
Public interface lead: `docs/HAILO10H_PUBLIC_LLM_COMPILER_INTERFACES.md`.

Consumer: the future SMIÐR placement/configuration builder, consuming the
existing dense semantic graph's persistent KV tensors. Implement original
typed token-major relative cache addressing as an explicit caller-selected
scenario. Preserve per-layer K/V identity, KV heads, capacity and distinct
key/value head widths. Require positive key/value element widths, explicit
row strides, alignment, pool budget and nonempty provenance; validate checked
products/sums, stride >= complete per-token entry and alignment, nonoverlap,
exact per-layer/aggregate bytes and source graph cache shape/identity.

Expose checked relative byte offsets for a requested layer, K/V selection,
slot, head and component. Logical head/capacity/component order must not be
silently equated with physical token-major storage. No default physical data
width/quantization/stride or resource budget is discovered/inferred. Return
owned values; retain no borrowed graph/source pointer. Source-dependent graph
mutations must reject before producing an apparently source-bound layout.

Acceptance: independent row-address arithmetic and exhaustive small slot/head/
component byte-range checks, distinct K/V widths, multiple layers, padding,
budget boundaries, overflow/invalid shapes/indices/alignment/stride/provenance,
malformed graph identity/alias refusals and returned ownership. Test structural
metadata only, with source fixtures unchanged. No cache/model/attention forward,
actual allocation/placement, ring state mutation, device write, upload or
CPU/CUDA/cloud/proxy inference. Report assumed mapping/hardware layout and
execution gates explicitly. Publish then continue ring/lifecycle and real
numerical program work toward the unchanged owner objective.
